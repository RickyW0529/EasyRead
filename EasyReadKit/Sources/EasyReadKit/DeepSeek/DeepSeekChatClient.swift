//
//  DeepSeekChatClient.swift
//  EasyReadKit
//
//  Created by wangruiqi on 2026/10/10.
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation

// MARK: - DeepSeekChatMessage

/// One message sent to DeepSeek's OpenAI-compatible /chat/completions endpoint.
public struct DeepSeekChatMessage: Equatable, Sendable {
    // MARK: Public

    public enum Role: String, Sendable {
        case system
        case user
        case assistant
    }

    public let role: Role
    public let content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}

// MARK: - DeepSeekChatError

/// Error taxonomy for DeepSeek chat requests (spec 4.4 and the degradation
/// matrix in section 11). Every case is classifiable from the HTTP status or
/// transport error alone, and the API key is never part of any payload.
public enum DeepSeekChatError: Error, Equatable, Sendable {
    /// No API key is stored — nothing was sent.
    case missingAPIKey
    /// HTTP 401 — the key is invalid or was revoked.
    case invalidAPIKey
    /// HTTP 403 — the key lacks permission for this resource.
    case forbidden
    /// HTTP 402 — the account is out of balance or quota.
    case insufficientBalance
    /// HTTP 429 — rate limited. `retryAfter` carries the server's
    /// `Retry-After` seconds when that header was present.
    case rateLimited(retryAfter: TimeInterval?)
    /// HTTP 5xx — server-side failure.
    case server(status: Int)
    /// Any other unexpected HTTP status (400, 404, ...).
    case unexpectedStatus(status: Int)
    /// Recoverable transport failure (connection lost, DNS, offline).
    case network(code: URLError.Code)
    /// The request exceeded its timeout budget.
    case timeout
    /// The response body was not decodable or carried no message content.
    case invalidResponse
    /// `finish_reason` was "length": the (JSON) output was truncated.
    case truncatedResponse
    /// The request was cancelled before completion.
    case cancelled
}

extension DeepSeekChatError {
    /// Whether the request may be retried (spec 4.4: 429, recoverable 5xx and
    /// transient network problems get at most 2 exponential-backoff retries;
    /// 401/403, invalid keys and decode failures never retry).
    var isRetryable: Bool {
        switch self {
        case .rateLimited, .server:
            true
        case .network(let code):
            Self.retryableNetworkCodes.contains(code)
        default:
            false
        }
    }

    /// Transport errors worth another attempt. Timeouts are deliberately not
    /// retried: one 15 s attempt already consumes the 20 s total budget.
    static let retryableNetworkCodes: Set<URLError.Code> = [
        .networkConnectionLost,
        .cannotConnectToHost,
        .dnsLookupFailed,
        .notConnectedToInternet,
    ]
}

// MARK: - DeepSeekChatClient

/// Non-streaming client for DeepSeek chat completions (spec 4.4).
///
/// Word explanation and sentence parsing need one complete JSON document, so
/// the client always sends `stream: false`, disables the thinking mode to keep
/// dictionary latency low, and can request `response_format: json_object`.
/// The endpoint, model name and API key are injected by the caller — this
/// type owns no secrets and hardcodes no model names.
public struct DeepSeekChatClient: Sendable {
    // MARK: Lifecycle

