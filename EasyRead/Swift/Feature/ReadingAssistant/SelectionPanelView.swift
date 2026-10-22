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

    static func primaryTranslation(in services: [QueryService], queryText: String, aiTranslation: String) -> String {
        let trimmedAI = aiTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAI.isEmpty { return trimmedAI }
        for service in services where !isDictionaryService(service) {
            guard let result = service.result else { continue }
            guard result.queryText == queryText else { continue }
            if let copied = result.copiedText?.trimmingCharacters(in: .whitespacesAndNewlines), !copied.isEmpty {
                return copied
            }
            if let translated = result.translatedText?.trimmingCharacters(in: .whitespacesAndNewlines),
               !translated.isEmpty {
                return translated
            }
        }
        return ""
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
            labeledBox(title: "selection.panel.translation") {
                translationBox
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
        SelectionPanelState.primaryTranslation(
            in: state.services,
            queryText: state.queryText,
            aiTranslation: model.translation
        )
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

            if !translationText.isEmpty {
                HStack(spacing: 0) {
                    iconButton("selection.panel.speak_translation", symbol: .speakerWave2) {
                        state.playTranslation?(translationText)
                    }
                    iconButton("selection.panel.copy_translation", symbol: .docOnDoc) {
                        translationText.ns_copyAndShowToast(true)
                    }
                }
            }
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
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: explanation.primaryMeaning)
                        .font(.system(size: 15, weight: .semibold))
                    Text(verbatim: explanation.explanation)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .panelContainer()
            } else if model.isLoading {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("reading.ai.loading").font(.system(size: 12)).foregroundStyle(.secondary)
                    Button("reading.action.cancel") { model.cancel() }.buttonStyle(.borderless).font(.system(size: 12))
                }
            } else if !model.errorMessage.isEmpty {
                HStack(spacing: 8) {
                    Text(verbatim: model.errorMessage).font(.system(size: 12)).foregroundStyle(.red)
                    Button("reading.action.retry") { model.retry() }.buttonStyle(.borderless).font(.system(size: 12))
                }
            } else if model.wasCancelled {
                HStack(spacing: 8) {
                    Text("reading.ai.cancelled").font(.system(size: 12)).foregroundStyle(.secondary)
                    Button("reading.action.retry") { model.retry() }.buttonStyle(.borderless).font(.system(size: 12))
                }
            } else if !model.isConfigured, DefaultsReadingAI.isEnabled {
                Text("reading.ai.no_key").font(.system(size: 12)).foregroundStyle(.secondary)
            } else if !state.queryText.isEmpty, DefaultsReadingAI.isEnabled {
                Text("selection.panel.no_grammar").font(.system(size: 12)).foregroundStyle(.secondary)
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
                if !chunks.isEmpty {
                    WrapLayout(horizontalSpacing: 12, verticalSpacing: 8) {
                        ForEach(chunks) { chunk in
                            grammarChunk(chunk)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array((visible.isEmpty ? grammar.structures : visible).enumerated()), id: \.offset) { _,
                        structure in
                        grammarBullet(structure, limited: !state.grammarDetailsExpanded)
                    }
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

    private func grammarChunk(_ chunk: GrammarChunk) -> some View {
        let color = chunk.structure.map { Color(nsColor: GrammarRole.color(for: $0)) }
        return VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: chunk.text)
                .font(.system(size: 14, weight: .semibold))
                .underline(color != nil, color: color ?? .clear)
            if let structure = chunk.structure, let color {
                Text(verbatim: structure.label)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .foregroundStyle(color)
                    .background(Capsule().fill(color.opacity(0.2)))
            }
        }
    }

    private func grammarBullet(_ structure: GrammarStructure, limited: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Circle().fill(Color(nsColor: GrammarRole.color(for: structure))).frame(width: 6, height: 6)
            Text(verbatim: "\(structure.excerpt)：\(structure.label)，\(structure.explanation)")
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(limited ? 2 : nil)
                .fixedSize(horizontal: false, vertical: true)
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
                    grammarBullet(structure, limited: false)
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
            chunks.append(GrammarChunk(id: chunks.count, text: nsSource.substring(with: range), structure: structure))
            cursor = NSMaxRange(range)
        }
        if cursor < nsSource.length {
            appendGap(nsSource.substring(from: cursor), to: &chunks)
        }
        return chunks
    }

    // MARK: Private

    private static func appendGap(_ text: String, to chunks: inout [GrammarChunk]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Keep a trailing period with the phrase it closes, instead of a chunk that is only punctuation.
        if trimmed.allSatisfy(\.isPunctuation), !chunks.isEmpty {
            let last = chunks[chunks.count - 1]
            chunks[chunks.count - 1] = GrammarChunk(
                id: last.id,
                text: last.text + trimmed,
                structure: last.structure
            )
            return
        }
        chunks.append(GrammarChunk(id: chunks.count, text: trimmed, structure: nil))
    }
}

// MARK: - WrapLayout

/// Places grammar fragments on as few rows as their measured widths allow.
struct WrapLayout: Layout {
    // MARK: Internal

    var horizontalSpacing: CGFloat = 10
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }
            .reduce(0, +)
        let rows = rows(in: max(width, 1), subviews: subviews)
        let height = rows.reduce(CGFloat(0)) { $0 + $1.height } + verticalSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: max(width, 1), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(in: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indexes {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: size.width, height: size.height)
                )
                x += size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }

    // MARK: Private

    private struct Row {
        var indexes: [Int] = []
        var height: CGFloat = 0
    }

    private func rows(in width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        var used: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let itemWidth = min(size.width, width)
            let next = current.indexes.isEmpty ? itemWidth : used + horizontalSpacing + itemWidth
            if !current.indexes.isEmpty, next > width + 0.5 {
                rows.append(current)
                current = Row()
                used = 0
            }
            current.indexes.append(index)
            current.height = max(current.height, size.height)
            used = current.indexes.count == 1 ? itemWidth : used + horizontalSpacing + itemWidth
        }
        if !current.indexes.isEmpty { rows.append(current) }
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
        button.title = title
        button.refreshChrome()
        context.coordinator.languages = languages
        context.coordinator.selected = selected
        context.coordinator.onSelect = onSelect
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: LanguageMenuButton, context: Context) -> CGSize? {
        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let titleWidth = (title as NSString).size(withAttributes: [.font: font]).width
        return CGSize(width: ceil(titleWidth) + 34, height: 26)
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
        font = .systemFont(ofSize: 12, weight: .medium)
        imagePosition = .imageTrailing
        imageScaling = .scaleProportionallyDown
        let image = NSImage(systemSymbol: .chevronDown)
        image.isTemplate = true
        image.size = NSSize(width: 9, height: 6)
        self.image = image
        wantsLayer = true
        layer?.cornerRadius = 8
        refreshChrome()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Internal

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshChrome()
    }

    func refreshChrome() {
        contentTintColor = .labelColor
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.08).cgColor
    }
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
