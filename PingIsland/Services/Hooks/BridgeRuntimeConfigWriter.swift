import Foundation

extension Notification.Name {
    static let bridgeRuntimeConfigDidChange = Notification.Name("BridgeRuntimeConfigDidChange")
}

/// Writes the small runtime config consumed by `PingIslandBridge` at hook time.
/// Schema must stay in sync with `BridgeRuntimeConfig` in `IslandShared`.
enum BridgeRuntimeConfigWriter {
    nonisolated static func write(routePromptsToTerminal: Bool) {
        let url = BridgeRuntimePaths.runtimeConfigURL

        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        guard let data = payloadData(routePromptsToTerminal: routePromptsToTerminal) else { return }

        try? data.write(to: url, options: .atomic)
    }

    nonisolated static func payloadData(routePromptsToTerminal: Bool) -> Data? {
        let payload: [String: Any] = [
            "routePromptsToTerminal": routePromptsToTerminal
        ]

        return try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )
    }
}
