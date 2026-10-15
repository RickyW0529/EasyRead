//
//  AIWordExplanationTests.swift
//  EasyReadKit
//
//  Created by wangruiqi on 2026/10/10.
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation
import Testing

@testable import EasyReadKit

// MARK: - AIWordExplanationTests

/// Decoding and validation tests for the `word_in_context` answer (spec 4.1
/// data contract, spec 4.4 "JSON validity is not schema compliance", spec
/// 5.1 quality requirements).
@Suite
struct AIWordExplanationTests {
    // MARK: Internal

    static let sentence = "The operating system schedules each process to run on the CPU."

    // MARK: - Decoding

    @Test
    func decodeValidJSONWithAllFields() throws {
        let json = """
        {
          "selectedText": "process",
          "primaryMeaningZh": "进程",
          "partOfSpeech": "noun",
          "contextualEvidence": "schedules each process",
          "explanationZh": "这里指被操作系统调度运行的进程。",
          "terminology": [{"term": "operating system", "meaningZh": "操作系统"}],
          "contextStatus": "contextual"
        }
        """

        let explanation = try AIWordExplanation.decode(jsonContent: json)

        #expect(explanation.selectedText == "process")
        #expect(explanation.primaryMeaningZh == "进程")
        #expect(explanation.partOfSpeech == "noun")
        #expect(explanation.contextualEvidence == "schedules each process")
        #expect(explanation.explanationZh == "这里指被操作系统调度运行的进程。")
        #expect(explanation.terminology == [TerminologyItem(term: "operating system", meaningZh: "操作系统")])
        #expect(explanation.contextStatus == .contextual)
    }

    @Test
    func decodeOmitsOptionalFields() throws {
        let json = """
        {
          "selectedText": "process",
          "primaryMeaningZh": "进程",
          "explanationZh": "这里指进程。",
          "terminology": [],
          "contextStatus": "contextual"
        }
        """

        let explanation = try AIWordExplanation.decode(jsonContent: json)

        #expect(explanation.partOfSpeech == nil)
        #expect(explanation.contextualEvidence == nil)
    }

    @Test
    func decodeMissingTerminologyDefaultsToEmpty() throws {
        let json = """
        {
          "selectedText": "process",
          "primaryMeaningZh": "进程",
          "explanationZh": "这里指进程。",
          "contextStatus": "contextual"
        }
        """

        let explanation = try AIWordExplanation.decode(jsonContent: json)
        #expect(explanation.terminology == [])
    }

