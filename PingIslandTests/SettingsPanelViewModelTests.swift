import XCTest
@testable import Ping_Island

@MainActor
final class SettingsPanelViewModelTests: XCTestCase {
    private actor StubRuntimeLauncher: NativeRuntimeLaunching {
        var started: [(SessionProvider, String)] = []
        var terminated: [(SessionProvider, String)] = []
        var nextError: Error?
        var nextResult = NativeRuntimeLaunchResult(sessionID: nil, remoteControlURL: nil, statusMessage: nil)

        func startSession(provider: SessionProvider, cwd: String) async throws -> NativeRuntimeLaunchResult {
            if let nextError {
                throw nextError
            }
            started.append((provider, cwd))
            return nextResult
        }

        func launches() -> [(SessionProvider, String)] {
            started
        }

        func setNextResult(_ result: NativeRuntimeLaunchResult) {
            nextResult = result
        }

        func terminateSession(provider: SessionProvider, sessionID: String) async throws {
            if let nextError {
                throw nextError
            }
            terminated.append((provider, sessionID))
        }

        func terminations() -> [(SessionProvider, String)] {
            terminated
        }
    }

    func testStartNativeRuntimeSessionValidatesDirectoryBeforeLaunch() async {
        let launcher = StubRuntimeLauncher()
        let viewModel = SettingsPanelViewModel(
            runtimeLauncher: launcher,
            fileExists: { _ in false }
        )
        viewModel.nativeRuntimeWorkingDirectory = "/missing/path"

        viewModel.startNativeRuntimeSession(provider: .claude)
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.nativeRuntimeStatusMessage, "目录不存在：/missing/path")
        let launches = await launcher.launches()
        XCTAssertTrue(launches.isEmpty)
    }

    func testStartNativeRuntimeSessionCallsLauncherAndUpdatesStatus() async {
        let launcher = StubRuntimeLauncher()
        let viewModel = SettingsPanelViewModel(
            runtimeLauncher: launcher,
            fileExists: { _ in true }
        )
        viewModel.nativeRuntimeWorkingDirectory = "/tmp/native-ui-test"

        viewModel.startNativeRuntimeSession(provider: .codex)
        try? await Task.sleep(nanoseconds: 100_000_000)

        let launches = await launcher.launches()
        XCTAssertEqual(launches.count, 1)
        XCTAssertEqual(launches.first?.0, .codex)
        XCTAssertEqual(launches.first?.1, "/tmp/native-ui-test")
        XCTAssertEqual(viewModel.nativeRuntimeStatusMessage, "Codex Native Runtime 已启动")
        XCTAssertNil(viewModel.nativeRuntimeRemoteControlURL)
        XCTAssertNil(viewModel.activeNativeRuntimeSessionID(for: .codex))
    }

    func testStartClaudeNativeRuntimeStoresHappyRemoteURL() async {
        let launcher = StubRuntimeLauncher()
        await launcher.setNextResult(
            NativeRuntimeLaunchResult(
                sessionID: "cmnvxu16j3xjluw0uc7tjo6b6",
                remoteControlURL: "https://app.happy.engineering/session/cmnvxu16j3xjluw0uc7tjo6b6",
                statusMessage: "Claude Native Runtime 已通过 Happy 通道启动"
            )
        )

        let viewModel = SettingsPanelViewModel(
            runtimeLauncher: launcher,
            fileExists: { _ in true }
        )
        viewModel.nativeRuntimeWorkingDirectory = "/tmp/native-ui-test"

        viewModel.startNativeRuntimeSession(provider: .claude)
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.nativeRuntimeStatusMessage, "Claude Native Runtime 已通过 Happy 通道启动")
        XCTAssertEqual(viewModel.nativeRuntimeRemoteControlURL, "https://app.happy.engineering/session/cmnvxu16j3xjluw0uc7tjo6b6")
        XCTAssertEqual(viewModel.activeNativeRuntimeSessionID(for: .claude), "cmnvxu16j3xjluw0uc7tjo6b6")
    }

    func testHappyClaudeLauncherMakeSessionURLFallsBackWhenEnvironmentMissing() {
        let url = HappyClaudeLauncher.makeSessionURL(
            sessionID: "cmnvyrcq48rmpuw0u63lo6cwg",
            environmentValue: String?.none
        )

        XCTAssertEqual(url, "https://app.happy.engineering/session/cmnvyrcq48rmpuw0u63lo6cwg")
    }

    func testHappyClaudeLauncherMakeSessionURLUsesEnvironmentOverrideWhenValid() {
        let url = HappyClaudeLauncher.makeSessionURL(
            sessionID: "cmnvyrcq48rmpuw0u63lo6cwg",
            environmentValue: "https://app.example.test/base"
        )

        XCTAssertEqual(url, "https://app.example.test/base/session/cmnvyrcq48rmpuw0u63lo6cwg")
    }

    func testTerminateNativeRuntimeSessionClearsActiveClaudeSession() async {
        let launcher = StubRuntimeLauncher()
        await launcher.setNextResult(
            NativeRuntimeLaunchResult(
                sessionID: "cmnvxu16j3xjluw0uc7tjo6b6",
                remoteControlURL: "https://app.happy.engineering/session/cmnvxu16j3xjluw0uc7tjo6b6",
                statusMessage: "Claude Native Runtime 已通过 Happy 通道启动"
            )
        )

        let viewModel = SettingsPanelViewModel(
            runtimeLauncher: launcher,
            fileExists: { _ in true }
        )
        viewModel.nativeRuntimeWorkingDirectory = "/tmp/native-ui-test"

        viewModel.startNativeRuntimeSession(provider: .claude)
        try? await Task.sleep(nanoseconds: 100_000_000)

        viewModel.terminateNativeRuntimeSession(provider: .claude)
        try? await Task.sleep(nanoseconds: 100_000_000)

        let terminations = await launcher.terminations()
        XCTAssertEqual(terminations.count, 1)
        XCTAssertEqual(terminations.first?.0, .claude)
        XCTAssertEqual(terminations.first?.1, "cmnvxu16j3xjluw0uc7tjo6b6")
        XCTAssertNil(viewModel.activeNativeRuntimeSessionID(for: .claude))
        XCTAssertNil(viewModel.nativeRuntimeRemoteControlURL)
        XCTAssertEqual(viewModel.nativeRuntimeStatusMessage, "Claude Native Runtime 已终止")
    }
}
