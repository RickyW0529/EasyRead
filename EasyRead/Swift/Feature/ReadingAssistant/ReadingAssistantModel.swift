// Copyright © 2026 EasyRead contributors. GPL-3.0.
import AppKit
import Combine
import Defaults
import EasyReadKit
import Foundation

/// Explicit AI actions are isolated from local dictionary results and never persist source text.
@MainActor
final class ReadingAssistantModel: ObservableObject {
    enum Intent { case word, translation, grammar }

    @Published private(set) var text = ""
    @Published private(set) var translation = ""
    @Published private(set) var wordExplanation = ""
    @Published private(set) var grammar: GrammarExplanation?
    @Published private(set) var errorMessage = ""
    @Published private(set) var isLoading = false
    @Published private(set) var wasCancelled = false
    @Published var showsDetails = false

    var onLayoutChange: (() -> Void)?
    private let service = DeepSeekService()
    private var task: Task<Void, Never>?
    private var queryID: UUID?
    private var requestID = UUID()
    private var snapshot: SelectionSnapshot?
    private var lastIntent: Intent = .word
    private var observers: Set<AnyCancellable> = []

    init() {
        Defaults.publisher(.enableReadingAI).receive(on: DispatchQueue.main).sink { [weak self] change in
            if !change.newValue { self?.cancel() }
        }.store(in: &observers)
        Defaults.publisher(.enableContextExtraction).receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.cancel()
        }.store(in: &observers)
        Defaults.publisher(.contextExtractionExcludedApps).receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.cancel()
        }.store(in: &observers)
        Defaults.publisher(.deepSeekAPIKeyMirror).receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.cancel()
        }.store(in: &observers)
    }

    var hasKey: Bool { !service.apiKey.isEmpty }
    var allowsAI: Bool { AXContextExtractor.allowsAI(snapshot: snapshot) }
    var canRequest: Bool {
        Defaults[.enableReadingAI] && hasKey && SelectionPolicy.default.validateSelection(text).isUsable
            && AXContextExtractor.allowsAI(snapshot: snapshot)
    }

    var rowHeight: CGFloat {
        if showsDetails, grammar != nil { return 520 }
        return translation.isEmpty && wordExplanation.isEmpty ? 190 : 350
    }

    func update(queryModel: QueryModel) {
        guard queryID != queryModel.readingQueryID || text != queryModel.inputText else { return }
        cancel()
        queryID = queryModel.readingQueryID
        text = queryModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        snapshot = [ActionType.autoSelectQuery, .shortcutQuery].contains(queryModel.actionType)
            ? queryModel.contextSnapshot : nil
        translation = ""
        wordExplanation = ""
        grammar = nil
        errorMessage = ""
        wasCancelled = false
        showsDetails = false
    }

    func cancel() {
        requestID = UUID()
        task?.cancel()
        task = nil
        if isLoading { wasCancelled = true }
        isLoading = false
        onLayoutChange?()
    }

    func retry() { request(lastIntent) }

    func request(_ intent: Intent) {
        guard canRequest else { return }
        cancel()
        lastIntent = intent
        let activeRequest = UUID()
        requestID = activeRequest
        let selectedText = text
        let attached = snapshot
        let latest = ContextExtractionCoordinator.shared.snapshot(forInputText: selectedText)
        let captured = attached?.selectionID == latest?.selectionID ? latest : nil
        guard AXContextExtractor.allowsAI(snapshot: captured) else { return }
        let source = captured?.availability == .selectionOnly ? nil : captured?.surroundingText
        let key = service.apiKey
        let model = service.model
        isLoading = true
        wasCancelled = false
        errorMessage = ""
        onLayoutChange?()

        task = Task { [weak self] in
            do {
                let systemPrompt: String
                let userPrompt: String
                switch intent {
                case .word:
                    systemPrompt = WordContextPrompt.systemPrompt
                    userPrompt = try WordContextPrompt.userPrompt(
                        selectedText: selectedText, sourceSentence: source,
                        availability: captured?.availability ?? .selectionOnly
                    )
                case .translation, .grammar:
                    systemPrompt = SentencePrompt.systemPrompt
                    userPrompt = try SentencePrompt.userPrompt(sentence: selectedText, grammar: intent == .grammar)
                }
                var configuration = DeepSeekChatClient.Configuration()
                if intent == .grammar {
                    configuration.requestTimeout = 30
                    configuration.totalTimeout = 40
                }
                try Task.checkCancellation()
                guard let self, requestID == activeRequest else { return }
                guard canRequest else { cancel(); return }
                let client = DeepSeekChatClient(endpoint: URL(string: service.endpoint)!, configuration: configuration)
                let output = try await client.complete(
                    model: model,
                    messages: [.init(role: .system, content: systemPrompt), .init(role: .user, content: userPrompt)],
                    apiKey: key
                )
                try Task.checkCancellation()
                guard requestID == activeRequest else { return }
                guard canRequest else { cancel(); return }
                if let captured {
                    guard ContextExtractionCoordinator.shared.snapshot(forInputText: selectedText)?.selectionID == captured.selectionID else {
                        cancel()
                        return
                    }
                }
                switch intent {
                case .word:
                    let answer = try AIWordExplanation.decode(jsonContent: output).validated(queriedText: selectedText, sourceSentence: source)
                    // Plain text rendering prevents source/model strings from becoming Markdown links or HTML.
                    wordExplanation = DeepSeekService.explanationMarkdown(answer, snapshot: captured)
                case .translation:
                    translation = try SentenceTranslation.decode(jsonContent: output, queriedSentence: selectedText).translationZh
                case .grammar:
                    let answer = try GrammarExplanation.decode(jsonContent: output).validated(queriedSentence: selectedText)
                    grammar = answer
                    translation = answer.translationZh
                    showsDetails = false
                }
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

    func copyResult() {
        var parts = [text, translation, wordExplanation].filter { !$0.isEmpty }
        if let grammar {
            parts.append(grammar.mainClause)
            parts += grammar.structures.map { "\($0.excerpt) — \($0.labelZh)：\($0.explanationZh)" }
            parts += grammar.readingSteps
            parts += grammar.terminology.map { "\($0.term)：\($0.meaningZh)" }
            if let question = grammar.comprehensionQuestion { parts.append(question) }
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(parts.joined(separator: "\n\n"), forType: .string)
    }
}
