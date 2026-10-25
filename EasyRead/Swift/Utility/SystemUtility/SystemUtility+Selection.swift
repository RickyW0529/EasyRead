//
//  SystemUtility+Selection.swift
//  EasyRead
//
//  Created by tisfeng on 2025/9/9.
//  Copyright © 2025 izual. All rights reserved.
//

import AppKit
import SelectedTextKit

extension SystemUtility {
    @MainActor
    @objc
    public func getSelectedText(strategy: TextStrategy) async throws -> String? {
        guard AXIsProcessTrusted(), !AXContextExtractor.shouldBlockCurrentSelection() else { return nil }
        let sourcePID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let text = try await selectedTextManager.getSelectedText(strategy: strategy)
        try Task.checkCancellation()
        // A fallback may suspend while focus or the user's exclusion rules change.
        guard sourcePID == NSWorkspace.shared.frontmostApplication?.processIdentifier,
              AXIsProcessTrusted(), !AXContextExtractor.shouldBlockCurrentSelection() else { return nil }
        return text
    }
}
