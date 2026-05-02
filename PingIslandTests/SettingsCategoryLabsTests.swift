import XCTest
@testable import Ping_Island

final class SettingsCategoryLabsTests: XCTestCase {
    func testLabsCategoryIsVisibleBeforeAbout() {
        let categories = SettingsCategory.allCases

        XCTAssertTrue(categories.contains(.labs))
        XCTAssertLessThan(
            categories.firstIndex(of: .labs)!,
            categories.firstIndex(of: .about)!
        )
    }

    func testLabsCategoryLabelsExperimentalContent() {
        XCTAssertEqual(SettingsCategory.labs.title, "实验室")
        XCTAssertEqual(SettingsCategory.labs.subtitle, "试验性特性")
        XCTAssertEqual(SettingsCategory.labs.icon, "flask.fill")
    }
}
