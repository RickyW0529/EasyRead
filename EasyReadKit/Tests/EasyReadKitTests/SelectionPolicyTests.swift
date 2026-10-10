//
//  SelectionPolicyTests.swift
//  EasyReadKit
//
//  Created by wangruiqi on 2026/10/9.
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation
import Testing

@testable import EasyReadKit

// MARK: - SelectionPolicyTests

@Suite
struct SelectionPolicyTests {
    // MARK: Internal

    @Test func validSelectionIsTrimmed() {
        let policy = SelectionPolicy()
        #expect(policy.validateSelection("  hello world  ") == .valid(trimmedText: "hello world"))
        #expect(policy.validateSelection("hello").isUsable)
    }

    @Test func emptySelection() {
        let policy = SelectionPolicy()
        #expect(policy.validateSelection("") == .empty)
        #expect(policy.validateSelection("   \n\t ") == .empty)
        #expect(!policy.validateSelection("").isUsable)
    }

    @Test func selectionAtLimitIsValid() {
        let policy = SelectionPolicy()
        let text = String(repeating: "a", count: 2_000)
        #expect(policy.validateSelection(text) == .valid(trimmedText: text))
    }

    @Test func overlongSelectionIsRejectedNotTruncated() {
        // T17: over the limit the selection is rejected with its real length;
        // it is never silently truncated.
        let policy = SelectionPolicy()
        let text = String(repeating: "a", count: 2_001)
        #expect(policy.validateSelection(text) == .tooLong(length: 2_001))
        #expect(!policy.validateSelection(text).isUsable)
    }

    @Test func customLimits() {
        let policy = SelectionPolicy(maxSelectionLength: 10, maxContextLength: 100)
        #expect(policy.validateSelection(String(repeating: "a", count: 11)) == .tooLong(length: 11))
        #expect(policy.maxContextLength == 100)
    }

    @Test func defaultLimitsMatchSpec() {
        let policy = SelectionPolicy.default
        #expect(policy.maxSelectionLength == 2_000)
        #expect(policy.maxContextLength == 600)
    }
}
