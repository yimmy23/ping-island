import XCTest
@testable import Ping_Island

final class ClaudeAskUserQuestionSessionTests: XCTestCase {
    func testPreToolUseQuestionImmediatelyEntersWaitingForInput() async {
        let sessionId = "claude-question-\(UUID().uuidString)"
        let store = SessionStore.shared

        await store.process(.hookReceived(makeClaudeQuestionEvent(sessionId: sessionId)))

        let session = await store.session(for: sessionId)
        XCTAssertEqual(session?.phase, .waitingForInput)
        XCTAssertEqual(session?.intervention?.kind, .question)
        XCTAssertEqual(session?.intervention?.resolvedQuestions.first?.options.map(\.title), ["会话层", "UI 层"])

        await store.process(.sessionArchived(sessionId: sessionId))
    }

    func testDuplicatePermissionRequestKeepsClaudeQuestionInWaitingForInput() async {
        let sessionId = "claude-ask-\(UUID().uuidString)"
        let store = SessionStore.shared

        await store.process(.hookReceived(makeClaudeQuestionEvent(sessionId: sessionId)))
        await store.process(.hookReceived(makeClaudePermissionRequest(sessionId: sessionId)))

        let session = await store.session(for: sessionId)
        XCTAssertEqual(session?.phase, .waitingForInput)
        XCTAssertEqual(session?.intervention?.kind, .question)
        XCTAssertNil(session?.activePermission)
        XCTAssertFalse(session?.needsApprovalResponse ?? true)

        await store.process(.sessionArchived(sessionId: sessionId))
    }

    func testDuplicatePermissionRequestDoesNotRestoreApprovalAfterAnswer() async {
        let sessionId = "claude-answer-\(UUID().uuidString)"
        let store = SessionStore.shared

        await store.process(.hookReceived(makeClaudeQuestionEvent(sessionId: sessionId)))
        await store.process(
            .interventionResolved(
                sessionId: sessionId,
                nextPhase: .processing,
                submittedAnswers: ["project": ["会话层"]]
            )
        )
        await store.process(.hookReceived(makeClaudePermissionRequest(sessionId: sessionId)))

        let session = await store.session(for: sessionId)
        XCTAssertEqual(session?.phase, .processing)
        XCTAssertNil(session?.intervention)
        XCTAssertNil(session?.activePermission)

        await store.process(.sessionArchived(sessionId: sessionId))
    }

    func testQoderWorkPermissionRequestIsNotIgnoredAsClaudeDuplicate() async {
        let sessionId = "qoderwork-permission-\(UUID().uuidString)"
        let store = SessionStore.shared

        await store.process(.hookReceived(makeQoderWorkPermissionRequest(sessionId: sessionId)))

        let session = await store.session(for: sessionId)
        XCTAssertEqual(session?.intervention?.kind, .question)
        XCTAssertEqual(session?.phase, .waitingForInput)
        XCTAssertFalse(session?.needsApprovalResponse ?? true)

        await store.process(.sessionArchived(sessionId: sessionId))
    }

    private func makeClaudeQuestionEvent(sessionId: String) -> HookEvent {
        HookEvent(
            sessionId: sessionId,
            cwd: "/tmp/project",
            event: "PreToolUse",
            status: "waiting_for_input",
            provider: .claude,
            clientInfo: SessionClientInfo(
                kind: .claudeCode,
                profileID: "claude_code",
                name: "Claude Code",
                bundleIdentifier: "com.anthropic.claudecode"
            ),
            pid: nil,
            tty: nil,
            tool: "AskUserQuestion",
            toolInput: [
                "questions": AnyCodable([
                    [
                        "id": "project",
                        "header": "方向",
                        "question": "你想先处理哪个模块？",
                        "options": [
                            ["label": "会话层"],
                            ["label": "UI 层"]
                        ]
                    ]
                ])
            ],
            toolUseId: "toolu_\(sessionId)",
            notificationType: nil,
            message: nil
        )
    }

    private func makeClaudePermissionRequest(sessionId: String) -> HookEvent {
        HookEvent(
            sessionId: sessionId,
            cwd: "/tmp/project",
            event: "PermissionRequest",
            status: "waiting_for_approval",
            provider: .claude,
            clientInfo: SessionClientInfo(
                kind: .claudeCode,
                profileID: "claude_code",
                name: "Claude Code",
                bundleIdentifier: "com.anthropic.claudecode"
            ),
            pid: nil,
            tty: nil,
            tool: "AskUserQuestion",
            toolInput: [
                "questions": AnyCodable([
                    [
                        "id": "project",
                        "header": "方向",
                        "question": "你想先处理哪个模块？",
                        "options": [
                            ["label": "会话层"],
                            ["label": "UI 层"]
                        ]
                    ]
                ])
            ],
            toolUseId: "toolu_\(sessionId)",
            notificationType: nil,
            message: nil
        )
    }

    private func makeQoderWorkPermissionRequest(sessionId: String) -> HookEvent {
        HookEvent(
            sessionId: sessionId,
            cwd: "/tmp/project",
            event: "PermissionRequest",
            status: "waiting_for_input",
            provider: .claude,
            clientInfo: SessionClientInfo(
                kind: .qoder,
                profileID: "qoderwork",
                name: "QoderWork",
                bundleIdentifier: "com.qoder.work"
            ),
            pid: nil,
            tty: nil,
            tool: "AskUserQuestion",
            toolInput: [
                "questions": AnyCodable([
                    [
                        "id": "topic",
                        "header": "主题",
                        "question": "先选一个主题",
                        "options": [
                            ["label": "A 方案"],
                            ["label": "B 方案"]
                        ]
                    ]
                ])
            ],
            toolUseId: nil,
            notificationType: nil,
            message: nil
        )
    }
}
