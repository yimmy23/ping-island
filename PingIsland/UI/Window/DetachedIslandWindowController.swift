import AppKit
import Combine
import SwiftUI

final class DetachedIslandWindow: NSWindow {
    var petMouseDownHandler: ((NSEvent) -> Bool)?
    var petMouseDraggedHandler: ((NSEvent) -> Bool)?
    var petMouseUpHandler: ((NSEvent) -> Bool)?
    var petRightMouseDownHandler: ((NSEvent) -> Bool)?
    var petRightMouseUpHandler: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        let handled: Bool = switch event.type {
        case .leftMouseDown:
            petMouseDownHandler?(event) ?? false
        case .leftMouseDragged:
            petMouseDraggedHandler?(event) ?? false
        case .leftMouseUp:
            petMouseUpHandler?(event) ?? false
        case .rightMouseDown:
            petRightMouseDownHandler?(event) ?? false
        case .rightMouseUp:
            petRightMouseUpHandler?(event) ?? false
        default:
            false
        }

        guard !handled else { return }
        super.sendEvent(event)
    }
}

final class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }

    required init(rootView: Content) {
        super.init(rootView: rootView)
        configureTransparency()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureTransparency()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    private func configureTransparency() {
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
    }
}

@MainActor
final class DetachedIslandViewController: NSViewController {
    private let viewModel: NotchViewModel
    private let sessionMonitor: SessionMonitor
    private let interactionModel: DetachedIslandInteractionModel
    private let bubbleViewState: DetachedIslandBubbleViewState
    private let onClose: () -> Void
    var onPetTap: () -> Void = {}
    var onPetDragStarted: () -> Void = {}
    var onPetDragChanged: (CGSize) -> Void = { _ in }
    var onPetDragEnded: () -> Void = {}
    private var hostingView: TransparentHostingView<AppLocalizedRootView<DetachedIslandPanelView>>!

    init(
        viewModel: NotchViewModel,
        sessionMonitor: SessionMonitor,
        interactionModel: DetachedIslandInteractionModel,
        bubbleViewState: DetachedIslandBubbleViewState,
        onClose: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.sessionMonitor = sessionMonitor
        self.interactionModel = interactionModel
        self.bubbleViewState = bubbleViewState
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        hostingView = TransparentHostingView(rootView: makeRootView())

        self.view = hostingView
    }

    private func makeRootView() -> AppLocalizedRootView<DetachedIslandPanelView> {
        AppLocalizedRootView {
            DetachedIslandPanelView(
                viewModel: viewModel,
                sessionMonitor: sessionMonitor,
                interactionModel: interactionModel,
                bubbleViewState: bubbleViewState,
                onClose: onClose,
                onPetTap: onPetTap,
                onPetDragStarted: onPetDragStarted,
                onPetDragChanged: onPetDragChanged,
                onPetDragEnded: onPetDragEnded
            )
        }
    }
}

@MainActor
final class DetachedIslandWindowController: NSWindowController, NSWindowDelegate {
    private static let defaultTrailingInset: CGFloat = 32
    private static let defaultBottomInset: CGFloat = 48

    private let viewModel: NotchViewModel
    private let sessionMonitor: SessionMonitor
    private let onClose: () -> Void
    private let onPetAnchorChanged: (CGPoint) -> Void
    private let interactionModel = DetachedIslandInteractionModel()
    private let bubbleViewState = DetachedIslandBubbleViewState()
    private var manualAttentionTracker = SessionManualAttentionTracker()
    private let detachedViewController: DetachedIslandViewController
    private var lastAppliedLayout: DetachedIslandWindowLayout
    private(set) var highlightedSessionStableID: String?
    private var cancellables = Set<AnyCancellable>()
    private var isWindowSizeUpdateScheduled = false
    private var isApplyingWindowSizeUpdate = false
    private var hasPendingWindowSizeUpdate = false
    private var interactionActivationWorkItem: DispatchWorkItem?
    private var bubbleVisibilityWorkItem: DispatchWorkItem?
    private var outsideClickMonitor: EventMonitor?
    private var floatingDragStartOrigin: CGPoint?
    private var petMouseDownPoint: CGPoint?
    private var petMouseDownScreenPoint: CGPoint?
    private var isPetDragActive = false
    private var isPetSecondaryClickArmed = false

