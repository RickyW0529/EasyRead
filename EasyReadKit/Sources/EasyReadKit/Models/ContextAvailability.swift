//
//  ContextAvailability.swift
//  EasyReadKit
//
//  Created by wangruiqi on 2026/10/9.
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation

// MARK: - ContextAvailability

/// How much reading context was captured for a text selection.
///
/// The value must stay honest: it is only allowed to claim `exactSentence`
/// when the source application exposed readable text and the selection was
/// actually located inside it. When in doubt, use the weaker state.
public enum ContextAvailability: String, Codable, Sendable {
    /// The source application exposed readable text and the selection was
    /// matched inside it, so the surrounding sentence is the real original
    /// sentence.
    case exactSentence

    /// Surrounding text could be read, but the boundaries may be incomplete:
    /// the selection could not be uniquely located, or the context had to be
    /// hard-capped. Never present this as a precise original sentence.
    case nearbyText

    /// Only the user's selected text is available; nothing else was read.
    case selectionOnly
}
