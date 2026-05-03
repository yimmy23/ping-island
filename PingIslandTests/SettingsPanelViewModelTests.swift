import XCTest
@testable import Ping_Island

final class SettingsPanelViewModelTests: XCTestCase {
    private func makeDefaults(testName: String = #function) -> UserDefaults {
        let suiteName = "PingIslandTests.SettingsPanelViewModel.\(testName).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    func testQoderCLINoticeGateIsConsumedOnlyOnce() {
        let defaults = makeDefaults()
        let firstGate = QoderCLIHookRefreshNoticeGate(defaults: defaults)

        XCTAssertTrue(firstGate.consumeShouldShowNotice())
        XCTAssertFalse(firstGate.consumeShouldShowNotice())

        let secondGate = QoderCLIHookRefreshNoticeGate(defaults: defaults)

        XCTAssertFalse(secondGate.consumeShouldShowNotice())
    }
}
