import XCTest
@testable import Ping_Island

final class ClaudeApprovalStateTests: XCTestCase {
    func testUnrelatedPostToolUseDoesNotClearPendingClaudeApproval() async {
        let sessionId = "claude-approval-\(UUID().uuidString)"
        let store = SessionStore.shared

        await store.process(.hookReceived(makeToolEvent(
            sessionId: sessionId,
            event: "PreToolUse",
            status: "running_tool",
            tool: "Bash",
            toolUseId: "tool-approve"
        )))
        await store.process(.hookReceived(makeToolEvent(
            sessionId: sessionId,
            event: "PermissionRequest",
            status: "waiting_for_approval",
            tool: "Bash",
            toolUseId: "tool-approve"
        )))
        await store.process(.hookReceived(makeToolEvent(
            sessionId: sessionId,
            event: "PreToolUse",
            status: "running_tool",
            tool: "Read",
            toolUseId: "tool-other"
        )))
        await store.process(.hookReceived(makeToolEvent(
            sessionId: sessionId,
            event: "PostToolUse",
            status: "processing",
            tool: "Read",
            toolUseId: "tool-other"
        )))

        let session = await store.session(for: sessionId)
        XCTAssertTrue(session?.phase.isWaitingForApproval ?? false)
        XCTAssertEqual(session?.activePermission?.toolUseId, "tool-approve")
        XCTAssertEqual(session?.activePermission?.toolName, "Bash")
        XCTAssertEqual(session?.pendingToolName, "Bash")
        XCTAssertTrue(session?.needsApprovalResponse ?? false)

        await store.process(.sessionArchived(sessionId: sessionId))
    }

    private func makeToolEvent(
        sessionId: String,
        event: String,
        status: String,
        tool: String,
        toolUseId: String
    ) -> HookEvent {
        HookEvent(
            sessionId: sessionId,
            cwd: "/tmp/project",
            event: event,
            status: status,
            provider: .claude,
            clientInfo: SessionClientInfo(
                kind: .claudeCode,
                profileID: "claude_code",
                name: "Claude Code",
                bundleIdentifier: "com.anthropic.claudecode"
            ),
            pid: nil,
            tty: nil,
            tool: tool,
            toolInput: ["command": AnyCodable("swift test")],
            toolUseId: toolUseId,
            notificationType: nil,
            message: nil
        )
    }
}
