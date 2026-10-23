//
//  DeepSeekChatClientTests.swift
//  EasyReadKit
//
//  Created by wangruiqi on 2026/10/10.
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation
import Testing

@testable import EasyReadKit

// MARK: - MockURLProtocol

/// Intercepts every request of a test's URLSession. The handler and counter
/// are static, so the suite below is `.serialized`.
final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        MockURLProtocol.requestCount += 1

        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - LockedBox

/// Lock-protected mutable box for values written on the session queue and
/// read by the test after `await` completes.
final class LockedBox<T> {
    // MARK: Lifecycle

    init(_ value: T) {
        self.value = value
    }

    // MARK: Internal

    func set(_ newValue: T) {
        lock.lock()
        value = newValue
        lock.unlock()
    }

    func get() -> T {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    // MARK: Private

    private let lock = NSLock()
    private var value: T
}

// MARK: - SleepRecorder

/// Records backoff delays instead of sleeping. Lock-protected, so the
/// `@Sendable` sleeper closure can safely capture it.
final class SleepRecorder: @unchecked Sendable {
    // MARK: Internal

    var delays: [TimeInterval] {
        lock.lock()
        defer { lock.unlock() }
        return recordedDelays
    }

    var sleep: DeepSeekChatClient.Sleeper {
        { delay in
            self.record(delay)
        }
    }

    // MARK: Private

    private let lock = NSLock()
    private var recordedDelays: [TimeInterval] = []

    private func record(_ delay: TimeInterval) {
        lock.lock()
        recordedDelays.append(delay)
        lock.unlock()
    }
}

// MARK: - URLRequest + Body

extension URLRequest {
    /// URLProtocol sees the request body as a stream, not `httpBody`.
    var bodyData: Data? {
        if let httpBody {
            return httpBody
        }
        guard let stream = httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let capacity = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: capacity)
            if read <= 0 {
                break
            }
            data.append(buffer, count: read)
        }
        return data
    }
}

// MARK: - DeepSeekChatClientTests

/// URLProtocol-backed tests for the non-streaming DeepSeek client (spec 4.4):
/// request shape, error taxonomy, retry policy and cancellation. No real
/// network traffic leaves the machine and no real API key is used.
@Suite(.serialized)
final class DeepSeekChatClientTests {
    // MARK: Lifecycle

    init() {
        MockURLProtocol.handler = nil
        MockURLProtocol.requestCount = 0
    }

    deinit {
        sessions.forEach { $0.finishTasksAndInvalidate() }
    }

    // MARK: Internal

    // MARK: - Success and request shape

    @Test
    func successReturnsContentAndBuildsSpecCompliantRequest() async throws {
        let requestBox = LockedBox<URLRequest?>(nil)
        MockURLProtocol.handler = { request in
            requestBox.set(request)
            return (
                Self.httpResponse(status: 200),
                Self.responseData(content: #"{"primaryMeaningZh":"进程"}"#)
            )
        }

        let client = makeClient()
        let content = try await client.complete(
            model: "deepseek-v4-flash",
            messages: [
                .init(role: .system, content: "You are a reading tutor."),
                .init(role: .user, content: "Explain 'process'."),
            ],
            apiKey: "sk-test-secret-1234"
        )

        #expect(content == #"{"primaryMeaningZh":"进程"}"#)

        let request = try #require(requestBox.get())
        #expect(request.httpMethod == "POST")
        #expect(request.url == Self.endpoint)
        #expect(request.timeoutInterval == 15)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test-secret-1234")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let bodyData = try #require(request.bodyData)
        let body = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        #expect(body["model"] as? String == "deepseek-v4-flash")
        #expect(body["stream"] as? Bool == false)
        #expect((body["thinking"] as? [String: Any])?["type"] as? String == "disabled")
        #expect((body["response_format"] as? [String: Any])?["type"] as? String == "json_object")

        let messages = try #require(body["messages"] as? [[String: Any]])
        #expect(messages.count == 2)
        #expect(messages[0]["role"] as? String == "system")
        #expect(messages[0]["content"] as? String == "You are a reading tutor.")
        #expect(messages[1]["role"] as? String == "user")
        #expect(messages[1]["content"] as? String == "Explain 'process'.")

        // The key must travel only in the Authorization header (T08: no key
        // in the body, which is what could end up in logs or error reports).
        let bodyString = String(data: bodyData, encoding: .utf8) ?? ""
        #expect(!bodyString.contains("sk-test-secret-1234"))
    }

    @Test
    func jsonOutputFalseOmitsResponseFormat() async throws {
        let requestBox = LockedBox<URLRequest?>(nil)
        MockURLProtocol.handler = { request in
            requestBox.set(request)
            return (Self.httpResponse(status: 200), Self.responseData(content: "pong"))
        }

        let client = makeClient()
        let content = try await client.complete(
            model: "deepseek-v4-flash",
            messages: [.init(role: .user, content: "ping")],
            apiKey: "sk-test",
            jsonOutput: false
        )

        #expect(content == "pong")

        let request = try #require(requestBox.get())
        let bodyData = try #require(request.bodyData)
        let body = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        #expect(body["response_format"] == nil)
        #expect(body["stream"] as? Bool == false)
    }

    @Test
    func missingAPIKeyThrowsWithoutSending() async {
        let client = makeClient()

        await #expect(throws: DeepSeekChatError.missingAPIKey) {
            try await client.complete(
                model: "deepseek-v4-flash",
                messages: [.init(role: .user, content: "ping")],
                apiKey: ""
            )
        }
        #expect(MockURLProtocol.requestCount == 0)
    }

