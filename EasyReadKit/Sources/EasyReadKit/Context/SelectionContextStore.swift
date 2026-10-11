// Copyright © 2026 EasyRead contributors. GPL-3.0.
import Foundation

/// A single in-memory selection, with generation checks for asynchronous context capture.
public final class SelectionContextStore: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot: SelectionSnapshot?

    public init() {}

    public func store(_ snapshot: SelectionSnapshot) {
        lock.lock()
        defer { lock.unlock() }
        self.snapshot = snapshot
    }

    /// Completes only the capture still owned by this selection; preserves its identity.
    public func completeCapture(_ captured: SelectionSnapshot, selectionID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        guard let current = snapshot, current.selectionID == selectionID,
              current.sourceBundleID == captured.sourceBundleID else { return }
        snapshot = SelectionSnapshot(
            selectedText: current.selectedText, surroundingText: captured.surroundingText,
            availability: captured.availability, sourceBundleID: current.sourceBundleID,
            timestamp: current.timestamp, selectionID: current.selectionID
        )
    }

    public func snapshot(matchingSelectedText text: String) -> SelectionSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        guard let snapshot, Self.normalized(snapshot.selectedText) == Self.normalized(text) else { return nil }
        return snapshot
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        snapshot = nil
    }

    private static func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{FFFC}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
