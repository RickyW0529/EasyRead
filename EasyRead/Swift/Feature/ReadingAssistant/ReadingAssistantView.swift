// Copyright © 2026 EasyRead contributors. GPL-3.0.
import EasyReadKit
import SwiftUI

/// Translation-first reading card with grammar explanations attached to the original text.
struct ReadingAssistantView: View {
    // MARK: Internal

    @ObservedObject var model: ReadingAssistantModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("reading.ai.title").font(.headline)
            if model.showsDictionaryHint {
                Text("reading.dictionary.lookup_hint").font(.caption).foregroundStyle(.secondary)
            }
            if model.kind == .sentence {
                Button("reading.action.grammar") { model.revealGrammar() }
                    .disabled(model.grammar == nil)
            }

            if !model.isConfigured {
                Text("reading.ai.no_key").font(.caption).foregroundStyle(.secondary)
            } else if !SelectionPolicy.default.validateSelection(model.text).isUsable {
                Text("reading.ai.too_long").font(.caption).foregroundStyle(.secondary)
            } else if !model.allowsAI {
                Text("reading.ai.blocked").font(.caption).foregroundStyle(.secondary)
            }

            if !model.isLoading, !model.wasCancelled, model.errorMessage.isEmpty,
               model.translation.isEmpty, model.wordExplanation == nil, model.canRequest {
                Button("reading.action.explain") { model.resumeCommittedQuery() }
            }
            if model.isLoading {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("reading.ai.loading")
                    Button("reading.action.cancel") { model.cancel() }
                }
            } else if model.wasCancelled {
                HStack {
                    Text("reading.ai.cancelled").font(.caption).foregroundStyle(.secondary)
                    Button("reading.action.retry") { model.retry() }.disabled(!model.canRequest)
                }
            }
            if !model.errorMessage.isEmpty {
                HStack {
                    Text(verbatim: model.errorMessage).font(.caption).foregroundStyle(.red)
                    Button("reading.action.retry") { model.retry() }.disabled(!model.canRequest)
                }
            }
            if !model.translation.isEmpty || model.wordExplanation != nil {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if model.showsGrammar, let grammar = model.grammar {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("reading.grammar.original").font(.headline)
                                Text("reading.grammar.hover_hint").font(.caption).foregroundStyle(.secondary)
                                Text("reading.grammar.color_legend").font(.caption2).foregroundStyle(.secondary)
                                GrammarAnnotatedText(source: model.text, structures: grammar.structures)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(12)
                            .background { RoundedRectangle(cornerRadius: 8).fill(.quaternary) }
                        }
                        if !model.translation.isEmpty {
                            Text(verbatim: model.translation).lineSpacing(4)
                        }
                        if let explanation = model.wordExplanation {
                            ReadingContextTip(answer: explanation, context: model.contextExcerpt)
                        }
                        if model.showsGrammar, let grammar = model.grammar {
                            DisclosureGroup("reading.grammar.details", isExpanded: $model.showsDetails) {
                                grammarDetails(grammar)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                }
                HStack {
                    Text(verbatim: model.resultSource).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("reading.action.copy") { model.copyResult() }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background { RoundedRectangle(cornerRadius: 8).fill(.quaternary) }
        .onChange(of: model.showsDetails) { _ in model.onLayoutChange?() }
    }

    // MARK: Private

    private func grammarDetails(_ answer: GrammarExplanation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("reading.grammar.main_clause").font(.headline)
            Text(verbatim: answer.mainClause)
            ForEach(Array(answer.structures.enumerated()), id: \.offset) { _, structure in
                if structure.sourceRange(in: model.text) == nil {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: structure.excerpt).font(.callout).foregroundStyle(.secondary)
                        Text(verbatim: structure.label).bold()
                        Text(verbatim: structure.explanation)
                    }
                }
            }
            Divider()
            Text("reading.grammar.reading_order").font(.headline)
            ForEach(Array(answer.readingSteps.enumerated()), id: \.offset) { index, step in
                Text(verbatim: "\(index + 1). \(step)")
            }
            ForEach(Array(answer.terminology.enumerated()), id: \.offset) { _, item in
                Text(verbatim: "\(item.term)：\(item.meaning)")
            }
            if let question = answer.comprehensionQuestion { Text(verbatim: question) }
        }
        .lineSpacing(4)
        .padding(.top, 8)
    }
}
