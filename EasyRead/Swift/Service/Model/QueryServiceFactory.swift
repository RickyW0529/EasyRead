//
//  QueryServiceFactory.swift
//  EasyRead
//
//  Created by tisfeng on 2025/12/16.
//  Copyright © 2025 izual. All rights reserved.
//

import Defaults
import Foundation

// MARK: - QueryServiceMetadata

struct QueryServiceMetadata {
    let serviceType: ServiceType
    let uuid: String
    let title: String
    let apiKeyRequirement: ServiceAPIKeyRequirement
    let isStream: Bool
    let allowsMultipleInstances: Bool
}

// MARK: - ServiceRegistration

private struct ServiceRegistration {
    // MARK: Lifecycle

    init(
        _ serviceType: ServiceType,
        _ serviceClass: QueryService.Type,
        _ titleKey: String,
        apiKeyRequirement: ServiceAPIKeyRequirement = .userProvided,
        allowsMultipleInstances: Bool = false
    ) {
        self.serviceType = serviceType
        self.serviceClass = serviceClass
        self.titleKey = titleKey
        self.apiKeyRequirement = apiKeyRequirement
        self.allowsMultipleInstances = allowsMultipleInstances
    }

    // MARK: Internal

    let serviceType: ServiceType
    let serviceClass: QueryService.Type
    let titleKey: String
    let apiKeyRequirement: ServiceAPIKeyRequirement
    let allowsMultipleInstances: Bool
}

// MARK: - QueryServiceFactory

/// A registry that maps `ServiceType` identifiers to their corresponding `QueryService` subclasses.
///
/// This class mirrors the legacy Objective-C `EZServiceTypes` API and stays accessible from both Objective-C and Swift.
@objcMembers
final class QueryServiceFactory: NSObject {
    // MARK: Internal

    /// Shared singleton instance.
    static let shared = QueryServiceFactory()

    var allServiceTypes: [ServiceType] {
        serviceRegistrations.map(\.serviceType)
    }

    var allServiceTypeIDs: [String] {
        allServiceTypes.map(\.rawValue)
    }

    func service(withTypeId typeIdIfHave: String) -> QueryService? {
        let components = serviceIdentifierComponents(from: typeIdIfHave)

        guard let serviceClass = serviceClass(withTypeId: typeIdIfHave) else {
            return nil
        }

        let service = serviceClass.init()
        service.uuid = components.uuid
        return service
    }

    /// Speech providers remain available even when they have no translation result card.
    /// Keep this separate from registration so it cannot restore retired AI or dictionary cards.
    func speechService(withTypeId typeId: String) -> QueryService? {
        guard let type = TTSServiceType(rawValue: typeId) else { return nil }
        switch type {
        case .youdao: return YoudaoService()
        case .baidu: return BaiduService()
        case .bing: return BingService()
        case .google: return GoogleService()
        case .apple: return AppleService()
        }
    }

    func services(fromTypes types: [String]) -> [QueryService] {
        types.compactMap { service(withTypeId: $0) }
    }

    func isStreamService(typeIdIfHave: String) -> Bool {
        guard let serviceClass = serviceClass(withTypeId: typeIdIfHave) else {
            return false
        }
        return serviceClass is StreamService.Type
    }

    func metadata(withTypeId typeIdIfHave: String) -> QueryServiceMetadata? {
        let components = serviceIdentifierComponents(from: typeIdIfHave)
        guard let registration = serviceRegistration(withTypeId: typeIdIfHave) else { return nil }

        return QueryServiceMetadata(
            serviceType: registration.serviceType,
            uuid: components.uuid,
            title: title(
                for: registration.serviceType,
                uuid: components.uuid,
                fallbackKey: registration.titleKey
            ),
            apiKeyRequirement: registration.apiKeyRequirement,
            isStream: registration.serviceClass is StreamService.Type,
            allowsMultipleInstances: registration.allowsMultipleInstances
        )
    }

    // MARK: Private

    /// AI results belong exclusively to the reading assistant. This registry
    /// contains dictionary and non-AI translation cards only.
    private let serviceRegistrations: [ServiceRegistration] = [
        .init(.appleDictionary, AppleDictionary.self, "apple_dictionary", apiKeyRequirement: .none),
        .init(.mDict, MDictService.self, "service.mdict.name", apiKeyRequirement: .none),
        .init(.deepL, DeepLService.self, "deepL_translate", apiKeyRequirement: .none),
        .init(.google, GoogleService.self, "google_translate", apiKeyRequirement: .none),
        .init(.apple, AppleService.self, "apple_translate", apiKeyRequirement: .none),
        .init(.bing, BingService.self, "bing_translate", apiKeyRequirement: .none),
    ]

    private func serviceClass(withTypeId typeIdIfHave: String) -> QueryService.Type? {
        serviceRegistration(withTypeId: typeIdIfHave)?.serviceClass
    }

    private func serviceRegistration(withTypeId typeIdIfHave: String) -> ServiceRegistration? {
        let components = serviceIdentifierComponents(from: typeIdIfHave)
        return serviceRegistrations.first { $0.serviceType.rawValue == components.rawType }
    }

    private func serviceIdentifierComponents(from typeIdIfHave: String)
        -> (rawType: String, uuid: String) {
        let components = typeIdIfHave.split(
            separator: "#",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        let rawType = String(components.first ?? Substring(typeIdIfHave))
        let uuid = components.count > 1 ? String(components[1]) : ""
        return (rawType, uuid)
    }

    private func title(for serviceType: ServiceType, uuid: String, fallbackKey: String) -> String {
        if serviceType == .customOpenAI {
            let nameKey = serivceConfigurationKey(
                .name,
                serviceType: serviceType,
                id: uuid,
                defaultValue: ""
            )
            let customName = Defaults[nameKey]
            if !customName.isEmpty {
                return customName
            }
        }
        return NSLocalizedString(fallbackKey, comment: "")
    }
}
