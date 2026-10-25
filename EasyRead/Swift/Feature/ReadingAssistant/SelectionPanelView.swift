// Copyright © 2026 EasyRead contributors. GPL-3.0.
import AppKit
import Defaults
import EasyReadKit
import SFSafeSymbols
import SwiftUI

// MARK: - SelectionPanelState

/// Panel chrome that survives result reloads. Query data stays on the reading model and services.
@MainActor
final class SelectionPanelState: ObservableObject {
    enum Tab: Int, CaseIterable, Identifiable {
        case sentence
        case dictionary
        case other

        // MARK: Internal

        var id: Int { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .sentence: "selection.panel.tab.sentence"
            case .dictionary: "selection.panel.tab.dictionary"
            case .other: "selection.panel.tab.other"
            }
        }
    }

    @Published var tab: Tab = .sentence
    @Published var queryText = ""
    @Published var sourceLanguage: Language = .auto
    @Published var targetLanguage: Language = .auto
    @Published var userSourceLanguage: Language = .auto
    @Published var userTargetLanguage: Language = .auto
    @Published var services: [QueryService] = []
    @Published var visibleServiceCount = 0
    @Published var originalExpanded = false
    @Published var translationExpanded = false
    @Published var grammarExpanded = true
    @Published var grammarDetailsExpanded = false

    var selectLanguage: ((String, Bool) -> ())?
    var swapLanguages: (() -> ())?
    var playTranslation: ((String) -> ())?

    static func isDictionaryService(_ service: QueryService) -> Bool {
        let type = service.serviceType()
        if type == .appleDictionary || type == .mDict { return true }
        let supported = service.supportedQueryType()
        return supported.contains(.dictionary) && !supported.contains(.translation)
    }

    func primaryTranslation(aiTranslation: String) -> ReadingTranslation? {
        let trimmedAI = aiTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAI.isEmpty {
            return ReadingTranslation(text: trimmedAI, from: sourceLanguage, to: targetLanguage, isComplete: true)
        }
        for service in services where !Self.isDictionaryService(service) {
            guard let result = service.result, result.queryText == queryText, result.error == nil else { continue }
            let text = [result.copiedText, result.translatedText]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty }
            guard let text else { continue }
            return ReadingTranslation(
                text: text, from: result.from, to: result.to,
                isComplete: !result.isLoading && (!service.isStream() || result.isStreamFinished)
            )
        }
        return nil
    }

    func resetChrome(isWord: Bool) {
        originalExpanded = false
        translationExpanded = false
        grammarExpanded = true
        grammarDetailsExpanded = false
        tab = isWord ? .dictionary : .sentence
    }

    func buttonTitle(userLanguage: Language, effectiveLanguage: Language) -> String {
        let shown = userLanguage == .auto ? effectiveLanguage : userLanguage
        guard shown != .auto else { return EZLanguageManager.shared().showingLanguageName(.auto) }
        return EZLanguageManager.shared().showingLanguageName(shown)
    }
}

// MARK: - SelectionPanelView

/// Compact selection popup: one original, one translation, and a single auxiliary section.
struct SelectionPanelView: View {
    // MARK: Internal

    @ObservedObject var model: ReadingAssistantModel
    @ObservedObject var state: SelectionPanelState

    var onTabChange: () -> ()
    var onContentHeight: (CGFloat) -> ()

