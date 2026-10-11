// Copyright © 2026 EasyRead contributors. GPL-3.0.
import Defaults
import EasyReadKit
import SwiftUI

/// Progressive reading card; translation appears first, grammar stays collapsed until requested.
struct ReadingAssistantView: View {
    @ObservedObject var model: ReadingAssistantModel
    @Default(.enableReadingAI) private var enableAI
    @Default(.deepSeekAPIKeyMirror) private var keyMirror

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("reading.ai.title").font(.headline)
                Spacer()
                Toggle("reading.ai.enable", isOn: $enableAI).disabled(keyMirror.isEmpty)
            }
            Text("reading.ai.privacy_notice").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("reading.action.explain") { model.request(.word) }
                Button("reading.action.translate") { model.request(.translation) }
                Button("reading.action.grammar") { model.request(.grammar) }
            }
            .disabled(!model.canRequest || model.isLoading)

            if !model.hasKey {
                Text("reading.ai.no_key").font(.caption).foregroundStyle(.secondary)
            } else if !SelectionPolicy.default.validateSelection(model.text).isUsable {
                Text("reading.ai.too_long").font(.caption).foregroundStyle(.secondary)
            } else if !model.allowsAI {
                Text("reading.ai.blocked").font(.caption).foregroundStyle(.secondary)
            }

            if model.isLoading {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("reading.ai.loading")
                    Button("reading.action.cancel") { model.cancel() }
                }
            } else if model.wasCancelled {
                Text("reading.ai.cancelled").font(.caption).foregroundStyle(.secondary)
            }
            if !model.errorMessage.isEmpty {
                HStack {
                    Text(verbatim: model.errorMessage).font(.caption).foregroundStyle(.red)
                    Button("reading.action.retry") { model.retry() }.disabled(!model.canRequest)
                }
            }
            if !model.translation.isEmpty || !model.wordExplanation.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if !model.translation.isEmpty { Text(verbatim: model.translation) }
                        if !model.wordExplanation.isEmpty { Text(verbatim: model.wordExplanation) }
                        if let grammar = model.grammar {
                            DisclosureGroup("reading.grammar.details", isExpanded: $model.showsDetails) {
                                grammarDetails(grammar)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                }
                HStack {
                    Text("reading.ai.source").font(.caption).foregroundStyle(.secondary)
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

    private func grammarDetails(_ answer: GrammarExplanation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("reading.grammar.main_clause").font(.headline)
            Text(verbatim: answer.mainClause)
            ForEach(Array(answer.structures.enumerated()), id: \.offset) { _, structure in
                VStack(alignment: .leading) {
                    Text(verbatim: structure.excerpt).font(.callout).foregroundStyle(.secondary)
                    Text(verbatim: structure.labelZh).bold()
                    Text(verbatim: structure.explanationZh)
                }
            }
            Text("reading.grammar.reading_order").font(.headline)
            ForEach(Array(answer.readingSteps.enumerated()), id: \.offset) { index, step in
                Text(verbatim: "\(index + 1). \(step)")
            }
            ForEach(Array(answer.terminology.enumerated()), id: \.offset) { _, item in
                Text(verbatim: "\(item.term)：\(item.meaningZh)")
            }
            if let question = answer.comprehensionQuestion { Text(verbatim: question) }
        }
        .padding(.top, 8)
    }
}
