import Foundation
import XCTest
@testable import Ping_Island

final class CodexRolloutParserTests: XCTestCase {
    func testRolloutParserPreservesTerminalHostedCodexCLIContext() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let threadId = "019d77a9-b7e4-76d3-996a-adadefcf7a56"
        let rolloutURL = tempDirectory.appendingPathComponent("rollout-\(threadId).jsonl")
        let rollout = """
        {"timestamp":"2026-04-10T13:51:51Z","type":"session_meta","payload":{"id":"\(threadId)","cwd":"/Users/wudanwu/github/claude-island","originator":"codex-tui","source":"cli"}}
        {"timestamp":"2026-04-10T13:51:52Z","type":"event_msg","payload":{"type":"user_message","message":"hi"}}
        {"timestamp":"2026-04-10T13:51:57Z","type":"event_msg","payload":{"type":"agent_message","phase":"final","message":"Hi. What do you need help with in this repo?"}}
        """
        try rollout.write(to: rolloutURL, atomically: true, encoding: .utf8)

        let snapshot = await CodexRolloutParser.shared.parseThread(
            threadId: threadId,
            fallbackCwd: "/Users/wudanwu/github/claude-island",
            clientInfo: SessionClientInfo(
                kind: .codexCLI,
                profileID: "codex-cli",
                name: "Codex",
                origin: "cli",
                threadSource: "cli",
                sessionFilePath: rolloutURL.path,
                terminalBundleIdentifier: "com.googlecode.iterm2",
                terminalProgram: "iTerm.app",
                terminalSessionIdentifier: "w0t0p0:82B6B83C-9817-47EB-B42B-EDC2AAB96556",
                iTermSessionIdentifier: "w0t0p0:82B6B83C-9817-47EB-B42B-EDC2AAB96556",
                processName: "/Users/wudanwu/.nvm/versions/node/v22.21.1/lib/node_modules/@openai/codex/node_modules/@openai/codex-darwin-arm64/vendor/aarch64-apple-darwin/codex/codex"
            )
        )

        let clientInfo = try XCTUnwrap(snapshot?.clientInfo)
        XCTAssertEqual(clientInfo.kind, .codexCLI)
        XCTAssertEqual(clientInfo.origin, "cli")
        XCTAssertEqual(clientInfo.threadSource, "cli")
        XCTAssertEqual(clientInfo.terminalBundleIdentifier, "com.googlecode.iterm2")
        XCTAssertEqual(clientInfo.iTermSessionIdentifier, "w0t0p0:82B6B83C-9817-47EB-B42B-EDC2AAB96556")
        XCTAssertNil(clientInfo.bundleIdentifier)
        XCTAssertNil(clientInfo.launchURL)
    }
}
