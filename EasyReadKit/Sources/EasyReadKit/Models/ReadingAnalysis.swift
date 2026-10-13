// Copyright © 2026 EasyRead contributors. GPL-3.0.
import Foundation

/// Validated, language-neutral result of one reading request, ready for local presentation changes.
public struct ReadingAnalysis: Decodable, Sendable {
    public enum Kind: String, Decodable, Sendable { case word, phrase, sentence }

    public let kind: Kind
    public let originalText: String
    public let translation: String
    public let wordExplanation: AIWordExplanation?
    public let grammar: GrammarExplanation?

    public static func decode(jsonContent: String, queriedText: String, sourceSentence: String?) throws -> Self {
        let answer = try JSONDecoder().decode(
            Self.self,
            from: Data(AIWordExplanation.strippingCodeFences(jsonContent).utf8)
        )
        guard !queriedText.isEmpty, answer.originalText.count <= 2000,
              AIWordExplanation.normalizedWhitespace(answer.originalText) == AIWordExplanation
              .normalizedWhitespace(queriedText),
              !answer.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              answer.translation.count <= 4000 else { throw GrammarExplanation.ValidationError.invalidField }
        switch answer.kind {
        case .phrase, .word:
            guard let word = answer.wordExplanation, answer.grammar == nil else {
                throw GrammarExplanation.ValidationError.invalidField
            }
            let validated = try word.validated(queriedText: queriedText, sourceSentence: sourceSentence)
            return Self(
                kind: answer.kind,
                originalText: answer.originalText,
                translation: answer.translation,
                wordExplanation: validated,
                grammar: nil
            )
        case .sentence:
            guard let grammar = answer.grammar, answer.wordExplanation == nil else {
                throw GrammarExplanation.ValidationError.invalidField
            }
            return Self(
                kind: answer.kind,
                originalText: answer.originalText,
                translation: answer.translation,
                wordExplanation: nil,
                grammar: try grammar.validated(queriedSentence: queriedText)
            )
        }
    }
}
