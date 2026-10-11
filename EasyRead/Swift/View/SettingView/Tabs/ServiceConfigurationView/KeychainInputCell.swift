//
//  KeychainInputCell.swift
//  Easydict
//
//  Created by wangruiqi on 2026/10/10.
//  Copyright © 2026 izual. All rights reserved.
//

import Defaults
import EasyReadKit
import SwiftUI
import SFSafeSymbols

// MARK: - KeychainInputCell

/// Secure input cell whose value is stored in the macOS Keychain instead of
/// UserDefaults (EasyRead: the DeepSeek API key, spec 7.2).
///
/// The buffer only saves on an explicit action — the secret is never written
/// on every keystroke — and `mirrorKey` (a non-sensitive Defaults value)
/// records key availability so the shared validation-button logic can
/// observe it.
struct KeychainInputCell: View {
    // MARK: Lifecycle

    init(
        textFieldTitleKey: LocalizedStringKey,
        placeholder: String,
        store: KeychainStore,
        mirrorKey: Defaults.Key<String>
    ) {
        self.textFieldTitleKey = textFieldTitleKey
        self.placeholder = placeholder
        self.store = store
        self.mirrorKey = mirrorKey
    }

    // MARK: Internal

    let textFieldTitleKey: LocalizedStringKey
    let placeholder: String
    let store: KeychainStore
    let mirrorKey: Defaults.Key<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                SecureTextField(
                    title: textFieldTitleKey,
                    placeholder: placeholder,
                    text: $inputText
                )

                Button(action: save) {
                    Image(systemSymbol: .checkmarkCircle)
                }
                .disabled(trimmedInput.isEmpty)
                .help(Text("service.configuration.api_key.save_to_keychain"))

                if hasStoredKey {
                    Button(role: .destructive, action: delete) {
                        Image(systemSymbol: .trash)
                    }
                    .help(Text("service.configuration.api_key.delete_from_keychain"))
                }
            }

            if hasStoredKey {
                Label {
                    Text("service.configuration.api_key.stored_in_keychain")
                } icon: {
                    Image(systemSymbol: .lockFill)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if showsSaveError {
                Label {
                    Text("service.configuration.api_key.keychain_error")
                } icon: {
                    Image(systemSymbol: .exclamationmarkTriangle)
                }
                .font(.caption)
                .foregroundStyle(.red)
            }
        }
        .onAppear {
            syncStoredState()
        }
    }

    // MARK: Private

    @State private var inputText = ""
    @State private var hasStoredKey = false
    @State private var showsSaveError = false

    private var trimmedInput: String {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Reads presence (never the value) and keeps the mirror in sync, so a
    /// key deleted outside the app is reflected here too.
    private func syncStoredState() {
        let stored = store.hasValue
        hasStoredKey = stored
        if !stored { Defaults[mirrorKey] = "" }
        else if Defaults[mirrorKey].isEmpty { Defaults[mirrorKey] = UUID().uuidString }
        if !stored { Defaults[.enableReadingAI] = false }
    }

    private func save() {
        do {
            try store.save(trimmedInput)
            Defaults[mirrorKey] = UUID().uuidString
            inputText = ""
            showsSaveError = false
            syncStoredState()
        } catch {
            // Status code only — the secret is never part of the error.
            logError("Saving API key to Keychain failed: \(error)")
            showsSaveError = true
        }
    }

    private func delete() {
        do {
            try store.delete()
            inputText = ""
            showsSaveError = false
            syncStoredState()
        } catch {
            showsSaveError = true
        }
    }
}
