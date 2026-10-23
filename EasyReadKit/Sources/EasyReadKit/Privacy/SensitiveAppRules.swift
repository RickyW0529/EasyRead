//
//  SensitiveAppRules.swift
//  EasyReadKit
//
//  Created by wangruiqi on 2026/10/9.
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation

// MARK: - SensitiveAppCategory

/// Why a source app is considered sensitive. Used for anonymous logging
/// (category only, never the app name or selected text).
public enum SensitiveAppCategory: String, Sendable {
    case passwordManager
    case banking
    case terminal
    case systemSecurity
    case selfApp
    case userExcluded
}

// MARK: - SensitiveAppRules

/// Rules that decide whether reading context from the frontmost application
/// must be skipped for privacy reasons (acceptance case T13).
///
/// The curated lists below are best-effort: automatic detection can never be
/// exhaustive, so the user-managed exclusion list is the authoritative
/// boundary. `banking` detection uses keyword matching on the bundle id
/// because bank app identifiers are not centrally enumerable.
public struct SensitiveAppRules: Equatable, Sendable {
    // MARK: Lifecycle

    public init(
        ownBundleIDs: Set<String> = [
            "com.easyread.EasyRead",
            "com.easyread.EasyRead-debug",
            "com.izual.Easydict",
        ],
        excludedBundleIDs: Set<String> = []
    ) {
        self.ownBundleIDs = ownBundleIDs
        self.excludedBundleIDs = excludedBundleIDs
    }

    // MARK: Public

    /// Password managers and credential stores.
    public static let passwordManagerBundleIDs: Set<String> = [
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword7.Ernest",
        "com.agilebits.onepassword-osx.1Password",
        "com.bitwarden.desktop",
        "com.dashlane.Dashlane",
        "com.lastpass.LastPass",
        "me.proton.pass.mac",
        "org.keepassxc.keepassxc",
        "com.apple.keychainaccess",
    ]

    /// Terminal emulators: selections frequently contain tokens, keys and
    /// other secrets.
    public static let terminalBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "dev.warp.Warp-Stable",
        "net.kovidgoyal.kitty",
        "com.github.wez.wezterm",
    ]

    /// System security agents (password and permission prompts).
    public static let systemSecurityBundleIDs: Set<String> = [
        "com.apple.SecurityAgent",
        "com.apple.preference.security",
    ]

    /// Keywords that indicate a banking/finance app in a bundle id.
    public static let bankingKeywords: Set<String> = [
        "bank",
        "banking",
        "finance",
        "broker",
        "wallet",
        "银行",
    ]

    /// Accessibility roles of elements whose content must never be read.
    ///
    /// Raw AX role strings are used (instead of HIServices constants) so that
    /// this module depends only on Foundation.
    public static let protectedElementRoles: Set<String> = [
        "AXSecureTextField",
    ]

    /// Bundle ids of this app itself (both release and debug builds), plus
    /// the upstream Easydict ids for safety when both apps are installed.
    public let ownBundleIDs: Set<String>

    /// User-managed exclusion list. This is the authoritative boundary.
    public let excludedBundleIDs: Set<String>

    /// Returns why the app is sensitive, or `nil` when context may be read.
    public func sensitiveCategory(for bundleID: String?) -> SensitiveAppCategory? {
        guard let bundleID, !bundleID.isEmpty else {
            return nil
        }

        if excludedBundleIDs.contains(bundleID) {
            return .userExcluded
        }
        if ownBundleIDs.contains(bundleID) {
            return .selfApp
        }
        if Self.passwordManagerBundleIDs.contains(bundleID) {
            return .passwordManager
        }
        if Self.terminalBundleIDs.contains(bundleID) {
            return .terminal
        }
        if Self.systemSecurityBundleIDs.contains(bundleID) {
            return .systemSecurity
        }

        let lowercased = bundleID.lowercased()
        if Self.bankingKeywords.contains(where: { lowercased.contains($0) }) {
            return .banking
        }

        return nil
    }

    /// Whether context extraction must be skipped for this app.
    public func isSensitive(bundleID: String?) -> Bool {
        sensitiveCategory(for: bundleID) != nil
    }

    /// Whether the given AX role belongs to a protected element
    /// (e.g. a password field) whose content must never be read.
    public func isProtectedElement(roleValue: String?) -> Bool {
        guard let roleValue else {
            return false
        }
        return Self.protectedElementRoles.contains(roleValue)
    }
}
