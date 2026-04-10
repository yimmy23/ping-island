import XCTest
@testable import Ping_Island

final class RemoteHookConfigurationTests: XCTestCase {
    func testRemoteBootstrapPrepareCommandStopsRunningAgentBeforeReplacingBridge() {
        let command = RemoteConnectorManager.remoteBootstrapPrepareCommand(
            installRoot: "/root/.ping-island",
            controlSocketPath: "/root/.ping-island/run/agent-control.sock",
            hookSocketPath: "/root/.ping-island/run/agent-hook.sock",
            configDirectoryPaths: ["/root/.codex", "/root/.qoder"]
        )

        XCTAssertTrue(command.contains("mkdir -p "))
        XCTAssertTrue(command.contains("pkill -f "))
        XCTAssertTrue(command.contains("PingIslandBridge"))
        XCTAssertTrue(command.contains("rm -f "))
        XCTAssertTrue(command.contains("PingIslandBridge.tmp"))
    }

    func testRemoteBootstrapInstallCommandPromotesStagedBridgeAtomically() {
        let command = RemoteConnectorManager.remoteBootstrapInstallCommand(
            installRoot: "/root/.ping-island",
            stagedBridgePath: "/root/.ping-island/bin/PingIslandBridge.tmp"
        )

        XCTAssertTrue(command.contains("mv -f '/root/.ping-island/bin/PingIslandBridge.tmp' '/root/.ping-island/bin/PingIslandBridge'"))
        XCTAssertTrue(command.contains("chmod 755 '/root/.ping-island/bin/PingIslandBridge' '/root/.ping-island/bin/ping-island-bridge'"))
    }

    func testRemoteManagedHookProfilesIncludeSupportedCliIntegrations() {
        let profileIDs = Set(RemoteConnectorManager.remoteManagedHookProfiles().map(\.id))

        XCTAssertEqual(profileIDs, [
            "claude-hooks",
            "codex-hooks",
            "qoder-hooks",
            "qoderwork-hooks",
        ])
    }

    func testRemoteManagedHookConfigDirectoryPathsResolveUnderRemoteHome() {
        let directories = RemoteConnectorManager.remoteManagedHookConfigDirectoryPaths(
            homeDirectory: "/root",
            profiles: RemoteConnectorManager.remoteManagedHookProfiles()
        )

        XCTAssertTrue(directories.contains("/root/.claude"))
        XCTAssertTrue(directories.contains("/root/.codex"))
        XCTAssertTrue(directories.contains("/root/.qoder"))
        XCTAssertTrue(directories.contains("/root/.qoderwork"))
    }

    func testRemoteConfigurationPathResolvesRelativeHomePaths() {
        XCTAssertEqual(
            RemoteConnectorManager.remoteConfigurationPath(
                relativePath: ".codex/hooks.json",
                homeDirectory: "/root"
            ),
            "/root/.codex/hooks.json"
        )
    }

    func testShouldBootstrapRemoteAgentForFreshEndpoint() {
        let endpoint = RemoteEndpoint(
            displayName: "Fresh",
            sshTarget: "dev@example"
        )

        XCTAssertTrue(
            RemoteConnectorManager.shouldBootstrapRemoteAgent(
                endpoint: endpoint,
                forceBootstrap: false
            )
        )
    }

    func testShouldReuseRemoteAgentAfterSuccessfulConnection() {
        let endpoint = RemoteEndpoint(
            displayName: "Known Host",
            sshTarget: "dev@example",
            agentVersion: "1.2.3",
            lastConnectedAt: Date()
        )

        XCTAssertFalse(
            RemoteConnectorManager.shouldBootstrapRemoteAgent(
                endpoint: endpoint,
                forceBootstrap: false
            )
        )
    }

    func testShouldBootstrapRemoteAgentWhenForced() {
        let endpoint = RemoteEndpoint(
            displayName: "Known Host",
            sshTarget: "dev@example",
            agentVersion: "1.2.3",
            lastConnectedAt: Date()
        )

        XCTAssertTrue(
            RemoteConnectorManager.shouldBootstrapRemoteAgent(
                endpoint: endpoint,
                forceBootstrap: true
            )
        )
    }

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

    func testManagedConfigurationDataRemovesLocalOnlyCommandsForRemoteInstall() throws {
        let existingJSON = """
        {
          "hooks": {
            "UserPromptSubmit": [
              {
                "hooks": [
                  {
                    "type": "command",
                    "command": "/Users/wudanwu/.claude/hooks/peon-ping/scripts/hook-handle-use.sh"
                  }
                ]
              },
              {
                "hooks": [
                  {
                    "type": "command",
                    "command": "/usr/bin/echo keep"
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
            customCommand: "ISLAND_SOCKET_PATH='/root/.ping-island/run/agent-hook.sock' '/root/.ping-island/bin/ping-island-bridge' --source claude",
            installing: true,
            removingCommandPrefixes: ["/Users/"]
        )

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let hooks = try XCTUnwrap(object["hooks"] as? [String: Any])
        let promptEntries = try XCTUnwrap(hooks["UserPromptSubmit"] as? [[String: Any]])
        let commands = promptEntries
            .compactMap { $0["hooks"] as? [[String: Any]] }
            .flatMap { $0 }
            .compactMap { $0["command"] as? String }

        XCTAssertFalse(commands.contains { $0.contains("/Users/wudanwu/.claude/hooks/peon-ping") })
        XCTAssertTrue(commands.contains("/usr/bin/echo keep"))
        XCTAssertTrue(commands.contains { $0.contains("/root/.ping-island/bin/ping-island-bridge") })
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