    var body: some View {
        VStack(alignment: .leading, spacing: SelectionPanelMetrics.sectionSpacing) {
            languageRow
            labeledBox(title: "selection.panel.original") {
                originalBox
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("selection.panel.translation")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    if !translationText.isEmpty {
                        iconButton("selection.panel.speak_translation", symbol: .speakerWave2) {
                            state.playTranslation?(translationText)
                        }
                        iconButton("selection.panel.copy_translation", symbol: .docOnDoc) {
                            translationText.ns_copyAndShowToast(true)
                        }
                    }
                    Spacer(minLength: 0)
                }
                translationBox.panelContainer()
            }
            tabBar
            tabContent
        }
        .padding(.horizontal, SelectionPanelMetrics.inset)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: SelectionPanelHeightKey.self, value: proxy.size.height)
            }
        }
        .onPreferenceChange(SelectionPanelHeightKey.self, perform: onContentHeight)
        .onChange(of: state.tab) { _ in onTabChange() }
        .textSelection(.enabled)
    }

    // MARK: Private

    private var languages: [Language] { EZLanguageManager.shared().allLanguages }

    private var translationText: String {
        state.primaryTranslation(aiTranslation: model.translation)?.text ?? ""
    }

    private var translationError: String? {
        guard translationText.isEmpty else { return nil }
        for service in state.services where !SelectionPanelState.isDictionaryService(service) {
            guard let result = service.result else { continue }
            guard result.queryText == state.queryText else { continue }
            if let message = result.errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
                return message
            }
        }
        return nil
    }

    private var translationIsLoading: Bool {
        guard translationText.isEmpty else { return false }
        return state.services.contains { service in
            guard let result = service.result else { return false }
            return !SelectionPanelState.isDictionaryService(service) && result.isLoading
                && result.queryText == state.queryText
        }
    }

    private var languageRow: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            LanguageMenuControl(
                title: state.buttonTitle(
                    userLanguage: state.userSourceLanguage,
                    effectiveLanguage: state.sourceLanguage
                ),
                languages: languages,
                selected: state.userSourceLanguage
            ) { language in
                state.selectLanguage?(language.rawValue, true)
            }
            Button(action: { state.swapLanguages?() }) {
                Image(systemSymbol: .arrowRight)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("toggle_languages")
            LanguageMenuControl(
                title: state.buttonTitle(
                    userLanguage: state.userTargetLanguage,
                    effectiveLanguage: state.targetLanguage
                ),
                languages: languages,
                selected: state.userTargetLanguage
            ) { language in
                state.selectLanguage?(language.rawValue, false)
            }
            Spacer(minLength: 0)
        }
    }

    private var originalBox: some View {
        collapsibleText(model.text.isEmpty ? state.queryText : model.text, expanded: $state.originalExpanded)
    }

    private var translationBox: some View {
        HStack(alignment: .center, spacing: 4) {
            VStack(alignment: .leading, spacing: 6) {
                if translationIsLoading, translationText.isEmpty {
                    ProgressView().controlSize(.small)
                }
                collapsibleText(translationText, expanded: $state.translationExpanded, prominent: true)
                if let translationError, translationText.isEmpty {
                    Text(verbatim: translationError)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                } else if translationText.isEmpty, !translationIsLoading, !state.queryText.isEmpty {
                    Text("selection.panel.no_translation")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(SelectionPanelState.Tab.allCases) { tab in
                let selected = state.tab == tab
                Button {
                    state.tab = tab
                } label: {
                    Text(tab.titleKey)
                        .font(.system(size: 12, weight: selected ? .semibold : .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .foregroundStyle(selected ? Color.white : Color.secondary)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.accentColor)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background {
            RoundedRectangle(cornerRadius: SelectionPanelMetrics.radius, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        }
    }

    @ViewBuilder private var tabContent: some View {
        switch state.tab {
        case .sentence:
            sentenceTab
        case .dictionary:
            emptyServiceHint("selection.panel.no_dictionary")
        case .other:
            emptyServiceHint("selection.panel.no_translation")
        }
    }

    private var sentenceTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let grammar = model.grammar {
                grammarSection(grammar)
            } else if let explanation = model.wordExplanation {
                ReadingContextTip(answer: explanation, context: model.contextExcerpt)
            } else if model.isLoading {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("reading.ai.loading").font(.system(size: 12)).foregroundStyle(.secondary)
                    Button("reading.action.cancel") { model.cancel() }.buttonStyle(.borderless).font(.system(size: 12))
                }
            } else if !model.errorMessage.isEmpty {
                HStack(spacing: 8) {
                    Text(verbatim: model.errorMessage).font(.system(size: 12)).foregroundStyle(.red)
                    Button("reading.action.retry") { model.retry() }
                        .buttonStyle(.borderless).font(.system(size: 12)).disabled(!model.canRequest)
                }
            } else if model.wasCancelled {
                HStack(spacing: 8) {
                    Text("reading.ai.cancelled").font(.system(size: 12)).foregroundStyle(.secondary)
                    Button("reading.action.retry") { model.retry() }
                        .buttonStyle(.borderless).font(.system(size: 12)).disabled(!model.canRequest)
                }
            } else if !model.isConfigured, DefaultsReadingAI.isEnabled {
                Text("reading.ai.no_key").font(.system(size: 12)).foregroundStyle(.secondary)
            } else if !state.queryText.isEmpty, DefaultsReadingAI.isEnabled {
                if !model.allowsAI {
                    Text("reading.ai.blocked").font(.system(size: 12)).foregroundStyle(.secondary)
                } else if !SelectionPolicy.default.validateSelection(model.text).isUsable {
                    Text("reading.ai.too_long").font(.system(size: 12)).foregroundStyle(.secondary)
                } else if model.canResumeCommittedQuery {
                    Button("reading.action.analyze") { model.resumeCommittedQuery() }
                        .buttonStyle(.borderless).font(.system(size: 12))
                } else {
                    Text("selection.panel.no_grammar").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            if !model.resultSource.isEmpty {
                Text(verbatim: model.resultSource).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func emptyServiceHint(_ key: LocalizedStringKey) -> some View {
        Group {
            if state.visibleServiceCount == 0 {
                Text(key).font(.system(size: 12)).foregroundStyle(.secondary).padding(.vertical, 2)
            }
        }
    }

    private func labeledBox(title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            content().panelContainer()
        }
    }

    private func collapsibleText(_ text: String, expanded: Binding<Bool>, prominent: Bool = false) -> some View {
        let canCollapse = Self.needsExpansion(text)
        return VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: text)
                .font(.system(size: prominent ? 16 : 15))
                .lineSpacing(3)
                .lineLimit(canCollapse && !expanded.wrappedValue ? 4 : nil)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if canCollapse {
                Button(expanded.wrappedValue ? "selection.panel.collapse" : "selection.panel.expand") {
                    expanded.wrappedValue.toggle()
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11))
            }
        }
    }

    private func iconButton(_ help: LocalizedStringKey, symbol: SFSymbol, action: @escaping () -> ()) -> some View {
        Button(action: action) {
            Image(systemSymbol: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    private func grammarSection(_ grammar: GrammarExplanation) -> some View {
        let source = model.text
        let chunks = GrammarChunk.chunks(source: source, structures: grammar.structures)
        let visible = chunks.compactMap(\.structure)
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                state.grammarExpanded.toggle()
            } label: {
                HStack {
                    Text("selection.panel.grammar").font(.system(size: 13, weight: .semibold))
                    Spacer(minLength: 8)
                    Image(systemSymbol: state.grammarExpanded ? .chevronUp : .chevronDown)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if state.grammarExpanded {
                GrammarAnalysisLayout {
                    if !chunks.isEmpty {
                        GrammarPhraseFlow(chunks: chunks)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array((visible.isEmpty ? grammar.structures : visible).enumerated()), id: \.offset) { _,
                            structure in
                            grammarBullet(structure)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .background {
                    GeometryReader { proxy in
                        if proxy.size.width >= GrammarAnalysisLayout.twoColumnMinimum {
                            Rectangle()
                                .fill(Color.primary.opacity(0.12))
                                .frame(width: 1, height: proxy.size.height)
                                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        }
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
                if hasFullAnalysis(grammar) {
                    Button(state.grammarDetailsExpanded ? "selection.panel.collapse" : "selection.panel.grammar.full") {
                        state.grammarDetailsExpanded.toggle()
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                }
                if state.grammarDetailsExpanded {
                    grammarDetails(grammar, shownStructures: visible)
                }
            }
        }
        .panelContainer()
    }

    private func grammarBullet(_ structure: GrammarStructure) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Circle().fill(Color(nsColor: GrammarRole.color(for: structure))).frame(width: 6, height: 6)
            Text(verbatim: "\(structure.excerpt)：\(structure.label)，\(structure.explanation)")
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func grammarDetails(
        _ grammar: GrammarExplanation,
        shownStructures: [GrammarStructure]
    )
        -> some View {
        if !grammar.mainClause.isEmpty {
            detailBlock("reading.grammar.main_clause", text: grammar.mainClause)
        }
        if !grammar.readingSteps.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Text("reading.grammar.reading_order").font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                ForEach(Array(grammar.readingSteps.enumerated()), id: \.offset) { index, step in
                    Text(verbatim: "\(index + 1). \(step)").font(.system(size: 12))
                }
            }
        }
        let extras = grammar.structures.filter { structure in
            !shownStructures.contains(structure)
        }
        if !extras.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(extras.enumerated()), id: \.offset) { _, structure in
                    grammarBullet(structure)
                }
            }
        }
        if !grammar.terminology.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Text("reading.grammar.terminology").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                ForEach(Array(grammar.terminology.enumerated()), id: \.offset) { _, item in
                    Text(verbatim: "\(item.term)：\(item.meaning)").font(.system(size: 12))
                }
            }
        }
        if let question = grammar.comprehensionQuestion, !question.isEmpty {
            Text(verbatim: question).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }

    private func detailBlock(_ title: LocalizedStringKey, text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            Text(verbatim: text).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
        }
    }

    private static func needsExpansion(_ text: String) -> Bool {
        text.count > 180 || text.reduce(into: 0) { count, character in
            if character == "\n" { count += 1 }
        } >= 3
    }

    private func hasFullAnalysis(_ grammar: GrammarExplanation) -> Bool {
        !grammar.mainClause.isEmpty || !grammar.readingSteps.isEmpty || !grammar.terminology.isEmpty
            || !(grammar.comprehensionQuestion ?? "").isEmpty || grammar.structures
            .contains { $0.explanation.count > 48 }
    }
}

// MARK: - SelectionPanelMetrics

private enum SelectionPanelMetrics {
    static let radius: CGFloat = 8
    static let inset: CGFloat = 12
    static let sectionSpacing: CGFloat = 10
}

// MARK: - SelectionPanelHeightKey

private struct SelectionPanelHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension View {
    fileprivate func panelContainer() -> some View {
        padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: SelectionPanelMetrics.radius, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            }
    }
}

// MARK: - DefaultsReadingAI

/// Avoids reading Defaults from the view body through a stored key path that the panel does not own.
private enum DefaultsReadingAI {
    static var isEnabled: Bool { Defaults[.enableReadingAI] }
}

// MARK: - GrammarChunk

struct GrammarChunk: Identifiable {
    // MARK: Internal

    let id: Int
    let text: String
    let structure: GrammarStructure?

    static func chunks(source: String, structures: [GrammarStructure]) -> [GrammarChunk] {
        let nsSource = source as NSString
        let located = structures.compactMap { structure -> (NSRange, GrammarStructure)? in
            guard let range = structure.sourceRange(in: source), range.location != NSNotFound, range.length > 0,
                  NSMaxRange(range) <= nsSource.length else { return nil }
            return (range, structure)
        }.sorted { lhs, rhs in
            if lhs.0.location != rhs.0.location { return lhs.0.location < rhs.0.location }
            return lhs.0.length > rhs.0.length
        }

        var chunks: [GrammarChunk] = []
        var cursor = 0
        for (range, structure) in located {
            if range.location < cursor { continue }
            if range.location > cursor {
                appendGap(
                    nsSource.substring(with: NSRange(location: cursor, length: range.location - cursor)),
                    to: &chunks
                )
            }
            var text = nsSource.substring(with: range)
            if let previous = chunks.last, previous.structure == nil,
               previous.text.allSatisfy({ "([{（【“\"".contains($0) }) {
                text = previous.text + text
                chunks.removeLast()
            }
            chunks.append(GrammarChunk(id: chunks.count, text: text, structure: structure))
            cursor = NSMaxRange(range)
        }
        if cursor < nsSource.length {
            appendGap(nsSource.substring(from: cursor), to: &chunks)
        }
        return chunks
    }

    // MARK: Private

    private static func appendGap(_ text: String, to chunks: inout [GrammarChunk]) {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Closing punctuation belongs to the preceding phrase; opening brackets belong to the next one.
        let closing = trimmed.prefix { $0.isPunctuation && !"([{（【“\"".contains($0) }
        if !closing.isEmpty, !chunks.isEmpty {
            let last = chunks[chunks.count - 1]
            chunks[chunks.count - 1] = GrammarChunk(
                id: last.id,
                text: last.text + closing,
                structure: last.structure
            )
            trimmed = String(trimmed.dropFirst(closing.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !trimmed.isEmpty else { return }
        chunks.append(GrammarChunk(id: chunks.count, text: trimmed, structure: nil))
    }
}

// MARK: - GrammarAnalysisLayout

/// Places the annotated sentence beside its explanations; narrow windows stack them.
struct GrammarAnalysisLayout: Layout {
    // MARK: Internal

    static let twoColumnMinimum: CGFloat = 600

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = max(proposal.width ?? Self.twoColumnMinimum, 1)
        let measuredRows = rows(in: width, subviews: subviews)
        return CGSize(
            width: width,
            height: measuredRows.reduce(0) { $0 + $1.height }
                + spacing * CGFloat(max(measuredRows.count - 1, 0))
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(in: bounds.width, subviews: subviews) {
            var x = bounds.minX
            let columns = bounds.width >= Self.twoColumnMinimum ? 2 : 1
            let columnWidth = (bounds.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
            for index in row.indexes {
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: columnWidth, height: row.height)
                )
                x += columnWidth + spacing
            }
            y += row.height + spacing
        }
    }

    // MARK: Private

    private struct Row {
        var indexes: [Int] = []
        var height: CGFloat = 0
    }

    private let spacing: CGFloat = 20

    private func rows(in width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        let columns = width >= Self.twoColumnMinimum ? 2 : 1
        let columnWidth = (width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        for index in subviews.indices {
            if index % columns == 0 { rows.append(Row()) }
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: columnWidth, height: nil))
            rows[rows.count - 1].indexes.append(index)
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows
    }
}

// MARK: - LanguageMenuControl

/// AppKit menu so language selection still works in the nonactivating selection panel.
struct LanguageMenuControl: NSViewRepresentable {
    var title: String
    var languages: [Language]
    var selected: Language
    var onSelect: (Language) -> ()

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> LanguageMenuButton {
        let button = LanguageMenuButton(frame: .zero)
        button.target = context.coordinator
        button.action = #selector(Coordinator.open(_:))
        return button
    }

    func updateNSView(_ button: LanguageMenuButton, context: Context) {
        button.setMenuTitle(title)
        button.refreshChrome()
        context.coordinator.languages = languages
        context.coordinator.selected = selected
        context.coordinator.onSelect = onSelect
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: LanguageMenuButton, context: Context) -> CGSize? {
        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let titleWidth = (title as NSString).size(withAttributes: [.font: font]).width
        // 12 leading + title + 10 gap + 8 chevron + 12 trailing.
        return CGSize(width: ceil(titleWidth) + 42, height: 26)
    }
}

// MARK: - LanguageMenuButton

final class LanguageMenuButton: NSButton {
    // MARK: Lifecycle

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        bezelStyle = .recessed
        setButtonType(.momentaryPushIn)
        title = ""
        image = nil
        wantsLayer = true
        layer?.cornerRadius = 8

        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let symbol = NSImage(systemSymbol: .chevronDown)
        symbol.isTemplate = true
        chevron.image = symbol
        chevron.contentTintColor = .secondaryLabelColor
        chevron.imageScaling = .scaleProportionallyDown

        let stack = NSStackView(views: [titleLabel, chevron])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 8),
            chevron.heightAnchor.constraint(equalToConstant: 5),
        ])
        refreshChrome()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Internal

    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) == nil ? nil : self
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshChrome()
    }

    func setMenuTitle(_ value: String) {
        titleLabel.stringValue = value
    }

    func refreshChrome() {
        titleLabel.textColor = .labelColor
        chevron.contentTintColor = .secondaryLabelColor
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.08).cgColor
    }

    // MARK: Private

    private let titleLabel = NSTextField(labelWithString: "")
    private let chevron = NSImageView()
}

