import Foundation
import IslandShared
@testable import IslandApp
import Testing

@Test
func sessionStorePrioritizesAttentionSessions() async throws {
    let recorder = await MainActor.run { SnapshotRecorder() }
    let store = SessionStore { snapshot in
        recorder.snapshot = snapshot
    }

    await store.ingest(
        BridgeEnvelope(
            provider: .claude,
            eventType: "PostToolUse",
            sessionKey: "claude:1",
            title: "Regular",
            preview: "working",
            status: SessionStatus(kind: .active)
        )
    )
    await store.ingest(
        BridgeEnvelope(
            provider: .claude,
            eventType: "PermissionRequest",
            sessionKey: "claude:2",
            title: "Needs approval",
            preview: "approve",
            status: SessionStatus(kind: .waitingForApproval),
            intervention: InterventionRequest(sessionID: "claude:2", kind: .approval, title: "Approval", message: "Approve?")
        )
    )

    let sessions = await MainActor.run { recorder.sessions }
    #expect(sessions.first?.id == "claude:2")
}

@MainActor
final class SnapshotRecorder {
    var snapshot = SessionSnapshot()

    var sessions: [AgentSession] {
        snapshot.sessions
    }
}
