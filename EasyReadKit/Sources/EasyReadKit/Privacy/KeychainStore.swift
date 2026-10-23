//
//  KeychainStore.swift
//  EasyReadKit
//
//  Created by wangruiqi on 2026/10/10.
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation
import Security

// MARK: - KeychainStoreError

/// A Keychain operation failed. Only the raw `OSStatus` is carried: the
/// failing operation's payload (the secret itself) must never appear in
/// an error description or a log.
public struct KeychainStoreError: Error, Equatable, Sendable {
    // MARK: Lifecycle

    public init(status: OSStatus) {
        self.status = status
    }

    // MARK: Public

    /// The `OSStatus` returned by the Security framework.
    public let status: OSStatus
}

// MARK: - KeychainStore

/// Keychain-backed storage for secrets (EasyRead: the DeepSeek API key).
///
/// The secret is stored as one generic-password item per `service`/`account`
/// pair and never touches UserDefaults, databases, the repository, crash
/// reports or logs. Saving an empty string deletes the item, so "clear the
/// key" is a plain `save("")`.
public struct KeychainStore: Equatable, Sendable {
    // MARK: Lifecycle

    public init(service: String, account: String) {
        self.service = service
        self.account = account
    }

    // MARK: Public

    /// The Keychain item's `kSecAttrService`.
    public let service: String

    /// The Keychain item's `kSecAttrAccount`.
    public let account: String

    /// Whether a secret is currently stored.
    public var hasValue: Bool {
        // `try?` flattens the double optional (`read()` returns `String?`),
        // so a thrown error and "no item stored" both land here as nil.
        guard let secret = try? read() else {
            return false
        }
        return !secret.isEmpty
    }

    /// Reads the stored secret.
    ///
    /// - Returns: The secret, or `nil` when no item is stored.
    /// - Throws: `KeychainStoreError` for unexpected Security framework
    ///   failures (the secret is never part of the error).
    public func read() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainStoreError(status: errSecParam)
            }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainStoreError(status: status)
        }
    }

    /// Saves `secret`, replacing any existing value. An empty string deletes
    /// the item.
    public func save(_ secret: String) throws {
        guard !secret.isEmpty else {
            try delete()
            return
        }

        let data = Data(secret.utf8)
        let updateStatus = SecItemUpdate(
            baseQuery() as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            break
        default:
            throw KeychainStoreError(status: updateStatus)
        }

        var addQuery = baseQuery()
        addQuery[kSecValueData as String] = data
        // Reading assistance needs the key only while the device is unlocked.
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainStoreError(status: addStatus)
        }
    }

    /// Deletes the secret, reporting failures so the UI never claims a retained key was removed.
    public func delete() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError(status: status)
        }
    }

    // MARK: Private

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
