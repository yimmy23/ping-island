import XCTest
@testable import Ping_Island

final class OpenCodeIntegrationTests: XCTestCase {
    func testOpenClawManagedProfileUsesHookDirectoryInstallation() {
        let profile = ClientProfileRegistry.managedHookProfile(id: "openclaw-hooks")

        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.title, "OpenClaw")
        XCTAssertEqual(profile?.installationKind, .hookDirectory)
        XCTAssertEqual(profile?.brand, .neutral)
        XCTAssertEqual(profile?.logoAssetName, "OpenClawLogo")
        XCTAssertEqual(profile?.prefersBundledLogoOverAppIcon, true)
        XCTAssertEqual(profile?.iconSymbolName, "bird.fill")
        XCTAssertEqual(profile?.primaryConfigurationURL.path, NSHomeDirectory() + "/.openclaw/hooks/ping-island-openclaw")
        XCTAssertEqual(profile?.activationConfigurationURL?.path, NSHomeDirectory() + "/.openclaw/openclaw.json")
        XCTAssertEqual(profile?.activationEntryName, "ping-island-openclaw")
        XCTAssertTrue(profile?.reinstallDescriptionFormat.contains("hook 目录") == true)
    }

    func testOpenClawRuntimeProfileResolvesBadgeLabel() {
        let profile = ClientProfileRegistry.matchRuntimeProfile(
            provider: .claude,
            explicitKind: "openclaw",
            explicitName: "OpenClaw",
            explicitBundleIdentifier: nil,
            terminalBundleIdentifier: nil,
            origin: "gateway",
            originator: "OpenClaw",
            threadSource: "openclaw-hooks",
            processName: nil
        )

        XCTAssertEqual(profile?.id, "openclaw")
        XCTAssertEqual(profile?.brand, .neutral)

        let clientInfo = SessionClientInfo(
            kind: .custom,
            profileID: "openclaw",
            name: "OpenClaw",
            origin: "gateway",
            originator: "OpenClaw",
            threadSource: "openclaw-hooks"
        )

        XCTAssertEqual(clientInfo.brand, .neutral)
        XCTAssertEqual(clientInfo.badgeLabel(for: .claude), "OpenClaw")
    }

    func testOpenCodeManagedProfileUsesPluginFileInstallation() {
        let profile = ClientProfileRegistry.managedHookProfile(id: "opencode-hooks")

        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.title, "OpenCode")
        XCTAssertEqual(profile?.installationKind, .pluginFile)
        XCTAssertEqual(profile?.brand, .opencode)
        XCTAssertEqual(profile?.localAppBundleIdentifiers, ["ai.opencode.desktop"])
        XCTAssertEqual(profile?.primaryConfigurationURL.path, NSHomeDirectory() + "/.config/opencode/plugins/ping-island.js")
        XCTAssertTrue(profile?.reinstallDescriptionFormat.contains("插件文件") == true)
    }

    func testOpenCodeRuntimeProfileResolvesBrandAndMascot() {
        let profile = ClientProfileRegistry.matchRuntimeProfile(
            provider: .claude,
            explicitKind: "OpenCode",
            explicitName: "OpenCode",
            explicitBundleIdentifier: nil,
            terminalBundleIdentifier: nil,
            origin: "cli",
            originator: "OpenCode",
            threadSource: "opencode-plugin",
            processName: nil
        )

        XCTAssertEqual(profile?.id, "opencode")
        XCTAssertEqual(profile?.brand, .opencode)
        XCTAssertEqual(profile?.defaultBundleIdentifier, "ai.opencode.desktop")
        XCTAssertEqual(profile?.bundleIdentifiers, ["ai.opencode.desktop"])

        let clientInfo = SessionClientInfo(
            kind: .custom,
            profileID: "opencode",
            name: "OpenCode",
            origin: "cli",
            originator: "OpenCode",
            threadSource: "opencode-plugin"
        )

        XCTAssertEqual(clientInfo.brand, .opencode)
        XCTAssertEqual(MascotClient(clientInfo: clientInfo, provider: .claude), .opencode)
        XCTAssertEqual(MascotKind(clientInfo: clientInfo, provider: .claude), .opencode)
        XCTAssertEqual(clientInfo.badgeLabel(for: .claude), "OpenCode")
    }
}
