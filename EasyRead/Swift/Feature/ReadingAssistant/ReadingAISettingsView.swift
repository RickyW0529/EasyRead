// Copyright © 2026 EasyRead contributors. GPL-3.0.
import Defaults
import EasyReadKit
import SwiftUI

// MARK: - ReadingAISettingsView

/// One settings entry owns AI opt-in, provider credentials and model selection.
struct ReadingAISettingsView: View {
    // MARK: Internal

    var body: some View {
        Form {
            Section {
                Toggle("reading.ai.enable", isOn: $enabled)
                Text("reading.ai.privacy_notice").font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Picker("reading.ai.provider", selection: $providerID) {
                    ForEach(ReadingAIProvider.all) { provider in
                        Text(verbatim: provider.displayName).tag(provider.id)
                    }
                }
                ReadingAIProviderFields(provider: .provider(id: providerID)).id(providerID)
            }
        }
        .formStyle(.grouped)
        .onAppear { _ = ReadingAIConfiguration.current() }
    }

    // MARK: Private

    @Default(.enableReadingAI) private var enabled
    @Default(.readingAIProvider) private var providerID
}

// MARK: - ReadingAIProviderFields

private struct ReadingAIProviderFields: View {
    // MARK: Lifecycle

    init(provider: ReadingAIProvider) {
        self.provider = provider
        self._endpoint = .init(ReadingAIConfiguration.endpointKey(for: provider))
        self._model = .init(ReadingAIConfiguration.modelKey(for: provider))
        self._models = .init(ReadingAIConfiguration.modelsKey(for: provider))
        self._credentialRevision = .init(ReadingAIConfiguration.mirrorKey(for: provider))
    }

    // MARK: Internal

    let provider: ReadingAIProvider

    var body: some View {
        TextField("reading.ai.endpoint", text: $endpoint)
        KeychainInputCell(
            textFieldTitleKey: "service.configuration.openai.api_key.title",
            placeholder: String(localized: "service.configuration.api_key.placeholder \(provider.displayName)"),
            store: ReadingAIConfiguration.keychain(for: provider.id),
            mirrorKey: ReadingAIConfiguration.mirrorKey(for: provider)
        )
        if !provider.requiresAPIKey {
            Text("reading.ai.optional_key").font(.caption).foregroundStyle(.secondary)
        }
        Picker("reading.ai.model", selection: $model) {
            if model.isEmpty { Text("reading.ai.select_model").tag("") }
            ForEach(selectableModels, id: \.self) { identifier in
                Text(verbatim: identifier).tag(identifier)
            }
        }
        HStack {
            TextField("reading.ai.custom_model", text: $customModel)
            Button("reading.ai.add_model") {
                let value = customModel.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else { return }
                if !models.contains(value) { models.append(value) }
                model = value
                customModel = ""
            }.disabled(customModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        HStack {
            Button("reading.ai.fetch_models") { run(fetchModels: true) }
                .disabled(isBusy || !canConnect)
            Button("reading.ai.test_connection") { run(fetchModels: false) }
                .disabled(isBusy || !canConnect || model.isEmpty)
            if isBusy { ProgressView().controlSize(.small) }
        }
        if !status.isEmpty {
            Text(verbatim: status).font(.caption).foregroundStyle(.secondary)
        }
        Text("reading.ai.configuration_hint").font(.caption).foregroundStyle(.secondary)
            .onChange(of: endpoint) { _ in invalidateOperation() }
            .onChange(of: model) { _ in invalidateOperation() }
            .onChange(of: credentialRevision) { _ in invalidateOperation() }
            .onDisappear { invalidateOperation() }
    }

    // MARK: Private

    @State private var customModel = ""
    @State private var status = ""
    @State private var isBusy = false
    @State private var operation: Task<(), Never>?
    @State private var operationID = UUID()

    @Default private var endpoint: String
    @Default private var model: String
    @Default private var models: [String]
    @Default private var credentialRevision: String

    private var selectableModels: [String] {
        var seen = Set<String>()
        return ([model] + models + provider.models).filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    private var canConnect: Bool {
        (!provider.requiresAPIKey || !credentialRevision.isEmpty) && !endpoint
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func invalidateOperation() {
        operationID = UUID()
        operation?.cancel()
        operation = nil
        isBusy = false
        status = ""
    }

    private func run(fetchModels: Bool) {
        invalidateOperation()
        let identifier = operationID
        let configuration = ReadingAIConfiguration.current()
        isBusy = true
        operation = Task { @MainActor in
            do {
                if fetchModels {
                    let fetched = try await ReadingAIClient().models(configuration: configuration)
                    try Task.checkCancellation()
                    guard identifier == operationID else { return }
                    models = Array(Set(models + fetched)).sorted()
                    status = String(localized: "reading.ai.models_loaded \(fetched.count)")
                } else {
                    _ = try await ReadingAIClient().complete(
                        configuration: configuration,
                        system: "Reply with OK.", prompt: "Connection test."
                    )
                    try Task.checkCancellation()
                    guard identifier == operationID else { return }
                    status = String(localized: "reading.ai.connection_success")
                }
            } catch {
                guard identifier == operationID, !Task.isCancelled else { return }
                status = (error as? DeepSeekChatError)?.queryError.localizedDescription ?? error.localizedDescription
            }
            guard identifier == operationID else { return }
            isBusy = false
            operation = nil
        }
    }
}
