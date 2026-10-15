// Copyright © 2026 EasyRead contributors. GPL-3.0.
import AppKit
import Combine
import Defaults
import SwiftUI

/// Objective-C bridge for the SwiftUI card inside the existing query window table.
@objc(ReadingAssistantHostView)
@MainActor
final class ReadingAssistantHostView: NSView {
    // MARK: Lifecycle

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let host = NSHostingView(rootView: ReadingAssistantView(model: model))
        host.translatesAutoresizingMaskIntoConstraints = false
        addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.topAnchor.constraint(equalTo: topAnchor), host.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        self.hostingView = host
        model.onLayoutChange = { [weak self] in self?.onHeightChange?() }
        self.visibilityObserver = Defaults.publisher(.enableReadingAI, options: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.onVisibilityChange?() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Internal

    @objc static var isEnabled: Bool { Defaults[.enableReadingAI] }

    @objc var onVisibilityChange: (() -> ())?

    @objc var onHeightChange: (() -> ())?

    @objc var rowHeight: CGFloat { model.rowHeight }

    @objc(updateWithQueryModel:)
    func update(queryModel: QueryModel) { model.update(queryModel: queryModel) }

    @objc(prepareAnalysisWithQueryModel:)
    func prepareAnalysis(queryModel: QueryModel) { model.prepareAnalysis(queryModel: queryModel) }

    @objc
    func cancel() { model.cancel() }

    // MARK: Private

    private var visibilityObserver: AnyCancellable?
    private let model = ReadingAssistantModel()
    private var hostingView: NSHostingView<ReadingAssistantView>?
}
