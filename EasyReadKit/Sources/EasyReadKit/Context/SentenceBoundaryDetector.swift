//
//  SentenceBoundaryDetector.swift
//  EasyReadKit
//
//  Created by wangruiqi on 2026/10/9.
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation

// MARK: - SentenceBoundaryDetector

/// Heuristic English sentence boundary detection for context extraction.
///
/// The detector is deliberately conservative: a missed boundary only makes the
/// extracted sentence longer (still real source text), while a false boundary
/// would fabricate a "precise original sentence" that never existed. It
/// therefore requires strong evidence (gap + sentence-like next word) before
/// treating a `.`, `!` or `?` as the end of a sentence.
///
/// Handled cases: common abbreviations (`e.g.`, `i.e.`, `Fig.`, `Dr.`),
/// name initials (`J. Smith`), decimal numbers (`3.14`), ellipses (`...`),
/// closing quotes and brackets after terminators, parentheses nesting,
/// backtick spans and newlines as hard boundaries.
///
/// Known limitation: the backward scan does not track parenthesis depth, so a
/// sentence that *starts* inside parentheses may be cut at their terminator.
/// This only ever makes the extracted text shorter, never fabricated.
public struct SentenceBoundaryDetector: Equatable, Sendable {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    /// Lowercase tokens (letters and inner dots) whose trailing period does
    /// not end a sentence.
    public static let abbreviations: Set<String> = [
        "e.g", "i.e", "etc", "al", "approx", "apt", "apr", "aug", "ca", "cf",
        "dec", "dept", "dist", "dr", "eq", "est", "ex", "feb", "fig", "fri",
        "govt", "inc", "jan", "jr", "jul", "jun", "ltd", "mar", "max", "min",
        "mon", "mr", "mrs", "ms", "no", "nov", "oct", "prof", "resp", "sat",
        "sec", "sept", "sr", "st", "sun", "tue", "tues", "thu", "thurs", "univ",
        "viz", "vs", "wed",
    ]

    /// Returns the UTF-16 range of the sentence in `text` that contains
    /// `location`.
    ///
    /// If `location` falls on whitespace, the scan first steps back onto the
    /// preceding non-whitespace character, so an index in the gap between two
    /// sentences resolves to the sentence that follows the gap. The returned
    /// range may include leading whitespace; callers trim it.
    public func sentenceRange(containing location: Int, in text: String) -> NSRange {
        let nsText = text as NSString
        let length = nsText.length
        guard length > 0 else {
            return NSRange(location: 0, length: 0)
        }

        var effective = min(max(location, 0), length - 1)
        while effective > 0, Self.isWhitespace(nsText.character(at: effective)) {
            effective -= 1
        }

        let start = sentenceStart(before: effective, in: nsText)
        let end = sentenceEnd(after: start, in: nsText)

        // Safety net: the sentence must at least contain the effective location.
        if end <= effective {
            return NSRange(location: start, length: length - start)
        }
        return NSRange(location: start, length: end - start)
    }

    // MARK: Private

    private static let period: unichar = 46
    private static let exclamation: unichar = 33
    private static let question: unichar = 63
    private static let newline: unichar = 10
    private static let carriageReturn: unichar = 13
    private static let backtick: unichar = 96

    private static let closingPunctuation: Set<unichar> = [
        34, // "
        39, // '
        41, // )
        93, // ]
        125, // }
        187, // »
        8217, // ’
        8221, // ”
    ]

    // MARK: Character classification

    private static func isTerminator(_ c: unichar) -> Bool {
        c == period || c == exclamation || c == question
    }

    private static func isNewline(_ c: unichar) -> Bool {
        c == newline || c == carriageReturn
    }

    private static func isWhitespace(_ c: unichar) -> Bool {
        c == 32 || c == 9 || c == 160 || c == 0x2028 || c == 0x2029
    }

    private static func isDigit(_ c: unichar) -> Bool {
        c >= 48 && c <= 57
    }

