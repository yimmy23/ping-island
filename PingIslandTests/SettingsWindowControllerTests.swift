import AppKit
import XCTest
@testable import Ping_Island

@MainActor
final class SettingsWindowControllerTests: XCTestCase {
    func testPresentReusesExistingWindowAndKeepsItVisible() throws {
        let controller = SettingsWindowController.shared
        controller.dismiss()

        controller.present()
        let window = try XCTUnwrap(controller.window)

        XCTAssertTrue(window.isVisible)
        XCTAssertFalse(window.isMiniaturized)
        XCTAssertEqual(window.contentRect(forFrameRect: window.frame).size.width, SettingsWindowDefaults.defaultContentSize.width)
        XCTAssertEqual(window.contentRect(forFrameRect: window.frame).size.height, SettingsWindowDefaults.defaultContentSize.height)

        controller.present()

        XCTAssertTrue(window.isVisible)
        XCTAssertIdentical(controller.window, window)
        XCTAssertFalse(window.isMiniaturized)

        controller.dismiss()
    }
}
