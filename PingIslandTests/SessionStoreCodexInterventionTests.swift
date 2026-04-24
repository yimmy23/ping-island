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

    func testCodexIdleRefreshDoesNotDowngradeRunningToolThread() async {
        let sessionId = "codex-running-tool-\(UUID().uuidString)"
        let store = SessionStore.shared
        let startedAt = Date()

        await store.syncCodexThreadSnapshot(
            CodexThreadSnapshot(
                threadId: sessionId,
                name: "Codex",
                preview: "Running tool",
                cwd: "/tmp/project",
                clientInfo: SessionClientInfo(kind: .codexCLI, profileID: "codex-cli", name: "Codex"),
                intervention: nil,
                createdAt: startedAt,
                updatedAt: startedAt,
                phase: .processing,
                historyItems: [
                    ChatHistoryItem(
                        id: "tool-1",
                        type: .toolCall(ToolCallItem(
                            name: "shell",
                            input: ["command": "sleep 120"],
                            status: .running,
                            result: nil,
                            structuredResult: nil,
                            subagentTools: []
                        )),
                        timestamp: startedAt
                    )
                ],
                conversationInfo: ConversationInfo(
                    summary: "Codex",
                    lastMessage: nil,
                    lastMessageRole: nil,
                    lastToolName: nil,
                    firstUserMessage: "keep going",
                    lastUserMessageDate: startedAt
                ),
                latestTurnId: "turn-1",
                latestResponseText: nil,
                latestResponsePhase: nil,
                latestUserText: "keep going"
            )
        )

        await store.upsertCodexSession(
            sessionId: sessionId,
            name: "Codex",
            preview: "Idle heartbeat",
            cwd: "/tmp/project",
            phase: .idle,
            intervention: nil,
            clientInfo: SessionClientInfo(kind: .codexCLI, profileID: "codex-cli", name: "Codex"),
            activityAt: startedAt.addingTimeInterval(90)
        )

        let session = await store.session(for: sessionId)
        XCTAssertEqual(session?.phase, .processing)
        XCTAssertEqual(session?.lastActivity, startedAt)

        await store.process(.sessionArchived(sessionId: sessionId))
    }

    func testCodexHookPermissionRequestSurvivesAppServerRefresh() async {
        let sessionId = "codex-hook-approval-\(UUID().uuidString)"
        let store = SessionStore.shared

        await store.process(.hookReceived(HookEvent(
            sessionId: sessionId,
            cwd: "/tmp/project",
            event: "PermissionRequest",
            status: "waiting_for_approval",
            provider: .codex,
            clientInfo: SessionClientInfo.codexApp(threadId: sessionId),
            pid: nil,
            tty: nil,
            tool: "Bash",
            toolInput: [
                "command": AnyCodable("date"),
                "description": AnyCodable("Show the current time.")
            ],
            toolUseId: "call-date-1",
            notificationType: nil,
            message: nil
        )))

        await store.upsertCodexSession(
            sessionId: sessionId,
            name: nil,
            preview: "Show the current time.",
            cwd: "/tmp/project",
            phase: .processing,
            intervention: nil,
            clientInfo: SessionClientInfo.codexApp(threadId: sessionId),
            activityAt: Date().addingTimeInterval(5)
        )

        let session = await store.session(for: sessionId)
        XCTAssertTrue(session?.phase.isWaitingForApproval == true)
        XCTAssertEqual(session?.activePermission?.toolUseId, "call-date-1")
        XCTAssertEqual(session?.activePermission?.toolName, "Bash")
        XCTAssertEqual(session?.intervention?.kind, .approval)
        XCTAssertEqual(session?.intervention?.title, "Approve Command")
        XCTAssertEqual(session?.intervention?.message, "date")
        XCTAssertEqual(session?.intervention?.supportsSessionScope, false)
        XCTAssertEqual(session?.intervention?.metadata["source"], "codex_hook_permission")
        XCTAssertEqual(session?.ingress, .hookBridge)

        await store.process(.sessionArchived(sessionId: sessionId))
    }

    func testCodexHookPermissionApprovalClearsInterventionImmediately() async {
        let sessionId = "codex-hook-approved-\(UUID().uuidString)"
        let store = SessionStore.shared

        await store.process(.hookReceived(HookEvent(
            sessionId: sessionId,
            cwd: "/tmp/project",
            event: "PermissionRequest",
            status: "waiting_for_approval",
            provider: .codex,
            clientInfo: SessionClientInfo(kind: .codexCLI, profileID: "codex-cli", name: "Codex CLI"),
            pid: nil,
            tty: nil,
            tool: "Bash",
            toolInput: [
                "command": AnyCodable("curl -I https://example.com"),
                "description": AnyCodable("Allow a test HEAD request.")
            ],
            toolUseId: "call-curl-1",
            notificationType: nil,
            message: nil
        )))

        var session = await store.session(for: sessionId)
        XCTAssertTrue(session?.needsApprovalResponse ?? false)
        XCTAssertEqual(session?.intervention?.metadata["source"], "codex_hook_permission")

        await store.process(.permissionApproved(sessionId: sessionId, toolUseId: "call-curl-1"))

        session = await store.session(for: sessionId)
        XCTAssertEqual(session?.phase, .processing)
        XCTAssertNil(session?.intervention)
        XCTAssertFalse(session?.needsApprovalResponse ?? true)

        await store.process(.sessionArchived(sessionId: sessionId))
    }

    func testCodexHookPermissionDenialClearsInterventionImmediately() async {
        let sessionId = "codex-hook-denied-\(UUID().uuidString)"
        let store = SessionStore.shared

        await store.process(.hookReceived(HookEvent(
            sessionId: sessionId,
            cwd: "/tmp/project",
            event: "PermissionRequest",
            status: "waiting_for_approval",
            provider: .codex,
            clientInfo: SessionClientInfo(kind: .codexCLI, profileID: "codex-cli", name: "Codex CLI"),
            pid: nil,
            tty: nil,
            tool: "Bash",
            toolInput: ["command": AnyCodable("curl -I https://example.com")],
            toolUseId: "call-curl-deny",
            notificationType: nil,
            message: nil
        )))

        await store.process(
            .permissionDenied(sessionId: sessionId, toolUseId: "call-curl-deny", reason: "No network")
        )

        let session = await store.session(for: sessionId)
        XCTAssertEqual(session?.phase, .processing)
        XCTAssertNil(session?.intervention)
        XCTAssertFalse(session?.needsApprovalResponse ?? true)

        await store.process(.sessionArchived(sessionId: sessionId))
    }
}
