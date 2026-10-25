//
//  DeepSeekService+WordExplanation.swift
//  EasyRead
//
//  Created by wangruiqi on 2026/10/10.
//  Copyright © 2026 izual. All rights reserved.
//

import Defaults
import EasyReadKit
import Foundation

// MARK: - DeepSeekService + Word Explanation

extension DeepSeekService {
    /// Returns the in-context explanation stream when this query is an
    /// English word/phrase lookup; `nil` otherwise, so the caller keeps the
    /// upstream streaming translation (spec 3.2/4.4/5.1).
    ///
    /// Every DeepSeek word lookup answers through the one structured,
    /// schema-validated pipeline (spec Phase 3: 词语解释使用确定 schema、
    /// 可控超时、错误映射及取消). Without captured context the request is
    /// still sent, but labeled word-only — the answer must never claim a
    /// sentence the request never had (spec 3.2/T04), and context that was
    /// never captured is never sent (spec 7.2).
    func wordExplanationStreamIfAvailable(
        text: String,
        from: Language,
        to: Language
    )
        -> AsyncThrowingStream<String, Error>? {
        guard from == .english,
              queryType(text: text, from: from, to: to) == .dictionary,
              !apiKey.isEmpty
        else {
            return nil
        }

        guard let url = URL(string: endpoint), url.isValid else {
            return nil
        }

        // This service owns its query snapshot even after the latest-selection cache changes.
        let snapshot = queryModel.contextSnapshot.map { attached in
            let latest = ContextExtractionCoordinator.shared.snapshot(forInputText: currentInputText)
            let owned = latest.flatMap { $0.selectionID == attached.selectionID ? $0 : nil } ?? attached
            guard Defaults[.enableContextExtraction] else {
                return SelectionSnapshot(
                    selectedText: owned.selectedText, surroundingText: nil, availability: .selectionOnly,
                    sourceBundleID: owned.sourceBundleID, timestamp: owned.timestamp, selectionID: owned.selectionID
                )
            }
            return owned
        }
        guard AXContextExtractor.allowsAI(snapshot: snapshot) else {
            return AsyncThrowingStream { $0.finish(throwing: CancellationError()) }
        }

        return explanationStream(text: text, snapshot: snapshot, url: url)
    }

    /// The raw selection text for store matching: the query model's
    /// `inputText` when a query flow drove this request, else the already
    /// normalized query text.
    private var currentInputText: String {
        let inputText = queryModel.inputText
        return inputText.isEmpty ? queryModel.queryText : inputText
    }

    // MARK: - Explanation Request

    private func explanationStream(
        text: String,
        snapshot: SelectionSnapshot?,
        url: URL
    )
        -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            if let currentTask, !currentTask.isCancelled {
                currentTask.cancel()
            }

            // What the request is allowed to know: a selection-only (or
            // missing) snapshot never contributes a sentence (spec 4.2/5.1
            // honesty clamps).
            let availability: ContextAvailability = snapshot?.availability ?? .selectionOnly
            let sourceSentence: String? = availability == .selectionOnly
                ? nil
                : snapshot?.surroundingText

