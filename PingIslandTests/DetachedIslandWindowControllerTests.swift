import AppKit
import XCTest
@testable import Ping_Island

@MainActor
final class DetachedIslandWindowControllerTests: XCTestCase {
    func testDetachedWindowKeepsMouseEventsDisabledUntilDragSettles() async throws {
        let originalDisplayMode = AppSettings.notchDisplayMode
        defer { AppSettings.notchDisplayMode = originalDisplayMode }
        AppSettings.notchDisplayMode = .detailed

        let viewModel = makeViewModel()
        let sessionMonitor = SessionMonitor()

        viewModel.beginDetachedPresentation(contentType: .instances)

        let controller = DetachedIslandWindowController(
            viewModel: viewModel,
            sessionMonitor: sessionMonitor,
            onClose: {}
        )
        defer { controller.dismiss() }

        let window = try XCTUnwrap(controller.window)
        let initialOrigin = CGPoint(x: 240, y: 640)
        let initialSize = DetachedIslandWindowController.windowSize(for: viewModel)
        let initialMaxY = initialOrigin.y + initialSize.height
        window.setFrame(
            NSRect(
                origin: initialOrigin,
                size: initialSize
            ),
            display: false
        )

        controller.activateInteraction()

        XCTAssertTrue(window.ignoresMouseEvents)

        try await Task.sleep(nanoseconds: 180_000_000)

        let expectedSize = DetachedIslandWindowController.windowSize(for: viewModel)
        XCTAssertEqual(window.frame.width, expectedSize.width, accuracy: 0.5)
        XCTAssertEqual(window.frame.height, expectedSize.height, accuracy: 0.5)
        XCTAssertEqual(window.frame.maxY, initialMaxY, accuracy: 0.5)
        XCTAssertFalse(window.ignoresMouseEvents)
    }

    private func makeViewModel() -> NotchViewModel {
        NotchViewModel(
            deviceNotchRect: .zero,
            screenRect: CGRect(x: 0, y: 0, width: 1440, height: 900),
            windowHeight: 320,
            hasPhysicalNotch: false,
            enableEventMonitoring: false,
            observeSystemEnvironment: false,
            fullscreenActivityProvider: { _ in false }
        )
    }
}
