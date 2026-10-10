//
//  ContextSanitizer.swift
//  EasyReadKit
//
//  Created by wangruiqi on 2026/10/9.
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation

// MARK: - ContextSanitizer

/// Masks content that must never leave the machine before context text is
/// stored in a `SelectionSnapshot`: URLs, absolute file paths and email
/// addresses (spec: "do not send URLs, web page titles, absolute file paths
/// or in-app account names").
///
/// Detection is deliberately conservative and pattern-based. Application
/// account names embedded in prose cannot be detected reliably; the
/// sensitive-app exclusion rules are the boundary for those cases.
public struct ContextSanitizer: Equatable, Sendable {
    public static let urlMask = "<URL>"
    public static let pathMask = "<PATH>"
    public static let emailMask = "<EMAIL>"

    public init() {}

    /// Matches http/https and bare www URLs, excluding trailing punctuation
    /// commonly attached to links in prose.
    private static let urlRegex = try? NSRegularExpression(
        pattern: #"(?i)\b(?:https?://|www\.)[^\s]+[^\s.,;:!?)\]}]"#,
        options: []
    )

    /// Matches absolute POSIX paths and `~/...` paths with at least one
    /// inner slash, e.g. `/Users/me/notes.txt`, `/usr/bin/env`, `~/Documents`.
    /// The final segment never ends in a dot, so a sentence's trailing period
    /// is kept. The `[` inside the lookbehind class must stay escaped for ICU.
    private static let pathRegex = try? NSRegularExpression(
        pattern: #"(?:^|(?<=\s)|(?<=[(\[]))~?/(?:[\w.\-]+/)+(?:[\w.\-]*[\w\-])?"#,
        options: []
    )

    /// Matches common email addresses.
    private static let emailRegex = try? NSRegularExpression(
        pattern: #"\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b"#,
        options: []
    )

    /// Returns the text with URLs, file paths and email addresses masked.
    public func sanitize(_ text: String) -> String {
        guard !text.isEmpty else {
            return text
        }

        var result = Self.mask(text, regex: Self.urlRegex, mask: Self.urlMask)
        result = Self.mask(result, regex: Self.pathRegex, mask: Self.pathMask)
        result = Self.mask(result, regex: Self.emailRegex, mask: Self.emailMask)
        return result
    }

    private static func mask(_ text: String, regex: NSRegularExpression?, mask: String) -> String {
        guard let regex else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: mask
        )
    }
}
