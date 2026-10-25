//
//  DeepSeekService.swift
//  EasyRead
//
//  Created by GarethNg on 2025/2/19.
//  Copyright © 2025 izual. All rights reserved.
//

import Combine
import Defaults
import EasyReadKit
import Foundation

// MARK: - DeepSeekService

/// DeepSeek translation service. Layers DeepSeek V4 reasoning parameters
/// (`thinking.type` and `reasoning_effort`) on top of the OpenAI-compatible
/// streaming pipeline as a model-agnostic per-service setting, so current
/// and future DeepSeek models opt in without code changes.
@objc(EZDeepSeekService)
class DeepSeekService: OpenAIService {
    // MARK: Lifecycle

    required public init() {
        super.init()
        Defaults.publisher(.enableReadingAI).sink { [weak self] change in
            if !change.newValue { self?.cancelStream() }
        }.store(in: &privacyObservers)
        Defaults.publisher(serviceUsageStatusKey).sink { [weak self] change in
            if change.newValue == .alwaysOff { self?.cancelStream() }
        }.store(in: &privacyObservers)
        Defaults.publisher(.contextExtractionExcludedApps).sink { [weak self] _ in
            self?.cancelStream()
        }.store(in: &privacyObservers)
        Defaults.publisher(.enableContextExtraction).sink { [weak self] change in
            if !change.newValue {
                ContextExtractionCoordinator.shared.store.clear()
                self?.cancelStream()
            }
        }.store(in: &privacyObservers)
        Defaults.publisher(.deepSeekAPIKeyMirror).sink { [weak self] _ in
            self?.cancelStream()
        }.store(in: &privacyObservers)
    }

    // MARK: Public

    public override func cancelStream() {
        updateResultLock.withLock { currentTask?.cancel() }
    }

    public override func name() -> String {
        NSLocalizedString("deepseek_translate", comment: "")
    }

    public override func serviceType() -> ServiceType {
        .deepSeek
    }

    public override func link() -> String? {
        "https://www.deepseek.com/"
    }

    /// The DeepSeek section replaces the plaintext API-key input with a
    /// Keychain-backed cell.
    public override func configurationListItems() -> Any? {
        _ = apiKey // Migrate legacy storage before the settings cell checks key presence.
        return StreamConfigurationView(
            service: self, usesKeychainAPIKey: true, showEndpointSection: false,
            showCustomPromptSection: false, showThinkTagContent: false
        )
    }

    // MARK: Internal

    /// Where the user's API key lives: the macOS Keychain, never
    /// UserDefaults, the database, crash reports or logs (spec 7.2).
    static let keychain = KeychainStore(
        service: "com.easyread.EasyRead.apikey",
        account: "deepseek"
    )

    /// The reading card owns automatic analysis; this legacy service remains available for manual queries.
    override var enabledAutoQuery: Bool {
        get { false }
        set { super.enabledAutoQuery = newValue }
    }

    override var endpoint: String { defaultEndpoint }

    /// The Keychain is the source of truth for the API key. Upstream
    /// Easydict stored it in UserDefaults; a legacy value is migrated to
    /// the Keychain and the plaintext copy is cleared on first read.
    override var apiKey: String {
        migrateLegacyAPIKeyIfNeeded()
        do {
            return try Self.keychain.read() ?? ""
        } catch {
            // Status code only — the secret is never part of the error.
            logError("DeepSeek API key Keychain read failed: \(error)")
            return ""
        }
    }

    /// The shared validation-button logic observes Defaults keys, which
    /// cannot see the Keychain, so it observes the non-sensitive mirror
    /// instead (see `Defaults.Keys.deepSeekAPIKeyMirror`).
    override var observeKeys: [Defaults.Key<String>] {
        [.deepSeekAPIKeyMirror, supportedModelsKey]
    }

    override var defaultModels: [String] {
        DeepSeekModel.allCases.map(\.rawValue)
    }

    override var defaultModel: String {
        DeepSeekModel.deepseekFlash.rawValue
    }

    /// EasyRead ships AI auto-query off by default: without an API key no request
    /// may leave the machine, and even with one, explanations should be opt-in.
    override var serviceUsageStatusKey: Defaults.Key<ServiceUsageStatus> {
        serviceDefaultsKey(.serviceUsageStatus, defaultValue: .alwaysOff)
    }

    /// EasyRead: in-context word explanation is the core feature, so DeepSeek
    /// opts into the dictionary query type by default (spec 3.2/T03) — a
    /// selected English word/phrase then answers through the structured
    /// explanation pipeline instead of a plain translation. The service
    /// itself stays `alwaysOff` until the user enables it with a key.
    override var isDictionaryEnabledByDefault: Bool {
        true
    }

    override var defaultEndpoint: String {
        "https://api.deepseek.com/v1/chat/completions"
    }

    override var remoteModelsEndpoint: String? {
        "https://api.deepseek.com/models"
    }

