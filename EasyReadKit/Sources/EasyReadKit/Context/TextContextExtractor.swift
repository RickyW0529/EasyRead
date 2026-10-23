//
//  TextContextExtractor.swift
//  EasyReadKit
//
//  Created by wangruiqi on 2026/10/9.
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation

// MARK: - TextContextExtractor

/// Pure context extraction: given the full text of a readable element and a
/// selection inside it, produce length-limited, sanitized surrounding text
/// plus an honest `ContextAvailability`.
///
/// The extractor never fabricates context: if the selection cannot be located
/// in the readable text, it degrades to `selectionOnly`; if the position is
/// ambiguous (the selection occurs multiple times) or the context had to be
/// hard-capped, it reports `nearbyText`.
public struct TextContextExtractor: Equatable, Sendable {
    // MARK: Lifecycle

    public init(
        policy: SelectionPolicy = .default,
        detector: SentenceBoundaryDetector = SentenceBoundaryDetector(),
        sanitizer: ContextSanitizer = ContextSanitizer()
    ) {
        self.policy = policy
        self.detector = detector
        self.sanitizer = sanitizer
    }

    // MARK: Public

    /// Extracted context ready to be stored in a `SelectionSnapshot`.
    public struct Result: Equatable, Sendable {
        public static let selectionOnly = Result(surroundingText: nil, availability: .selectionOnly)

        /// Length-limited, sanitized surrounding text. `nil` when no context
        /// could be captured.
        public let surroundingText: String?

        /// How trustworthy `surroundingText` is.
        public let availability: ContextAvailability
    }

    public var policy: SelectionPolicy
    public var detector: SentenceBoundaryDetector
    public var sanitizer: ContextSanitizer

    /// Extracts the context around `selectedText` from `fullText`.
    ///
    /// - Parameters:
    ///   - fullText: Full text of the focused element, if the source app
    ///     exposed it. May be `nil`.
    ///   - selectedText: The user's selected text (raw, will be trimmed).
    ///   - selectedRange: The selection range inside `fullText` in UTF-16
    ///     units, as reported by the Accessibility API. A range with length 0
    ///     or a mismatching range is ignored, and the selection is located by
    ///     searching the text instead.
    public func extractContext(
        fullText: String?,
        selectedText: String,
        selectedRange: NSRange?
    )
        -> Result {
        guard case let .valid(trimmedSelection) = policy.validateSelection(selectedText) else {
            return .selectionOnly
        }

        guard let fullText, !fullText.isEmpty else {
            return .selectionOnly
        }

        let nsFullText = fullText as NSString
        guard nsFullText.length > 0 else {
            return .selectionOnly
        }

        // 1. Locate the selection inside the readable text.
        var availability: ContextAvailability = .exactSentence
        guard let locatedRange = locateSelection(
            trimmedSelection,
            reportedRange: selectedRange,
            in: nsFullText,
            availability: &availability
        ) else {
            // The readable text does not contain the selection; it most likely
            // belongs to a different element. Never invent context from it.
            return .selectionOnly
        }

        // 2. Sentence containing the selection, extended to neighboring
        //    sentences within the context budget.
        let sentence = detector.sentenceRange(containing: locatedRange.location, in: fullText)
        let context = contextRange(aroundSentence: sentence, selection: locatedRange, in: nsFullText)

        if context.hardCapped {
            // The containing sentence alone exceeds the budget: cut a window
            // around the selection. Boundaries are incomplete, so degrade.
            availability = .nearbyText
        }

        // 3. Build the sanitized surrounding text.
        let rawContext = nsFullText.substring(with: context.range)
        let sanitized = sanitizer.sanitize(rawContext)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sanitized.isEmpty else {
            return .selectionOnly
        }

        return Result(surroundingText: sanitized, availability: availability)
    }

    // MARK: Private

    /// Characters that may trail a sentence's last content character: gap
    /// whitespace, extra terminators (ellipsis, `?!`) and closing quotes or
    /// brackets. Walking backwards over them lands on the previous
    /// sentence's final content character.
    private static let sentenceTailCharacters: Set<unichar> = [
        32, 9, 10, 13, 160, // space, tab, newline, carriage return, no-break space
        46, 33, 63, // . ! ?
        34, 39, 41, 93, 125, 187, 8217, 8221, // " ' ) ] } » ’ ”
    ]

    private static func isGapCharacter(_ c: unichar) -> Bool {
        c == 32 || c == 9 || c == 10 || c == 13 || c == 160
    }

