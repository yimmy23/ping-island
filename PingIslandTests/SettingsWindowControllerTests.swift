import AppKit
import XCTest
@testable import Ping_Island

@MainActor
final class SettingsWindowControllerTests: XCTestCase {
    func testFloatingPetGuidanceStringsMentionSecondaryClickToReopenSettings() {
        let zhHans = try! localizationFileContents(named: "zh-Hans")
        XCTAssertTrue(
            zhHans.contains("\"进入独立悬浮宠物模式后，右键宠物形象可重新打开设置面板。\" = \"进入独立悬浮宠物模式后，右键宠物形象可重新打开设置面板。\";")
        )
        XCTAssertTrue(
            zhHans.contains("\"独立悬浮宠物默认贴近当前激活窗口右下角显示。拖动后会记住新位置，右键宠物形象可重新打开设置面板。\" = \"独立悬浮宠物默认贴近当前激活窗口右下角显示。拖动后会记住新位置，右键宠物形象可重新打开设置面板。\";")
        )

        let english = try! localizationFileContents(named: "en")
        XCTAssertTrue(
            english.contains("\"进入独立悬浮宠物模式后，右键宠物形象可重新打开设置面板。\" = \"After entering floating pet mode, right-click the mascot to reopen the Settings panel.\";")
        )
        XCTAssertTrue(
            english.contains("\"独立悬浮宠物默认贴近当前激活窗口右下角显示。拖动后会记住新位置，右键宠物形象可重新打开设置面板。\" = \"The floating pet appears near the bottom-right corner of the active window by default. Dragging remembers the new position, and right-clicking the mascot reopens the Settings panel.\";")
        )
        XCTAssertTrue(
            zhHans.contains("\"拖动宠物，让 Island 离岛工作\" = \"拖动宠物，让 Island 离岛工作\";")
        )
        XCTAssertTrue(
            english.contains("\"拖动宠物，让 Island 离岛工作\" = \"Drag the mascot to undock the Island.\";")
        )
    }

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

    func testPresentationModeWelcomeWindowStaysVisibleUntilCompleted() throws {
        let controller = PresentationModeWelcomeWindowController.shared
        controller.dismiss()

        controller.present { _ in }
        let window = try XCTUnwrap(controller.window)

        XCTAssertTrue(window.isVisible)
        XCTAssertFalse(window.isMiniaturized)
        XCTAssertEqual(window.contentRect(forFrameRect: window.frame).size.width, 760)
        XCTAssertEqual(window.contentRect(forFrameRect: window.frame).size.height, 520)

        controller.dismiss()
    }

    private func localizationFileContents(named localeCode: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let repoRoot = testsDirectory.deletingLastPathComponent()
        let fileURL = repoRoot
            .appendingPathComponent("PingIsland")
            .appendingPathComponent("Resources")
            .appendingPathComponent("\(localeCode).lproj")
            .appendingPathComponent("Localizable.strings")
        return try String(contentsOf: fileURL, encoding: .utf8)
    }
}
