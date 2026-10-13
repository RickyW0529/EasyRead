// Copyright © 2026 EasyRead contributors. GPL-3.0.
import Foundation

// MARK: - GrammarStructure

/// One grammar structure grounded in a literal fragment of the selected sentence.
public struct GrammarStructure: Decodable, Equatable, Sendable {
    // MARK: Lifecycle

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.excerpt = try values.decode(String.self, forKey: .excerpt)
        self.label = try values.decodeIfPresent(String.self, forKey: .label) ?? values.decode(
            String.self,
            forKey: .labelZh
        )
        self.explanation = try values.decodeIfPresent(String.self, forKey: .explanation) ?? values.decode(
            String.self,
            forKey: .explanationZh
        )
        self.occurrence = try values.decodeIfPresent(Int.self, forKey: .occurrence)
        self.role = try values.decodeIfPresent(Role.self, forKey: .role)
    }

    // MARK: Public

    public enum Role: String, Decodable, Sendable {
        case subject, predicate, object, adverbial, attributive, complement, other
    }

    public let excerpt: String
    public let label: String
    public let explanation: String
    public let role: Role?
    /// Zero-based occurrence among whole-word matches; omitted legacy values require a unique match.
    public let occurrence: Int?

    public var labelZh: String { label }
    public var explanationZh: String { explanation }

    public func sourceRange(in source: String) -> NSRange? {
        let trimmed = excerpt.trimmingCharacters(in: .whitespacesAndNewlines)
        var pattern = trimmed.split(whereSeparator: \.isWhitespace)
            .map { NSRegularExpression.escapedPattern(for: String($0)) }.joined(separator: "\\s+")
        guard !pattern.isEmpty else { return nil }
        if let first = trimmed.first, Self.usesWordBoundary(first) {
            pattern = "(?<![\\p{Latin}\\p{Greek}\\p{Cyrillic}\\p{M}\\p{N}_])" + pattern
        }
        if let last = trimmed.last, Self.usesWordBoundary(last) {
            pattern += "(?![\\p{Latin}\\p{Greek}\\p{Cyrillic}\\p{M}\\p{N}_])"
        }
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let matches = regex.matches(in: source, range: NSRange(source.startIndex..., in: source))
        if let occurrence {
            guard matches.indices.contains(occurrence) else { return nil }
            return matches[occurrence].range
        }
        return matches.count == 1 ? matches.first?.range : nil
    }

    // MARK: Private

    private enum CodingKeys: String, CodingKey {
        case excerpt, occurrence, role, label, explanation, labelZh, explanationZh
    }

    private static func usesWordBoundary(_ character: Character) -> Bool {
        String(character).range(of: #"[\p{Latin}\p{Greek}\p{Cyrillic}\p{N}]"#, options: .regularExpression) != nil
    }
}

// MARK: - GrammarExplanation

/// A complete, validated sentence analysis. Never render raw decoded output.
public struct GrammarExplanation: Decodable, Equatable, Sendable {
    // MARK: Lifecycle

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.originalSentence = try container.decode(String.self, forKey: .originalSentence)
        self.translation = try container.decodeIfPresent(String.self, forKey: .translation) ?? container.decode(
            String.self,
            forKey: .translationZh
        )
        self.mainClause = try container.decode(String.self, forKey: .mainClause)
        self.structures = try container.decode([GrammarStructure].self, forKey: .structures)
        self.readingSteps = try container.decode([String].self, forKey: .readingSteps)
        // An omitted optional glossary means no terminology, not a failed grammar analysis.
        self.terminology = try container.decodeIfPresent([TerminologyItem].self, forKey: .terminology) ?? []
        self.comprehensionQuestion = try container.decodeIfPresent(String.self, forKey: .comprehensionQuestion)
    }

    // MARK: Public

    /// Carries no reading text or model output.
    public enum ValidationError: Error, Equatable, Sendable {
        case originalMismatch
        case invalidField
        case inventedExcerpt
    }

    public let originalSentence: String
    public let translation: String
    public let mainClause: String
    public let structures: [GrammarStructure]
    public let readingSteps: [String]
    public let terminology: [TerminologyItem]
    public let comprehensionQuestion: String?

    public var translationZh: String { translation }

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
            if structure.occurrence != nil, structure.sourceRange(in: queriedSentence) == nil {
                throw ValidationError.invalidField
            }
        }
        return self
    }

    // MARK: Private

    private enum CodingKeys: String, CodingKey {
        case originalSentence, translation, translationZh, mainClause, structures, readingSteps, terminology,
             comprehensionQuestion
    }

    private static func valid(_ value: String, limit: Int) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.count <= limit
    }
}

// MARK: - SentenceTranslation

/// Translation-only responses use a separate contract, avoiding an unsolicited grammar report.
public struct SentenceTranslation: Decodable, Equatable, Sendable {
    // MARK: Lifecycle

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.originalSentence = try values.decode(String.self, forKey: .originalSentence)
        self.translation = try values.decodeIfPresent(String.self, forKey: .translation) ?? values.decode(
            String.self,
            forKey: .translationZh
        )
    }

    // MARK: Public

    public let originalSentence: String
    public let translation: String

    public var translationZh: String { translation }

    public static func decode(jsonContent: String, queriedSentence: String) throws -> Self {
        let answer = try JSONDecoder().decode(
            Self.self,
            from: Data(AIWordExplanation.strippingCodeFences(jsonContent).utf8)
        )
        guard AIWordExplanation.normalizedWhitespace(answer.originalSentence) == AIWordExplanation
            .normalizedWhitespace(queriedSentence),
            !queriedSentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            answer.originalSentence.count <= 2000,
            !answer.translationZh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            answer.translationZh.count <= 4000 else {
            throw GrammarExplanation.ValidationError.invalidField
        }
        return answer
    }

    // MARK: Private

    private enum CodingKeys: String, CodingKey { case originalSentence, translation, translationZh }
}
