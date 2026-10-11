// Copyright © 2026 EasyRead contributors. GPL-3.0.
import Foundation

/// One grammar structure grounded in a literal fragment of the selected sentence.
public struct GrammarStructure: Decodable, Equatable, Sendable {
    public let excerpt: String
    public let labelZh: String
    public let explanationZh: String
}

/// A complete, validated sentence analysis. Never render raw decoded output.
public struct GrammarExplanation: Decodable, Equatable, Sendable {
    public let originalSentence: String
    public let translationZh: String
    public let mainClause: String
    public let structures: [GrammarStructure]
    public let readingSteps: [String]
    public let terminology: [TerminologyItem]
    public let comprehensionQuestion: String?

    /// Carries no reading text or model output.
    public enum ValidationError: Error, Equatable, Sendable {
        case originalMismatch
        case invalidField
        case inventedExcerpt
    }

    public static func decode(jsonContent: String) throws -> Self {
        try JSONDecoder().decode(Self.self, from: Data(AIWordExplanation.strippingCodeFences(jsonContent).utf8))
    }

    /// Rejects fabricated evidence, empty fields and excessive output before display.
    public func validated(queriedSentence: String) throws -> Self {
        let normalized = AIWordExplanation.normalizedWhitespace(queriedSentence)
        guard !normalized.isEmpty, originalSentence.count <= 2000,
              AIWordExplanation.normalizedWhitespace(originalSentence) == normalized else {
            throw ValidationError.originalMismatch
        }
        guard Self.valid(translationZh, limit: 4000), Self.valid(mainClause, limit: 2000),
              !structures.isEmpty, structures.count <= 20,
              !readingSteps.isEmpty, readingSteps.count <= 20,
              readingSteps.allSatisfy({ Self.valid($0, limit: 2000) }),
              terminology.count <= 20,
              terminology.allSatisfy({ Self.valid($0.term, limit: 100) && Self.valid($0.meaningZh, limit: 300) }),
              comprehensionQuestion.map({ Self.valid($0, limit: 1000) }) ?? true else {
            throw ValidationError.invalidField
        }
        for structure in structures {
            guard Self.valid(structure.excerpt, limit: 2000), Self.valid(structure.labelZh, limit: 100),
                  Self.valid(structure.explanationZh, limit: 2000) else {
                throw ValidationError.invalidField
            }
            guard normalized.contains(AIWordExplanation.normalizedWhitespace(structure.excerpt)) else {
                throw ValidationError.inventedExcerpt
            }
        }
        return self
    }

    private static func valid(_ value: String, limit: Int) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.count <= limit
    }
}

/// Translation-only responses use a separate contract, avoiding an unsolicited grammar report.
public struct SentenceTranslation: Decodable, Equatable, Sendable {
    public let originalSentence: String
    public let translationZh: String

    public static func decode(jsonContent: String, queriedSentence: String) throws -> Self {
        let answer = try JSONDecoder().decode(Self.self, from: Data(AIWordExplanation.strippingCodeFences(jsonContent).utf8))
        guard AIWordExplanation.normalizedWhitespace(answer.originalSentence) == AIWordExplanation.normalizedWhitespace(queriedSentence),
              !queriedSentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              answer.originalSentence.count <= 2000,
              !answer.translationZh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              answer.translationZh.count <= 4000 else {
            throw GrammarExplanation.ValidationError.invalidField
        }
        return answer
    }
}
