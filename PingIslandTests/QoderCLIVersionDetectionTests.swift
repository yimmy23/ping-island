import XCTest
@testable import Ping_Island

final class QoderCLIVersionDetectionTests: XCTestCase {
    func testQoderCLIVersionParserAcceptsPlainVersion() {
        XCTAssertEqual(HookInstaller.qoderCLIVersion(from: "0.2.6\n"), "0.2.6")
    }

    func testQoderCLIVersionParserAcceptsCommandLabel() {
        XCTAssertEqual(HookInstaller.qoderCLIVersion(from: "qodercli version 0.3.1"), "0.3.1")
    }

    func testQoderCLIVersionComparisonUsesNumericComponents() {
        XCTAssertEqual(HookInstaller.compareSemanticVersions("0.2.6", "0.2.5"), .orderedDescending)
        XCTAssertEqual(HookInstaller.compareSemanticVersions("0.2.5", "0.2.5"), .orderedSame)
        XCTAssertEqual(HookInstaller.compareSemanticVersions("0.2.4", "0.2.5"), .orderedAscending)
        XCTAssertEqual(HookInstaller.compareSemanticVersions("0.10.0", "0.2.5"), .orderedDescending)
    }

    func testQoderCLIExecutableURLUsesLocalBinUnderHome() throws {
        let home = URL(fileURLWithPath: "/Users/example")

        let url = try XCTUnwrap(HookInstaller.qoderCLIExecutableURL(homeDirectory: home))

        XCTAssertEqual(url.path, "/Users/example/.local/bin/qodercli")
    }

    func testQoderHookRefreshPreservesUnrelatedSettings() throws {
        let profile = try XCTUnwrap(ClientProfileRegistry.managedHookProfile(id: "qoder-hooks"))
        let existing = """
        {
          "env": {"KEEP": "1"},
          "theme": "dark",
          "hooks": {
            "PreToolUse": [
              {
                "matcher": "*",
                "hooks": [{"type": "command", "command": "/usr/bin/printf keep"}]
              },
              {
                "matcher": "*",
                "hooks": [{"type": "command", "command": "/Users/test/.ping-island/bin/ping-island-bridge --source claude --client-kind qoder"}]
              }
            ],
            "PostToolUseFailure": [
              {
                "matcher": "*",
                "hooks": [{"type": "command", "command": "/Users/test/.ping-island/bin/ping-island-bridge --source claude --client-kind qoder"}]
              }
            ]
          }
        }
        """.data(using: .utf8)

        let data = HookInstaller.updatedConfigurationData(
            existingData: existing,
            profile: profile,
            customCommand: "/Users/test/.ping-island/bin/ping-island-bridge --source claude --client-kind qoder-cli --client-name Qoder CLI --client-origin cli --client-originator Qoder",
            installing: true
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual((json["env"] as? [String: String])?["KEEP"], "1")
        XCTAssertEqual(json["theme"] as? String, "dark")

        let hooks = try XCTUnwrap(json["hooks"] as? [String: Any])
        XCTAssertNotNil(hooks["SessionStart"])
        XCTAssertNotNil(hooks["SessionEnd"])
        XCTAssertNotNil(hooks["PreCompact"])
        XCTAssertNil(hooks["PostToolUseFailure"])

        let preToolUse = try XCTUnwrap(hooks["PreToolUse"] as? [[String: Any]])
        let commands = preToolUse.compactMap { entry in
            ((entry["hooks"] as? [[String: Any]])?.first?["command"] as? String)
        }
        XCTAssertTrue(commands.first?.contains("/.ping-island/bin/ping-island-bridge") == true)
        XCTAssertTrue(commands.contains("/usr/bin/printf keep"))
        XCTAssertEqual(
            commands.filter { $0.contains("/.ping-island/bin/ping-island-bridge") }.count,
            1
        )
        let managedPreToolUseHook = try XCTUnwrap((preToolUse.first?["hooks"] as? [[String: Any]])?.first)
        XCTAssertEqual(managedPreToolUseHook["timeout"] as? Int, 86_400)
    }
}