    /// Locates the trimmed selection in the full text.
    ///
    /// A reported Accessibility range is trusted when its (trimmed) content
    /// matches the selection. Otherwise the text is searched: a unique
    /// occurrence determines the position; multiple occurrences still allow
    /// reading nearby text but downgrade availability to `nearbyText`.
    private func locateSelection(
        _ selection: String,
        reportedRange: NSRange?,
        in text: NSString,
        availability: inout ContextAvailability
    )
        -> NSRange? {
        if let reportedRange, reportedRange.length > 0, reportedRange.location >= 0,
           NSMaxRange(reportedRange) <= text.length {
            let reportedText = text.substring(with: reportedRange)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if reportedText == selection {
                return reportedRange
            }
        }

        let occurrences = occurrences(of: selection, in: text)
        switch occurrences.count {
        case 1:
            return occurrences[0]
        case 2...:
            // The selection cannot be uniquely located; the extracted text
            // may belong to a different occurrence.
            availability = .nearbyText
            return occurrences[0]
        default:
            return nil
        }
    }

    /// All UTF-16 ranges where `needle` occurs in `text` (literal search).
    private func occurrences(of needle: String, in text: NSString) -> [NSRange] {
        var result: [NSRange] = []
        var searchRange = NSRange(location: 0, length: text.length)
        while searchRange.location <= text.length {
            let found = text.range(
                of: needle,
                options: [.literal],
                range: searchRange
            )
            guard found.location != NSNotFound, found.length > 0 else {
                break
            }
            result.append(found)
            let next = NSMaxRange(found)
            guard next <= text.length else {
                break
            }
            searchRange = NSRange(location: next, length: text.length - next)
        }
        return result
    }

    /// Extends the containing sentence to neighboring sentences while the
    /// total stays within `policy.maxContextLength`.
    private func contextRange(
        aroundSentence sentence: NSRange,
        selection: NSRange,
        in text: NSString
    )
        -> (range: NSRange, hardCapped: Bool) {
        let length = text.length
        let maxLength = policy.maxContextLength

        var start = sentence.location
        var end = NSMaxRange(sentence)

        // Hard cap: the containing sentence alone is too long. Take a window
        // of at most `maxLength` UTF-16 units centered on the selection.
        if end - start > maxLength {
            let mid = selection.location + selection.length / 2
            let half = maxLength / 2
            let windowStart = max(0, mid - half)
            var windowEnd = min(length, windowStart + maxLength)
            let adjustedStart = max(0, windowEnd - maxLength)
            windowEnd = min(length, adjustedStart + maxLength)
            return (
                NSRange(location: adjustedStart, length: windowEnd - adjustedStart),
                true
            )
        }

        var currentLength = end - start
        while currentLength < maxLength {
            var extendedAny = false

            if start > 0, let previous = previousSentence(endingAt: start, in: text) {
                let newLength = currentLength + (start - previous.location)
                if newLength <= maxLength {
                    start = previous.location
                    currentLength = newLength
                    extendedAny = true
                }
            }

            if currentLength < maxLength, end < length,
               let next = nextSentence(startingAt: end, in: text) {
                let newLength = currentLength + (NSMaxRange(next) - end)
                if newLength <= maxLength {
                    end = NSMaxRange(next)
                    currentLength = newLength
                    extendedAny = true
                }
            }

            if !extendedAny {
                break
            }
        }

        return (NSRange(location: start, length: end - start), false)
    }

    /// The sentence whose text sits right before `start` (which may point at
    /// the gap between two sentences). `nil` when there is none.
    private func previousSentence(endingAt start: Int, in text: NSString) -> NSRange? {
        // Walk back over the gap, the previous sentence's terminator(s) and
        // any closing quotes or brackets, so the index lands on the last
        // content character of that sentence.
        var i = start - 1
        while i >= 0, Self.sentenceTailCharacters.contains(text.character(at: i)) {
            i -= 1
        }
        guard i >= 0 else {
            return nil
        }

        let range = detector.sentenceRange(containing: i, in: text as String)
        guard range.length > 0, range.location < start, NSMaxRange(range) <= start else {
            return nil
        }
        return range
    }

    /// The sentence whose text sits right after `end` (which may point at the
    /// gap between two sentences). `nil` when there is none.
    private func nextSentence(startingAt end: Int, in text: NSString) -> NSRange? {
        var i = end
        while i < text.length, Self.isGapCharacter(text.character(at: i)) {
            i += 1
        }
        guard i < text.length else {
            return nil
        }

        let range = detector.sentenceRange(containing: i, in: text as String)
        guard range.length > 0, range.location >= end, NSMaxRange(range) > end else {
            return nil
        }
        return range
    }
}
