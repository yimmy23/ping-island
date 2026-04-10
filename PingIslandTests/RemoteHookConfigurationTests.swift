import XCTest
@testable import Ping_Island

final class RemoteHookConfigurationTests: XCTestCase {
    func testManagedConfigurationDataInstallsClaudeHooksWithoutRemovingExistingEntries() throws {
        let existingJSON = """
        {
          "hooks": {
            "UserPromptSubmit": [
              {
                "hooks": [
                  {
                    "type": "command",
                    "command": "/usr/bin/echo existing"
                  }
                ]
              }
            ]
          }
        }
        """.data(using: .utf8)

        let profile = try XCTUnwrap(ClientProfileRegistry.managedHookProfile(id: "claude-hooks"))
        let command = HookInstaller.managedBridgeCommand(
            source: profile.bridgeSource,
            extraArguments: profile.bridgeExtraArguments,
            launcherPath: "/remote/bin/ping-island-bridge",
            socketPath: "/remote/run/agent-hook.sock"
        )

        let data = HookInstaller.updatedConfigurationData(
            existingData: existingJSON,
            profile: profile,
            customCommand: command,
            installing: true
        )

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let hooks = try XCTUnwrap(object["hooks"] as? [String: Any])
        let promptEntries = try XCTUnwrap(hooks["UserPromptSubmit"] as? [[String: Any]])

        XCTAssertEqual(promptEntries.count, 2)
    }

    func testManagedConfigurationDataRemovesIslandManagedEntriesWhenUninstalling() throws {
        let existingJSON = """
        {
          "hooks": {
            "UserPromptSubmit": [
              {
                "hooks": [
                  {
                    "type": "command",
                    "command": "/usr/bin/echo keep"
                  }
                ]
              },
              {
                "hooks": [
                  {
                    "type": "command",
                    "command": "ISLAND_SOCKET_PATH='/remote/run/agent-hook.sock' '/home/test/.ping-island/bin/ping-island-bridge' --source claude"
                  }
                ]
              }
            ]
          }
        }
        """.data(using: .utf8)

        let profile = try XCTUnwrap(ClientProfileRegistry.managedHookProfile(id: "claude-hooks"))
        let data = HookInstaller.updatedConfigurationData(
            existingData: existingJSON,
            profile: profile,
            customCommand: "",
            installing: false
        )

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let hooks = try XCTUnwrap(object["hooks"] as? [String: Any])
        let promptEntries = try XCTUnwrap(hooks["UserPromptSubmit"] as? [[String: Any]])

        XCTAssertEqual(promptEntries.count, 1)
    }
}
