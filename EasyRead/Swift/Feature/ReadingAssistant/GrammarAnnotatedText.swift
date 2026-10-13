// Copyright © 2026 EasyRead contributors. GPL-3.0.
import AppKit
import EasyReadKit
import SwiftUI

// MARK: - GrammarAnnotatedText

/// Measures independently of SwiftUI's layout probes so the displayed text keeps its final width.
struct GrammarAnnotatedText: NSViewRepresentable {
    // MARK: Internal

    let source: String
    let structures: [GrammarStructure]

    func makeNSView(context: Context) -> GrammarTextContainer { GrammarTextContainer() }

    func updateNSView(_ view: GrammarTextContainer, context: Context) {
        let content = annotatedString()
        guard view.textView.attributedString() != content else { return }
        view.textView.closeExplanation()
        view.textView.textStorage?.setAttributedString(content)
        view.needsLayout = true
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: GrammarTextContainer, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let storage = NSTextStorage(attributedString: nsView.textView.attributedString())
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        layout.ensureLayout(for: container)
        return CGSize(width: width, height: ceil(layout.usedRect(for: container).height) + 2)
    }

    // MARK: Private

    private func annotatedString() -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 6
        let content = NSMutableAttributedString(string: source, attributes: [
            .font: NSFont.systemFont(ofSize: 15), .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph,
        ])
        let matches = structures.compactMap { structure -> (range: NSRange, structure: GrammarStructure)? in
            guard let range = structure.sourceRange(in: source) else { return nil }
            return (range, structure)
        }
        // Keep every explanation for nested clauses; the most specific fragment sets the color.
        let boundaries = Set(matches.flatMap { [$0.range.location, NSMaxRange($0.range)] }).sorted()
        for (start, end) in zip(boundaries, boundaries.dropFirst()) {
            let range = NSRange(location: start, length: end - start)
            let covering = matches.filter { NSIntersectionRange($0.range, range).length == range.length }
                .sorted { $0.range.length < $1.range.length }
            guard let first = covering.first else { continue }
            let explanation = covering.map {
                "\($0.structure.label) · \($0.structure.excerpt)\n\($0.structure.explanation)"
            }.joined(separator: "\n\n")
            content.addAttributes([
                .underlineStyle: NSUnderlineStyle.thick.rawValue,
                .underlineColor: GrammarRole.color(for: first.structure),
                .backgroundColor: GrammarRole.color(for: first.structure).withAlphaComponent(0.13),
                GrammarHoverTextView.explanationAttribute: explanation,
            ], range: range)
        }
        return content
    }
}

// MARK: - GrammarTextContainer

/// The native text view never changes its own frame; SwiftUI owns the enclosing view's height.
final class GrammarTextContainer: NSView {
    // MARK: Lifecycle

    init() {
        super.init(frame: .zero)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = false
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.heightTracksTextView = false
        addSubview(textView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Internal

    override var isFlipped: Bool { true }

    let textView = GrammarHoverTextView()

    override func layout() {
        super.layout()
        textView.frame = bounds
        textView.textContainer?.containerSize = NSSize(width: bounds.width, height: .greatestFiniteMagnitude)
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
