//
//  ContextSanitizerTests.swift
//  EasyReadKit
//
//  Created by wangruiqi on 2026/10/9.
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation
import Testing

@testable import EasyReadKit

// MARK: - ContextSanitizerTests

@Suite
struct ContextSanitizerTests {
    // MARK: Internal

    let sanitizer = ContextSanitizer()

    @Test func httpsURLIsMasked() {
        let result = sanitizer.sanitize("Visit https://example.com/docs for details.")
        #expect(result == "Visit <URL> for details.")
    }

    @Test func bareWWWUrlIsMasked() {
        let result = sanitizer.sanitize("See www.example.com for details.")
        #expect(result == "See <URL> for details.")
    }

    @Test func trailingPunctuationAfterURLIsKept() {
        let result = sanitizer.sanitize("Read https://example.com.")
        #expect(result == "Read <URL>.")
    }

    @Test func absolutePathIsMasked() {
        let result = sanitizer.sanitize("Open /Users/bob/notes.txt and read it.")
        #expect(result == "Open <PATH> and read it.")
    }

    @Test func homeRelativePathIsMasked() {
        let result = sanitizer.sanitize("Check ~/Documents/report.pdf first.")
        #expect(result == "Check <PATH> first.")
    }

    @Test func relativeWordsAndDecimalsAreNotMasked() {
        let text = "Use TCP/IP connections with version 3.14 of the library."
        #expect(sanitizer.sanitize(text) == text)
    }

    @Test func emailIsMasked() {
        let result = sanitizer.sanitize("Contact bob@example.com today.")
        #expect(result == "Contact <EMAIL> today.")
    }

    @Test func plainSentenceIsUnchanged() {
        let text = "The operating system schedules each process to run on the CPU."
        #expect(sanitizer.sanitize(text) == text)
    }

    @Test func emptyTextIsUnchanged() {
        #expect(sanitizer.sanitize("") == "")
    }

    @Test func multipleMasksInOneSentence() {
        let result = sanitizer.sanitize(
            "Email bob@example.com or visit https://example.com, then open /tmp/notes.txt."
        )
        #expect(result == "Email <EMAIL> or visit <URL>, then open <PATH>.")
    }
}
