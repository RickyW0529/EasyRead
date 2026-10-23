//
//  SelectionSnapshot.swift
//  EasyReadKit
//
//  Created by wangruiqi on 2026/10/9.
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation

// MARK: - SelectionSnapshot

/// A privacy-aware snapshot of one text selection together with the reading
/// context that was captured for it.
///
/// `surroundingText` is already length-limited and sanitized, so it is safe
/// to upload to an AI provider (when the user has configured one). Everything
/// else in this snapshot stays on the local machine: `sourceBundleID` exists
/// only for local policy decisions and must never be uploaded.
public struct SelectionSnapshot: Equatable, Sendable {
    // MARK: Lifecycle

    public init(
        selectedText: String,
        surroundingText: String?,
        availability: ContextAvailability,
        sourceBundleID: String?,
        timestamp: Date = Date(),
        selectionID: UUID = UUID()
    ) {
        self.selectedText = selectedText
        self.surroundingText = surroundingText
        self.availability = availability
        self.sourceBundleID = sourceBundleID
        self.timestamp = timestamp
        self.selectionID = selectionID
    }

    // MARK: Public

    /// The text the user selected, trimmed.
    public let selectedText: String

    /// The sentence(s) around the selection, length-limited and sanitized.
    /// `nil` when no context could be captured (`selectionOnly`).
    public let surroundingText: String?

    /// How trustworthy `surroundingText` is.
    public let availability: ContextAvailability

    /// Bundle identifier of the app the selection came from.
    /// Local-only: used for privacy rules, never uploaded.
    public let sourceBundleID: String?

    /// When the snapshot was captured.
    public let timestamp: Date

    /// Unique id for this selection. AI requests and result cards carry it so
    /// a late response can never be attached to a different selection.
    public let selectionID: UUID

    /// A snapshot without any context, for sensitive or unsupported sources.
    public static func selectionOnly(
        selectedText: String,
        sourceBundleID: String?
    )
        -> SelectionSnapshot {
        SelectionSnapshot(
            selectedText: selectedText,
            surroundingText: nil,
            availability: .selectionOnly,
            sourceBundleID: sourceBundleID
        )
    }
}
