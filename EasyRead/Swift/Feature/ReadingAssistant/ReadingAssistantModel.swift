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
        Defaults.publisher(.enableReadingAI, options: []).receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.invalidatePrivateResults()
        }.store(in: &observers)
        Defaults.publisher(.enableContextExtraction, options: []).receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.invalidatePrivateResults()
            }.store(in: &observers)
        Defaults.publisher(.contextExtractionExcludedApps, options: []).receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.invalidatePrivateResults()
            }.store(in: &observers)
        Defaults.publisher(.readingAIProvider, options: []).receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.invalidatePrivateResults()
        }.store(in: &observers)
        for provider in ReadingAIProvider.all {
            let keys = [
                ReadingAIConfiguration.endpointKey(for: provider),
                ReadingAIConfiguration.modelKey(for: provider),
                ReadingAIConfiguration.mirrorKey(for: provider),
            ]
            for key in keys {
                Defaults.publisher(key, options: []).receive(on: DispatchQueue.main).sink { [weak self] _ in
                    guard Defaults[.readingAIProvider] == provider.id else { return }
                    self?.invalidatePrivateResults()
                }.store(in: &observers)
            }
        }
    }

    // MARK: Internal

    @Published private(set) var text = ""
    @Published private(set) var translation = ""
    @Published private(set) var resultSource = ""
    @Published private(set) var wordExplanation: AIWordExplanation?
    @Published private(set) var contextExcerpt: String?
    @Published private(set) var grammar: GrammarExplanation?
    @Published private(set) var kind: ReadingAnalysis.Kind?
    @Published private(set) var errorMessage = ""
    @Published private(set) var isLoading = false
    @Published private(set) var wasCancelled = false
    @Published var showsDetails = false
    var onLayoutChange: (() -> ())?

    var isConfigured: Bool { ReadingAIConfiguration.current().isReady }
    var showsDictionaryHint: Bool { kind == .sentence }
    var allowsAI: Bool { AXContextExtractor.allowsAI(snapshot: snapshot) }
    var canRequest: Bool {
        Defaults[.enableReadingAI] && isConfigured && SelectionPolicy.default.validateSelection(text)
            .isUsable && allowsAI
    }

    var rowHeight: CGFloat {
        if grammar != nil { return contentHeight > 1 ? contentHeight : (showsDetails ? 640 : 420) }
        if wordExplanation != nil { return 380 }
        return translation.isEmpty ? 120 : 220
    }

    /// The card reports its laid-out height. The table row follows that height so details
    /// expand in place instead of scrolling inside a fixed box.
    func updateContentHeight(_ height: CGFloat) {
        let next = ceil(height)
        guard next > 1, abs(next - contentHeight) > 1 else { return }
        contentHeight = next
        onLayoutChange?()
    }

    /// Drop the measured height so the next table pass uses the expanded or collapsed fallback
    /// until SwiftUI reports the new layout.
    func prepareForDetailResize() {
        contentHeight = 0
        onLayoutChange?()
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

    func copyResult() {
        var parts = [text, translation].filter { !$0.isEmpty }
        if let wordExplanation {
            parts += [wordExplanation.primaryMeaning, wordExplanation.explanation]
            if let contextExcerpt { parts.append(contextExcerpt) }
        }
        if let grammar {
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

    private var contentHeight: CGFloat = 0
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
        let configuration = ReadingAIConfiguration.current()
        clearResult()
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
                guard canRequest, configuration == ReadingAIConfiguration.current(),
                      AXContextExtractor.allowsAI(snapshot: captured) else { throw CancellationError() }
                let source = captured?.availability == .selectionOnly ? nil : captured?.surroundingText
                let availability = captured?.availability ?? .selectionOnly
                let cacheKey = ReadingAnalysisCache.Key(
                    text: selectedText,
                    context: source,
                    availability: availability.rawValue,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage,
                    explanationLanguage: explanationLanguage,
                    model: configuration.model,
                    endpoint: configuration.endpoint,
                    provider: configuration.providerID,
                    credentialRevision: configuration.credentialRevision
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
                    let output = try await ReadingAIClient().complete(
                        configuration: configuration,
                        system: ReadingAnalysisPrompt.systemPrompt,
                        prompt: prompt
                    )
                    answer = try ReadingAnalysis.decode(
                        jsonContent: output,
                        queriedText: selectedText,
                        sourceSentence: source
                    )
                }
                try Task.checkCancellation()
                guard requestID == activeRequest else { return }
                guard canRequest, configuration == ReadingAIConfiguration.current(),
                      AXContextExtractor.allowsAI(snapshot: captured) else { throw CancellationError() }
                if let captured {
                    guard ContextExtractionCoordinator.shared.snapshot(forInputText: selectedText)?
                        .selectionID == captured.selectionID else {
                        throw CancellationError()
                    }
                }
                ReadingAnalysisCache.shared.insert(answer, for: cacheKey)
                resultSource = "\(configuration.provider.displayName) · \(configuration.model)"
                kind = answer.kind
                wordExplanation = answer.wordExplanation
                contextExcerpt = answer.wordExplanation?.contextualEvidence ?? source
                translation = answer.kind == .sentence ? answer.translation : ""
                grammar = answer.grammar
                showsDetails = false
            } catch {
                guard let self, requestID == activeRequest else { return }
                if error is CancellationError || (error as? DeepSeekChatError) == .cancelled {
                    wasCancelled = true
                } else if let error = error as? DeepSeekChatError {
                    errorMessage = error.queryError.localizedDescription
                } else if let error = error as? QueryError {
                    errorMessage = error.localizedDescription
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
        onLayoutChange?()
    }

    private func clearResult() {
        resultSource = ""
        translation = ""
        wordExplanation = nil
        contextExcerpt = nil
        grammar = nil
        kind = nil
        errorMessage = ""
        wasCancelled = false
        showsDetails = false
        contentHeight = 0
    }
}
