// Copyright © 2026 EasyRead contributors. GPL-3.0.
import EasyReadKit
import SFSafeSymbols
import SwiftUI

/// A compact contextual explanation rendered from validated fields, never raw Markdown.
struct ReadingContextTip: View {
    let answer: AIWordExplanation
    let context: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Image(systemSymbol: .lightbulb).foregroundStyle(Color.accentColor)
                Text(answer
                    .contextStatus == .contextual ? LocalizedStringKey("reading.context.meaning") :
                    LocalizedStringKey("reading.context.word_only"))
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if let part = answer.partOfSpeech {
                    Text(verbatim: part).font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(verbatim: answer.primaryMeaning).font(.headline)
            Text(verbatim: answer.explanation).font(.system(size: 13)).lineSpacing(4)
            if answer.contextStatus == .contextual, let context, !context.isEmpty {
                DisclosureGroup("deepseek.explanation.context_passage") {
                    Text(verbatim: context).font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.caption)
            } else {
                Text("reading.context.unavailable").font(.caption).foregroundStyle(.secondary)
            }
            if !answer.terminology.isEmpty {
                DisclosureGroup("reading.grammar.terminology") {
                    ForEach(Array(answer.terminology.enumerated()), id: \.offset) { _, item in
                        Text(verbatim: "\(item.term) · \(item.meaning)").font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background { RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)) }
    }
}