// MARK: - LanguageMenuControl.Coordinator

extension LanguageMenuControl {
    final class Coordinator: NSObject {
        var languages: [Language] = []
        var selected: Language = .auto
        var onSelect: (Language) -> () = { _ in }

        @objc
        func open(_ sender: NSButton) {
            let menu = NSMenu()
            for language in languages {
                let item = NSMenuItem(
                    title: EZLanguageManager.shared().showingLanguageName(withFlag: language),
                    action: #selector(pick(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = language.rawValue as NSString
                item.state = language == selected ? .on : .off
                menu.addItem(item)
            }
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
        }

        @objc
        func pick(_ sender: NSMenuItem) {
            guard let rawValue = sender.representedObject as? String else { return }
            onSelect(Language(rawValue: rawValue))
        }
    }
}

// MARK: - ReadingTranslation

/// The panel's selected result; actions use the same text and completed direction as the display.
@objc(ReadingTranslation)
@objcMembers
final class ReadingTranslation: NSObject {
    // MARK: Lifecycle

    init(text: String, from: Language, to: Language, isComplete: Bool) {
        self.text = text
        self.from = from
        self.to = to
        self.isComplete = isComplete
    }

    // MARK: Internal

    let text: String
    let from: Language
    let to: Language
    let isComplete: Bool
}
