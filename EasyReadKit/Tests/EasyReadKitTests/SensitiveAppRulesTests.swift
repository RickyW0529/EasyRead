//
//  SensitiveAppRulesTests.swift
//  EasyReadKit
//
//  Created by wangruiqi on 2026/10/9.
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation
import Testing

@testable import EasyReadKit

// MARK: - SensitiveAppRulesTests

@Suite
struct SensitiveAppRulesTests {
    // MARK: Internal

    @Test func passwordManagersAreBlocked() {
        let rules = SensitiveAppRules()
        #expect(rules.sensitiveCategory(for: "com.bitwarden.desktop") == .passwordManager)
        #expect(rules.sensitiveCategory(for: "com.agilebits.onepassword7") == .passwordManager)
        #expect(rules.isSensitive(bundleID: "com.lastpass.LastPass"))
    }

    @Test func terminalsAreBlocked() {
        let rules = SensitiveAppRules()
        #expect(rules.sensitiveCategory(for: "com.apple.Terminal") == .terminal)
        #expect(rules.sensitiveCategory(for: "com.googlecode.iterm2") == .terminal)
        #expect(rules.isSensitive(bundleID: "com.mitchellh.ghostty"))
    }

    @Test func systemSecurityAgentIsBlocked() {
        let rules = SensitiveAppRules()
        #expect(rules.sensitiveCategory(for: "com.apple.SecurityAgent") == .systemSecurity)
        #expect(rules.isSensitive(bundleID: "com.apple.SecurityAgent"))
    }

    @Test func ownAppBundleIDsAreBlocked() {
        let rules = SensitiveAppRules()
        #expect(rules.sensitiveCategory(for: "com.easyread.EasyRead") == .selfApp)
        #expect(rules.sensitiveCategory(for: "com.easyread.EasyRead-debug") == .selfApp)

        let customRules = SensitiveAppRules(ownBundleIDs: ["dev.me.MyApp"])
        #expect(customRules.sensitiveCategory(for: "dev.me.MyApp") == .selfApp)
    }

    @Test func userExcludedAppsAreBlocked() {
        // The user-managed list is the authoritative boundary (T13).
        let rules = SensitiveAppRules(excludedBundleIDs: ["com.example.SecretTool"])
        #expect(rules.sensitiveCategory(for: "com.example.SecretTool") == .userExcluded)
        #expect(rules.isSensitive(bundleID: "com.example.SecretTool"))
        #expect(!rules.isSensitive(bundleID: "com.example.OtherTool"))
    }

    @Test func bankingKeywordHeuristic() {
        let rules = SensitiveAppRules()
        #expect(rules.sensitiveCategory(for: "com.bigbank.MobileBanking") == .banking)
        #expect(rules.sensitiveCategory(for: "cn.example.MyWallet") == .banking)
        #expect(rules.sensitiveCategory(for: "com.example.NewsReader") == nil)
    }

    @Test func normalReadingAppsAreAllowed() {
        let rules = SensitiveAppRules()
        #expect(rules.sensitiveCategory(for: "com.apple.Safari") == nil)
        #expect(rules.sensitiveCategory(for: "com.google.Chrome") == nil)
        #expect(rules.sensitiveCategory(for: "com.apple.Preview") == nil)
        #expect(rules.sensitiveCategory(for: "com.microsoft.VSCode") == nil)
        #expect(rules.sensitiveCategory(for: "md.obsidian") == nil)
        #expect(!rules.isSensitive(bundleID: nil))
        #expect(!rules.isSensitive(bundleID: ""))
    }

    @Test func protectedElementRoles() {
        let rules = SensitiveAppRules()
        #expect(rules.isProtectedElement(roleValue: "AXSecureTextField"))
        #expect(!rules.isProtectedElement(roleValue: "AXTextField"))
        #expect(!rules.isProtectedElement(roleValue: "AXTextArea"))
        #expect(!rules.isProtectedElement(roleValue: nil))
    }
}
