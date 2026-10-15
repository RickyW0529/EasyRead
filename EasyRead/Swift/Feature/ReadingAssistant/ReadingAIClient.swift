// Copyright © 2026 EasyRead contributors. GPL-3.0.
import Alamofire
import EasyReadKit
import Foundation

// MARK: - ReadingAIClient

/// Streaming OpenAI-compatible chat for the unified reading card.
/// Consumes SSE chunk events while ignoring reasoning deltas, and rejects redirects
/// to keep credentials and selected text at the configured endpoint.
struct ReadingAIClient {
    // MARK: Lifecycle

    init(session: Session = ReadingAIClient.sharedSession) {
        self.session = session
    }

    // MARK: Internal

    func complete(configuration: ReadingAIConfiguration, system: String, prompt: String) async throws -> String {
        guard configuration.isReady, let url = configuration.completionURL else {
            throw QueryError(type: .parameter, message: String(localized: "reading.ai.invalid_configuration"))
        }
        var body: [String: Any] = [
            "model": configuration.model,
            "messages": [["role": "system", "content": system], ["role": "user", "content": prompt]],
            "stream": true,
        ]
        body[configuration.providerID == "openai" ? "max_completion_tokens" : "max_tokens"] = 8192
        // Reading assistance prioritizes latency. Only send the vendor's declared wire shape.
        switch configuration.provider.reasoning {
        case .thinkingType: body["thinking"] = ["type": "disabled"]
        case .enableThinking: body["enable_thinking"] = false
        case .providerDefault: break
        }
        var request = URLRequest(url: url, timeoutInterval: 50)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await stream(request, apiKey: configuration.apiKey)
    }

    func models(configuration: ReadingAIConfiguration) async throws -> [String] {
        guard let url = configuration.modelsURL,
              !configuration.provider.requiresAPIKey || !configuration.apiKey.isEmpty else {
            throw QueryError(type: .parameter, message: String(localized: "reading.ai.invalid_configuration"))
        }
        let data = try await send(URLRequest(url: url, timeoutInterval: 20), apiKey: configuration.apiKey)
        guard let response = try? JSONDecoder().decode(ModelsResponse.self, from: data) else {
            throw DeepSeekChatError.invalidResponse
        }
        return Array(Set(response.data.map { $0.id.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })).sorted()
    }

    // MARK: Private

    private struct StreamChunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable {
                // Unknown keys like `reasoning_content` are ignored by decoding only `content`.
                let content: String?
            }

