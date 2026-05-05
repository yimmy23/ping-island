import XCTest
@testable import Ping_Island

final class SettingsCategoryLabsTests: XCTestCase {
    func testLabsCategoryIsHiddenUntilUnlocked() {
        let hiddenCategories = SettingsCategory.visibleCategories(labsUnlocked: false)

        XCTAssertFalse(hiddenCategories.contains(.labs))

        let unlockedCategories = SettingsCategory.visibleCategories(labsUnlocked: true)

        XCTAssertTrue(unlockedCategories.contains(.labs))
        XCTAssertLessThan(
            unlockedCategories.firstIndex(of: .labs)!,
            unlockedCategories.firstIndex(of: .about)!
        )
    }

    func testLabsCategoryLabelsExperimentalContent() {
        XCTAssertEqual(SettingsCategory.labs.title, "实验室")
        XCTAssertEqual(SettingsCategory.labs.subtitle, "试验性特性")
        XCTAssertEqual(SettingsCategory.labs.icon, "flask.fill")
    }
}
