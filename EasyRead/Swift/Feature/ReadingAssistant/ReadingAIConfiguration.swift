// Copyright © 2026 EasyRead contributors. GPL-3.0.
import Defaults
import EasyReadKit
import Foundation

/// An immutable request snapshot. Secrets remain in memory and never enter cache identity.
struct ReadingAIConfiguration: Equatable, Sendable {
    // MARK: Internal

    let providerID: String
    let endpoint: String
    let model: String
    let apiKey: String
    let credentialRevision: String

    var provider: ReadingAIProvider { .provider(id: providerID) }
    var isReady: Bool {
        (!provider.requiresAPIKey || !apiKey.isEmpty) && !model.isEmpty && completionURL != nil
    }

    /// Accepts either an API base URL or a complete chat-completions endpoint.
    var completionURL: URL? {
        guard var components = URLComponents(string: endpoint),
              ["https", "http"].contains(components.scheme?.lowercased() ?? ""),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil, components.fragment == nil else { return nil }
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = path.isEmpty ? "" : "/" + path
        if path.isEmpty, let preset = URLComponents(string: provider.baseURL), preset.host == host {
            components.path = preset.path
        }
        if !components.path.hasSuffix("/chat/completions") {
            components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            components.path = "/" + [components.path, "chat/completions"].filter { !$0.isEmpty }.joined(separator: "/")
        }
        return components.url
    }

    var modelsURL: URL? {
        guard let url = completionURL,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        components.path = String(components.path.dropLast("chat/completions".count)) + "models"
        return components.url
    }

    @MainActor
    static func current() -> Self {
        let provider = ReadingAIProvider.provider(id: Defaults[.readingAIProvider])
        let key = provider.id == "deepseek" ? legacyDeepSeek.apiKey : (try? keychain(for: provider.id).read()) ?? ""
        let endpoint = Defaults[endpointKey(for: provider)].trimmingCharacters(in: .whitespacesAndNewlines)
        return .init(
            providerID: provider.id,
            endpoint: endpoint.isEmpty ? provider.baseURL : endpoint,
            model: Defaults[modelKey(for: provider)].trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: key,
            credentialRevision: Defaults[mirrorKey(for: provider)]
        )
    }

    static func keychain(for providerID: String) -> KeychainStore {
        KeychainStore(service: "com.easyread.EasyRead.apikey", account: providerID)
    }

    static func endpointKey(for provider: ReadingAIProvider) -> Defaults.Key<String> {
        .init("readingAI_\(provider.id)_endpoint", default: provider.baseURL)
    }

    static func modelKey(for provider: ReadingAIProvider) -> Defaults.Key<String> {
        if provider.id == "deepseek" {
            // Keep the original model key, including an existing user's selection.
            return serivceConfigurationKey(
                .model,
                serviceType: .deepSeek,
                id: "",
                defaultValue: DeepSeekModel.deepseekFlash.rawValue
            )
        }
        return .init("readingAI_\(provider.id)_model", default: provider.models.first ?? "")
    }

    static func modelsKey(for provider: ReadingAIProvider) -> Defaults.Key<[String]> {
        .init("readingAI_\(provider.id)_models", default: provider.models)
    }

    static func mirrorKey(for provider: ReadingAIProvider) -> Defaults.Key<String> {
        provider.id == "deepseek" ? .deepSeekAPIKeyMirror : .init(
            "readingAI_\(provider.id)_credentialRevision",
            default: ""
        )
    }

    // MARK: Private

    @MainActor private static let legacyDeepSeek = DeepSeekService()
}
