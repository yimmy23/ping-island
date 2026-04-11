import XCTest
@testable import Ping_Island

final class SessionStoreCodexInterventionTests: XCTestCase {
    func testCodexAppServerIdleRefreshDoesNotClearExternalOnlyIntervention() async {
        let sessionId = "codex-external-\(UUID().uuidString)"
        let store = SessionStore.shared

        let intervention = SessionIntervention(
            id: "mcp-pending-omx_state-state_list_active",
            kind: .question,
            title: "MCP Tool Approval Needed",
            message: "Allow the omx_state MCP server to run tool \"state_list_active\"?",
            options: [],
            questions: [],
            supportsSessionScope: false,
            metadata: [
                "responseMode": "external_only",
                "source": "rollout_pending_mcp",
                "server": "omx_state",
                "toolName": "state_list_active"
            ]
        )

        await store.upsertCodexSession(
            sessionId: sessionId,
            name: nil,
            preview: intervention.message,
            cwd: "/tmp/project",
            phase: .waitingForInput,
            intervention: intervention,
            clientInfo: SessionClientInfo(kind: .codexCLI, profileID: "codex-cli", name: "Codex")
        )

        await store.upsertCodexSession(
            sessionId: sessionId,
            name: nil,
            preview: "删除 LICENSE 文件",
            cwd: "/tmp/project",
            phase: .idle,
            intervention: nil,
            clientInfo: SessionClientInfo(kind: .codexCLI, profileID: "codex-cli", name: "Codex")
        )

        let session = await store.session(for: sessionId)
        XCTAssertEqual(session?.intervention?.title, "MCP Tool Approval Needed")
        XCTAssertEqual(session?.phase, .waitingForInput)

        await store.process(.sessionArchived(sessionId: sessionId))
    }

    func testStaleCodexIdleRefreshDoesNotDowngradeFreshProcessingState() async {
        let sessionId = "codex-stale-idle-\(UUID().uuidString)"
        let store = SessionStore.shared
        let freshActivityAt = Date()

        await store.upsertCodexSession(
            sessionId: sessionId,
            name: "Codex",
            preview: "Following up",
            cwd: "/tmp/project",
            phase: .processing,
            intervention: nil,
            clientInfo: SessionClientInfo(kind: .codexCLI, profileID: "codex-cli", name: "Codex"),
            activityAt: freshActivityAt
        )

        await store.upsertCodexSession(
            sessionId: sessionId,
            name: "Codex",
            preview: "Old snapshot",
            cwd: "/tmp/project",
            phase: .idle,
            intervention: nil,
            clientInfo: SessionClientInfo(kind: .codexCLI, profileID: "codex-cli", name: "Codex"),
            activityAt: freshActivityAt.addingTimeInterval(-300)
        )

        let session = await store.session(for: sessionId)
        XCTAssertEqual(session?.phase, .processing)
        XCTAssertEqual(session?.lastActivity, freshActivityAt)

        await store.process(.sessionArchived(sessionId: sessionId))
    }
}