            let delta: Delta?
            let finish_reason: String?
        }

        let choices: [Choice]
    }

    private struct ModelsResponse: Decodable {
        struct Model: Decodable { let id: String }

        let data: [Model]
    }

    private static let sharedSession: Session = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.timeoutIntervalForResource = 60
        return Session(configuration: configuration, redirectHandler: Redirector(behavior: .doNotFollow))
    }()

    private let session: Session

    /// Accumulates one streamed chat completion and returns the final message content.
    ///
    /// - Throws: The same mapped errors as the non-streaming path, plus `truncatedResponse`
    ///   when the server reports `finish_reason` "length".
    private func stream(_ original: URLRequest, apiKey: String) async throws -> String {
        try Task.checkCancellation()
        var request = original
        if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        let streamRequest = session.streamRequest(request)
        var eventParser = StreamEventParser()
        var content = ""
        var finishReason: String?
        var reachedDone = false
        var hasUndecodableEvent = false
        var consume: (String) -> () = { payload in
            if reachedDone { return }
            if payload == "[DONE]" {
                reachedDone = true
            } else if let chunk = try? JSONDecoder().decode(
                StreamChunk.self, from: Data(payload.utf8)
            ) {
                if let choice = chunk.choices.first {
                    if let delta = choice.delta?.content { content += delta }
                    if let reason = choice.finish_reason { finishReason = reason }
                }
            } else {
                // Deferred: an undecodable event must not mask the HTTP status mapping.
                hasUndecodableEvent = true
            }
        }

        for await streamEvent in streamRequest.streamTask().streamingData() {
            try Task.checkCancellation()
            switch streamEvent.event {
            case let .stream(.success(data)):
                for payload in eventParser.payloads(from: data) { consume(payload) }
            case let .stream(.failure(never)):
                // `streamingData()` uses `Failure == Never`; this case cannot occur.
                switch never {}
            case .complete:
                for payload in eventParser.flush() { consume(payload) }
            }
        }

        if let error = streamRequest.error { throw transportError(error) }
        if let status = streamRequest.response?.statusCode, !(200 ... 299).contains(status) {
            throw statusError(status)
        }
        if finishReason == "length" { throw DeepSeekChatError.truncatedResponse }
        if hasUndecodableEvent { throw DeepSeekChatError.invalidResponse }
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DeepSeekChatError.invalidResponse
        }
        return content
    }

    /// Non-streaming request used by the models listing; reading assistance streams.
    private func send(_ original: URLRequest, apiKey: String) async throws -> Data {
        try Task.checkCancellation()
        var request = original
        if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        let response = await session.request(request).serializingData(automaticallyCancelling: true).response
        try Task.checkCancellation()
        if let status = response.response?.statusCode, !(200 ... 299).contains(status) { throw statusError(status) }
        if let error = response.error { throw transportError(error) }
        guard let data = response.data else { throw DeepSeekChatError.invalidResponse }
        return data
    }

    private func statusError(_ status: Int) -> Error {
        switch status {
        case 401: DeepSeekChatError.invalidAPIKey
        case 402: DeepSeekChatError.insufficientBalance
        case 403: DeepSeekChatError.forbidden
        case 429: DeepSeekChatError.rateLimited(retryAfter: nil)
        default:
            // Never surface response bodies, which can echo credentials or selected text.
            QueryError(type: .api, message: String(localized: "reading.ai.http_error \(status)"))
        }
    }

    private func transportError(_ error: AFError) -> DeepSeekChatError {
        if (error.underlyingError as? URLError)?.code == .timedOut { return .timeout }
        return .network(code: (error.underlyingError as? URLError)?.code ?? .unknown)
    }
}

// MARK: - StreamEventParser

/// Extracts the `data:` payload of every complete SSE event from a raw byte stream.
///
/// Buffers bytes so chunk boundaries never split multi-byte UTF-8 or event delimiters;
/// comment lines such as `: keep-alive` produce no payload.
struct StreamEventParser {
    // MARK: Internal

    /// Feeds raw bytes and returns the data payload of every event that became complete.
    mutating func payloads(from data: Data) -> [String] {
        buffer.append(data)
        return drainCompleteEvents()
    }

    /// Returns the payload of a trailing event delivered without a final delimiter.
    mutating func flush() -> [String] {
        defer { buffer.removeAll(keepingCapacity: true) }
        guard let event = String(data: buffer, encoding: .utf8) else { return [] }
        return [event].compactMap(Self.dataPayload(of:))
    }

    // MARK: Private

    private static let eventDelimiters: [Data] = [Data([13, 10, 13, 10]), Data([10, 10]), Data([13, 13])]

    private var buffer = Data()

    private static func dataPayload(of event: String) -> String? {
        let dataLines = event
            .components(separatedBy: .newlines)
            .filter { $0.hasPrefix("data:") }
            .map { $0.dropFirst("data:".count).trimmingCharacters(in: .whitespaces) }
        guard !dataLines.isEmpty else { return nil }
        return dataLines.joined(separator: "\n")
    }

    private mutating func drainCompleteEvents() -> [String] {
        var payloads: [String] = []
        while let range = nextEventDelimiter() {
            let eventData = buffer.subdata(in: buffer.startIndex ..< range.lowerBound)
            buffer.removeSubrange(buffer.startIndex ..< range.upperBound)
            if let event = String(data: eventData, encoding: .utf8) {
                if let payload = Self.dataPayload(of: event) { payloads.append(payload) }
            }
        }
        return payloads
    }

    private func nextEventDelimiter() -> Range<Data.Index>? {
        Self.eventDelimiters.compactMap { delimiter in
            buffer.firstRange(of: delimiter)
        }.min { $0.lowerBound < $1.lowerBound }
    }
}