    public init(
        endpoint: URL,
        session: URLSession = DeepSeekChatClient.privateSession,
        configuration: Configuration = Configuration(),
        sleep: @escaping Sleeper = { seconds in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    ) {
        self.endpoint = endpoint
        self.session = session
        self.configuration = configuration
        self.sleep = sleep
    }

    /// In-memory transport without HTTP cache or cookies; source text never reaches disk caches.
    public static let privateSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration, delegate: OfficialRedirectPolicy(), delegateQueue: nil)
    }()

    // MARK: Public

    /// Tuning knobs; the defaults follow the spec's engineering targets
    /// (12–20 s total network budget, at most 2 retries).
    public struct Configuration: Sendable {
        /// Per-attempt network timeout.
        public var requestTimeout: TimeInterval = 15
        /// Total wall-clock budget across all attempts.
        public var totalTimeout: TimeInterval = 20
        /// Maximum number of retries after a retryable failure.
        public var maxRetries: Int = 2
        /// Base delay for exponential backoff (0.5 s, 1 s, ...).
        public var retryBaseDelay: TimeInterval = 0.5
        /// Upper bound for a server-provided `Retry-After` wait.
        public var maxRetryAfter: TimeInterval = 5

        public init() {}
    }

    /// Waits before a retry. Injectable so tests can record instead of sleep.
    public typealias Sleeper = @Sendable (TimeInterval) async throws -> Void

    /// Sends one chat completion request and returns the assistant message
    /// content. Throws `DeepSeekChatError` on any classified failure.
    ///
    /// - Parameters:
    ///   - model: model id, owned by the caller's central constant.
    ///   - messages: conversation (system prompt + user prompt).
    ///   - apiKey: the user's Keychain-stored key; sent only as a header.
    ///   - jsonOutput: request `response_format: {"type": "json_object"}`.
    public func complete(
        model: String,
        messages: [DeepSeekChatMessage],
        apiKey: String,
        jsonOutput: Bool = true
    ) async throws -> String {
        guard !apiKey.isEmpty else {
            throw DeepSeekChatError.missingAPIKey
        }

        let request = try makeRequest(
            model: model,
            messages: messages,
            apiKey: apiKey,
            jsonOutput: jsonOutput
        )

        let clock = ContinuousClock()
        let startedAt = clock.now
        var retry = 0

        while true {
            if Task.isCancelled {
                throw DeepSeekChatError.cancelled
            }

            do {
                let elapsed = Self.seconds(startedAt.duration(to: clock.now))
                let remaining = configuration.totalTimeout - elapsed
                guard remaining > 0 else { throw DeepSeekChatError.timeout }
                var attempt = request
                attempt.timeoutInterval = min(configuration.requestTimeout, remaining)
                return try await sendWithDeadline(attempt, remaining: remaining)
            } catch let error as DeepSeekChatError {
                retry += 1
                guard retry <= configuration.maxRetries, error.isRetryable else {
                    throw error
                }

                let delay = retryDelay(for: error, retry: retry)
                let elapsed = Self.seconds(startedAt.duration(to: clock.now))
                guard elapsed + delay <= configuration.totalTimeout else {
                    throw error
                }

                do {
                    try await sleep(delay)
                } catch {
                    throw DeepSeekChatError.cancelled
                }
            }
        }
    }

    // MARK: Private

    private let endpoint: URL
    private let session: URLSession
    private let configuration: Configuration
    private let sleep: Sleeper

    /// Request body mirrored after the spec's protocol example (section 4.4):
    /// `thinking` is always disabled for low-latency reading assistance and
    /// `response_format` is only present for structured-JSON tasks.
    private struct RequestBody: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        struct Thinking: Encodable {
            let type = "disabled"
        }

        struct ResponseFormat: Encodable {
            let type = "json_object"
        }

        let model: String
        let messages: [Message]
        let stream = false
        let maxTokens = 4096
        let thinking = Thinking()
        let responseFormat: ResponseFormat?

        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case stream
            case maxTokens = "max_tokens"
            case thinking
            case responseFormat = "response_format"
        }
    }

    /// Non-streaming chat completion response; only the fields EasyRead
    /// consumes are decoded.
    private struct ResponseBody: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }

            let message: Message?
            let finishReason: String?

            enum CodingKeys: String, CodingKey {
                case message
                case finishReason = "finish_reason"
            }
        }

        let choices: [Choice]?
    }

    private func makeRequest(
        model: String,
        messages: [DeepSeekChatMessage],
        apiKey: String,
        jsonOutput: Bool
    ) throws -> URLRequest {
        let requestBody = RequestBody(
            model: model,
            messages: messages.map { .init(role: $0.role.rawValue, content: $0.content) },
            responseFormat: jsonOutput ? .init() : nil
        )

        var request = URLRequest(url: endpoint, timeoutInterval: configuration.requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)
        return request
    }

    /// One attempt: transport, HTTP status classification and body decoding.
    private func sendOnce(_ request: URLRequest) async throws -> String {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw DeepSeekChatError.cancelled
        } catch let error as URLError {
            throw Self.classify(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepSeekChatError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ... 299:
            break
        case 401:
            throw DeepSeekChatError.invalidAPIKey
        case 402:
            throw DeepSeekChatError.insufficientBalance
        case 403:
            throw DeepSeekChatError.forbidden
        case 429:
            throw DeepSeekChatError.rateLimited(retryAfter: Self.retryAfter(from: httpResponse))
        case 500 ... 599:
            throw DeepSeekChatError.server(status: httpResponse.statusCode)
        default:
            throw DeepSeekChatError.unexpectedStatus(status: httpResponse.statusCode)
        }

        let body: ResponseBody
        do {
            body = try JSONDecoder().decode(ResponseBody.self, from: data)
        } catch {
            throw DeepSeekChatError.invalidResponse
        }

        // finish_reason "length" means the output was cut off: a JSON
        // document truncated mid-way must not reach the parser (spec 4.4).
        if body.choices?.first?.finishReason == "length" {
            throw DeepSeekChatError.truncatedResponse
        }

        guard let content = body.choices?.first?.message?.content, !content.isEmpty else {
            throw DeepSeekChatError.invalidResponse
        }

        return content
    }

    /// URLRequest timeouts measure inactivity; an independent deadline bounds a slow trickle too.
    private func sendWithDeadline(_ request: URLRequest, remaining: TimeInterval) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask { try await sendOnce(request) }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                throw DeepSeekChatError.timeout
            }
            defer { group.cancelAll() }
            guard let answer = try await group.next() else { throw DeepSeekChatError.invalidResponse }
            if Task.isCancelled { throw DeepSeekChatError.cancelled }
            return answer
        }
    }

    private static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    private func retryDelay(for error: DeepSeekChatError, retry: Int) -> TimeInterval {
        if case .rateLimited(let retryAfter) = error, let retryAfter {
            return min(max(retryAfter, 0), configuration.maxRetryAfter)
        }
        return configuration.retryBaseDelay * pow(2, Double(retry - 1))
    }

    private static func classify(_ error: URLError) -> DeepSeekChatError {
        switch error.code {
        case .timedOut:
            .timeout
        case .cancelled:
            .cancelled
        default:
            .network(code: error.code)
        }
    }

    /// `Retry-After` in seconds; the HTTP-date form is not used by DeepSeek
    /// and is ignored.
    private static func retryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        guard let header = response.value(forHTTPHeaderField: "Retry-After") else {
            return nil
        }
        guard let seconds = TimeInterval(header.trimmingCharacters(in: .whitespaces)), seconds.isFinite else { return nil }
        return seconds
    }
}

/// Do not forward a reading payload to another host through a redirect.
private final class OfficialRedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        let allowed = request.url?.scheme == "https" && request.url?.host == "api.deepseek.com"
        completionHandler(allowed ? request : nil)
    }
}
