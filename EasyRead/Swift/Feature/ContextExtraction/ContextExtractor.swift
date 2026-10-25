//
//  ContextExtractor.swift
//  EasyRead
//
//  Created by wangruiqi on 2026/10/10.
//  Copyright © 2026 izual. All rights reserved.
//

import AppKit
import Defaults
import EasyReadKit
import Foundation
import os

// MARK: - ContextExtracting

/// Captures the reading context around a text selection from the source
/// application. Injectable so tests can replace the Accessibility-backed
/// implementation.
///
/// Privacy: implementations must never log the selected text or the
/// extracted context, and must degrade to `selectionOnly` for sensitive
/// applications and protected elements instead of reading them.
protocol ContextExtracting: Sendable {
    /// Captures the context around `selectedText` from the currently focused
    /// element of the frontmost application.
    func captureContext(selectedText: String) async -> SelectionSnapshot
}

// MARK: - ContextExtractionCoordinator

/// Coordinates context capture for text selections: gates on the user's
/// privacy setting, runs the extractor asynchronously and keeps the latest
/// snapshot available to the query flow.
final class ContextExtractionCoordinator: Sendable {
    // MARK: Lifecycle

    init(extractor: any ContextExtracting = AXContextExtractor()) {
        self.extractor = extractor
    }

    // MARK: Internal

    static let shared = ContextExtractionCoordinator()

    /// Latest captured context; in-memory only, replaced on every selection.
    let store = SelectionContextStore()

    /// Whether the user enabled context extraction in privacy settings.
    var isContextExtractionEnabled: Bool {
        Defaults[.enableContextExtraction]
    }

    /// Captures the reading context for a fresh selection without blocking
    /// the selection flow. Does nothing when the feature is disabled.
    func captureContext(for selectedText: String) {
        let initial = SelectionSnapshot.selectionOnly(
            selectedText: selectedText,
            sourceBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        )
        // Replace immediately, even with context off, so repeated words never inherit an old sentence.
        store.store(initial)
        guard isContextExtractionEnabled,
              SelectionPolicy.default.validateSelection(selectedText).isUsable else { return }
        let task = Task { [extractor] in
            let captured = await extractor.captureContext(selectedText: selectedText)
            guard isContextExtractionEnabled else { return }
            store.completeCapture(captured, selectionID: initial.selectionID)
        }
        pendingCapture.withLock { pending in
            pending?.1.cancel()
            pending = (initial.selectionID, task)
        }
    }

    /// Awaits only this selection's existing capture; never reads another app after the query opens.
    func completedSnapshot(forInputText text: String, selectionID: UUID) async -> SelectionSnapshot? {
        let task = pendingCapture.withLock { $0?.0 == selectionID ? $0?.1 : nil }
        if isContextExtractionEnabled { await task?.value }
        guard !Task.isCancelled,
              let snapshot = snapshot(forInputText: text), snapshot.selectionID == selectionID else { return nil }
        return snapshot
    }

    /// The stored snapshot when its selected text matches the query's input
    /// text (the raw selection before word segmentation).
    func snapshot(forInputText inputText: String) -> SelectionSnapshot? {
        guard let snapshot = store.snapshot(matchingSelectedText: inputText) else { return nil }
        guard isContextExtractionEnabled else {
            return SelectionSnapshot(
                selectedText: snapshot.selectedText, surroundingText: nil, availability: .selectionOnly,
                sourceBundleID: snapshot.sourceBundleID, timestamp: snapshot.timestamp,
                selectionID: snapshot.selectionID
            )
        }
        return snapshot
    }

    // MARK: Private

    private let extractor: any ContextExtracting
    private let pendingCapture = OSAllocatedUnfairLock<(UUID, Task<(), Never>)?>(initialState: nil)
}