    // MARK: - Error taxonomy (T08)

    @Test
    func unauthorizedIsNotRetried() async {
        MockURLProtocol.handler = { _ in
            (Self.httpResponse(status: 401), Self.responseData(content: nil))
        }

        let client = makeClient(sleep: SleepRecorder().sleep)
        await #expect(throws: DeepSeekChatError.invalidAPIKey) {
            try await client.complete(
                model: "m", messages: [.init(role: .user, content: "hi")], apiKey: "sk-test"
            )
        }
        #expect(MockURLProtocol.requestCount == 1)
    }

    @Test
    func forbiddenIsNotRetried() async {
        MockURLProtocol.handler = { _ in
            (Self.httpResponse(status: 403), Self.responseData(content: nil))
        }

        let client = makeClient(sleep: SleepRecorder().sleep)
        await #expect(throws: DeepSeekChatError.forbidden) {
            try await client.complete(
                model: "m", messages: [.init(role: .user, content: "hi")], apiKey: "sk-test"
            )
        }
        #expect(MockURLProtocol.requestCount == 1)
    }

    @Test
    func insufficientBalanceIsNotRetried() async {
        MockURLProtocol.handler = { _ in
            (Self.httpResponse(status: 402), Self.responseData(content: nil))
        }

        let client = makeClient(sleep: SleepRecorder().sleep)
        await #expect(throws: DeepSeekChatError.insufficientBalance) {
            try await client.complete(
                model: "m", messages: [.init(role: .user, content: "hi")], apiKey: "sk-test"
            )
        }
        #expect(MockURLProtocol.requestCount == 1)
    }

    @Test
    func unexpectedStatusIsNotRetried() async {
        MockURLProtocol.handler = { _ in
            (Self.httpResponse(status: 400), Self.responseData(content: nil))
        }

        let client = makeClient(sleep: SleepRecorder().sleep)
        await #expect(throws: DeepSeekChatError.unexpectedStatus(status: 400)) {
            try await client.complete(
                model: "m", messages: [.init(role: .user, content: "hi")], apiKey: "sk-test"
            )
        }
        #expect(MockURLProtocol.requestCount == 1)
    }

    @Test
    func timeoutIsNotRetried() async {
        MockURLProtocol.handler = { _ in
            throw URLError(.timedOut)
        }

        let client = makeClient(sleep: SleepRecorder().sleep)
        await #expect(throws: DeepSeekChatError.timeout) {
            try await client.complete(
                model: "m", messages: [.init(role: .user, content: "hi")], apiKey: "sk-test"
            )
        }
        #expect(MockURLProtocol.requestCount == 1)
    }

    // MARK: - Response decoding (T07: malformed output never reaches callers)

    @Test
    func malformedBodyThrowsInvalidResponse() async {
        MockURLProtocol.handler = { _ in
            (Self.httpResponse(status: 200), Data("not json".utf8))
        }

        let client = makeClient()
        await #expect(throws: DeepSeekChatError.invalidResponse) {
            try await client.complete(
                model: "m", messages: [.init(role: .user, content: "hi")], apiKey: "sk-test"
            )
        }
    }

    @Test
    func missingChoicesThrowsInvalidResponse() async {
        MockURLProtocol.handler = { _ in
            (Self.httpResponse(status: 200), Data(#"{"id":"chat-1"}"#.utf8))
        }

        let client = makeClient()
        await #expect(throws: DeepSeekChatError.invalidResponse) {
            try await client.complete(
                model: "m", messages: [.init(role: .user, content: "hi")], apiKey: "sk-test"
            )
        }
    }

    @Test
    func emptyContentThrowsInvalidResponse() async {
        MockURLProtocol.handler = { _ in
            (Self.httpResponse(status: 200), Self.responseData(content: ""))
        }

        let client = makeClient()
        await #expect(throws: DeepSeekChatError.invalidResponse) {
            try await client.complete(
                model: "m", messages: [.init(role: .user, content: "hi")], apiKey: "sk-test"
            )
        }
    }

    @Test
    func truncatedOutputThrowsTruncatedResponse() async {
        MockURLProtocol.handler = { _ in
            (Self.httpResponse(status: 200), Self.responseData(
                content: #"{"primaryMeaning""#,
                finishReason: "length"
            ))
        }

        let client = makeClient()
        await #expect(throws: DeepSeekChatError.truncatedResponse) {
            try await client.complete(
                model: "m", messages: [.init(role: .user, content: "hi")], apiKey: "sk-test"
            )
        }
    }

    // MARK: - Retry policy (spec 4.4)

    @Test
    func rateLimitedRetriesWithExponentialBackoffAndSucceeds() async throws {
        let responses: [(HTTPURLResponse, Data)] = [
            (Self.httpResponse(status: 429), Self.responseData(content: nil)),
            (Self.httpResponse(status: 429), Self.responseData(content: nil)),
            (Self.httpResponse(status: 200), Self.responseData(content: "ok")),
        ]
        var index = 0
        MockURLProtocol.handler = { _ in
            let response = responses[min(index, responses.count - 1)]
            index += 1
            return response
        }

        let sleepRecorder = SleepRecorder()
        let client = makeClient(sleep: sleepRecorder.sleep)

        let content = try await client.complete(
            model: "m", messages: [.init(role: .user, content: "hi")], apiKey: "sk-test"
        )

        #expect(content == "ok")
        #expect(MockURLProtocol.requestCount == 3)
        #expect(sleepRecorder.delays == [0.5, 1.0])
    }

    @Test
    func rateLimitedStopsAfterMaxRetries() async {
        MockURLProtocol.handler = { _ in
            (Self.httpResponse(status: 429), Self.responseData(content: nil))
        }

        let sleepRecorder = SleepRecorder()
        let client = makeClient(sleep: sleepRecorder.sleep)

        await #expect(throws: DeepSeekChatError.rateLimited(retryAfter: nil)) {
            try await client.complete(
                model: "m", messages: [.init(role: .user, content: "hi")], apiKey: "sk-test"
            )
        }
        #expect(MockURLProtocol.requestCount == 3)
        #expect(sleepRecorder.delays == [0.5, 1.0])
    }

    @Test
    func retryAfterHeaderOverridesBackoffDelay() async throws {
        let responses: [(HTTPURLResponse, Data)] = [
            (Self.httpResponse(status: 429, headers: ["Retry-After": "2"]), Self.responseData(content: nil)),
            (Self.httpResponse(status: 200), Self.responseData(content: "ok")),
        ]
        var index = 0
        MockURLProtocol.handler = { _ in
            let response = responses[min(index, responses.count - 1)]
            index += 1
            return response
        }

        let sleepRecorder = SleepRecorder()
        let client = makeClient(sleep: sleepRecorder.sleep)

        let content = try await client.complete(
            model: "m", messages: [.init(role: .user, content: "hi")], apiKey: "sk-test"
        )

        #expect(content == "ok")
        #expect(MockURLProtocol.requestCount == 2)
        #expect(sleepRecorder.delays == [2])
    }

    @Test
    func retryAfterHeaderIsCapped() async throws {
        let responses: [(HTTPURLResponse, Data)] = [
            (Self.httpResponse(status: 429, headers: ["Retry-After": "30"]), Self.responseData(content: nil)),
            (Self.httpResponse(status: 200), Self.responseData(content: "ok")),
        ]
        var index = 0
        MockURLProtocol.handler = { _ in
            let response = responses[min(index, responses.count - 1)]
            index += 1
            return response
        }

        let sleepRecorder = SleepRecorder()
        let client = makeClient(sleep: sleepRecorder.sleep)

        _ = try await client.complete(
            model: "m", messages: [.init(role: .user, content: "hi")], apiKey: "sk-test"
        )

        // 30 s would blow the total budget; the cap keeps it at 5 s.
        #expect(sleepRecorder.delays == [5])
    }

    @Test
    func serverErrorIsRetriedAndCanRecover() async throws {
        let responses: [(HTTPURLResponse, Data)] = [
            (Self.httpResponse(status: 500), Self.responseData(content: nil)),
            (Self.httpResponse(status: 503), Self.responseData(content: nil)),
            (Self.httpResponse(status: 200), Self.responseData(content: "ok")),
        ]
        var index = 0
        MockURLProtocol.handler = { _ in
            let response = responses[min(index, responses.count - 1)]
            index += 1
            return response
        }

        let sleepRecorder = SleepRecorder()
        let client = makeClient(sleep: sleepRecorder.sleep)

        let content = try await client.complete(
            model: "m", messages: [.init(role: .user, content: "hi")], apiKey: "sk-test"
        )

        #expect(content == "ok")
        #expect(MockURLProtocol.requestCount == 3)
        #expect(sleepRecorder.delays == [0.5, 1.0])
    }

    @Test
    func transientNetworkErrorIsRetried() async throws {
        var failedOnce = false
        MockURLProtocol.handler = { _ in
            if failedOnce {
                return (Self.httpResponse(status: 200), Self.responseData(content: "ok"))
            }
            failedOnce = true
            throw URLError(.networkConnectionLost)
        }

        let sleepRecorder = SleepRecorder()
        let client = makeClient(sleep: sleepRecorder.sleep)

        let content = try await client.complete(
            model: "m", messages: [.init(role: .user, content: "hi")], apiKey: "sk-test"
        )

        #expect(content == "ok")
        #expect(MockURLProtocol.requestCount == 2)
        #expect(sleepRecorder.delays == [0.5])
    }

    @Test
    func budgetExhaustedSkipsRetry() async {
        var configuration = DeepSeekChatClient.Configuration()
        configuration.retryBaseDelay = 100

        MockURLProtocol.handler = { _ in
            (Self.httpResponse(status: 429), Self.responseData(content: nil))
        }

        let sleepRecorder = SleepRecorder()
        let client = makeClient(configuration: configuration, sleep: sleepRecorder.sleep)

        await #expect(throws: DeepSeekChatError.rateLimited(retryAfter: nil)) {
            try await client.complete(
                model: "m", messages: [.init(role: .user, content: "hi")], apiKey: "sk-test"
            )
        }
        #expect(MockURLProtocol.requestCount == 1)
        #expect(sleepRecorder.delays.isEmpty)
    }

    // MARK: - Cancellation (T11)

    @Test
    func cancellationDuringBackoffThrowsCancelled() async {
        MockURLProtocol.handler = { _ in
            (Self.httpResponse(status: 429), Self.responseData(content: nil))
        }

        let client = makeClient(sleep: { _ in throw CancellationError() })

        await #expect(throws: DeepSeekChatError.cancelled) {
            try await client.complete(
                model: "m", messages: [.init(role: .user, content: "hi")], apiKey: "sk-test"
            )
        }
        #expect(MockURLProtocol.requestCount == 1)
    }

    @Test
    func attemptTimeoutRespectsRemainingBudget() async throws {
        let requestBox = LockedBox<URLRequest?>(nil)
        MockURLProtocol.handler = { request in
            requestBox.set(request)
            return (Self.httpResponse(status: 200), Self.responseData(content: "ok"))
        }
        var configuration = DeepSeekChatClient.Configuration()
        configuration.totalTimeout = 0.2
        _ = try await makeClient(configuration: configuration).complete(
            model: "m", messages: [.init(role: .user, content: "hi")], apiKey: "sk-test"
        )
        #expect(try #require(requestBox.get()).timeoutInterval <= 0.2)
    }

    // MARK: Private

    private static let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!

    /// Sessions created by the running test; invalidated in `deinit`.
    private var sessions: [URLSession] = []

    private static func httpResponse(
        status: Int,
        headers: [String: String] = [:]
    )
        -> HTTPURLResponse {
        HTTPURLResponse(
            url: endpoint,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
    }

    private static func responseData(content: String?, finishReason: String = "stop") -> Data {
        var message: [String: Any] = ["role": "assistant"]
        if let content {
            message["content"] = content
        }

        let payload: [String: Any] = [
            "choices": [["index": 0, "message": message, "finish_reason": finishReason]],
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    // MARK: - Helpers

    private func makeClient(
        configuration: DeepSeekChatClient.Configuration = DeepSeekChatClient.Configuration(),
        sleep: @escaping DeepSeekChatClient.Sleeper = { _ in }
    )
        -> DeepSeekChatClient {
        let urlConfiguration = URLSessionConfiguration.ephemeral
        urlConfiguration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: urlConfiguration)
        sessions.append(session)

        return DeepSeekChatClient(
            endpoint: Self.endpoint,
            session: session,
            configuration: configuration,
            sleep: sleep
        )
    }
}
