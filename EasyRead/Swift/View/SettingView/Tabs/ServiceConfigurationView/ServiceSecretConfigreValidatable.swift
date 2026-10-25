//
//  ServiceSecretConfigreValidatable.swift
//  EasyRead
//
//  Created by phlpsong on 2024/1/30.
//  Copyright © 2024 izual. All rights reserved.
//

import Foundation

// MARK: - ServiceSecretConfigreValidatable

protocol ServiceSecretConfigreValidatable {
    func validate() async -> QueryResult
}

// MARK: - QueryService + ServiceSecretConfigreValidatable

extension QueryService: ServiceSecretConfigreValidatable {
    func validate() async -> QueryResult {
        // EasyRead: DeepSeek validates with a minimal non-streaming chat
        // request (spec 4.4) so failures map to distinct localized errors.
        // The cast is required because methods added by this extension
        // cannot be overridden by service subclasses.
        if let deepSeekService = self as? DeepSeekService {
            return await deepSeekService.validateConnection()
        }

        resetServiceResult()

        /**
         To reduce output text, save cost, a simple translation example is enough.

         1. use zh -> en to avoid analyze English sentence.
         2. if Chinese text length > 5, it won't query dict.
         */

        let text = "曾经沧海难为水"
        var latestResult = result ?? QueryResult()

        do {
            for try await result in translateStream(text, from: .simplifiedChinese, to: .english) {
                latestResult = result
            }
        } catch {
            latestResult = result ?? latestResult
            if latestResult.error == nil {
                latestResult.error = QueryError.queryError(from: error)
            }
        }

        return latestResult
    }
}

// MARK: - ServiceConfigRemovable

protocol ServiceConfigRemovable {
    func remove()
}

// MARK: - QueryService + ServiceConfigRemovable

extension QueryService: ServiceConfigRemovable {
    func remove() {
        for winType in [EZWindowType.fixed, EZWindowType.main, EZWindowType.mini] {
            LocalStorage.shared().removeServiceType(
                serviceTypeWithUniqueIdentifier(),
                windowType: winType,
                allowRemovingLast: true
            )
            NotificationCenter.default.postServiceUpdateNotification(windowType: winType)
        }
        GlobalContext.shared.reloadLLMServicesSubscribers()
    }
}
