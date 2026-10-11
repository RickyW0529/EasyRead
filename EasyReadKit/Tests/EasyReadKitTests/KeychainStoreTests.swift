//
//  KeychainStoreTests.swift
//  EasyReadKit
//
//  Created by wangruiqi on 2026/10/10.
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation
import Testing

@testable import EasyReadKit

// MARK: - KeychainStoreTests

/// Roundtrip tests against the real Keychain (spec T16: key save / restart /
/// delete must behave correctly and never touch plaintext storage).
///
/// Each test uses its own throwaway `service` name; the suite's `deinit`
/// removes every item it created, so the app's real DeepSeek item is never
/// touched and no test garbage is left behind. swift-testing creates a new
/// instance per test function, so the cleanup runs after every test.
@Suite(.serialized)
final class KeychainStoreTests {
    // MARK: Internal

    /// A fresh store with a unique service name, registered for cleanup.
    private func makeStore() -> KeychainStore {
        let store = KeychainStore(
            service: "com.easyread.EasyRead.tests.\(UUID().uuidString)",
            account: "test-key"
        )
        stores.append(store)
        return store
    }

    /// Stores created by the running test; removed in `deinit`.
    private var stores: [KeychainStore] = []

    deinit {
        stores.forEach { try? $0.delete() }
    }

    @Test func readReturnsNilWhenAbsent() throws {
        let store = makeStore()
        #expect(try store.read() == nil)
        #expect(!store.hasValue)
    }

    @Test func saveThenReadRoundtrips() throws {
        let store = makeStore()
        try store.save("sk-test-secret-1234")
        #expect(try store.read() == "sk-test-secret-1234")
        #expect(store.hasValue)
    }

    @Test func saveReplacesExistingValue() throws {
        let store = makeStore()
        try store.save("sk-first")
        try store.save("sk-second")
        #expect(try store.read() == "sk-second")
    }

    @Test func saveEmptyStringDeletesItem() throws {
        let store = makeStore()
        try store.save("sk-first")
        try store.save("")
        #expect(try store.read() == nil)
        #expect(!store.hasValue)
    }

    @Test func deleteRemovesItem() throws {
        let store = makeStore()
        try store.save("sk-first")
        try store.delete()
        #expect(try store.read() == nil)
    }

    @Test func deleteWhenAbsentIsNoOp() throws {
        let store = makeStore()
        try store.delete()
        try store.delete()
        #expect(!store.hasValue)
    }

    @Test func sameServiceAndAccountShareStorage() throws {
        let store = makeStore()
        let sameIdentity = KeychainStore(service: store.service, account: store.account)
        try store.save("sk-shared")
        #expect(try sameIdentity.read() == "sk-shared")
        try sameIdentity.delete()
        #expect(try store.read() == nil)
    }
}
