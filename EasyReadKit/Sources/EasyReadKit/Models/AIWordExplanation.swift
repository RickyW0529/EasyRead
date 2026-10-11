//
//  AIWordExplanation.swift
//  EasyReadKit
//
//  Created by wangruiqi on 2026/10/10.
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation

// MARK: - TerminologyItem

/// One technical term of an `AIWordExplanation` (spec 4.1 data contract).
public struct TerminologyItem: Decodable, Equatable, Sendable {
    public let term: String
    public let meaningZh: String

    public init(term: String, meaningZh: String) {
        self.term = term
        self.meaningZh = meaningZh
    }
}

// MARK: - AIWordExplanation

/// Structured in-context explanation of the selected word, decoded from the
/// model's `word_in_context` JSON answer (spec 4.1/5.1).
///
/// JSON being syntactically valid is not schema compliance (spec 4.4): call
/// `validated(queriedText:sourceSentence:)` before displaying anything, so
/// fabricated context and oversized fields never reach the result card.
public struct AIWordExplanation: Decodable, Equatable, Sendable {
    // MARK: Lifecycle

    public init(
        selectedText: String,
        primaryMeaningZh: String,
        partOfSpeech: String? = nil,
        contextualEvidence: String? = nil,
        explanationZh: String,
        terminology: [TerminologyItem] = [],
        contextStatus: ContextStatus
    ) {
        self.selectedText = selectedText
        self.primaryMeaningZh = primaryMeaningZh
        self.partOfSpeech = partOfSpeech
        self.contextualEvidence = contextualEvidence
        self.explanationZh = explanationZh
        self.terminology = terminology
        self.contextStatus = contextStatus
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedText = try container.decode(String.self, forKey: .selectedText)
        primaryMeaningZh = try container.decode(String.self, forKey: .primaryMeaningZh)
        partOfSpeech = try container.decodeIfPresent(String.self, forKey: .partOfSpeech)
        contextualEvidence = try container.decodeIfPresent(String.self, forKey: .contextualEvidence)
        explanationZh = try container.decode(String.self, forKey: .explanationZh)
        // The schema requires the array, but models sometimes omit it when a
        // word has no relevant terminology; an empty list is the honest value.
        terminology = try container.decodeIfPresent([TerminologyItem].self, forKey: .terminology) ?? []
        contextStatus = try container.decode(ContextStatus.self, forKey: .contextStatus)
    }

    // MARK: Public

    /// Whether the answer was grounded in the provided source sentence.
    public enum ContextStatus: String, Codable, Sendable {
        /// The explanation used the provided sentence.
        case contextual
        /// The model answered from the word alone.
        case selectionOnly = "selection_only"
    }

    public let selectedText: String
    public let primaryMeaningZh: String
    public let partOfSpeech: String?
    public let contextualEvidence: String?
    public let explanationZh: String
    public let terminology: [TerminologyItem]
    public let contextStatus: ContextStatus

    // MARK: Private

    private enum CodingKeys: String, CodingKey {
        case selectedText
        case primaryMeaningZh
        case partOfSpeech
        case contextualEvidence
        case explanationZh
        case terminology
        case contextStatus
    }
}

// MARK: - AIWordExplanation + Decoding

extension AIWordExplanation {
    /// Decodes one assistant message body (spec 4.4/5.1). Defensively strips
    /// a Markdown code fence the model may add despite `response_format`.
    public static func decode(jsonContent: String) throws -> AIWordExplanation {
        let stripped = strippingCodeFences(jsonContent)
        return try JSONDecoder().decode(AIWordExplanation.self, from: Data(stripped.utf8))
    }

