// Copyright © 2026 EasyRead contributors. GPL-3.0.
import AppKit
import Combine
import Defaults
import SwiftUI

/// Hosts the selection panel and the service views for the active auxiliary tab.
@objc(ReadingAssistantHostView)
@MainActor
final class ReadingAssistantHostView: NSView {
    // MARK: Lifecycle

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let root = SelectionPanelView(model: model, state: state, onTabChange: { [weak self] in
            self?.onServiceTabChange?()
        }, onContentHeight: { [weak self] height in
            self?.applyContentHeight(height)
        })
        let host = NSHostingView(rootView: root)
        host.translatesAutoresizingMaskIntoConstraints = false
        host.sizingOptions = [.intrinsicContentSize]
        serviceContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(host)
        addSubview(serviceContainer)
        self.hostingHeightConstraint = host.heightAnchor.constraint(equalToConstant: 1)
        self.serviceHeightConstraint = serviceContainer.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.topAnchor.constraint(equalTo: topAnchor),
            hostingHeightConstraint,
            serviceContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            serviceContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            serviceContainer.topAnchor.constraint(equalTo: host.bottomAnchor),
            serviceHeightConstraint,
        ])
        self.hostingView = host
        // The hosting view is not pinned to the bottom. A tall table row must not stretch the panel.
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
    @objc var onServiceTabChange: (() -> ())?

    @objc var selectLanguage: ((String, Bool) -> ())? {
        get { state.selectLanguage }
        set { state.selectLanguage = newValue }
    }

    @objc var swapLanguages: (() -> ())? {
        get { state.swapLanguages }
        set { state.swapLanguages = newValue }
    }

    @objc var playTranslation: ((String) -> ())? {
        get { state.playTranslation }
        set { state.playTranslation = newValue }
    }

    /// SwiftUI content plus the service views of the selected tab. Never a fixed card height.
    @objc var rowHeight: CGFloat { max(hostingHeight + serviceSectionHeight, 1) }

    override func layout() {
        super.layout()
        layoutServiceViews()
    }

    @objc(updateWithQueryModel:)
    func update(queryModel: QueryModel) {
        let queryText = queryModel.queryText
        if state.queryText != queryText {
            let isWord = !queryText.isEmpty && queryText.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
            state.queryText = queryText
            state.resetChrome(isWord: isWord)
        }
        state.userSourceLanguage = queryModel.userSourceLanguage
        state.userTargetLanguage = queryModel.userTargetLanguage
        state.sourceLanguage = queryModel.queryFromLanguage
        state.targetLanguage = queryModel.queryTargetLanguage
        model.update(queryModel: queryModel)
    }

    @objc(prepareAnalysisWithQueryModel:)
    func prepareAnalysis(queryModel: QueryModel) {
        update(queryModel: queryModel)
        model.prepareAnalysis(queryModel: queryModel)
    }

    @objc
    func cancel() { model.cancel() }

    @objc(updateServices:)
    func updateServices(_ services: [QueryService]) {
        state.services = services
    }

    @objc(servicesForCurrentTab:)
    func servicesForCurrentTab(_ services: [QueryService]) -> [QueryService] {
        switch state.tab {
        case .sentence:
            []
        case .dictionary:
            services.filter(SelectionPanelState.isDictionaryService)
        case .other:
            services.filter { !SelectionPanelState.isDictionaryService($0) }
        }
    }

    /// Shows the already created service views for the active tab. Passing an empty list hides them.
    @objc(displayServiceViews:heights:)
    func displayServiceViews(_ views: [NSView], heights: [NSNumber]) {
        let nextHeights = heights.map { CGFloat(truncating: $0) }
        serviceViews = views
        serviceHeights = nextHeights
        let visible = Set(views.map(ObjectIdentifier.init))
        for view in serviceContainer.subviews where !visible.contains(ObjectIdentifier(view)) {
            // Keep dictionary web views attached; removing them makes WebKit drop the rendered page.
            view.isHidden = true
        }
        for view in views {
            if view.superview !== serviceContainer {
                serviceContainer.addSubview(view)
            }
            view.isHidden = false
        }
        if state.visibleServiceCount != views.count {
            state.visibleServiceCount = views.count
        }
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    // MARK: Private

    private final class TopDownView: NSView {
        override var isFlipped: Bool { true }
    }

    private var visibilityObserver: AnyCancellable?
    private let model = ReadingAssistantModel()
    private let state = SelectionPanelState()
    private var hostingView: NSHostingView<SelectionPanelView>?
    private let serviceContainer = TopDownView()
    private var hostingHeightConstraint = NSLayoutConstraint()
    private var serviceHeightConstraint = NSLayoutConstraint()
    private var hostingHeight: CGFloat = 1
    private var serviceSectionHeight: CGFloat = 0
    private var reportedHeight: CGFloat = 0
    private var serviceViews: [NSView] = []
    private var serviceHeights: [CGFloat] = []

    private func applyContentHeight(_ height: CGFloat) {
        let next = ceil(height)
        guard next > 1, abs(next - hostingHeight) > 1 else { return }
        hostingHeight = next
        hostingHeightConstraint.constant = next
        publishHeightIfNeeded()
    }

    private func layoutServiceViews() {
        let width = serviceContainer.bounds.width
        guard width > 1 else { return }
        let inset: CGFloat = 8
        let contentWidth = max(width - inset * 2, 1)
        var y: CGFloat = 0
        for index in serviceViews.indices {
            let itemHeight = max(index < serviceHeights.count ? serviceHeights[index] : 1, 1)
            serviceViews[index].frame = NSRect(x: inset, y: y, width: contentWidth, height: itemHeight)
            y += itemHeight
            if index < serviceViews.count - 1 { y += 8 }
        }
        if y > 0 { y += 4 }
        serviceSectionHeight = y
        if abs(serviceHeightConstraint.constant - y) > 0.5 {
            serviceHeightConstraint.constant = y
        }
        publishHeightIfNeeded()
    }

    private func publishHeightIfNeeded() {
        let total = rowHeight
        guard abs(total - reportedHeight) > 1 else { return }
        reportedHeight = total
        onHeightChange?()
    }
}
