// Copyright © 2026 EasyRead contributors. GPL-3.0.
import AppKit
import EasyReadKit
import SwiftUI

// MARK: - GrammarPhraseFlow

/// Keeps each line fragment, continuous underline, and role label together.
struct GrammarPhraseFlow: NSViewRepresentable {
    let chunks: [GrammarChunk]

    func makeNSView(context: Context) -> GrammarPhraseContainer { GrammarPhraseContainer() }

    func updateNSView(_ view: GrammarPhraseContainer, context: Context) {
        view.chunks = chunks
        view.needsLayout = true
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: GrammarPhraseContainer, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        return CGSize(width: width, height: nsView.fragments(width: width).height)
    }
}

// MARK: - GrammarPhraseContainer

/// Wraps at word boundaries and repeats the role below each continuation fragment.
final class GrammarPhraseContainer: NSView {
    // MARK: Internal

    struct Fragment {
        let text: String
        let structure: GrammarStructure?
        let frame: CGRect
    }

    override var isFlipped: Bool { true }

    var chunks: [GrammarChunk] = []

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsLayout = true
    }

    override func layout() {
        super.layout()
        subviews.forEach { $0.removeFromSuperview() }
        for fragment in fragments(width: bounds.width).items {
            let color = fragment.structure.map(GrammarRole.color) ?? .secondaryLabelColor
            let text = NSTextField(labelWithString: fragment.text)
            text.font = Self.textFont
            text.textColor = .labelColor
            text.isSelectable = true
            text.lineBreakMode = .byClipping
            text.frame = CGRect(
                x: fragment.frame.minX,
                y: fragment.frame.minY,
                width: fragment.frame.width,
                height: 19
            )
            addSubview(text)
            guard let structure = fragment.structure else { continue }
            let line = NSView(frame: CGRect(
                x: fragment.frame.minX,
                y: fragment.frame.minY + 19,
                width: fragment.frame.width,
                height: 1.5
            ))
            line.wantsLayer = true
            line.layer?.backgroundColor = color.cgColor
            addSubview(line)
            let label = NSTextField(labelWithString: structure.label)
            label.font = Self.labelFont
            let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            label.textColor = isDark ? color : color.blended(withFraction: 0.45, of: .black)
            label.lineBreakMode = .byTruncatingTail
            label.frame = CGRect(
                x: fragment.frame.minX,
                y: fragment.frame.minY + 22,
                width: fragment.frame.width,
                height: 12
            )
            label.toolTip = "\(structure.label)\n\(structure.explanation)"
            text.toolTip = label.toolTip
            addSubview(label)
        }
    }

    /// Measurement and display use the same fragments, avoiding SwiftUI proposal-dependent clipping.
    func fragments(width: CGFloat) -> (items: [Fragment], height: CGFloat) {
        let limit = max(width, 1)
        var items: [Fragment] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        let rowHeight: CGFloat = 37
        let gap: CGFloat = 10
        for chunk in chunks {
            let words = fittingWords(chunk.text, width: limit)
            var pending = ""
            let labelWidth = chunk.structure.map { Self.width($0.label, font: Self.labelFont) } ?? 0

            func appendFragment() {
                guard !pending.isEmpty else { return }
                let textWidth = Self.width(pending, font: Self.textFont)
                let itemWidth = min(limit, max(textWidth, labelWidth))
                items.append(Fragment(
                    text: pending,
                    structure: chunk.structure,
                    frame: CGRect(x: x, y: y, width: itemWidth, height: 34)
                ))
                x += itemWidth + gap
                pending = ""
            }

            for (index, word) in words.enumerated() {
                let candidate = pending.isEmpty ? word : pending + " " + word
                let needed = max(Self.width(candidate, font: Self.textFont), labelWidth)
                if needed > limit - x, !pending.isEmpty {
                    // Keep the final two words together instead of orphaning a short tail.
                    var continuation = word
                    if index == words.count - 1, let lastSpace = pending.lastIndex(of: " ") {
                        let tail = String(pending[pending.index(after: lastSpace)...]) + " " + word
                        if Self.width(tail, font: Self.textFont) <= limit {
                            continuation = tail
                            pending = String(pending[..<lastSpace])
                        }
                    }
                    appendFragment()
                    x = 0
                    y += rowHeight
                    pending = continuation
                    continue
                } else if needed > limit - x, x > 0 {
                    x = 0
                    y += rowHeight
                }
                pending = pending.isEmpty ? word : pending + " " + word
            }
            appendFragment()
        }
        return (items, items.isEmpty ? 1 : y + 35)
    }

    // MARK: Private

    private static let textFont = NSFont.systemFont(ofSize: 13)
    private static let labelFont = NSFont.systemFont(ofSize: 9, weight: .medium)

    private static func width(_ text: String, font: NSFont) -> CGFloat {
        // NSTextField reserves a small inset on both sides of its glyphs.
        ceil((text as NSString).size(withAttributes: [.font: font]).width) + 4
    }

    /// Ordinary words stay intact. An identifier wider than the whole panel wraps without shrinking the font.
    private func fittingWords(_ text: String, width: CGFloat) -> [String] {
        text.split(whereSeparator: \.isWhitespace).flatMap { word -> [String] in
            var pieces: [String] = []
            var current = ""
            for character in word {
                let candidate = current + String(character)
                if !current.isEmpty, Self.width(candidate, font: Self.textFont) > width {
                    pieces.append(current)
                    current = ""
                }
                current.append(character)
            }
            if !current.isEmpty { pieces.append(current) }
            return pieces
        }
    }
}

// MARK: - GrammarRole

/// Consistent colors shared by the annotation and legend; labels remain visible in the popover.
enum GrammarRole {
    static func color(for structure: GrammarStructure) -> NSColor {
        if let role = structure.role {
            switch role {
            case .subject: return .systemRed
            case .predicate: return .systemYellow
            case .object: return .systemBlue
            case .adverbial: return .systemGreen
            case .attributive: return .systemPurple
            case .complement, .other: return .systemOrange
            }
        }
        let label = structure.label
        if label.contains("状语") { return .systemGreen }
        if label.contains("定语") { return .systemPurple }
        if label.contains("主语") { return .systemRed }
        if label.contains("宾语") { return .systemBlue }
        if label.contains("谓语") || label.contains("动词") { return .systemYellow }
        return .systemOrange
    }
}
