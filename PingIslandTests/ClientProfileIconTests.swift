import XCTest
@testable import Ping_Island

final class ClientProfileIconTests: XCTestCase {
    func testManagedHookProfilesUseBundledLogosForSettings() throws {
        let expectedAssets = [
            "claude-hooks": "ClaudeLogo",
            "codex-hooks": "CodexLogo",
            "gemini-hooks": "GeminiLogo",
            "openclaw-hooks": "OpenClawLogo",
            "codebuddy-hooks": "CodeBuddyLogo",
            "workbuddy-hooks": "WorkBuddyLogo",
            "cursor-hooks": "CursorLogo",
            "qoder-hooks": "QoderLogo",
            "qoderwork-hooks": "QoderWorkLogo",
            "copilot-hooks": "CopilotLogo",
            "opencode-hooks": "OpenCodeLogo",
        ]

        for (profileID, assetName) in expectedAssets {
            let profile = try XCTUnwrap(
                ClientProfileRegistry.managedHookProfile(id: profileID),
                "Missing managed hook profile \(profileID)"
            )
            XCTAssertEqual(profile.logoAssetName, assetName)
            XCTAssertTrue(profile.prefersBundledLogoOverAppIcon)
        }
    }

    func testIDEExtensionProfilesUseBundledLogosForSettings() throws {
        let expectedAssets = [
            "vscode-extension": "VSCodeLogo",
            "cursor-extension": "CursorLogo",
            "codebuddy-extension": "CodeBuddyLogo",
            "workbuddy-extension": "WorkBuddyLogo",
            "qoder-extension": "QoderLogo",
        ]

        for (profileID, assetName) in expectedAssets {
            let profile = try XCTUnwrap(
                ClientProfileRegistry.ideExtensionProfile(id: profileID),
                "Missing IDE extension profile \(profileID)"
            )
            XCTAssertEqual(profile.logoAssetName, assetName)
            XCTAssertTrue(profile.prefersBundledLogoOverAppIcon)
        }
    }

    func testQoderCLIHookProfileMatchesClaudeCodeHooks() throws {
        let qoderProfile = try XCTUnwrap(ClientProfileRegistry.managedHookProfile(id: "qoder-hooks"))
        let qoderEvents = Set(qoderProfile.events.map(\.name))
        let claudeProfile = try XCTUnwrap(ClientProfileRegistry.managedHookProfile(id: "claude-hooks"))
        let claudeEvents = Set(claudeProfile.events.map(\.name))

        XCTAssertEqual(qoderEvents, claudeEvents)
        XCTAssertEqual(
            qoderProfile.events.first { $0.name == "PreToolUse" }?.timeout,
            86_400
        )
        XCTAssertEqual(
            qoderProfile.bridgeExtraArguments,
            [
                "--client-kind", "qoder-cli",
                "--client-name", "Qoder CLI",
                "--client-origin", "cli",
                "--client-originator", "Qoder"
            ]
        )
    }
}
