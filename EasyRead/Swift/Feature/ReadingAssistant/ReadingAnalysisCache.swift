// Copyright © 2026 EasyRead contributors. GPL-3.0.
import EasyReadKit
import Foundation

/// Bounded, memory-only cache. Context and languages are part of identity; source text never reaches disk.
@MainActor
final class ReadingAnalysisCache {
    // MARK: Internal

    struct Key: Hashable {
        let text: String
        let context: String?
        let availability: String
        let sourceLanguage: String
        let targetLanguage: String
        let explanationLanguage: String
        let model: String
        let endpoint: String
    }

    static let shared = ReadingAnalysisCache()

    func value(for key: Key) -> ReadingAnalysis? {
        let now = Date()
        entries = entries.filter { now.timeIntervalSince($0.value.created) < 600 }
        guard var entry = entries[key] else { return nil }
        entry.lastUsed = now
        entries[key] = entry
        return entry.answer
    }

    func insert(_ answer: ReadingAnalysis, for key: Key) {
        guard entries[key] == nil else { return }
        if entries.count >= 12, let oldest = entries.min(by: { $0.value.lastUsed < $1.value.lastUsed })?.key {
            entries.removeValue(forKey: oldest)
        }
        entries[key] = Entry(answer: answer, created: Date(), lastUsed: Date())
    }

    func removeAll() { entries.removeAll() }

    // MARK: Private

    private struct Entry {
        let answer: ReadingAnalysis
        let created: Date
        var lastUsed: Date
    }

    private var entries: [Key: Entry] = [:]
}