    init(
        viewModel: NotchViewModel,
        sessionMonitor: SessionMonitor,
        onClose: @escaping () -> Void,
        onPetAnchorChanged: @escaping (CGPoint) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.sessionMonitor = sessionMonitor
        self.onClose = onClose
        self.onPetAnchorChanged = onPetAnchorChanged
        self.lastAppliedLayout = Self.windowLayout(
            for: viewModel,
            sessionMonitor: sessionMonitor
        )

        let initialContentSize = lastAppliedLayout.containerSize
        let hostingController = DetachedIslandViewController(
            viewModel: viewModel,
            sessionMonitor: sessionMonitor,
            interactionModel: interactionModel,
            bubbleViewState: bubbleViewState,
            onClose: onClose
        )
        hostingController.loadViewIfNeeded()
        self.detachedViewController = hostingController

        let window = DetachedIslandWindow(
            contentRect: NSRect(origin: .zero, size: initialContentSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        hostingController.view.frame = NSRect(origin: .zero, size: initialContentSize)
        hostingController.view.autoresizingMask = [.width, .height]
        window.contentView = hostingController.view
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        // Keep shadow rendering inside SwiftUI content; window-level shadow on a transparent
        // borderless window produces jagged outlines around the composited alpha edges.
        window.hasShadow = false
        window.isMovableByWindowBackground = false
        window.ignoresMouseEvents = true
        // Keep the detached pet visible above fullscreen apps and across spaces.
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false

        super.init(window: window)

        hostingController.onPetTap = { [weak interactionModel, weak sessionMonitor] in
            interactionModel?.togglePinned(
                canPresentBubble: DetachedIslandContentModel.canPresentBubble(
                    from: sessionMonitor?.instances ?? [],
                    mode: .pinnedList
                )
            )
        }
        hostingController.onPetDragStarted = { [weak self] in
            self?.beginFloatingDrag()
        }
        hostingController.onPetDragChanged = { [weak self] translation in
            self?.updateFloatingDrag(translation: translation)
        }
        hostingController.onPetDragEnded = { [weak self] in
            self?.endFloatingDrag()
        }
        window.petMouseDownHandler = { [weak self] event in
            self?.handlePetMouseDown(event) ?? false
        }
        window.petMouseDraggedHandler = { [weak self] event in
            self?.handlePetMouseDragged(event) ?? false
        }
        window.petMouseUpHandler = { [weak self] event in
            self?.handlePetMouseUp(event) ?? false
        }
        window.petRightMouseDownHandler = { [weak self] event in
            self?.handlePetRightMouseDown(event) ?? false
        }
        window.petRightMouseUpHandler = { [weak self] event in
            self?.handlePetRightMouseUp(event) ?? false
        }

        window.delegate = self
        bindWindowSizeUpdates()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(at origin: CGPoint) {
        guard let window else { return }
        suppressInteraction()
        lastAppliedLayout = Self.windowLayout(
            for: viewModel,
            sessionMonitor: sessionMonitor,
            bubbleState: bubbleViewState.renderedBubbleState,
            bubbleDirection: interactionModel.bubbleDirection
        )
        let initialFrame = NSRect(
            origin: origin,
            size: lastAppliedLayout.containerSize
        )
        window.setFrame(initialFrame, display: false)
        updateBubbleDirectionForCurrentWindow()
        NSApp.activate(ignoringOtherApps: false)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        presentExistingAttentionIfNeeded()
    }

    func present(atPetAnchor petAnchor: CGPoint) {
        guard let window else { return }
        suppressInteraction()
        lastAppliedLayout = Self.windowLayout(
            for: viewModel,
            sessionMonitor: sessionMonitor,
            bubbleState: bubbleViewState.renderedBubbleState,
            bubbleDirection: interactionModel.bubbleDirection
        )
        let origin = Self.windowOrigin(
            preservingPetAnchorAt: petAnchor,
            layout: lastAppliedLayout
        )
        let frame = NSRect(origin: origin, size: lastAppliedLayout.containerSize)
        window.setFrame(frame, display: false)
        updateBubbleDirectionForCurrentWindow()
        NSApp.activate(ignoringOtherApps: false)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        presentExistingAttentionIfNeeded()
    }

    var currentPetAnchor: CGPoint? {
        guard let window else { return nil }
        return Self.petAnchorScreenPoint(for: window.frame, layout: lastAppliedLayout)
    }

    var currentExpandedRoute: IslandExpandedRoute? {
        guard let bubbleContentMode = interactionModel.bubbleContentMode else { return nil }
        return DetachedIslandContentModel.route(
            for: sessionMonitor.instances,
            viewModel: viewModel,
            mode: bubbleContentMode
        )
    }

    func activateInteraction() {
        interactionActivationWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, let window = self.window else { return }
            self.interactionActivationWorkItem = nil
            window.ignoresMouseEvents = false
        }

        interactionActivationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    func updateDragPosition(
        cursorLocation: CGPoint,
        cursorWindowOffset: CGPoint
    ) {
        guard let window else { return }
        suppressInteraction()
        interactionModel.resetForDragSuppression()
        hideBubbleRenderingImmediately()
        let contentSize = window.frame.size
        let origin = Self.windowOrigin(
            for: cursorLocation,
            cursorWindowOffset: cursorWindowOffset,
            windowSize: contentSize
        )
        window.setFrameOrigin(origin)
        updateBubbleDirectionForCurrentWindow()
    }

    func beginFloatingDrag() {
        guard floatingDragStartOrigin == nil else { return }
        cancelInteractionActivation()
        interactionModel.resetForDragSuppression()
        hideBubbleRenderingImmediately()
        floatingDragStartOrigin = window?.frame.origin
    }

    func updateFloatingDrag(translation: CGSize) {
        guard let window else { return }

        if floatingDragStartOrigin == nil {
            beginFloatingDrag()
        }

        guard let startOrigin = floatingDragStartOrigin else { return }
        let origin = CGPoint(
            x: startOrigin.x + translation.width,
            y: startOrigin.y - translation.height
        )
        window.setFrameOrigin(origin)
        updateBubbleDirectionForCurrentWindow()
    }

    func endFloatingDrag() {
        floatingDragStartOrigin = nil
        if let currentPetAnchor {
            onPetAnchorChanged(currentPetAnchor)
        }
        activateInteraction()
    }

    func handlePetSecondaryClick() {
        SettingsWindowController.shared.present()
    }

    func presentHoverBubbleForTesting() {
        let canPresentBubble = DetachedIslandContentModel.canPresentBubble(
            from: sessionMonitor.instances,
            mode: .hoverPreview
        )
        interactionModel.presentHoverPreview(canPresentBubble: canPresentBubble)
        syncBubblePresentation(to: interactionModel.bubbleState)
        syncOutsideClickMonitor()
        reconcileHighlightedSessionState()
    }

    func togglePinnedBubbleForTesting() {
        let canPresentBubble = DetachedIslandContentModel.canPresentBubble(
            from: sessionMonitor.instances,
            mode: .pinnedList
        )
        interactionModel.togglePinned(canPresentBubble: canPresentBubble)
        syncBubblePresentation(to: interactionModel.bubbleState)
        syncOutsideClickMonitor()
        reconcileHighlightedSessionState()
    }

    func hideBubbleForTesting() {
        interactionModel.hidePinnedBubble()
        syncBubblePresentation(to: interactionModel.bubbleState)
        syncOutsideClickMonitor()
        reconcileHighlightedSessionState()
    }

    var renderedBubbleStateForTesting: DetachedIslandBubbleState {
        bubbleViewState.renderedBubbleState
    }

    var isBubbleVisibleForTesting: Bool {
        bubbleViewState.isBubbleVisible
    }

    func applySessionSnapshotForTesting(_ sessions: [SessionState]) {
        sessionMonitor.instances = sessions
        handleManualAttentionChange()
        reconcileHighlightedSessionState()
    }

    func dismiss() {
        interactionActivationWorkItem?.cancel()
        interactionActivationWorkItem = nil
        bubbleVisibilityWorkItem?.cancel()
        bubbleVisibilityWorkItem = nil
        outsideClickMonitor?.stop()
        outsideClickMonitor = nil
        floatingDragStartOrigin = nil
        window?.orderOut(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        onClose()
        return false
    }

    private func bindWindowSizeUpdates() {
        viewModel.$contentType
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleWindowSizeUpdate()
            }
            .store(in: &cancellables)

        sessionMonitor.$instances
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleManualAttentionChange()
                self?.reconcileHighlightedSessionState()
                self?.reconcileBubbleStateWithAvailableContent()
                self?.scheduleWindowSizeUpdate()
            }
            .store(in: &cancellables)

        interactionModel.$bubbleState
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bubbleState in
                self?.syncBubblePresentation(to: bubbleState)
                self?.syncOutsideClickMonitor()
                self?.reconcileHighlightedSessionState()
            }
            .store(in: &cancellables)

        interactionModel.$bubbleDirection
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleWindowSizeUpdate()
            }
            .store(in: &cancellables)

        AppSettings.shared.$notchDisplayMode
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reconcileHighlightedSessionState()
                self?.reconcileBubbleStateWithAvailableContent()
                self?.scheduleWindowSizeUpdate()
            }
            .store(in: &cancellables)
    }

    private func scheduleWindowSizeUpdate() {
        hasPendingWindowSizeUpdate = true
        guard !isWindowSizeUpdateScheduled else { return }
        isWindowSizeUpdateScheduled = true

        DispatchQueue.main.async { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isWindowSizeUpdateScheduled = false
                self.applyPendingWindowSizeUpdate()
            }
        }
    }

    private func applyPendingWindowSizeUpdate() {
        guard let window else { return }
        guard hasPendingWindowSizeUpdate else { return }

        if isApplyingWindowSizeUpdate {
            scheduleWindowSizeUpdate()
            return
        }

        hasPendingWindowSizeUpdate = false
        let currentFrame = window.frame
        let petAnchorScreen = Self.petAnchorScreenPoint(
            for: currentFrame,
            layout: lastAppliedLayout
        )
        let newLayout = Self.windowLayout(
            for: viewModel,
            sessionMonitor: sessionMonitor,
            bubbleState: bubbleViewState.renderedBubbleState,
            bubbleDirection: interactionModel.bubbleDirection
        )
        let newOrigin = Self.windowOrigin(
            preservingPetAnchorAt: petAnchorScreen,
            layout: newLayout
        )
        let targetFrame = NSRect(origin: newOrigin, size: newLayout.containerSize)

        guard !Self.framesMatch(currentFrame, targetFrame) else {
            lastAppliedLayout = newLayout
            return
        }

        isApplyingWindowSizeUpdate = true
        window.setFrame(targetFrame, display: false, animate: false)
        isApplyingWindowSizeUpdate = false
        lastAppliedLayout = newLayout

        if hasPendingWindowSizeUpdate {
            scheduleWindowSizeUpdate()
        }
    }

    static func windowLayout(
        for viewModel: NotchViewModel,
        sessionMonitor: SessionMonitor,
        bubbleState: DetachedIslandBubbleState = .hidden,
        bubbleDirection: DetachedIslandBubbleDirection = .right
    ) -> DetachedIslandWindowLayout {
        DetachedIslandContentModel.layout(
            for: sessionMonitor.instances,
            viewModel: viewModel,
            bubbleState: bubbleState,
            bubbleDirection: bubbleDirection
        )
    }

    static func windowSize(
        for viewModel: NotchViewModel,
        sessionMonitor: SessionMonitor,
        bubbleState: DetachedIslandBubbleState = .hidden,
        bubbleDirection: DetachedIslandBubbleDirection = .right
    ) -> CGSize {
        windowLayout(
            for: viewModel,
            sessionMonitor: sessionMonitor,
            bubbleState: bubbleState,
            bubbleDirection: bubbleDirection
        ).containerSize
    }

    static func windowOrigin(
        for cursorLocation: CGPoint,
        cursorWindowOffset: CGPoint,
        windowSize: CGSize
    ) -> CGPoint {
        CGPoint(
            x: cursorLocation.x - cursorWindowOffset.x,
            y: cursorLocation.y - min(cursorWindowOffset.y, windowSize.height)
        )
    }

    static func defaultPetAnchor(
        in visibleFrame: CGRect,
        alignedTo activeWindowFrame: CGRect? = nil
    ) -> CGPoint {
        let halfPet = DetachedIslandPanelMetrics.petHitFrame / 2
        let referenceFrame = activeWindowFrame?
            .intersection(visibleFrame)
            .nilIfEmpty ?? visibleFrame

        return CGPoint(
            x: referenceFrame.maxX - defaultTrailingInset - halfPet,
            y: referenceFrame.minY + defaultBottomInset + halfPet
        )
    }

    static func clampedPetAnchor(
        _ petAnchor: CGPoint,
        in visibleFrame: CGRect
    ) -> CGPoint {
        let halfPet = DetachedIslandPanelMetrics.petHitFrame / 2
        let minX = visibleFrame.minX + halfPet
        let maxX = visibleFrame.maxX - halfPet
        let minY = visibleFrame.minY + halfPet
        let maxY = visibleFrame.maxY - halfPet

        let resolvedX = minX <= maxX
            ? min(max(petAnchor.x, minX), maxX)
            : visibleFrame.midX
        let resolvedY = minY <= maxY
            ? min(max(petAnchor.y, minY), maxY)
            : visibleFrame.midY

        return CGPoint(x: resolvedX, y: resolvedY)
    }

    static func floatingPetAnchor(
        from petAnchor: CGPoint,
        in visibleFrame: CGRect
    ) -> FloatingPetAnchor {
        let clampedAnchor = clampedPetAnchor(petAnchor, in: visibleFrame)
        let xRatio = visibleFrame.width > 0
            ? (clampedAnchor.x - visibleFrame.minX) / visibleFrame.width
            : 0.5
        let yRatio = visibleFrame.height > 0
            ? (clampedAnchor.y - visibleFrame.minY) / visibleFrame.height
            : 0.5

        return FloatingPetAnchor(
            xRatio: Double(xRatio),
            yRatio: Double(yRatio)
        )
    }

    static func petAnchor(
        from storedAnchor: FloatingPetAnchor?,
        in visibleFrame: CGRect,
        defaultWindowFrame: CGRect? = nil
    ) -> CGPoint {
        guard let storedAnchor else {
            return clampedPetAnchor(
                defaultPetAnchor(
                    in: visibleFrame,
                    alignedTo: defaultWindowFrame
                ),
                in: visibleFrame
            )
        }

        let rawAnchor = CGPoint(
            x: visibleFrame.minX + (CGFloat(storedAnchor.xRatio) * visibleFrame.width),
            y: visibleFrame.minY + (CGFloat(storedAnchor.yRatio) * visibleFrame.height)
        )
        return clampedPetAnchor(rawAnchor, in: visibleFrame)
    }

    static func petAnchorScreenPoint(
        for frame: NSRect,
        layout: DetachedIslandWindowLayout
    ) -> CGPoint {
        CGPoint(
            x: frame.minX + layout.petAnchorInWindow.x,
            y: frame.maxY - layout.petAnchorInWindow.y
        )
    }

    static func windowOrigin(
        preservingPetAnchorAt petAnchorScreen: CGPoint,
        layout: DetachedIslandWindowLayout
    ) -> CGPoint {
        CGPoint(
            x: petAnchorScreen.x - layout.petAnchorInWindow.x,
            y: petAnchorScreen.y - (layout.containerSize.height - layout.petAnchorInWindow.y)
        )
    }

    static func petInteractionFrame(
        for layout: DetachedIslandWindowLayout
    ) -> CGRect {
        CGRect(
            x: layout.petFrame.minX,
            y: layout.containerSize.height - layout.petFrame.maxY,
            width: layout.petFrame.width,
            height: layout.petFrame.height
        )
    }

    static func floatingDragTranslation(
        from start: CGPoint,
        to current: CGPoint
    ) -> CGSize {
        CGSize(
            width: current.x - start.x,
            height: start.y - current.y
        )
    }

    private static func framesMatch(_ lhs: NSRect, _ rhs: NSRect) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) < 0.5 &&
        abs(lhs.origin.y - rhs.origin.y) < 0.5 &&
        abs(lhs.size.width - rhs.size.width) < 0.5 &&
        abs(lhs.size.height - rhs.size.height) < 0.5
    }

    private func suppressInteraction() {
        cancelInteractionActivation()
        window?.ignoresMouseEvents = true
    }

    private func cancelInteractionActivation() {
        interactionActivationWorkItem?.cancel()
        interactionActivationWorkItem = nil
    }

    private func handlePetMouseDown(_ event: NSEvent) -> Bool {
        let point = event.locationInWindow
        guard isPointInsidePet(point) else { return false }
        petMouseDownPoint = point
        petMouseDownScreenPoint = currentScreenPoint(for: event)
        isPetDragActive = false
        return true
    }

    private func handlePetMouseDragged(_ event: NSEvent) -> Bool {
        guard let petMouseDownPoint,
              let petMouseDownScreenPoint else { return false }

        let currentScreenPoint = currentScreenPoint(for: event)
        let translation = Self.floatingDragTranslation(
            from: petMouseDownScreenPoint,
            to: currentScreenPoint
        )

        if !isPetDragActive,
           hypot(translation.width, translation.height) >= 3 {
            isPetDragActive = true
            beginFloatingDrag()
        }

        guard isPetDragActive else { return true }
        updateFloatingDrag(translation: translation)
        return true
    }

    private func handlePetMouseUp(_ event: NSEvent) -> Bool {
        defer {
            petMouseDownPoint = nil
            petMouseDownScreenPoint = nil
            isPetDragActive = false
        }

        guard petMouseDownPoint != nil else { return false }

        if isPetDragActive {
            endFloatingDrag()
            return true
        }

        guard isPointInsidePet(event.locationInWindow) else { return true }
        detachedViewController.onPetTap()
        return true
    }

    private func handlePetRightMouseDown(_ event: NSEvent) -> Bool {
        guard isPointInsidePet(event.locationInWindow) else {
            isPetSecondaryClickArmed = false
            return false
        }

        isPetSecondaryClickArmed = true
        return true
    }

    private func handlePetRightMouseUp(_ event: NSEvent) -> Bool {
        defer { isPetSecondaryClickArmed = false }
        guard isPetSecondaryClickArmed else { return false }
        guard isPointInsidePet(event.locationInWindow) else { return true }

        handlePetSecondaryClick()
        return true
    }

    private func isPointInsidePet(_ point: CGPoint) -> Bool {
        Self.petInteractionFrame(for: lastAppliedLayout).contains(point)
    }

    private func currentScreenPoint(for event: NSEvent) -> CGPoint {
        guard let window else { return .zero }
        return window.convertPoint(toScreen: event.locationInWindow)
    }

    private func syncBubblePresentation(to targetState: DetachedIslandBubbleState) {
        bubbleVisibilityWorkItem?.cancel()
        bubbleVisibilityWorkItem = nil

        switch targetState {
        case .hidden:
            hideBubblePresentation()
        case .hoverPreview, .pinned:
            showBubblePresentation(targetState)
        }
    }

    private func showBubblePresentation(_ targetState: DetachedIslandBubbleState) {
        bubbleViewState.prepareLayout(for: targetState)
        applyWindowSizeUpdateImmediately()
        withAnimation(.easeInOut(duration: bubbleViewState.bubbleFadeDuration)) {
            bubbleViewState.setBubbleVisible(true)
        }
    }

    private func hideBubbleRenderingImmediately() {
        bubbleVisibilityWorkItem?.cancel()
        bubbleVisibilityWorkItem = nil
        bubbleViewState.setBubbleVisible(false)
        bubbleViewState.prepareLayout(for: .hidden)
        applyWindowSizeUpdateImmediately()
    }

    private func hideBubblePresentation() {
        let collapseBubble = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.bubbleVisibilityWorkItem = nil
            guard self.interactionModel.bubbleState == .hidden else { return }
            self.bubbleViewState.prepareLayout(for: .hidden)
            self.applyWindowSizeUpdateImmediately()
        }

        withAnimation(.easeInOut(duration: bubbleViewState.bubbleFadeDuration)) {
            bubbleViewState.setBubbleVisible(false)
        }

        bubbleVisibilityWorkItem = collapseBubble
        DispatchQueue.main.asyncAfter(
            deadline: .now() + bubbleViewState.bubbleFadeDuration,
            execute: collapseBubble
        )
    }

    private func applyWindowSizeUpdateImmediately() {
        hasPendingWindowSizeUpdate = true
        applyPendingWindowSizeUpdate()
    }

    private func presentExistingAttentionIfNeeded() {
        guard interactionModel.bubbleState != .pinned else { return }
        guard DetachedIslandContentModel.canPresentBubble(
            from: sessionMonitor.instances,
            mode: .hoverPreview
        ) else { return }
        guard IslandExpandedRouteResolver.highestPriorityAttentionSession(
            from: sessionMonitor.instances
        ) != nil else { return }

        interactionModel.presentHoverPreview(canPresentBubble: true)
    }

    private func handleManualAttentionChange() {
        guard let targetSession = manualAttentionTracker.consumeNewAttentionSession(
            from: sessionMonitor.instances
        ) else {
            return
        }

        if interactionModel.bubbleState == .pinned {
            updateHighlightedSessionStableID(targetSession.stableId)
            return
        }

        updateHighlightedSessionStableID(nil)
        interactionModel.presentHoverPreview(
            canPresentBubble: DetachedIslandContentModel.canPresentBubble(
                from: sessionMonitor.instances,
                mode: .hoverPreview
            )
        )
    }

    private func reconcileHighlightedSessionState() {
        guard interactionModel.bubbleState == .pinned else {
            updateHighlightedSessionStableID(nil)
            return
        }

        guard let highlightedSessionStableID else { return }

        guard let session = sessionMonitor.instances.first(where: {
            $0.stableId == highlightedSessionStableID
        }), session.needsManualAttention else {
            updateHighlightedSessionStableID(nil)
            return
        }
    }

    private func updateHighlightedSessionStableID(_ stableID: String?) {
        guard highlightedSessionStableID != stableID else { return }
        highlightedSessionStableID = stableID
        bubbleViewState.highlightedSessionStableID = stableID
    }

    private func reconcileBubbleStateWithAvailableContent() {
        switch interactionModel.bubbleState {
        case .hidden:
            return
        case .hoverPreview:
            guard DetachedIslandContentModel.canPresentBubble(
                from: sessionMonitor.instances,
                mode: .hoverPreview
            ) else {
                interactionModel.hidePinnedBubble()
                return
            }
        case .pinned:
            guard DetachedIslandContentModel.canPresentBubble(
                from: sessionMonitor.instances,
                mode: .pinnedList
            ) else {
                interactionModel.hidePinnedBubble()
                return
            }
        }
    }

    private func syncOutsideClickMonitor() {
        let shouldMonitorOutsideClicks = interactionModel.bubbleState == .pinned

        if shouldMonitorOutsideClicks {
            guard outsideClickMonitor == nil else { return }
            let monitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                self?.handlePotentialOutsideClick(event)
            }
            monitor.start()
            outsideClickMonitor = monitor
        } else {
            outsideClickMonitor?.stop()
            outsideClickMonitor = nil
        }
    }

    private func handlePotentialOutsideClick(_ event: NSEvent) {
        guard interactionModel.bubbleState == .pinned,
              let window else { return }

        let eventLocation = MouseEventReplay.repostLocation(
            for: event,
            fallbackScreenLocation: NSEvent.mouseLocation
        )

        guard !window.frame.contains(eventLocation) else { return }
        interactionModel.hidePinnedBubble()
    }

    private func updateBubbleDirectionForCurrentWindow() {
        guard let window else { return }
        let petOnlyLayout = Self.windowLayout(
            for: viewModel,
            sessionMonitor: sessionMonitor,
            bubbleState: bubbleViewState.renderedBubbleState,
            bubbleDirection: interactionModel.bubbleDirection
        )
        let petCenterX = window.frame.minX + petOnlyLayout.petAnchorInWindow.x
        let direction = DetachedIslandContentModel.bubbleDirection(
            for: petCenterX,
            screenMidX: viewModel.screenRect.midX
        )
        interactionModel.setBubbleDirection(direction)
    }
}

private extension CGRect {
    var nilIfEmpty: CGRect? {
        guard !isNull, !isEmpty, width > 0, height > 0 else {
            return nil
        }

        return self
    }
}
