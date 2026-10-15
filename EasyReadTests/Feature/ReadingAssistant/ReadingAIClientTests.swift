//
//  ReadingAIClientTests.swift
//  EasyRead
//
//  Created by wangruiqi on 2026/10/15.
//  Copyright © 2026 izual. All rights reserved.
//

import Alamofire
import EasyReadKit
import Foundation
import Testing

@testable import EasyRead

// MARK: - ReadingAIMockURLProtocol

/// Intercepts every request of a test's session and delivers the response body
/// in fragments. The handler and counter are static, so the suite is `.serialized`.
final class ReadingAIMockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, [Data]))?
    static var lastRequest: URLRequest?
    static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        ReadingAIMockURLProtocol.requestCount += 1
        ReadingAIMockURLProtocol.lastRequest = request
        guard let handler = ReadingAIMockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (response, fragments) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            for fragment in fragments {
                client?.urlProtocol(self, didLoad: fragment)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
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

// MARK: - ReadingAIClientTests

/// URLProtocol-backed tests for the streaming reading client: SSE event
/// parsing across chunk boundaries, request shape and error mapping parity
/// with the non-streaming path. No real network traffic leaves the machine
/// and no real API key is used.
@Suite(.serialized)
final class ReadingAIClientTests {
    // MARK: Lifecycle

    init() {
        ReadingAIMockURLProtocol.handler = nil
        ReadingAIMockURLProtocol.lastRequest = nil
        ReadingAIMockURLProtocol.requestCount = 0
    }

    // MARK: Internal

    // MARK: - Stream event parsing

    @Test
    func parserSplitsEventsAcrossChunkBoundaries() {
        let fragments = Self.boundaryFragments(
            of: "data: {\"choices\":[{\"delta\":{\"content\":\"推\"}}]}\n\ndata: [DONE]\n\n"
        )

        var parser = StreamEventParser()
        var payloads: [String] = []
        for fragment in fragments {
            payloads.append(contentsOf: parser.payloads(from: fragment))
        }

        #expect(payloads == ["{\"choices\":[{\"delta\":{\"content\":\"推\"}}]}", "[DONE]"])
        #expect(parser.flush().isEmpty)
    }

    @Test
    func parserIgnoresKeepAliveComments() {
        var parser = StreamEventParser()
        #expect(parser.payloads(from: Data(": keep-alive\n\n".utf8)).isEmpty)
        #expect(parser.payloads(from: Data("data: {\"x\":1}\r\n\r\n".utf8)) == ["{\"x\":1}"])
    }

    @Test
    func parserFlushesTrailingEventWithoutDelimiter() {
        var parser = StreamEventParser()
        _ = parser.payloads(from: Data("data: {\"x\":1}\n\n".utf8))
        parser.payloads(from: Data("data: [DONE]".utf8))
        #expect(parser.flush() == ["[DONE]"])
        #expect(parser.flush().isEmpty)
    }

    // MARK: - Success and request shape

    @Test
    func completeAccumulatesStreamedContentIgnoringReasoningDeltas() async throws {
        ReadingAIMockURLProtocol.handler = { _ in
            (
                Self.httpResponse(status: 200),
                [
                    Data(
                        "data: {\"choices\":[{\"delta\":{\"role\":\"assistant\",\"content\":\"<think>\"}}]}\n\n".utf8
                    ),
                    Data(": keep-alive\n\n".utf8),
                    Data(
                        "data: {\"choices\":[{\"delta\":{\"content\":\"推\",\"reasoning_content\":\"思考\"}}]}\n\n"
                            .utf8
                    ),
                    Data("data: {\"choices\":[{\"delta\":{\"content\":\"理</think>\"}}]}\n\n".utf8),
                    Data("data: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}\n\n".utf8),
                    Data("data: [DONE]\n\n".utf8),
                ]
            )
        }

        let content = try await makeClient()
            .complete(configuration: Self.configuration, system: "system", prompt: "prompt")

        #expect(content == "<think>推理</think>")

        let request = try #require(ReadingAIMockURLProtocol.lastRequest)
        let data = try #require(request.bodyData)
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(body["stream"] as? Bool == true)
        #expect(body["enable_thinking"] as? Bool == false)
        #expect(body["max_tokens"] as? Int == 8192)
        #expect(body["model"] as? String == "MiniMax-M2.7")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
    }

    @Test
    func completeDeliversChunkBoundariesThroughTransport() async throws {
        ReadingAIMockURLProtocol.handler = { _ in
            let payload = "data: {\"choices\":[{\"delta\":{\"content\":\"推\"}}]}\n\ndata: [DONE]\n\n"
            return (Self.httpResponse(status: 200), Self.boundaryFragments(of: payload))
        }

        let content = try await makeClient()
            .complete(configuration: Self.configuration, system: "system", prompt: "prompt")

        #expect(content == "推")
    }

    // MARK: - Error mapping

    @Test
    func completeMapsUnauthorizedToInvalidAPIKey() async {
        ReadingAIMockURLProtocol.handler = { _ in
            (Self.httpResponse(status: 401), [Data("{\"error\":{\"message\":\"bad key\"}}".utf8)])
        }

        await #expect(throws: DeepSeekChatError.invalidAPIKey) {
            _ = try await makeClient().complete(
                configuration: Self.configuration, system: "system", prompt: "prompt"
            )
        }
    }

    @Test
    func completeMapsServerErrorToQueryError() async throws {
        ReadingAIMockURLProtocol.handler = { _ in
            (Self.httpResponse(status: 500), [])
        }

        do {
            _ = try await makeClient().complete(
                configuration: Self.configuration, system: "system", prompt: "prompt"
            )
            Issue.record("Expected an error for HTTP 500")
        } catch let error as QueryError {
            #expect(error.type == .api)
            #expect(error.message == String(
                localized: "reading.ai.http_error \(500)",
                bundle: Bundle(for: QueryError.self)
            ))
        } catch {
            Issue.record("Expected QueryError, got \(error)")
        }
    }

    @Test
    func completeThrowsTruncatedForLengthFinishReason() async {
        ReadingAIMockURLProtocol.handler = { _ in
            (
                Self.httpResponse(status: 200),
                [
                    Data("data: {\"choices\":[{\"delta\":{\"content\":\"{\\\"kind\\\":\\\"word\\\"}\"}}]}\n\n".utf8),
                    Data("data: {\"choices\":[{\"delta\":{},\"finish_reason\":\"length\"}]}\n\n".utf8),
                    Data("data: [DONE]\n\n".utf8),
                ]
            )
        }

        await #expect(throws: DeepSeekChatError.truncatedResponse) {
            _ = try await makeClient().complete(
                configuration: Self.configuration, system: "system", prompt: "prompt"
            )
        }
    }

    @Test
    func completeThrowsInvalidResponseForEmptyStream() async {
        ReadingAIMockURLProtocol.handler = { _ in
            (Self.httpResponse(status: 200), [Data(": keep-alive\n\n".utf8), Data("data: [DONE]\n\n".utf8)])
        }

        await #expect(throws: DeepSeekChatError.invalidResponse) {
            _ = try await makeClient().complete(
                configuration: Self.configuration, system: "system", prompt: "prompt"
            )
        }
    }

    @Test
    func completeThrowsInvalidResponseForUndecodableEvent() async {
        ReadingAIMockURLProtocol.handler = { _ in
            (Self.httpResponse(status: 200), [Data("data: not-json\n\n".utf8)])
        }

        await #expect(throws: DeepSeekChatError.invalidResponse) {
            _ = try await makeClient().complete(
                configuration: Self.configuration, system: "system", prompt: "prompt"
            )
        }
    }

    @Test
    func completeMapsTransportTimeout() async {
        ReadingAIMockURLProtocol.handler = { _ in
            throw URLError(.timedOut)
        }

        await #expect(throws: DeepSeekChatError.timeout) {
            _ = try await makeClient().complete(
                configuration: Self.configuration, system: "system", prompt: "prompt"
            )
        }
    }

    // MARK: Private

    private static let configuration = ReadingAIConfiguration(
        providerID: "minimax",
        endpoint: "https://api.minimaxi.com/v1",
        model: "MiniMax-M2.7",
        apiKey: "test-key",
        credentialRevision: ""
    )

    private static func httpResponse(status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.minimaxi.com/v1/chat/completions")!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/event-stream"]
        )!
    }

    /// Splits a payload through the middle of `推` and the middle of the first event delimiter.
    private static func boundaryFragments(of payload: String) -> [Data] {
        let data = Data(payload.utf8)
        guard let characterRange = data.firstRange(of: Data("推".utf8)),
              let delimiterRange = data.firstRange(of: Data("\n\n".utf8))
        else {
            preconditionFailure("fixture is missing the character or event delimiter used to split chunks")
        }
        let midCharacter = data.index(characterRange.lowerBound, offsetBy: 1)
        let midDelimiter = data.index(delimiterRange.lowerBound, offsetBy: 1)
        return fragments(of: data, splitAt: [midCharacter, midDelimiter])
    }

    private static func fragments(of data: Data, splitAt cuts: [Data.Index]) -> [Data] {
        var pieces: [Data] = []
        var start = data.startIndex
        for cut in cuts.sorted() where cut > start && cut < data.endIndex {
            pieces.append(data.subdata(in: start ..< cut))
            start = cut
        }
        pieces.append(data.subdata(in: start ..< data.endIndex))
        return pieces
    }

    private func makeClient() -> ReadingAIClient {
        let urlConfiguration = URLSessionConfiguration.ephemeral
        urlConfiguration.protocolClasses = [ReadingAIMockURLProtocol.self]
        return ReadingAIClient(session: Session(configuration: urlConfiguration))
    }
}
