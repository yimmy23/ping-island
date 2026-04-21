import AppKit
import Combine
import SwiftUI

final class DetachedIslandWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class DetachedIslandViewController: NSViewController {
    private let viewModel: NotchViewModel
    private let sessionMonitor: SessionMonitor
    private let onClose: () -> Void
    private var hostingView: NSHostingView<AppLocalizedRootView<DetachedIslandPanelView>>!

    init(
        viewModel: NotchViewModel,
        sessionMonitor: SessionMonitor,
        onClose: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.sessionMonitor = sessionMonitor
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        hostingView = NSHostingView(
            rootView: AppLocalizedRootView {
                DetachedIslandPanelView(
                    viewModel: viewModel,
                    sessionMonitor: sessionMonitor,
                    onClose: onClose
                )
            }
        )

        self.view = hostingView
    }
}

@MainActor
final class DetachedIslandWindowController: NSWindowController, NSWindowDelegate {
    private let viewModel: NotchViewModel
    private let sessionMonitor: SessionMonitor
    private let onClose: () -> Void
    private let detachedViewController: DetachedIslandViewController
    private var cancellables = Set<AnyCancellable>()
    private var isWindowSizeUpdateScheduled = false
    private var isApplyingWindowSizeUpdate = false
    private var hasPendingWindowSizeUpdate = false
    private var interactionActivationWorkItem: DispatchWorkItem?

    init(
        viewModel: NotchViewModel,
        sessionMonitor: SessionMonitor,
        onClose: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.sessionMonitor = sessionMonitor
        self.onClose = onClose

        let initialContentSize = Self.windowSize(for: viewModel)
        let hostingController = DetachedIslandViewController(
            viewModel: viewModel,
            sessionMonitor: sessionMonitor,
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
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false

        super.init(window: window)

        window.delegate = self
        bindWindowSizeUpdates()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(at origin: CGPoint) {
        guard let window else { return }
        suppressInteraction()
        let initialFrame = NSRect(origin: origin, size: Self.windowSize(for: viewModel))
        window.setFrame(initialFrame, display: false)
        NSApp.activate(ignoringOtherApps: false)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
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
        let contentSize = window.frame.size
        let origin = Self.windowOrigin(
            for: cursorLocation,
            cursorWindowOffset: cursorWindowOffset,
            windowSize: contentSize
        )
        window.setFrameOrigin(origin)
    }

    func dismiss() {
        interactionActivationWorkItem?.cancel()
        interactionActivationWorkItem = nil
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

        viewModel.$detachedDisplayMode
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
        let topLeft = CGPoint(x: currentFrame.minX, y: currentFrame.maxY)
        let newSize = Self.windowSize(for: viewModel)
        let newOrigin = CGPoint(x: topLeft.x, y: topLeft.y - newSize.height)
        let targetFrame = NSRect(origin: newOrigin, size: newSize)

        guard !Self.framesMatch(currentFrame, targetFrame) else { return }

        isApplyingWindowSizeUpdate = true
        window.setFrame(targetFrame, display: false, animate: false)
        isApplyingWindowSizeUpdate = false

        if hasPendingWindowSizeUpdate {
            scheduleWindowSizeUpdate()
        }
    }

    static func windowSize(for viewModel: NotchViewModel) -> CGSize {
        switch viewModel.detachedDisplayMode {
        case .compact:
            return viewModel.detachedSize
        case .hoverExpanded:
            return CGSize(
                width: viewModel.detachedSize.width + (DetachedIslandPanelMetrics.outerHorizontalInset * 2),
                height: viewModel.detachedSize.height + DetachedIslandPanelMetrics.bottomInset
            )
        }
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

    private static func framesMatch(_ lhs: NSRect, _ rhs: NSRect) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) < 0.5 &&
        abs(lhs.origin.y - rhs.origin.y) < 0.5 &&
        abs(lhs.size.width - rhs.size.width) < 0.5 &&
        abs(lhs.size.height - rhs.size.height) < 0.5
    }

    private func suppressInteraction() {
        interactionActivationWorkItem?.cancel()
        interactionActivationWorkItem = nil
        window?.ignoresMouseEvents = true
    }
}
