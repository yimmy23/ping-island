import XCTest
@testable import Ping_Island

final class UsageSummaryPresenterTests: XCTestCase {
    func testProvidersIncludeClaudeAndCodexSnapshots() {
        let providers = UsageSummaryPresenter.providers(
            claudeSnapshot: ClaudeUsageSnapshot(
                fiveHour: ClaudeUsageWindow(usedPercentage: 42, resetsAt: Date(timeIntervalSince1970: 1_760_000_000)),
                sevenDay: nil,
                cachedAt: nil
            ),
            codexSnapshot: CodexUsageSnapshot(
                sourceFilePath: "/tmp/rollout.jsonl",
                capturedAt: nil,
                planType: "pro",
                limitID: "codex",
                windows: [
                    CodexUsageWindow(
                        key: "primary",
                        label: "5h",
                        usedPercentage: 13,
                        leftPercentage: 87,
                        windowMinutes: 300,
                        resetsAt: Date(timeIntervalSince1970: 1_775_158_295)
                    )
                ]
            ),
            mode: .used,
            now: Date(timeIntervalSince1970: 1_759_999_000),
            locale: Locale(identifier: "en")
        )

        XCTAssertEqual(providers.map(\.title), ["Claude", "Codex"])
        XCTAssertEqual(providers.first?.windows.first?.valueText, "42%")
        XCTAssertEqual(providers.last?.windows.first?.valueText, "13%")
    }

    func testRemainingModeFormatsRemainingPercentInEnglish() {
        let valueText = UsageSummaryPresenter.valueText(
            for: 13,
            mode: .remaining,
            locale: Locale(identifier: "en")
        )

        XCTAssertEqual(valueText, "87% left")
    }

    func testShouldShowSummaryHidesAttentionAndCompletionRoutes() {
        let providers = [
            UsageSummaryProvider(
                id: "claude",
                title: "Claude",
                windows: [
                    UsageSummaryWindow(
                        id: "claude-5h",
                        label: "5h",
                        valueText: "42%",
                        resetText: nil,
                        severity: .healthy,
                        remainingPercentage: 58
                    )
                ]
            )
        ]
        let session = SessionState(sessionId: "session", cwd: "/tmp/demo", phase: .processing)
        let notification = SessionCompletionNotification(session: session, kind: .completed)

        XCTAssertTrue(
            UsageSummaryPresenter.shouldShowSummary(
                for: .sessionList,
                showUsage: true,
                providers: providers
            )
        )
        XCTAssertFalse(
            UsageSummaryPresenter.shouldShowSummary(
                for: .attentionNotification(session),
                showUsage: true,
                providers: providers
            )
        )
        XCTAssertFalse(
            UsageSummaryPresenter.shouldShowSummary(
                for: .completionNotification(notification),
                showUsage: true,
                providers: providers
            )
        )
    }

    func testSeverityUsesRemainingQuotaThresholds() {
        XCTAssertEqual(UsageSummaryPresenter.severity(forUsedPercentage: 60), .healthy)
        XCTAssertEqual(UsageSummaryPresenter.severity(forUsedPercentage: 69), .healthy)
        XCTAssertEqual(UsageSummaryPresenter.severity(forUsedPercentage: 70), .warning)
        XCTAssertEqual(UsageSummaryPresenter.severity(forUsedPercentage: 75), .warning)
        XCTAssertEqual(UsageSummaryPresenter.severity(forUsedPercentage: 90), .critical)
        XCTAssertEqual(UsageSummaryPresenter.severity(forUsedPercentage: 95), .critical)
    }

    func testFloatingBoltShowsOnlyBelowSixtyPercentRemaining() {
        let sixtyRemaining = UsageSummaryWindow(
            id: "sixty",
            label: "5h",
            valueText: "60% left",
            resetText: nil,
            severity: .healthy,
            remainingPercentage: 60
        )
        let belowSixtyRemaining = UsageSummaryWindow(
            id: "below-sixty",
            label: "5h",
            valueText: "59% left",
            resetText: nil,
            severity: .healthy,
            remainingPercentage: 59
        )

        XCTAssertFalse(UsageSummaryPresenter.shouldShowFloatingBolt(for: sixtyRemaining))
        XCTAssertTrue(UsageSummaryPresenter.shouldShowFloatingBolt(for: belowSixtyRemaining))
    }
}