    private static func isLetter(_ c: unichar) -> Bool {
        (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || (c >= 128 && c <= 255 && c != 215 && c != 247)
    }

    private static func isOpenBracket(_ c: unichar) -> Bool {
        c == 40 || c == 91 || c == 123 // ( [ {
    }

    private static func isCloseBracket(_ c: unichar) -> Bool {
        c == 41 || c == 93 || c == 125 // ) ] }
    }

    private static func isClosingPunctuation(_ c: unichar) -> Bool {
        closingPunctuation.contains(c)
    }

    /// Whether a character can start a new sentence: uppercase letters,
    /// digits, quotes, opening brackets and common markdown markers.
    private static func isWordStartLike(_ c: unichar) -> Bool {
        if c >= 65, c <= 90 { // A-Z
            return true
        }
        if c >= 192, c <= 222, c != 215 { // Latin-1 uppercase
            return true
        }
        if isDigit(c) {
            return true
        }
        switch c {
        case 34, 35, 39, 40, 42, 45, // " ' ( < [ {
             60, 62, 91, 95, 123, // " ' ( < [ {
             126, 171, // * # > - _ ~ “ ‘ «
             8216, 8220: // * # > - _ ~ “ ‘ «
            return true
        default:
            return false
        }
    }

    /// Scans backwards for the start of the sentence containing `location`.
    private func sentenceStart(before location: Int, in text: NSString) -> Int {
        var i = location
        while i >= 0 {
            let c = text.character(at: i)
            if Self.isNewline(c) {
                return i + 1
            }
            if Self.isTerminator(c), let gapIndex = boundaryGapIndex(at: i, in: text) {
                return gapIndex
            }
            i -= 1
        }
        return 0
    }

    /// Scans forwards for the end of the sentence that starts at `start`.
    ///
    /// Tracks parenthesis depth and backtick spans from the sentence start so
    /// terminators inside them do not end the sentence.
    private func sentenceEnd(after start: Int, in text: NSString) -> Int {
        let length = text.length
        var depth = 0
        var inBacktick = false
        var i = start

        while i < length {
            let c = text.character(at: i)
            if Self.isNewline(c) {
                return i
            }
            if Self.isOpenBracket(c) {
                depth += 1
            } else if Self.isCloseBracket(c) {
                if depth > 0 {
                    depth -= 1
                }
            } else if c == Self.backtick {
                inBacktick.toggle()
            } else if Self.isTerminator(c), depth == 0, !inBacktick,
                      let gapIndex = boundaryGapIndex(at: i, in: text) {
                return gapIndex
            }
            i += 1
        }
        return length
    }

    /// If the terminator at `index` really ends a sentence, returns the index
    /// just after the terminator, any consecutive terminators (ellipsis,
    /// `?!`) and any closing quotes or brackets — the start of the gap before
    /// the next sentence. Otherwise returns `nil`.
    ///
    /// A terminator counts only when followed by a gap (whitespace, newline
    /// or end of text) and, unless a newline follows, the next visible
    /// character looks like the start of a new sentence.
    private func boundaryGapIndex(at index: Int, in text: NSString) -> Int? {
        let length = text.length
        guard Self.isTerminator(text.character(at: index)) else {
            return nil
        }

        var j = index + 1
        while j < length, Self.isTerminator(text.character(at: j)) {
            j += 1
        }
        while j < length, Self.isClosingPunctuation(text.character(at: j)) {
            j += 1
        }

        guard j == length
            || Self.isWhitespace(text.character(at: j))
            || Self.isNewline(text.character(at: j))
        else {
            return nil
        }

        if text.character(at: index) == Self.period {
            if isDecimalPoint(at: index, in: text) {
                return nil
            }
            if isAbbreviationPeriod(at: index, in: text) {
                return nil
            }
        }

        // Unless a newline or end of text follows, the next visible character
        // must look like the beginning of a sentence.
        if j < length, !Self.isNewline(text.character(at: j)) {
            guard let nextVisible = firstNonWhitespaceIndex(after: j, in: text) else {
                return j
            }
            guard Self.isWordStartLike(text.character(at: nextVisible)) else {
                return nil
            }
        }

        return j
    }

    /// Whether the period at `index` sits between two digits (`3.14`).
    private func isDecimalPoint(at index: Int, in text: NSString) -> Bool {
        let length = text.length
        guard index > 0, index + 1 < length else {
            return false
        }
        let before = text.character(at: index - 1)
        let after = text.character(at: index + 1)
        return Self.isDigit(before) && Self.isDigit(after)
    }

    /// Whether the period at `index` ends a known abbreviation or a name
    /// initial (`Fig.`, `e.g.`, `J. Smith`).
    private func isAbbreviationPeriod(at index: Int, in text: NSString) -> Bool {
        var i = index - 1
        while i >= 0 {
            let c = text.character(at: i)
            if Self.isLetter(c) || c == Self.period {
                i -= 1
            } else {
                break
            }
        }

        let tokenRange = NSRange(location: i + 1, length: index - (i + 1))
        guard tokenRange.length > 0 else {
            return false
        }

        var token = text.substring(with: tokenRange)
        // Strip leading dots left over from ellipses.
        while let first = token.first, first == "." {
            token.removeFirst()
        }

        guard !token.isEmpty else {
            return false
        }

        // A single uppercase letter is a name initial, e.g. "J. Smith".
        if token.count == 1, let scalar = token.unicodeScalars.first {
            return CharacterSet.uppercaseLetters.contains(scalar)
        }

        return Self.abbreviations.contains(token.lowercased())
    }

    private func firstNonWhitespaceIndex(after index: Int, in text: NSString) -> Int? {
        var i = index
        while i < text.length {
            let c = text.character(at: i)
            if !Self.isWhitespace(c), !Self.isNewline(c) {
                return i
            }
            i += 1
        }
        return nil
    }
}
