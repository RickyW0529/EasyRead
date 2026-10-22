// Copyright © 2026 EasyRead contributors. GPL-3.0.
import EasyReadKit
import SwiftUI

// MARK: - ReadingAssistantView

/// Sentence results show grammar above the translation. Grammar details expand in place.
struct ReadingAssistantView: View {
    // MARK: Internal

    @ObservedObject var model: ReadingAssistantModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("reading.ai.title").font(.headline)
            status
            if let grammar = model.grammar {
                sentenceResult(grammar)
            } else if !model.translation.isEmpty || model.wordExplanation != nil {
                wordResult
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: model.grammar == nil ? .infinity : nil, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: model.grammar != nil)
        .background { RoundedRectangle(cornerRadius: 8).fill(.quaternary) }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: ReadingCardHeightKey.self, value: proxy.size.height)
            }
        }
        .onPreferenceChange(ReadingCardHeightKey.self) { height in
            guard model.grammar != nil else { return }
            model.updateContentHeight(height)
        }
        .onChange(of: model.showsDetails) { _ in model.prepareForDetailResize() }
        .textSelection(.enabled)
    }

    // MARK: Private

    @ViewBuilder private var status: some View {
        if !model.isConfigured {
            Text("reading.ai.no_key").font(.caption).foregroundStyle(.secondary)
        } else if !SelectionPolicy.default.validateSelection(model.text).isUsable {
            Text("reading.ai.too_long").font(.caption).foregroundStyle(.secondary)
        } else if !model.allowsAI {
            Text("reading.ai.blocked").font(.caption).foregroundStyle(.secondary)
        }

        if !model.isLoading, !model.wasCancelled, model.errorMessage.isEmpty,
           model.translation.isEmpty, model.wordExplanation == nil, model.grammar == nil, model.canRequest {
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
    }

    private var wordResult: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if !model.translation.isEmpty {
                        Text(verbatim: model.translation).lineSpacing(4)
                    }
                    if let explanation = model.wordExplanation {
                        ReadingContextTip(answer: explanation, context: model.contextExcerpt)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            resultFooter
        }
    }

    private var resultFooter: some View {
        HStack {
            Text(verbatim: model.resultSource).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("reading.action.copy") { model.copyResult() }
        }
    }

    private func sentenceResult(_ grammar: GrammarExplanation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            grammarPanel(grammar)
            if !model.translation.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("reading.grammar.translation")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(verbatim: model.translation)
                        .font(.system(size: 15))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            DisclosureGroup(isExpanded: $model.showsDetails) {
                grammarDetails(grammar)
            } label: {
                Text("reading.grammar.details")
            }
            resultFooter
            Text("reading.dictionary.lookup_hint").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private func grammarPanel(_ grammar: GrammarExplanation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("reading.grammar.original")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            GrammarAnnotatedText(source: model.text, structures: grammar.structures)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("reading.grammar.color_legend")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("reading.grammar.hover_hint")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)) }
    }

    private func grammarDetails(_ answer: GrammarExplanation) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            detailSection("reading.grammar.main_clause") {
                Text(verbatim: answer.mainClause).lineSpacing(4)
            }
            detailSection("reading.grammar.components") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(orderedStructures(answer).enumerated()), id: \.offset) { _, structure in
                        structureRow(structure)
                    }
                }
            }
            detailSection("reading.grammar.reading_order") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(answer.readingSteps.enumerated()), id: \.offset) { index, step in
                        Text(verbatim: "\(index + 1). \(step)").lineSpacing(3)
                    }
                }
            }
            if !answer.terminology.isEmpty {
                detailSection("reading.grammar.terminology") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(answer.terminology.enumerated()), id: \.offset) { _, item in
                            Text(verbatim: "\(item.term) · \(item.meaning)").font(.callout)
                        }
                    }
                }
            }
            if let question = answer.comprehensionQuestion {
                Text(verbatim: question)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
        }
        .padding(.top, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func structureRow(_ structure: GrammarStructure) -> some View {
        let color = Color(nsColor: GrammarRole.color(for: structure))
        return HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 3)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(verbatim: structure.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                    Text(verbatim: structure.excerpt).font(.callout)
                }
                Text(verbatim: structure.explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func detailSection(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Follow the sentence when a fragment can be located; unmatched excerpts stay at the end.
    private func orderedStructures(_ answer: GrammarExplanation) -> [GrammarStructure] {
        answer.structures.enumerated().sorted { lhs, rhs in
            let left = lhs.element.sourceRange(in: model.text)?.location ?? Int.max
            let right = rhs.element.sourceRange(in: model.text)?.location ?? Int.max
            if left == right { return lhs.offset < rhs.offset }
            return left < right
        }.map(\.element)
    }
}

// MARK: - ReadingCardHeightKey

private struct ReadingCardHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
