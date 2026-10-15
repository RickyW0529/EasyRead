//
//  ReadingAnalysisTests.swift
//  EasyReadKit
//
//  Created by wangruiqi on 2026/10/15.
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation
import Testing

@testable import EasyReadKit

// MARK: - ReadingAnalysisTests

/// End-to-end decoding tests for the `reading_analysis` answer, covering content
/// shapes real providers return (spec 4.4, spec 5.1).
@Suite
struct ReadingAnalysisTests {
    @Test
    func decodeStripsLeadingThinkBlockFromSentenceAnswer() throws {
        let content = """
        <think>先分类，再翻译，最后做语法分析。</think>
        {"kind":"sentence","originalText":"Birds fly.","translation":"鸟会飞。","wordExplanation":null,"grammar":{"originalSentence":"Birds fly.","translation":"鸟会飞。","mainClause":"Birds fly.","structures":[{"excerpt":"Birds","occurrence":0,"role":"subject","label":"主语","explanation":"动作的发出者。"},{"excerpt":"fly","occurrence":0,"role":"predicate","label":"谓语","explanation":"说明主语的动作。"}],"readingSteps":["先看主语，再看谓语。"],"terminology":[],"comprehensionQuestion":null}}
        """

        let answer = try ReadingAnalysis.decode(
            jsonContent: content, queriedText: "Birds fly.", sourceSentence: nil
        )

        #expect(answer.kind == .sentence)
        #expect(answer.translation == "鸟会飞。")
        #expect(answer.wordExplanation == nil)
        #expect(answer.grammar?.structures.count == 2)
    }

    @Test
    func decodeStripsThinkBlockBeforeCodeFencedWordAnswer() throws {
        let content = """
        <think>这是个单词。</think>
        ```json
        {"kind":"word","originalText":"bank","translation":"河岸","wordExplanation":{"selectedText":"bank","primaryMeaning":"河岸","partOfSpeech":"名词","contextualEvidence":null,"explanation":"这里指河流边的陆地。","contextStatus":"selection_only","terminology":[]},"grammar":null}
        ```
        """

        let answer = try ReadingAnalysis.decode(
            jsonContent: content, queriedText: "bank", sourceSentence: nil
        )

        #expect(answer.kind == .word)
        #expect(answer.translation == "河岸")
        #expect(answer.wordExplanation?.primaryMeaning == "河岸")
        #expect(answer.grammar == nil)
    }

    @Test
    func decodeUnclosedThinkBlockThrows() {
        #expect(throws: DecodingError.self) {
            _ = try ReadingAnalysis.decode(
                jsonContent: "<think>思考未结束，正文丢失",
                queriedText: "Birds fly.", sourceSentence: nil
            )
        }
    }

    @Test
    func decodePlainAnswerUnchanged() throws {
        let content = """
        {"kind":"sentence","originalText":"Birds fly.","translation":"鸟会飞。","wordExplanation":null,"grammar":{"originalSentence":"Birds fly.","translation":"鸟会飞。","mainClause":"Birds fly.","structures":[{"excerpt":"Birds","occurrence":0,"role":"subject","label":"主语","explanation":"动作的发出者。"}],"readingSteps":["先看主语，再看谓语。"],"terminology":[],"comprehensionQuestion":null}}
        """

        let answer = try ReadingAnalysis.decode(
            jsonContent: content, queriedText: "Birds fly.", sourceSentence: nil
        )

        #expect(answer.kind == .sentence)
        #expect(answer.grammar?.structures.first?.role == .subject)
    }
}
