//
//  SentenceBoundaryDetectorTests.swift
//  EasyReadKit
//
//  Created by wangruiqi on 2026/10/9.
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation
import Testing

@testable import EasyReadKit

// MARK: - SentenceBoundaryDetectorTests

@Suite
struct SentenceBoundaryDetectorTests {
    // MARK: Internal

    let detector = SentenceBoundaryDetector()

    @Test func simpleSentence() {
        let text = "The operating system schedules each process to run on the CPU. Another sentence follows here."
        let range = detector.sentenceRange(containing: location(of: "Another", in: text), in: text)
        #expect(sentence(range, in: text) == "Another sentence follows here.")
    }

    @Test func abbreviationEGDoesNotSplit() {
        let text = "Modern CPUs are fast, e.g. the M-series chips. The kernel manages memory."
        let range = detector.sentenceRange(containing: location(of: "chips", in: text), in: text)
        #expect(sentence(range, in: text) == "Modern CPUs are fast, e.g. the M-series chips.")
    }

    @Test func abbreviationIEDoesNotSplit() {
        let text = "Some tools, i.e. the compiler, are slow. The linker is fast."
        let range = detector.sentenceRange(containing: location(of: "compiler", in: text), in: text)
        #expect(sentence(range, in: text) == "Some tools, i.e. the compiler, are slow.")
    }

    @Test func abbreviationFigDoesNotSplit() {
        let text = "Fig. 3 shows the architecture of the system. It has three layers."
        let range = detector.sentenceRange(containing: location(of: "architecture", in: text), in: text)
        #expect(sentence(range, in: text) == "Fig. 3 shows the architecture of the system.")
    }

    @Test func nameInitialDoesNotSplit() {
        let text = "This idea was proposed by J. Smith in 1998. It became popular."
        let range = detector.sentenceRange(containing: location(of: "Smith", in: text), in: text)
        #expect(sentence(range, in: text) == "This idea was proposed by J. Smith in 1998.")
    }

    @Test func decimalNumberDoesNotSplit() {
        let text = "Increase the timeout to 3.5 seconds before retrying the request."
        let range = detector.sentenceRange(containing: location(of: "seconds", in: text), in: text)
        #expect(sentence(range, in: text) == text)
    }

    @Test func terminatorInsideParenthesesDoesNotSplit() {
        let text = "The kernel (see section 2.1) manages memory. It also schedules processes."
        let range = detector.sentenceRange(containing: location(of: "memory", in: text), in: text)
        #expect(sentence(range, in: text) == "The kernel (see section 2.1) manages memory.")
    }

    @Test func closingQuoteAfterTerminator() {
        let text = "He said \"Stop.\" Then he left the room."
        let range = detector.sentenceRange(containing: location(of: "left", in: text), in: text)
        #expect(sentence(range, in: text) == "Then he left the room.")
    }

    @Test func newlineIsHardBoundary() {
        let text = "First line ends here.\nSecond line starts here."
        let range = detector.sentenceRange(containing: location(of: "Second", in: text), in: text)
        #expect(sentence(range, in: text) == "Second line starts here.")
    }

    @Test func noTerminatorReturnsWholeText() {
        let text = "the quick brown fox jumps over the lazy dog"
        let range = detector.sentenceRange(containing: location(of: "fox", in: text), in: text)
        #expect(sentence(range, in: text) == text)
    }

    @Test func lowercaseAfterPeriodIsNotBoundary() {
        // Conservative: a lowercase continuation means the period does not end
        // the sentence, so the extracted range only grows.
        let text = "We waited, and waited. then it happened."
        let range = detector.sentenceRange(containing: location(of: "happened", in: text), in: text)
        #expect(sentence(range, in: text) == text)
    }

    @Test func ellipsisIsSingleBoundary() {
        let text = "Wait... Then it happened."
        var range = detector.sentenceRange(containing: location(of: "Wait", in: text), in: text)
        #expect(sentence(range, in: text) == "Wait...")
        range = detector.sentenceRange(containing: location(of: "happened", in: text), in: text)
        #expect(sentence(range, in: text) == "Then it happened.")
    }

    @Test func terminatorInsideBackticksIgnoredWhenTracked() {
        let text = "Install the tool `make install. Then run` the tests and verify."
        let range = detector.sentenceRange(containing: location(of: "tool", in: text), in: text)
        #expect(sentence(range, in: text) == text)
    }

    @Test func emptyTextReturnsEmptyRange() {
        #expect(detector.sentenceRange(containing: 0, in: "") == NSRange(location: 0, length: 0))
    }

    @Test func specCorpusSentences() {
        let corpus = [
            "The operating system schedules each process to run on the CPU.",
            "The bank approved the loan after reviewing the application.",
            "We sat on the bank of the river and watched the water.",
            "Although virtual memory gives each process the illusion of a private address space, the operating "
                + "system must carefully manage the mapping between virtual and physical pages.",
            "The packet, which had been retransmitted several times because of congestion, eventually reached its "
                + "destination.",
            "Only after the transaction had committed did the client receive an acknowledgment.",
            "Given that the buffer has already been allocated, the function returns a pointer rather than copying "
                + "the entire array.",
            "The function returns a value, which is subsequently cached by the runtime.",
        ]

        for text in corpus {
            let range = detector.sentenceRange(containing: 0, in: text)
            #expect(
                sentence(range, in: text) == text,
                "Whole corpus sentence expected for: \(text.prefix(40))"
            )
        }
    }

    // MARK: Private

    private func location(of needle: String, in text: String) -> Int {
        let range = (text as NSString).range(of: needle)
        precondition(range.location != NSNotFound, "test needle missing: \(needle)")
        return range.location
    }

    private func sentence(_ range: NSRange, in text: String) -> String {
        guard range.length >= 0, NSMaxRange(range) <= (text as NSString).length else {
            return "<invalid>"
        }
        return ((text as NSString).substring(with: range) as String)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