    /// Removes an opening ` ``` `/` ```json ` line and a closing ` ``` ` line.
    static func strippingCodeFences(_ content: String) -> String {
        var text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix("```") else {
            return text
        }

        if let firstLineEnd = text.firstIndex(of: "\n") {
            text = String(text[text.index(after: firstLineEnd)...])
        } else {
            return ""
        }

        if text.hasSuffix("```") {
            text = String(text.dropLast(3))
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - AIWordExplanation + Validation

extension AIWordExplanation {
    /// Render-safety limits (spec 5.1/5.2: no field or array may grow so
    /// large that the result card becomes unreadable).
    public enum Limits {
        public static let maxSelectedTextLength = 2000
        public static let maxPrimaryMeaningLength = 200
        public static let maxPartOfSpeechLength = 30
        public static let maxContextualEvidenceLength = 400
        public static let maxExplanationLength = 2000
        public static let maxTermLength = 100
        public static let maxMeaningLength = 300
        public static let maxTerminologyItems = 20
    }

    /// Field names reported by validation errors.
    public enum Field: String, Equatable, Sendable {
        case selectedText
        case primaryMeaningZh
        case partOfSpeech
        case contextualEvidence
        case explanationZh
    }

    /// Why a decoded explanation was rejected. Never carries model content.
    public enum ValidationError: Error, Equatable, Sendable {
        /// A required field is present but empty.
        case emptyField(Field)
        /// A field exceeds its render-safety limit.
        case fieldTooLong(Field, limit: Int)
        /// The echoed `selectedText` differs from the queried text
        /// (whitespace may be unified, words may not — spec 5.2).
        case selectedTextMismatch
        /// `contextStatus` claims context the request never provided.
        case fabricatedContextStatus
    }

    /// Validates this explanation against the query it answers and returns
    /// the copy that is safe to render.
    ///
    /// - Parameters:
    ///   - queriedText: the text the user selected. The echoed
    ///     `selectedText` must match it after whitespace normalization.
    ///   - sourceSentence: the sentence sent with the request; `nil` when
    ///     the request was selection-only.
    ///
    /// Rejected (thrown): empty or oversized scalar fields, an echo that
    /// rewrites the queried text, and a `contextStatus` that claims context
    /// the request never had. Sanitized instead: `partOfSpeech` is
    /// normalized to `nil` when empty or oversized, terminology items that
    /// are empty or oversized are dropped with the list capped at
    /// `Limits.maxTerminologyItems`, and a `contextualEvidence` that is not
    /// a verifiable fragment of the provided sentence is dropped — an
    /// unverifiable quote is never displayed (spec 5.1).
    public func validated(queriedText: String, sourceSentence: String?) throws -> AIWordExplanation {
        let partOfSpeech = normalizedOptional(partOfSpeech, limit: Limits.maxPartOfSpeechLength)

        guard !primaryMeaningZh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyField(.primaryMeaningZh)
        }
        guard primaryMeaningZh.count <= Limits.maxPrimaryMeaningLength else {
            throw ValidationError.fieldTooLong(.primaryMeaningZh, limit: Limits.maxPrimaryMeaningLength)
        }
        guard !explanationZh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyField(.explanationZh)
        }
        guard explanationZh.count <= Limits.maxExplanationLength else {
            throw ValidationError.fieldTooLong(.explanationZh, limit: Limits.maxExplanationLength)
        }

        let normalizedQueriedText = Self.normalizedWhitespace(queriedText)
        guard !normalizedQueriedText.isEmpty else {
            throw ValidationError.selectedTextMismatch
        }
        guard selectedText.count <= Limits.maxSelectedTextLength else {
            throw ValidationError.fieldTooLong(.selectedText, limit: Limits.maxSelectedTextLength)
        }
        guard Self.normalizedWhitespace(selectedText) == normalizedQueriedText else {
            throw ValidationError.selectedTextMismatch
        }

        if sourceSentence == nil, contextStatus == .contextual {
            throw ValidationError.fabricatedContextStatus
        }

        let evidence = verifiedContextualEvidence(sourceSentence: sourceSentence)

        return AIWordExplanation(
            selectedText: selectedText,
            primaryMeaningZh: primaryMeaningZh,
            partOfSpeech: partOfSpeech,
            contextualEvidence: evidence,
            explanationZh: explanationZh,
            terminology: Self.sanitizedTerminology(terminology),
            contextStatus: contextStatus
        )
    }

    // MARK: Private

    /// Trims and drops an optional string that is empty or over its limit.
    private func normalizedOptional(_ value: String?, limit: Int) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              trimmed.count <= limit
        else {
            return nil
        }
        return trimmed
    }

    /// The contextual evidence only when it is a verifiable fragment of the
    /// provided sentence (spec 5.1: it must quote the real sentence). With
    /// no sentence in the request, any evidence is fabricated and dropped.
    private func verifiedContextualEvidence(sourceSentence: String?) -> String? {
        let candidate = normalizedOptional(
            contextualEvidence,
            limit: Limits.maxContextualEvidenceLength
        )
        guard let candidate, let sourceSentence else {
            return nil
        }

        let normalizedSentence = Self.normalizedWhitespace(sourceSentence)
        let normalizedEvidence = Self.normalizedWhitespace(candidate)
        guard !normalizedEvidence.isEmpty,
              normalizedSentence.contains(normalizedEvidence)
        else {
            return nil
        }
        return candidate
    }

    /// Drops empty or oversized items and caps the list size.
    private static func sanitizedTerminology(_ items: [TerminologyItem]) -> [TerminologyItem] {
        Array(
            items
                .filter { item in
                    !item.term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && !item.meaningZh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && item.term.count <= Limits.maxTermLength
                        && item.meaningZh.count <= Limits.maxMeaningLength
                }
                .prefix(Limits.maxTerminologyItems)
        )
    }

    /// Collapses all whitespace runs to single spaces and trims the ends.
    static func normalizedWhitespace(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
    }
}