    override var remoteModelFetchRequiresEndpoint: Bool {
        false
    }

    /// DeepSeek V4 supports reasoning effort, exposing the shared picker and
    /// sending `thinking` and `reasoning_effort` to the API.
    override var supportsReasoningEffort: Bool {
        true
    }

    /// The in-flight request task. Internal (not private) so the
    /// word-explanation extension file can cancel and replace it.
    var currentTask: Task<(), Never>?

    override func contentStreamTranslate(
        _ text: String,
        from: Language,
        to: Language
    )
        -> AsyncThrowingStream<String, Error> {
        guard Defaults[.enableReadingAI], SelectionPolicy.default.validateSelection(text).isUsable,
              AXContextExtractor.allowsAI(snapshot: queryModel.contextSnapshot) else {
            return AsyncThrowingStream { $0.finish(throwing: CancellationError()) }
        }
        // EasyRead Phase 3c (spec 3.2/4.4/5.1): English word/phrase lookups
        // with captured reading context answer with one structured
        // in-context explanation instead of a streaming translation.
        if let explanationStream = wordExplanationStreamIfAvailable(
            text: text,
            from: from,
            to: to
        ) {
            return explanationStream
        }

        return AsyncThrowingStream { continuation in
            guard let url = URL(string: endpoint), url.isValid else {
                continuation.finish(
                    throwing: QueryError(
                        type: .parameter,
                        message: "`\(serviceType().rawValue)` endpoint is invalid"
                    )
                )
                return
            }

            guard !apiKey.isEmpty else {
                continuation.finish(
                    throwing: QueryError(type: .missingSecretKey, message: "API key is empty")
                )
                return
            }

            if let currentTask, !currentTask.isCancelled {
                currentTask.cancel()
            }

            let task = Task {
                do {
                    try Task.checkCancellation()
                    guard Defaults[.enableReadingAI], !apiKey.isEmpty,
                          AXContextExtractor.allowsAI(snapshot: queryModel.contextSnapshot) else {
                        throw CancellationError()
                    }
                    let queryType = queryType(text: text, from: from, to: to)
                    let chatQueryParam = ChatQueryParam(
                        text: text,
                        sourceLanguage: from,
                        targetLanguage: to,
                        queryType: queryType,
                        enableSystemPrompt: true
                    )
                    let request = try makeChatRequest(
                        url: url,
                        messages: chatMessageDicts(chatQueryParam)
                    )

                    let (asyncBytes, response) = try await DeepSeekChatClient.privateSession.bytes(for: request)
                    try validateHTTPResponse(response)
                    try await processStreamBytes(asyncBytes, continuation: continuation)
                    continuation.finish()
                } catch is CancellationError {
                    logInfo("DeepSeek task was cancelled.")
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            currentTask = task
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// EasyRead "测试连接" (spec 4.4): one minimal non-streaming chat request
    /// through `DeepSeekChatClient` — cheap, cancellable and classified into
    /// distinct localized failure messages — instead of the shared streaming
    /// translation used by other services.
    func validateConnection() async -> QueryResult {
        resetServiceResult()

        let result = QueryResult()

        guard let url = URL(string: endpoint), url.isValid else {
            result.error = QueryError(
                type: .parameter,
                message: "`\(serviceType().rawValue)` endpoint is invalid"
            )
            return result
        }

        do {
            let client = DeepSeekChatClient(endpoint: url)
            _ = try await client.complete(
                model: model,
                messages: [.init(role: .user, content: "Hi")],
                apiKey: apiKey,
                jsonOutput: false
            )
        } catch let error as DeepSeekChatError {
            result.error = error.queryError
        } catch {
            result.error = QueryError.queryError(from: error)
        }

        return result
    }

    // MARK: Private

    private var privacyObservers: Set<AnyCancellable> = []

    /// Moves a legacy plaintext key (upstream Easydict stored it in
    /// UserDefaults) into the Keychain exactly once, then clears the
    /// plaintext value and sets the mirror. The race of two concurrent
    /// reads is benign: both write the same value and the second save is
    /// a plain replace.
    private func migrateLegacyAPIKeyIfNeeded() {
        let legacyKey = Defaults[apiKeyKey]
        guard !legacyKey.isEmpty else {
            return
        }
        do {
            if try Self.keychain.read() == nil {
                try Self.keychain.save(legacyKey)
            }
            Defaults[apiKeyKey] = ""
            Defaults[.deepSeekAPIKeyMirror] = "1"
        } catch {
            // Keep the legacy value for a later retry; status code only.
            logError("DeepSeek API key Keychain migration failed: \(error)")
        }
    }

    private func makeChatRequest(url: URL, messages: [ChatMessage]) throws -> URLRequest {
        let effort = configuredReasoningEffort
        let requestBody = DeepSeekChatRequest(
            messages: messages.map(DeepSeekChatMessage.init),
            model: model,
            temperature: temperature,
            stream: true,
            thinking: .init(type: effort.isEnabled ? "enabled" : "disabled"),
            reasoningEffort: effort.requestValue
        )

        var request = URLRequest(
            url: url, timeoutInterval: SharedConstants.llmRequestTimeoutInterval
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)
        return request
    }

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw QueryError(type: .api, message: "Invalid DeepSeek response")
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw QueryError(type: .api, message: "HTTP \(httpResponse.statusCode)")
        }
    }

    private func processStreamBytes(
        _ asyncBytes: URLSession.AsyncBytes,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        var dataBuffer = Data()
        var textBuffer = ""

        for try await byte in asyncBytes {
            try Task.checkCancellation()
            dataBuffer.append(byte)

            guard byte == 0x0A else {
                continue
            }

            if let text = String(data: dataBuffer, encoding: .utf8) {
                textBuffer.append(text)
                dataBuffer.removeAll()
                processCompleteEvents(from: &textBuffer, continuation: continuation)
            }
        }

        if !dataBuffer.isEmpty, let text = String(data: dataBuffer, encoding: .utf8) {
            textBuffer.append(text)
        }
        processCompleteEvents(from: &textBuffer, continuation: continuation)
    }

    private func processCompleteEvents(
        from textBuffer: inout String,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) {
        textBuffer = textBuffer.replacingOccurrences(of: "\r\n", with: "\n")
        let eventSeparator = "\n\n"
        guard textBuffer.contains(eventSeparator) else { return }

        let parts = textBuffer.split(separator: eventSeparator, omittingEmptySubsequences: false)
        textBuffer = String(parts.last ?? "")

        for event in parts.dropLast() where !event.isEmpty {
            guard let content = parseSSEEvent(String(event)) else { continue }
            continuation.yield(content)
        }
    }

    private func parseSSEEvent(_ event: String) -> String? {
        let dataPrefix = "data:"
        let doneFlag = "[DONE]"
        var dataString = ""

        for line in event.split(separator: "\n") where line.starts(with: dataPrefix) {
            let payload = line.dropFirst(dataPrefix.count).trimmingCharacters(in: .whitespaces)
            guard payload != doneFlag else { return nil }
            dataString += payload
        }

        guard !dataString.isEmpty,
              let data = dataString.data(using: .utf8)
        else {
            return nil
        }

        guard let chunk = try? JSONDecoder().decode(DeepSeekStreamChunk.self, from: data) else {
            // Length only: the SSE payload may contain model output, which
            // must never be written to logs (spec 7.4).
            logError("Failed to decode DeepSeek SSE data (\(dataString.count) bytes)")
            return nil
        }

        return chunk.choices.first?.delta.content
    }
}

// MARK: - DeepSeekModel

enum DeepSeekModel: String, CaseIterable {
    // Docs: https://api-docs.deepseek.com
    // Pricing: https://api-docs.deepseek.com/quick_start/pricing
    case deepseekFlash = "deepseek-flash"
    case deepseekV4Pro = "deepseek-v4-pro"
}

// MARK: - DeepSeekChatRequest

/// Encodable chat-completions payload for DeepSeek. Mirrors the OpenAI-
/// compatible fields EasyRead already uses and adds DeepSeek V4's `thinking`
/// and `reasoning_effort` parameters.
private struct DeepSeekChatRequest: Encodable {
    // MARK: Internal

    let messages: [DeepSeekChatMessage]
    let model: String
    let temperature: Double
    let stream: Bool
    let thinking: DeepSeekThinking
    let reasoningEffort: String?

    // MARK: Private

    private enum CodingKeys: String, CodingKey {
        case messages
        case model
        case temperature
        case stream
        case thinking
        case reasoningEffort = "reasoning_effort"
    }
}

// MARK: - DeepSeekChatMessage

/// Minimal chat message shape accepted by DeepSeek's OpenAI-compatible
/// endpoint, built from EasyRead's provider-agnostic prompt messages.
private struct DeepSeekChatMessage: Encodable {
    // MARK: Lifecycle

    init(_ message: ChatMessage) {
        self.role = message.role.rawValue
        self.content = message.content
    }

    // MARK: Internal

    let role: String
    let content: String
}

// MARK: - DeepSeekThinking

/// DeepSeek V4 thinking mode switch. The effort level is encoded separately
/// because the API keeps `thinking.type` and `reasoning_effort` as sibling
/// parameters.
private struct DeepSeekThinking: Encodable {
    let type: String
}

// MARK: - DeepSeekStreamChunk

/// Streaming chat-completions chunk returned by DeepSeek. Only the assistant
/// content delta is needed for EasyRead's text output pipeline.
private struct DeepSeekStreamChunk: Decodable {
    struct Choice: Decodable {
        let delta: Delta
    }

    struct Delta: Decodable {
        let content: String?
    }

    let choices: [Choice]
}
