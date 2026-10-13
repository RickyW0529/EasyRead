// Copyright © 2026 EasyRead contributors. GPL-3.0.
import AppKit
import Combine
import Defaults
import EasyReadKit
import Foundation

/// One request prepares a word/phrase tip or a sentence translation with ready-to-display grammar.
@MainActor
final class ReadingAssistantModel: ObservableObject {
    // MARK: Lifecycle

    init() {
        Defaults.publisher(.enableReadingAI, options: []).receive(on: DispatchQueue.main).sink { [weak self] change in
            if !change.newValue, !Defaults[.enableReadingAI] { self?.invalidatePrivateResults() }
        }.store(in: &observers)
        Defaults.publisher(.enableContextExtraction, options: []).receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.invalidatePrivateResults()
            }.store(in: &observers)
        Defaults.publisher(.contextExtractionExcludedApps, options: []).receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.invalidatePrivateResults()
            }.store(in: &observers)
        Defaults.publisher(.deepSeekAPIKeyMirror, options: []).receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.invalidatePrivateResults()
        }.store(in: &observers)
    }

    // MARK: Internal

    @Published private(set) var text = ""
    @Published private(set) var translation = ""
    @Published private(set) var wordExplanation: AIWordExplanation?
    @Published private(set) var contextExcerpt: String?
    @Published private(set) var grammar: GrammarExplanation?
    @Published private(set) var kind: ReadingAnalysis.Kind?
    @Published private(set) var errorMessage = ""
    @Published private(set) var isLoading = false
    @Published private(set) var wasCancelled = false
    @Published var showsGrammar = false
    @Published var showsDetails = false
    var onLayoutChange: (() -> ())?

    var hasKey: Bool { !service.apiKey.isEmpty }
    var showsDictionaryHint: Bool { kind == .sentence }
    var allowsAI: Bool { AXContextExtractor.allowsAI(snapshot: snapshot) }
    var canRequest: Bool {
        Defaults[.enableReadingAI] && hasKey && SelectionPolicy.default.validateSelection(text).isUsable && allowsAI
    }

    var rowHeight: CGFloat {
        if showsGrammar, grammar != nil { return showsDetails ? 560 : 460 }
        if wordExplanation != nil { return 380 }
        return translation.isEmpty ? 150 : 300
    }

    func update(queryModel: QueryModel) {
        let input = queryModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = queryModel.queryFromLanguage.queryLanguageName
        let target = queryModel.queryTargetLanguage.queryLanguageName
        guard queryID != queryModel
            .readingQueryID || text != input || sourceLanguage != source || targetLanguage != target else { return }
        cancel()
        queryID = queryModel.readingQueryID
        committedQueryID = nil
        preparedQueryID = nil
        text = input
        sourceLanguage = source
        targetLanguage = target
        snapshot = [ActionType.autoSelectQuery, .shortcutQuery].contains(queryModel.actionType) ? queryModel
            .contextSnapshot : nil
        clearResult()
    }

    /// The query controller calls this after language detection, never from row layout or typing.
    func prepareAnalysis(queryModel: QueryModel) {
        update(queryModel: queryModel)
        committedQueryID = queryModel.readingQueryID
        guard preparedQueryID != queryModel.readingQueryID, canRequest else { return }
        preparedQueryID = queryModel.readingQueryID
        request()
    }

    func cancel() {
        requestID = UUID()
        task?.cancel()
        task = nil
        if isLoading { wasCancelled = true }
        isLoading = false
        onLayoutChange?()
    }

    func retry() { request() }

    /// Switching to grammar only changes presentation; it never creates a network request.
    func revealGrammar() {
        guard grammar != nil else { return }
        showsGrammar.toggle()
        onLayoutChange?()
    }

    func copyResult() {
        var parts = [text, translation].filter { !$0.isEmpty }
        if let wordExplanation {
            parts += [wordExplanation.primaryMeaning, wordExplanation.explanation]
            if let contextExcerpt { parts.append(contextExcerpt) }
        }
        if showsGrammar, let grammar {
            parts.append(grammar.mainClause)
            parts += grammar.structures.map { "\($0.excerpt) — \($0.label)：\($0.explanation)" }
            parts += grammar.readingSteps
            parts += grammar.terminology.map { "\($0.term)：\($0.meaning)" }
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(parts.joined(separator: "\n\n"), forType: .string)
    }

    func resumeCommittedQuery() {
        guard let queryID, committedQueryID == queryID, canRequest, !isLoading else { return }
        preparedQueryID = queryID
        request()
    }

    // MARK: Private

    private let service = DeepSeekService()
    private var task: Task<(), Never>?
    private var queryID: UUID?
    private var committedQueryID: UUID?
    private var preparedQueryID: UUID?
    private var requestID = UUID()
    private var snapshot: SelectionSnapshot?
    private var sourceLanguage = "auto"
    private var targetLanguage = "auto"
    private var observers: Set<AnyCancellable> = []

    private func request() {
        guard canRequest else { return }
        cancel()
        let activeRequest = UUID()
        requestID = activeRequest
        let selectedText = text
        let attached = snapshot
        let sourceLanguage = sourceLanguage
        let targetLanguage = targetLanguage
        let explanationLanguage = I18nHelper.shared.localizeCode
        let key = service.apiKey
        let model = service.model
        let endpoint = service.endpoint
        isLoading = true
        wasCancelled = false
        errorMessage = ""
        onLayoutChange?()

        task = Task { [weak self] in
            do {
                let captured: SelectionSnapshot?
                if let attached {
                    captured = await ContextExtractionCoordinator.shared.completedSnapshot(
                        forInputText: selectedText,
                        selectionID: attached.selectionID
                    )
                    guard captured != nil else { throw CancellationError() }
                } else { captured = nil }
                try Task.checkCancellation()
                guard let self, requestID == activeRequest else { return }
                guard canRequest, AXContextExtractor.allowsAI(snapshot: captured) else { throw CancellationError() }
                let source = captured?.availability == .selectionOnly ? nil : captured?.surroundingText
                let availability = captured?.availability ?? .selectionOnly
                let cacheKey = ReadingAnalysisCache.Key(
                    text: selectedText,
                    context: source,
                    availability: availability.rawValue,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage,
                    explanationLanguage: explanationLanguage,
                    model: model,
                    endpoint: endpoint
                )
                let answer: ReadingAnalysis
                if let cached = ReadingAnalysisCache.shared.value(for: cacheKey) {
                    answer = cached
                } else {
                    let prompt = try ReadingAnalysisPrompt.userPrompt(
                        text: selectedText,
                        sourceSentence: source,
                        availability: availability,
                        sourceLanguage: sourceLanguage,
                        targetLanguage: targetLanguage,
                        explanationLanguage: explanationLanguage
                    )
                    var configuration = DeepSeekChatClient.Configuration()
                    configuration.requestTimeout = 40
                    configuration.totalTimeout = 50
                    configuration.maxOutputTokens = 8192
                    guard let url = URL(string: endpoint) else { throw DeepSeekChatError.invalidResponse }
                    let output = try await DeepSeekChatClient(endpoint: url, configuration: configuration).complete(
                        model: model, messages: [
                            .init(role: .system, content: ReadingAnalysisPrompt.systemPrompt),
                            .init(role: .user, content: prompt),
                        ], apiKey: key
                    )
                    answer = try ReadingAnalysis.decode(
                        jsonContent: output,
                        queriedText: selectedText,
                        sourceSentence: source
                    )
                }
                try Task.checkCancellation()
                guard requestID == activeRequest else { return }
                guard canRequest, AXContextExtractor.allowsAI(snapshot: captured) else { throw CancellationError() }
                if let captured {
                    guard ContextExtractionCoordinator.shared.snapshot(forInputText: selectedText)?
                        .selectionID == captured.selectionID else {
                        throw CancellationError()
                    }
                }
                ReadingAnalysisCache.shared.insert(answer, for: cacheKey)
                kind = answer.kind
                wordExplanation = answer.wordExplanation
                contextExcerpt = answer.wordExplanation?.contextualEvidence ?? source
                translation = answer.kind == .sentence ? answer.translation : ""
                grammar = answer.grammar
                showsGrammar = false
                showsDetails = false
            } catch {
                guard let self, requestID == activeRequest else { return }
                if error is CancellationError || (error as? DeepSeekChatError) == .cancelled {
                    wasCancelled = true
                } else if let error = error as? DeepSeekChatError {
                    errorMessage = error.queryError.localizedDescription
                } else {
                    errorMessage = String(localized: "deepseek.error.invalid_response")
                }
            }
            guard let self, requestID == activeRequest else { return }
            isLoading = false
            task = nil
            onLayoutChange?()
        }
    }

    private func invalidatePrivateResults() {
        cancel()
        preparedQueryID = nil
        ReadingAnalysisCache.shared.removeAll()
        clearResult()
    }

    private func clearResult() {
        translation = ""
        wordExplanation = nil
        contextExcerpt = nil
        grammar = nil
        kind = nil
        errorMessage = ""
        wasCancelled = false
        showsGrammar = false
        showsDetails = false
    }
}
