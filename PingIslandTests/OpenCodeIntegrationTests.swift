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
        XCTAssertEqual(MascotClient(clientInfo: clientInfo, provider: .claude), .openclaw)
        XCTAssertEqual(MascotKind(clientInfo: clientInfo, provider: .claude), .openclaw)
        XCTAssertEqual(MascotClient.allCases.contains(.openclaw), true)
        XCTAssertEqual(clientInfo.badgeLabel(for: .claude), "OpenClaw")
    }

    func testOpenClawEventsDoNotEnableClaudeTranscriptSync() {
        let clientInfo = SessionClientInfo(
            kind: .custom,
            profileID: "openclaw",
            name: "OpenClaw",
            origin: "gateway",
            originator: "OpenClaw",
            threadSource: "openclaw-hooks"
        )
        let event = HookEvent(
            sessionId: "openclaw-session",
            cwd: "/Users/wudanwu/Island",
            event: "command:new",
            status: "processing",
            provider: .claude,
            clientInfo: clientInfo,
            pid: nil,
            tty: nil,
            tool: nil,
            toolInput: nil,
            toolUseId: nil,
            notificationType: nil,
            message: "/new"
        )

        XCTAssertFalse(event.shouldSyncFile)
        XCTAssertFalse(SessionMonitor.shouldWatchTranscript(for: event, phase: .processing))
    }

    func testOpenCodeManagedProfileUsesPluginFileInstallation() {
        let profile = ClientProfileRegistry.managedHookProfile(id: "opencode-hooks")

        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.title, "OpenCode")
        XCTAssertEqual(profile?.installationKind, .pluginFile)
        XCTAssertEqual(profile?.brand, .opencode)
        XCTAssertEqual(profile?.localAppBundleIdentifiers, ["ai.opencode.desktop"])
        XCTAssertEqual(profile?.primaryConfigurationURL.path, NSHomeDirectory() + "/.config/opencode/plugins/ping-island.js")
        XCTAssertEqual(profile?.activationConfigurationURL?.path, NSHomeDirectory() + "/.config/opencode/config.json")
        XCTAssertTrue(profile?.reinstallDescriptionFormat.contains("插件文件") == true)
    }

    func testOpenCodeManagedPluginIncludesEventMappingAndReplyFlow() throws {
        let profile = try XCTUnwrap(ClientProfileRegistry.managedHookProfile(id: "opencode-hooks"))
        let source = HookInstaller.managedPluginSource(for: profile)

        XCTAssertTrue(source.contains("export const server = async ({ client, serverUrl }) =>"))
        XCTAssertTrue(source.contains("export default server"))
        XCTAssertTrue(source.contains("type === \"permission.asked\""))
        XCTAssertTrue(source.contains("type === \"question.asked\""))
        XCTAssertTrue(source.contains("hook_event_name: \"PermissionRequest\""))
        XCTAssertTrue(source.contains("hook_event_name: \"PreToolUse\""))
        XCTAssertTrue(source.contains("tool_name: \"AskUserQuestion\""))
        XCTAssertTrue(source.contains("/permission/${requestId}/reply"))
        XCTAssertTrue(source.contains("/question/${requestId}/reply"))
        XCTAssertTrue(source.contains("\"shell.env\": async"))
        XCTAssertTrue(source.contains("stdout: captureResponse ? \"pipe\" : \"ignore\""))
        XCTAssertTrue(source.contains("_env: collectBridgeEnv()"))
        XCTAssertTrue(source.contains("_tty: detectedTTY"))
    }

    func testOpenCodeActivationConfigInstallsPluginEntryWithoutRemovingOthers() throws {
        let existingJSON = """
        {
          "$schema": "https://opencode.ai/config.json",
          "plugin": [
            "file:///Users/wudanwu/.config/opencode/plugins/open-island.js"
          ]
        }
        """.data(using: .utf8)

        let profile = try XCTUnwrap(ClientProfileRegistry.managedHookProfile(id: "opencode-hooks"))
        let data = HookInstaller.updatedConfigurationData(
            existingData: existingJSON,
            profile: profile,
            customCommand: "",
            installing: true
        )

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let plugins = try XCTUnwrap(object["plugin"] as? [String])

        XCTAssertTrue(plugins.contains("file:///Users/wudanwu/.config/opencode/plugins/open-island.js"))
        XCTAssertTrue(plugins.contains(profile.primaryConfigurationURL.absoluteURL.absoluteString))
        XCTAssertEqual(
            plugins.filter { $0 == profile.primaryConfigurationURL.absoluteURL.absoluteString }.count,
            1
        )
    }

    func testOpenCodeActivationConfigRemovesOnlyPingIslandPluginEntry() throws {
        let existingJSON = """
        {
          "$schema": "https://opencode.ai/config.json",
          "plugin": [
            "file:///Users/wudanwu/.config/opencode/plugins/open-island.js",
            "file:///Users/wudanwu/.config/opencode/plugins/ping-island.js"
          ]
        }
        """.data(using: .utf8)

        let profile = try XCTUnwrap(ClientProfileRegistry.managedHookProfile(id: "opencode-hooks"))
        let data = HookInstaller.updatedConfigurationData(
            existingData: existingJSON,
            profile: profile,
            customCommand: "",
            installing: false
        )

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let plugins = try XCTUnwrap(object["plugin"] as? [String])

        XCTAssertTrue(plugins.contains("file:///Users/wudanwu/.config/opencode/plugins/open-island.js"))
        XCTAssertFalse(plugins.contains(profile.primaryConfigurationURL.absoluteURL.absoluteString))
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