    @Test
    func decodeMissingRequiredFieldThrows() {
        #expect(throws: DecodingError.self) {
            _ = try AIWordExplanation.decode(
                jsonContent: """
                {"selectedText": "process", "primaryMeaningZh": "进程"}
                """
            )
        }
    }

    @Test
    func decodeWrongFieldTypeThrows() {
        #expect(throws: DecodingError.self) {
            _ = try AIWordExplanation.decode(
                jsonContent: """
                {"selectedText": 1, "primaryMeaningZh": "进程", "explanationZh": "x", "contextStatus": "contextual"}
                """
            )
        }
    }

    @Test
    func decodeUnknownContextStatusThrows() {
        #expect(throws: DecodingError.self) {
            _ = try AIWordExplanation.decode(
                jsonContent: """
                {"selectedText": "process", "primaryMeaningZh": "进程", "explanationZh": "x", "contextStatus": "partly"}
                """
            )
        }
    }

    @Test
    func decodeStripsMarkdownCodeFences() throws {
        let fenced = """
        ```json
        {"selectedText": "process", "primaryMeaningZh": "进程", "explanationZh": "这里指进程。", "contextStatus": "contextual"}
        ```
        """

        let explanation = try AIWordExplanation.decode(jsonContent: fenced)
        #expect(explanation.primaryMeaningZh == "进程")
    }

    @Test
    func decodeStripsLeadingThinkBlock() throws {
        let thinking = """
        <think>
        让我想想这个词。
        </think>
        {"selectedText": "process", "primaryMeaningZh": "进程", "explanationZh": "这里指进程。", "contextStatus": "contextual"}
        """

        let explanation = try AIWordExplanation.decode(jsonContent: thinking)
        #expect(explanation.primaryMeaningZh == "进程")
    }

    @Test
    func decodeStripsThinkBlockBeforeCodeFence() throws {
        let thinking = """
        <think>推理内容</think>
        ```json
        {"selectedText": "process", "primaryMeaningZh": "进程", "explanationZh": "这里指进程。", "contextStatus": "contextual"}
        ```
        """

        let explanation = try AIWordExplanation.decode(jsonContent: thinking)
        #expect(explanation.primaryMeaningZh == "进程")
    }

    @Test
    func decodeUnclosedThinkBlockFailsDecode() {
        #expect(throws: DecodingError.self) {
            _ = try AIWordExplanation.decode(
                jsonContent: """
                <think>推理内容但未闭合，正文也不会出现
                """
            )
        }
    }

    @Test
    func decodeKeepsThinkTextOutsideLeadingBlock() {
        #expect(throws: DecodingError.self) {
            _ = try AIWordExplanation.decode(jsonContent: "进程就是 process，<think>不是前缀</think>")
        }
    }

    @Test
    func decodeMalformedJSONThrows() {
        #expect(throws: DecodingError.self) {
            _ = try AIWordExplanation.decode(jsonContent: "进程就是 process。")
        }
    }

    // MARK: - Validation: required fields and limits

    @Test
    func validatedKeepsWellFormedExplanation() throws {
        let validated = try makeExplanation()
            .validated(queriedText: "process", sourceSentence: Self.sentence)

        #expect(validated.primaryMeaningZh == "进程")
        #expect(validated.partOfSpeech == "noun")
        #expect(validated.contextualEvidence == "schedules each process")
        #expect(validated.explanationZh == "这里指被操作系统调度运行的进程。")
        #expect(validated.terminology == [TerminologyItem(term: "operating system", meaningZh: "操作系统")])
        #expect(validated.contextStatus == .contextual)
    }

    @Test
    func validatedThrowsOnEmptyMeaning() {
        #expect(throws: AIWordExplanation.ValidationError.emptyField(.primaryMeaningZh)) {
            _ = try makeExplanation(primaryMeaningZh: "")
                .validated(queriedText: "process", sourceSentence: Self.sentence)
        }
    }

    @Test
    func validatedThrowsOnEmptyExplanation() {
        #expect(throws: AIWordExplanation.ValidationError.emptyField(.explanationZh)) {
            _ = try makeExplanation(explanationZh: "")
                .validated(queriedText: "process", sourceSentence: Self.sentence)
        }
    }

    @Test
    func validatedThrowsOnOverlongMeaning() {
        #expect(throws: AIWordExplanation.ValidationError.fieldTooLong(.primaryMeaningZh, limit: 200)) {
            _ = try makeExplanation(primaryMeaningZh: String(repeating: "进", count: 201))
                .validated(queriedText: "process", sourceSentence: Self.sentence)
        }
    }

    @Test
    func validatedThrowsOnOverlongExplanation() {
        #expect(throws: AIWordExplanation.ValidationError.fieldTooLong(.explanationZh, limit: 2000)) {
            _ = try makeExplanation(explanationZh: String(repeating: "释", count: 2001))
                .validated(queriedText: "process", sourceSentence: Self.sentence)
        }
    }

    @Test
    func validatedDropsOverlongPartOfSpeech() throws {
        let validated = try makeExplanation(partOfSpeech: String(repeating: "n", count: 31))
            .validated(queriedText: "process", sourceSentence: Self.sentence)

        #expect(validated.partOfSpeech == nil)
    }

    @Test
    func validatedDropsEmptyPartOfSpeech() throws {
        let validated = try makeExplanation(partOfSpeech: "   ")
            .validated(queriedText: "process", sourceSentence: Self.sentence)

        #expect(validated.partOfSpeech == nil)
    }

    // MARK: - Validation: selected-text echo

    @Test
    func validatedAcceptsWhitespaceOnlyEchoDifference() throws {
        let validated = try makeExplanation(selectedText: "  process\n")
            .validated(queriedText: "process", sourceSentence: Self.sentence)

        #expect(validated.selectedText == "  process\n")
    }

    @Test
    func validatedThrowsOnRewrittenEcho() {
        #expect(throws: AIWordExplanation.ValidationError.selectedTextMismatch) {
            _ = try makeExplanation(selectedText: "processor")
                .validated(queriedText: "process", sourceSentence: Self.sentence)
        }
    }

    @Test
    func validatedThrowsOnEmptyQueriedText() {
        #expect(throws: AIWordExplanation.ValidationError.selectedTextMismatch) {
            _ = try makeExplanation()
                .validated(queriedText: "", sourceSentence: Self.sentence)
        }
    }

    @Test
    func validatedThrowsOnOverlongEcho() {
        #expect(throws: AIWordExplanation.ValidationError.fieldTooLong(.selectedText, limit: 2000)) {
            _ = try makeExplanation(selectedText: String(repeating: "p", count: 2001))
                .validated(queriedText: String(repeating: "p", count: 2001), sourceSentence: Self.sentence)
        }
    }

    // MARK: - Validation: context honesty

    @Test
    func validatedThrowsWhenSelectionOnlyAnswerClaimsContext() {
        #expect(throws: AIWordExplanation.ValidationError.fabricatedContextStatus) {
            _ = try makeExplanation()
                .validated(queriedText: "process", sourceSentence: nil)
        }
    }

    @Test
    func validatedKeepsHonestSelectionOnlyDowngrade() throws {
        let validated = try makeExplanation(
            contextualEvidence: nil,
            contextStatus: .selectionOnly
        )
        .validated(queriedText: "process", sourceSentence: Self.sentence)

        #expect(validated.contextStatus == .selectionOnly)
        #expect(validated.contextualEvidence == nil)
    }

    @Test
    func validatedKeepsEvidenceFragmentOfSentence() throws {
        let validated = try makeExplanation(contextualEvidence: "run on the CPU")
            .validated(queriedText: "process", sourceSentence: Self.sentence)

        #expect(validated.contextualEvidence == "run on the CPU")
    }

    @Test
    func validatedAcceptsEvidenceWithUnifiedWhitespace() throws {
        let validated = try makeExplanation(contextualEvidence: "schedules each   process")
            .validated(queriedText: "process", sourceSentence: Self.sentence)

        #expect(validated.contextualEvidence == "schedules each   process")
    }

    @Test
    func validatedDropsEvidenceNotInSentence() throws {
        let validated = try makeExplanation(contextualEvidence: "runs on the GPU core")
            .validated(queriedText: "process", sourceSentence: Self.sentence)

        #expect(validated.contextualEvidence == nil)
    }

    @Test
    func validatedDropsEvidenceWithoutSourceSentence() throws {
        let validated = try makeExplanation(contextualEvidence: "schedules each process", contextStatus: .selectionOnly)
            .validated(queriedText: "process", sourceSentence: nil)

        #expect(validated.contextualEvidence == nil)
    }

    // MARK: - Validation: terminology sanitation

    @Test
    func validatedDropsEmptyTerminologyItems() throws {
        let validated = try makeExplanation(
            terminology: [
                TerminologyItem(term: "", meaningZh: "操作系统"),
                TerminologyItem(term: "operating system", meaningZh: "  "),
                TerminologyItem(term: "CPU", meaningZh: "中央处理器"),
            ]
        )
        .validated(queriedText: "process", sourceSentence: Self.sentence)

        #expect(validated.terminology == [TerminologyItem(term: "CPU", meaningZh: "中央处理器")])
    }

    @Test
    func validatedDropsOverlongTerminologyItems() throws {
        let validated = try makeExplanation(
            terminology: [
                TerminologyItem(term: String(repeating: "t", count: 101), meaningZh: "x"),
                TerminologyItem(term: "CPU", meaningZh: String(repeating: "义", count: 301)),
                TerminologyItem(term: "CPU", meaningZh: "中央处理器"),
            ]
        )
        .validated(queriedText: "process", sourceSentence: Self.sentence)

        #expect(validated.terminology == [TerminologyItem(term: "CPU", meaningZh: "中央处理器")])
    }

    @Test
    func validatedCapsTerminologyItemCount() throws {
        let items = (1 ... 25).map { TerminologyItem(term: "term\($0)", meaningZh: "词\($0)") }

        let validated = try makeExplanation(terminology: items)
            .validated(queriedText: "process", sourceSentence: Self.sentence)

        #expect(validated.terminology.count == 20)
        #expect(validated.terminology.first == TerminologyItem(term: "term1", meaningZh: "词1"))
        #expect(validated.terminology.last == TerminologyItem(term: "term20", meaningZh: "词20"))
    }

    @Test
    func whitespaceOnlyRequiredFieldsAreRejected() {
        let answer = makeExplanation(primaryMeaningZh: "   ")
        #expect(throws: AIWordExplanation.ValidationError.self) {
            try answer.validated(queriedText: "process", sourceSentence: Self.sentence)
        }
    }

    // MARK: Private

    private func makeExplanation(
        selectedText: String = "process",
        primaryMeaningZh: String = "进程",
        partOfSpeech: String? = "noun",
        contextualEvidence: String? = "schedules each process",
        explanationZh: String = "这里指被操作系统调度运行的进程。",
        terminology: [TerminologyItem] = [TerminologyItem(term: "operating system", meaningZh: "操作系统")],
        contextStatus: AIWordExplanation.ContextStatus = .contextual
    )
        -> AIWordExplanation {
        AIWordExplanation(
            selectedText: selectedText,
            primaryMeaningZh: primaryMeaningZh,
            partOfSpeech: partOfSpeech,
            contextualEvidence: contextualEvidence,
            explanationZh: explanationZh,
            terminology: terminology,
            contextStatus: contextStatus
        )
    }
}
