//
//  AXContextExtractor.swift
//  Easydict
//
//  Created by wangruiqi on 2026/10/10.
//  Copyright © 2026 izual. All rights reserved.
//

import AXSwift
import Defaults
import EasyReadKit
import Foundation

// MARK: - AXContextExtractor

/// Reads the reading context of the current selection through the
/// Accessibility API.
///
/// This reads the focused element directly instead of calling
/// `SystemUtility.focusedElementInfo()`, which re-enters the selection
/// machinery (`getSelectedText()`) and must not be called while a selection
/// is still being processed.
///
/// Privacy: only the availability and the sensitive-app category are logged;
/// the selected text, the extracted context and the bundle id never are.
struct AXContextExtractor: ContextExtracting {
    func captureContext(selectedText: String) async -> SelectionSnapshot {
        let trimmedSelection = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        // Read the frontmost application once: a second read for the AX
        // element could observe a different app if the user switched while
        // capture was starting, mismatching the sensitive-app check below.
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let bundleID = frontmostApp?.bundleIdentifier
        let rules = Self.makeRules()

        // Sensitive apps and protected elements are never read; the snapshot
        // degrades to the selection only (acceptance case T13).
        if let category = rules.sensitiveCategory(for: bundleID) {
            logInfo("Skip context extraction for sensitive app category: \(category.rawValue)")
            return .selectionOnly(selectedText: trimmedSelection, sourceBundleID: bundleID)
        }

        guard let app = frontmostApp,
              let element = try? Application(app).focusedUIElement() else {
            logInfo("No focused element available for context extraction")
            return .selectionOnly(selectedText: trimmedSelection, sourceBundleID: bundleID)
        }

        let roleValue = try? element.roleValue()
        if rules.isProtectedElement(roleValue: roleValue) {
            logInfo("Skip context extraction for protected element role")
            return .selectionOnly(selectedText: trimmedSelection, sourceBundleID: bundleID)
        }

        let fullText = try? element.value()
        let selectedRange = (try? element.selectedTextRange())
            .map { NSRange(location: $0.location, length: $0.length) }

        let result = TextContextExtractor().extractContext(
            fullText: fullText,
            selectedText: trimmedSelection,
            selectedRange: selectedRange
        )

        // Privacy: log only the availability, never the text.
        logInfo("Context extraction availability: \(result.availability.rawValue)")

        return SelectionSnapshot(
            selectedText: trimmedSelection,
            surroundingText: result.surroundingText,
            availability: result.availability,
            sourceBundleID: bundleID
        )
    }

    // MARK: Private

    /// Sensitive-app rules with this app's own bundle id added and the
    /// user-managed exclusion list applied.
    private static func makeRules() -> SensitiveAppRules {
        var ownBundleIDs = SensitiveAppRules().ownBundleIDs
        if let ownBundleID = Bundle.main.bundleIdentifier, !ownBundleID.isEmpty {
            ownBundleIDs.insert(ownBundleID)
        }
        return SensitiveAppRules(
            ownBundleIDs: ownBundleIDs,
            excludedBundleIDs: Set(Defaults[.contextExtractionExcludedApps])
        )
    }
}
