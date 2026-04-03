import Foundation
import IslandShared

actor ApprovalCoordinator {
    private var pending: [UUID: CheckedContinuation<InterventionDecision, Never>] = [:]

    func waitForDecision(requestID: UUID) async -> InterventionDecision {
        await withCheckedContinuation { continuation in
            pending[requestID] = continuation
        }
    }

    func resolve(requestID: UUID, decision: InterventionDecision) {
        pending.removeValue(forKey: requestID)?.resume(returning: decision)
    }
}
