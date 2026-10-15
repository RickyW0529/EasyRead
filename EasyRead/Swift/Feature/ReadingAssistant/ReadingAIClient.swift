// Copyright © 2026 EasyRead contributors. GPL-3.0.
import Alamofire
import EasyReadKit
import Foundation

/// Non-streaming OpenAI-compatible chat for the unified reading card.
/// Uses an ephemeral session and rejects redirects to keep credentials and selected text at the configured endpoint.
struct ReadingAIClient {
    // MARK: Internal

    func complete(configuration: ReadingAIConfiguration, system: String, prompt: String) async throws -> String {
        guard configuration.isReady, let url = configuration.completionURL else {
            throw QueryError(type: .parameter, message: String(localized: "reading.ai.invalid_configuration"))
        }
        var body: [String: Any] = [
            "model": configuration.model,
            "messages": [["role": "system", "content": system], ["role": "user", "content": prompt]],
            "stream": false,
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
        let data = try await send(request, apiKey: configuration.apiKey)
        guard let response = try? JSONDecoder().decode(ChatResponse.self, from: data),
              let choice = response.choices.first else { throw DeepSeekChatError.invalidResponse }
        if choice.finish_reason == "length" { throw DeepSeekChatError.truncatedResponse }
        guard let content = choice.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DeepSeekChatError.invalidResponse
        }
        return content
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

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }

            let message: Message
            let finish_reason: String?
        }

        let choices: [Choice]
    }

    private struct ModelsResponse: Decodable {
        struct Model: Decodable { let id: String }

        let data: [Model]
    }

    private static let session: Session = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.timeoutIntervalForResource = 60
        return Session(configuration: configuration, redirectHandler: Redirector(behavior: .doNotFollow))
    }()

    private func send(_ original: URLRequest, apiKey: String) async throws -> Data {
        try Task.checkCancellation()
        var request = original
        if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        let response = await Self.session.request(request).serializingData(automaticallyCancelling: true).response
        try Task.checkCancellation()
        if let status = response.response?.statusCode, !(200 ... 299).contains(status) {
            switch status {
            case 401: throw DeepSeekChatError.invalidAPIKey
            case 402: throw DeepSeekChatError.insufficientBalance
            case 403: throw DeepSeekChatError.forbidden
            case 429: throw DeepSeekChatError.rateLimited(retryAfter: nil)
            default:
                // Never surface response bodies, which can echo credentials or selected text.
                throw QueryError(type: .api, message: String(localized: "reading.ai.http_error \(status)"))
            }
        }
        if let error = response.error {
            if (error.underlyingError as? URLError)?.code == .timedOut { throw DeepSeekChatError.timeout }
            throw DeepSeekChatError.network(code: (error.underlyingError as? URLError)?.code ?? .unknown)
        }
        guard let data = response.data else { throw DeepSeekChatError.invalidResponse }
        return data
    }
}
