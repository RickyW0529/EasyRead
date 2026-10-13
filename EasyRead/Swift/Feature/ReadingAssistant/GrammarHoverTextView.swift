// Copyright © 2026 EasyRead contributors. GPL-3.0.
import AppKit
import SwiftUI

// MARK: - GrammarHoverTextView

/// Shows an immediate, wrapped explanation instead of relying on NSTextView's delayed tooltips.
final class GrammarHoverTextView: NSTextView {
    // MARK: Internal

    static let explanationAttribute = NSAttributedString.Key("EasyReadGrammarExplanation")

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTracking { removeTrackingArea(hoverTracking) }
        let tracking = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
            owner: self
        )
        addTrackingArea(tracking)
        hoverTracking = tracking
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        showExplanation(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        showExplanation(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) { scheduleClose() }

    override func scrollWheel(with event: NSEvent) {
        closeExplanation()
        super.scrollWheel(with: event)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { closeExplanation() }
    }

    func closeExplanation() {
        pendingClose?.cancel()
        pendingClose = nil
        explanationPopover?.close()
        explanationPopover = nil
        activeRange = nil
    }

    // MARK: Private

    private var hoverTracking: NSTrackingArea?
    private var explanationPopover: NSPopover?
    private var activeRange: NSRange?
    private var pendingClose: DispatchWorkItem?

    private func scheduleClose() {
        pendingClose?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let mouse = NSEvent.mouseLocation
            if explanationPopover?.contentViewController?.view.window?.frame.contains(mouse) == true { return }
            if let window {
                let point = convert(window.convertPoint(fromScreen: mouse), from: nil)
                if visibleRect.contains(point), explanationHit(at: point)?.range == activeRange { return }
            }
            closeExplanation()
        }
        pendingClose = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    private func explanationHit(at point: CGPoint) -> (range: NSRange, rect: NSRect, text: String, color: NSColor)? {
        guard let layout = layoutManager, let container = textContainer, let storage = textStorage,
              storage.length > 0 else { return nil }
        let glyph = layout.glyphIndex(for: point, in: container)
        guard glyph < layout.numberOfGlyphs else { return nil }
        let glyphRect = layout.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container)
        guard glyphRect.insetBy(dx: -2, dy: -3).contains(point) else { return nil }
        let character = layout.characterIndexForGlyph(at: glyph)
        var range = NSRange()
        guard let explanation = storage.attribute(
            Self.explanationAttribute,
            at: character,
            effectiveRange: &range
        ) as? String
        else { return nil }
        let color = storage.attribute(.underlineColor, at: character, effectiveRange: nil) as? NSColor ?? .labelColor
        return (range, glyphRect, explanation, color)
    }

    private func showExplanation(at point: CGPoint) {
        guard let hit = explanationHit(at: point) else { scheduleClose(); return }
        pendingClose?.cancel()
        guard activeRange != hit.range || explanationPopover?.isShown != true else { return }
        closeExplanation()
        activeRange = hit.range
        let content = GrammarExplanationPopover(explanation: hit.text, color: hit.color) { [weak self] hovering in
            if hovering { self?.pendingClose?.cancel() } else { self?.scheduleClose() }
        }
        let controller = NSHostingController(rootView: content)
        let popover = NSPopover()
        popover.animates = false
        popover.behavior = .transient
        popover.contentViewController = controller
        popover.contentSize = controller.view.fittingSize
        explanationPopover = popover
        popover.show(relativeTo: hit.rect, of: self, preferredEdge: .maxY)
    }
}

// MARK: - GrammarExplanationPopover

private struct GrammarExplanationPopover: View {
    let explanation: String
    let color: NSColor
    let onHover: (Bool) -> ()

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(Color(nsColor: color)).frame(width: 3)
                Text(verbatim: explanation).font(.system(size: 13)).lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
        }
        .frame(width: 340, height: min(260, max(110, CGFloat(explanation.count / 24 + 2) * 22)))
        .onHover(perform: onHover)
    }
}
