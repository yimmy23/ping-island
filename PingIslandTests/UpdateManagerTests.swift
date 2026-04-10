import XCTest
import Sparkle
@testable import Ping_Island

final class UpdateManagerTests: XCTestCase {
    func testNoUpdateErrorMapsToUpToDateState() {
        let error = NSError(
            domain: SUSparkleErrorDomain,
            code: Int(SUError.noUpdateError.rawValue),
            userInfo: [
                SPUNoUpdateFoundReasonKey: NSNumber(value: SPUNoUpdateFoundReason.onLatestVersion.rawValue)
            ]
        )

        XCTAssertEqual(
            UpdateManager.terminalState(forUpdateCycleError: error),
            .upToDate
        )
    }

    func testCompatibilityNoUpdateErrorMapsToActionableErrorState() {
        let error = NSError(
            domain: SUSparkleErrorDomain,
            code: Int(SUError.noUpdateError.rawValue),
            userInfo: [
                SPUNoUpdateFoundReasonKey: NSNumber(value: SPUNoUpdateFoundReason.systemIsTooOld.rawValue)
            ]
        )

        XCTAssertEqual(
            UpdateManager.terminalState(forUpdateCycleError: error),
            .error(message: "当前系统版本过低，无法安装可用更新")
        )
    }

    func testUnexpectedSparkleErrorPreservesLocalizedMessage() {
        let error = NSError(
            domain: SUSparkleErrorDomain,
            code: Int(SUError.downloadError.rawValue),
            userInfo: [NSLocalizedDescriptionKey: "下载失败"]
        )

        XCTAssertEqual(
            UpdateManager.terminalState(forUpdateCycleError: error),
            .error(message: "下载失败")
        )
    }
}
