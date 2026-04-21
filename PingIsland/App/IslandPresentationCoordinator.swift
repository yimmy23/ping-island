import AppKit

@MainActor
final class IslandPresentationCoordinator {
    let sessionMonitor = SessionMonitor()
    let viewModel: NotchViewModel

    private var screen: NSScreen
    private var dockedWindowController: NotchWindowController?
    private var detachedWindowController: DetachedIslandWindowController?
    private var activeDetachmentPayload: IslandDetachmentPayload?

    init(screen: NSScreen) {
        self.screen = screen
        self.viewModel = Self.makeViewModel(for: screen)
        bindViewModel()
        recreateDockedWindow(performBootAnimation: true)
    }

    func updateScreen(_ screen: NSScreen) {
        self.screen = screen

        if viewModel.presentationMode == .detached {
            dockedWindowController?.window?.orderOut(nil)
            dockedWindowController = nil
            return
        }

        recreateDockedWindow(performBootAnimation: false)
    }

    func beginDetachment(from request: IslandDetachmentRequest) {
        let resolvedContent = IslandDetachedContentResolver.resolve(
            status: viewModel.status,
            openReason: viewModel.openReason,
            contentType: viewModel.contentType,
            sessions: sessionMonitor.instances
        )

        viewModel.beginDetachedPresentation(contentType: resolvedContent)

        let windowSize = DetachedIslandWindowController.windowSize(for: viewModel)
        let cursorWindowOffset = CGPoint(
            x: windowSize.width / 2,
            y: max(viewModel.closedHeight + 18, windowSize.height - 24)
        )

        let payload = IslandDetachmentPayload(
            contentType: resolvedContent,
            dragStartScreenLocation: request.dragStartScreenLocation,
            initialCursorScreenLocation: request.currentScreenLocation,
            cursorWindowOffset: cursorWindowOffset
        )
        activeDetachmentPayload = payload

        dockedWindowController?.window?.orderOut(nil)

        let detachedWindowController = DetachedIslandWindowController(
            viewModel: viewModel,
            sessionMonitor: sessionMonitor,
            onClose: { [weak self] in
                self?.redockDetached()
            }
        )
        self.detachedWindowController = detachedWindowController

        let origin = DetachedIslandWindowController.windowOrigin(
            for: payload.initialCursorScreenLocation,
            cursorWindowOffset: payload.cursorWindowOffset,
            windowSize: windowSize
        )
        detachedWindowController.present(at: origin)
    }

    func updateDetachment(cursorLocation: CGPoint) {
        guard let payload = activeDetachmentPayload else { return }
        detachedWindowController?.updateDragPosition(
            cursorLocation: cursorLocation,
            cursorWindowOffset: payload.cursorWindowOffset
        )
    }

    func finishDetachment(cursorLocation: CGPoint?) {
        if let cursorLocation {
            updateDetachment(cursorLocation: cursorLocation)
        }

        DispatchQueue.main.async { [weak self] in
            self?.detachedWindowController?.activateInteraction()
        }
    }

    func redockDetached() {
        detachedWindowController?.dismiss()
        detachedWindowController = nil
        activeDetachmentPayload = nil

        viewModel.redockAfterDetached()
        recreateDockedWindow(performBootAnimation: false)
    }

    private func bindViewModel() {
        viewModel.onDetachmentRequested = { [weak self] request in
            self?.beginDetachment(from: request)
        }
        viewModel.onDetachmentUpdated = { [weak self] location in
            self?.updateDetachment(cursorLocation: location)
        }
        viewModel.onDetachmentFinished = { [weak self] location in
            self?.finishDetachment(cursorLocation: location)
        }
    }

    private func recreateDockedWindow(performBootAnimation: Bool) {
        dockedWindowController?.window?.orderOut(nil)
        dockedWindowController?.close()

        let controller = NotchWindowController(
            screen: screen,
            viewModel: viewModel,
            sessionMonitor: sessionMonitor,
            performBootAnimation: performBootAnimation
        )
        dockedWindowController = controller
        controller.showWindow(nil)
    }

    private static func makeViewModel(for screen: NSScreen) -> NotchViewModel {
        let screenFrame = screen.frame
        let notchSize = screen.notchSize
        let windowHeight: CGFloat = 750
        let deviceNotchRect = CGRect(
            x: (screenFrame.width - notchSize.width) / 2,
            y: 0,
            width: notchSize.width,
            height: notchSize.height
        )

        return NotchViewModel(
            deviceNotchRect: deviceNotchRect,
            screenRect: screenFrame,
            windowHeight: windowHeight,
            hasPhysicalNotch: screen.hasPhysicalNotch
        )
    }
}
