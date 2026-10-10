//
//  ContextExtractor.swift
//  Easydict
//
//  Created by wangruiqi on 2026/10/10.
//  Copyright © 2026 izual. All rights reserved.
//

import Defaults
import EasyReadKit
import Foundation

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

// MARK: - SelectionContextStore

/// Thread-safe holder of the most recently captured selection context.
///
/// Keeps at most one snapshot in memory; nothing is persisted. A new
/// selection replaces the previous snapshot immediately.
final class SelectionContextStore: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot: SelectionSnapshot?

    /// Stores `snapshot`, replacing any previous one.
    func store(_ snapshot: SelectionSnapshot) {
        lock.lock()
        defer { lock.unlock() }
        self.snapshot = snapshot
    }

    /// The stored snapshot when its selected text equals `text`.
    ///
    /// Matching by text keeps a stale snapshot (from an earlier selection)
    /// from being attached to an unrelated query. Both sides are normalized
    /// with `removeInvisibleChar()` + `trim()`, mirroring what the query flow
    /// does to the raw selection (`EventMonitor.handleSelectedText` strips
    /// invisible object replacement characters before querying), so an
    /// invisible character alone cannot silently drop the context.
    /// Known limitation: Books.app excerpt stripping
    /// (`removeBooksExcerptInfo`) runs only on the query side; selections
    /// whose text it changes will not match and degrade to selection-only.
    func snapshot(matchingSelectedText text: String) -> SelectionSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        let normalizedText = text.removeInvisibleChar().trim()
        guard let snapshot,
              snapshot.selectedText.removeInvisibleChar().trim() == normalizedText
        else {
            return nil
        }
        return snapshot
    }

    /// Removes the stored snapshot.
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        snapshot = nil
    }
}

// MARK: - ContextExtractionCoordinator

/// Coordinates context capture for text selections: gates on the user's
/// privacy setting, runs the extractor asynchronously and keeps the latest
/// snapshot available to the query flow.
final class ContextExtractionCoordinator: Sendable {
    static let shared = ContextExtractionCoordinator()

    /// Latest captured context; in-memory only, replaced on every selection.
    let store = SelectionContextStore()

    private let extractor: any ContextExtracting

    init(extractor: any ContextExtracting = AXContextExtractor()) {
        self.extractor = extractor
    }

    /// Whether the user enabled context extraction in privacy settings.
    var isContextExtractionEnabled: Bool {
        Defaults[.enableContextExtraction]
    }

    /// Captures the reading context for a fresh selection without blocking
    /// the selection flow. Does nothing when the feature is disabled.
    func captureContext(for selectedText: String) {
        guard isContextExtractionEnabled, !selectedText.isEmpty else {
            return
        }
        Task { [extractor] in
            let snapshot = await extractor.captureContext(selectedText: selectedText)
            store.store(snapshot)
        }
    }

    /// The stored snapshot when its selected text matches the query's input
    /// text (the raw selection before word segmentation).
    func snapshot(forInputText inputText: String) -> SelectionSnapshot? {
        store.snapshot(matchingSelectedText: inputText)
    }
}
