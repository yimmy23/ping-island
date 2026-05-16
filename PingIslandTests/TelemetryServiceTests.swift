import XCTest
@testable import Ping_Island

actor RecordingTelemetrySink: TelemetrySink {
    private var batches: [[TelemetryRecord]] = []

    func send(_ records: [TelemetryRecord], configuration _: TelemetryConfiguration) async throws {
        batches.append(records)
    }

    func sentRecords() -> [TelemetryRecord] {
        batches.flatMap { $0 }
    }
}

final class TelemetryServiceTests: XCTestCase {
    private func makeDefaults(testName: String = #function) -> UserDefaults {
        let suiteName = "PingIslandTests.TelemetryService.\(testName)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    func testConfigurationBuildsSLSWebTrackingEndpoint() {
        let configuration = TelemetryConfiguration(
            slsHost: "https://cn-hangzhou.log.aliyuncs.com/",
            project: "ping-island",
            logstore: "ping-island"
        )

        XCTAssertEqual(
            configuration.endpointURL?.absoluteString,
            "https://ping-island.cn-hangzhou.log.aliyuncs.com/logstores/ping-island/track"
        )
    }

    func testTelemetryDoesNotSendWhenConsentIsDisabled() async {
        let defaults = makeDefaults()
        let sink = RecordingTelemetrySink()
        let service = TelemetryService(
            configuration: TelemetryConfiguration(slsHost: "cn-hangzhou.log.aliyuncs.com"),
            defaults: defaults,
            sink: sink,
            maxBatchSize: 1
        )

        await service.record(.appLaunched)

        let records = await sink.sentRecords()
        XCTAssertTrue(records.isEmpty)
    }

    func testTelemetryOnlySendsAllowlistedFields() async throws {
        let defaults = makeDefaults()
        defaults.set(true, forKey: TelemetryConsent.analyticsEnabledKey)
        let sink = RecordingTelemetrySink()
        let service = TelemetryService(
            configuration: TelemetryConfiguration(slsHost: "cn-hangzhou.log.aliyuncs.com"),
            defaults: defaults,
            sink: sink,
            maxBatchSize: 1
        )

        await service.record(
            .settingChanged,
            properties: [
                "setting_key": "surfaceMode",
                "value": "floatingPet",
                "cwd": "/Users/example/private-project"
            ]
        )

        let records = await sink.sentRecords()
        let fields = try XCTUnwrap(records.first?.fields)
        XCTAssertEqual(fields["event"], "setting_changed")
        XCTAssertEqual(fields["setting_key"], "surfaceMode")
        XCTAssertEqual(fields["value"], "floatingPet")
        XCTAssertNil(fields["cwd"])
        XCTAssertNotNil(fields["anonymous_user_id"])
    }

    func testDailyLimitCapsUploads() async {
        let defaults = makeDefaults()
        defaults.set(true, forKey: TelemetryConsent.analyticsEnabledKey)
        let sink = RecordingTelemetrySink()
        let service = TelemetryService(
            configuration: TelemetryConfiguration(
                slsHost: "cn-hangzhou.log.aliyuncs.com",
                dailyEventLimit: 1
            ),
            defaults: defaults,
            sink: sink,
            maxBatchSize: 1
        )

        await service.record(.appLaunched)
        await service.record(.integrationStatusSnapshot)

        let records = await sink.sentRecords()
        XCTAssertEqual(records.count, 1)
    }
}
