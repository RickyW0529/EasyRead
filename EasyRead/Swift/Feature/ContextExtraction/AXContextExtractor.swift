//
//  AXContextExtractor.swift
//  Easydict
//
//  Created by wangruiqi on 2026/10/10.
//  Copyright © 2026 izual. All rights reserved.
//

import AppKit
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
    // MARK: Internal

    /// Runs before every selection strategy, including clipboard/browser fallbacks.
    static func shouldBlockCurrentSelection() -> Bool {
        let app = NSWorkspace.shared.frontmostApplication
        let rules = makeRules()
        if rules.isSensitive(bundleID: app?.bundleIdentifier) { return true }
        guard let app, let application = Application(app),
              let element = try? application.focusedUIElement() else { return false }
        return isProtected(element, rules: rules)
    }

    /// Re-evaluates exclusions at send time, including changes made after capture.
    static func allowsAI(snapshot: SelectionSnapshot?) -> Bool {
        if let snapshot, makeRules().isSensitive(bundleID: snapshot.sourceBundleID) { return false }
        return true
    }

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
              let application = Application(app),
              let element = try? application.focusedUIElement() else {
            logInfo("No focused element available for context extraction")
            return .selectionOnly(selectedText: trimmedSelection, sourceBundleID: bundleID)
        }

        if Self.isProtected(element, rules: rules) {
            logInfo("Skip context extraction for protected element role")
            return .selectionOnly(selectedText: trimmedSelection, sourceBundleID: bundleID)
        }

        // Request only a bounded range; AXValue can expose an entire document and is never read.
        guard let range = try? element.selectedTextRange(), range.location >= 0, range.length > 0,
              range.length <= SelectionPolicy.default.maxSelectionLength * 2 else {
            return .selectionOnly(selectedText: trimmedSelection, sourceBundleID: bundleID)
        }
        var countValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element.element, kAXNumberOfCharactersAttribute as CFString, &countValue) ==
            .success,
            let count = countValue as? Int, count >= range.location,
            range.length <= count - range.location else {
            return .selectionOnly(selectedText: trimmedSelection, sourceBundleID: bundleID)
        }
        let lower = max(0, range.location - 300)
        let upper = min(count, range.location + range.length + 300)
        var readRange = CFRange(location: lower, length: upper - lower)
        guard let axRange = AXValueCreate(.cfRange, &readRange) else {
            return .selectionOnly(selectedText: trimmedSelection, sourceBundleID: bundleID)
        }
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element.element, kAXStringForRangeParameterizedAttribute as CFString, axRange, &value
        ) == .success, let boundedText = value as? String else {
            return .selectionOnly(selectedText: trimmedSelection, sourceBundleID: bundleID)
        }
        let result = TextContextExtractor().extractContext(
            fullText: boundedText, selectedText: trimmedSelection,
            selectedRange: NSRange(location: range.location - lower, length: range.length)
        )
        // Clipped document boundaries cannot establish an exact complete sentence.
        let availability: ContextAvailability = result.availability == .selectionOnly ? .selectionOnly
            : (lower == 0 && upper == count ? result.availability : .nearbyText)

        // Privacy: log only the availability, never the text.
        logInfo("Context extraction availability: \(result.availability.rawValue)")

        return SelectionSnapshot(
            selectedText: trimmedSelection,
            surroundingText: result.surroundingText,
            availability: availability,
            sourceBundleID: bundleID
        )
    }

    // MARK: Private

    private static func isProtected(_ element: UIElement, rules: SensitiveAppRules) -> Bool {
        let subrole: String? = try? element.attribute(.subrole)
        return rules.isProtectedElement(roleValue: try? element.roleValue())
            || rules.isProtectedElement(roleValue: subrole)
    }

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
