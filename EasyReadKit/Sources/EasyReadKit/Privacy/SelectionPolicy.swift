//
//  SelectionPolicy.swift
//  EasyReadKit
//
//  Created by wangruiqi on 2026/10/9.
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation

// MARK: - SelectionPolicy

/// Conservative size limits for selections and extracted context.
///
/// Defaults follow the EasyRead development spec: a single selection may be
/// at most 2,000 characters, and the context sent around a selection is at
/// most 600 characters, trimmed on real sentence boundaries with a hard cap.
public struct SelectionPolicy: Equatable, Sendable {
    /// Maximum number of characters allowed in one selection.
    public let maxSelectionLength: Int

    /// Maximum number of characters of surrounding context (total, before and
    /// after the selection combined).
    public let maxContextLength: Int

    public init(maxSelectionLength: Int = 2_000, maxContextLength: Int = 600) {
        self.maxSelectionLength = maxSelectionLength
        self.maxContextLength = maxContextLength
    }

    // MARK: Internal

    /// Default limits from the development spec.
    public static let `default` = SelectionPolicy()

    /// Validates a raw selected text.
    ///
    /// Over-long selections are rejected, never silently truncated: the user
    /// must narrow the selection (acceptance case T17).
    public func validateSelection(_ text: String) -> SelectionValidation {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .empty
        }
        if trimmed.count > maxSelectionLength {
            return .tooLong(length: trimmed.count)
        }
        return .valid(trimmedText: trimmed)
    }
}

// MARK: - SelectionValidation

/// Result of validating the user's raw selection.
public enum SelectionValidation: Equatable, Sendable {
    /// The selection is usable; `trimmedText` is the trimmed selection.
    case valid(trimmedText: String)

    /// The selection contains no visible content.
    case empty

    /// The selection is longer than `SelectionPolicy.maxSelectionLength`.
    /// The value is the trimmed character count.
    case tooLong(length: Int)

    /// Whether the selection can be used for queries.
    public var isUsable: Bool {
        switch self {
        case .valid:
            true
        case .empty, .tooLong:
            false
        }
    }
}
