import Foundation
import IslandShared
import Testing

@Test
func mapsApprovalEventFromClaudePayload() throws {
    let payload = """
    {
      "hook_event_name": "PermissionRequest",
      "tool_name": "Bash",
      "reason": "Needs to run tests",
      "session_id": "abc123"
    }
    """.data(using: .utf8)!

    let envelope = HookPayloadMapper.makeEnvelope(
        source: .claude,
        arguments: ["island-bridge", "--source", "claude"],
        environment: ["TERM_PROGRAM": "iTerm.app", "ITERM_SESSION_ID": "iterm-1", "PWD": "/tmp/demo"],
        stdinData: payload
    )

    #expect(envelope.provider == .claude)
    #expect(envelope.eventType == "PermissionRequest")
    #expect(envelope.intervention?.kind == .approval)
    #expect(envelope.status?.kind == .waitingForApproval)
    #expect(envelope.sessionKey == "claude:abc123")
}

@Test
func mapsQuestionEventOptions() throws {
    let payload = """
    {
      "questions": [{
        "id": "terminal_scope",
        "question": "Which terminal?",
        "options": [
          {"label": "iTerm2", "description": "Primary recommendation"},
          {"label": "Terminal", "description": "Fallback"}
        ]
      }]
    }
    """.data(using: .utf8)!

    let envelope = HookPayloadMapper.makeEnvelope(
        source: .codex,
        arguments: ["island-bridge", "--source", "codex"],
        environment: ["PWD": "/tmp/demo"],
        stdinData: payload
    )

    #expect(envelope.intervention?.kind == .question)
    #expect(envelope.intervention?.options.count == 2)
    #expect(envelope.status?.kind == .waitingForInput)
}