            let generation = updateResultLock.withLock { resultGeneration }
            let task = Task {
                do {
                    try Task.checkCancellation()
                    guard Defaults[.enableReadingAI], !apiKey.isEmpty,
                          sourceSentence == nil || Defaults[.enableContextExtraction],
                          updateResultLock.withLock({ resultGeneration == generation }),
                          AXContextExtractor.allowsAI(snapshot: snapshot) else { throw CancellationError() }
                    let messages = [
                        DeepSeekChatMessage(
                            role: .system,
                            content: WordContextPrompt.systemPrompt
                        ),
                        DeepSeekChatMessage(
                            role: .user,
                            content: try WordContextPrompt.userPrompt(
                                selectedText: text,
                                sourceSentence: sourceSentence,
                                availability: availability
                            )
                        ),
                    ]

                    let client = DeepSeekChatClient(endpoint: url)
                    let jsonContent = try await client.complete(
                        model: model,
                        messages: messages,
                        apiKey: apiKey
                    )

                    let explanation = try AIWordExplanation.decode(jsonContent: jsonContent)
                    let validated = try explanation.validated(
                        queriedText: text,
                        sourceSentence: sourceSentence
                    )

                    try Task.checkCancellation()
                    guard Defaults[.enableReadingAI], !apiKey.isEmpty,
                          sourceSentence == nil || Defaults[.enableContextExtraction],
                          updateResultLock.withLock({ resultGeneration == generation }),
                          AXContextExtractor.allowsAI(snapshot: snapshot) else { throw CancellationError() }
                    continuation.yield(Self.explanationMarkdown(validated, snapshot: snapshot))
                    continuation.finish()
                } catch is CancellationError {
                    logInfo("DeepSeek explanation task was cancelled.")
                    continuation.finish(throwing: CancellationError())
                } catch DeepSeekChatError.cancelled {
                    // The client reports task cancellation as `.cancelled`;
                    // surface it as CancellationError so the shared stream
                    // pipeline stops the card silently instead of showing an
                    // error (spec 4.4: 取消后不得在 UI 报"成功").
                    logInfo("DeepSeek explanation task was cancelled.")
                    continuation.finish(throwing: CancellationError())
                } catch let error as DeepSeekChatError {
                    continuation.finish(throwing: error.queryError)
                } catch let error as AIWordExplanation.ValidationError {
                    // Field names only; model content never enters the log.
                    logError("DeepSeek explanation schema validation failed: \(error)")
                    continuation.finish(throwing: Self.schemaViolationError)
                } catch is DecodingError {
                    logError("DeepSeek explanation JSON decoding failed.")
                    continuation.finish(throwing: Self.schemaViolationError)
                } catch {
                    continuation.finish(throwing: QueryError.queryError(from: error))
                }
            }

            currentTask = task
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Formatting

    /// Schema violations surface as a distinct API error, never as guessed
    /// content (spec 4.4/T07). Reuses the shared invalid-response wording.
    static var schemaViolationError: QueryError {
        QueryError(type: .api, message: String(localized: "deepseek.error.invalid_response"))
    }

    /// Renders one validated explanation as the card's Markdown text
    /// (spec 3.2/6.3: primary meaning first, honest source labels).
    ///
    /// A `nil` or selection-only snapshot produces a word-only card that
    /// never quotes a sentence and says so in the source label (spec 3.2:
    /// 若调用 AI，必须标注"无原句上下文"; T04).
    static func explanationMarkdown(
        _ explanation: AIWordExplanation,
        snapshot: SelectionSnapshot?
    )
        -> String {
        var headline = "**\(explanation.primaryMeaningZh)**"
        if let partOfSpeech = explanation.partOfSpeech, !partOfSpeech.isEmpty {
            headline += " · \(partOfSpeech)"
        }

        var lines = [headline]

        let availability = snapshot?.availability ?? .selectionOnly

        // The quoted passage is the sanitized, length-limited text captured
        // by Phase 2 — labeled with exactly as much certainty as the
        // snapshot's availability claims (spec 6.3).
        if availability != .selectionOnly,
           let sentence = snapshot?.surroundingText, !sentence.isEmpty {
            let passageLabel = availability == .exactSentence
                ? String(localized: "deepseek.explanation.original_sentence")
                : String(localized: "deepseek.explanation.context_passage")
            lines.append("")
            lines.append("> \(passageLabel)：\(sentence)")
        }

        lines.append("")
        lines.append(explanation.explanationZh)

        if !explanation.terminology.isEmpty {
            lines.append("")
            lines.append("**\(String(localized: "deepseek.explanation.terminology"))**")
            for item in explanation.terminology {
                lines.append("- \(item.term)：\(item.meaningZh)")
            }
        }

        let sourceLabel: String
        switch explanation.contextStatus == .selectionOnly ? ContextAvailability.selectionOnly : availability {
        case .exactSentence:
            sourceLabel = String(localized: "deepseek.explanation.source_exact")
        case .nearbyText:
            sourceLabel = String(localized: "deepseek.explanation.source_nearby")
        case .selectionOnly:
            sourceLabel = String(localized: "deepseek.explanation.source_selection_only")
        }
        lines.append("")
        lines.append("—— \(sourceLabel)")

        return lines.joined(separator: "\n")
    }
}
