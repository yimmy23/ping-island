import Combine
import Foundation
import os.log

@MainActor
final class RemoteConnectorManager: ObservableObject {
    static let shared = RemoteConnectorManager()

    @Published private(set) var endpoints: [RemoteEndpoint] = []
    @Published private(set) var runtimeStates: [UUID: RemoteEndpointRuntimeState] = [:]

    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.wudanwu.pingisland", category: "Remote")
    private let persistenceKey = "RemoteConnectorManager.endpoints.v1"

    private var eventHandler: (@Sendable (HookEvent) -> Void)?
    private var permissionFailureHandler: (@Sendable (_ sessionId: String, _ toolUseId: String) -> Void)?
    private var connectors: [UUID: RemoteAttachConnector] = [:]
    private var pendingRequests: [String: PendingRemoteRequest] = [:]
    private var ephemeralPasswords: [UUID: String] = [:]
    private var hasStarted = false
    private let assetResolver = RemoteBridgeAssetResolver()

    private init() {
        loadPersistedEndpoints()
    }

    func start(
        onEvent: @escaping @Sendable (HookEvent) -> Void,
        onPermissionFailure: (@Sendable (_ sessionId: String, _ toolUseId: String) -> Void)? = nil
    ) {
        eventHandler = onEvent
        permissionFailureHandler = onPermissionFailure

        guard !hasStarted else { return }
        hasStarted = true

        for endpoint in endpoints where endpoint.authMode == .publicKey {
            connect(endpointID: endpoint.id, password: nil, forceBootstrap: false)
        }
    }

    func stop() {
        hasStarted = false
        for connector in connectors.values {
            connector.stop()
        }
        connectors.removeAll()
        pendingRequests.removeAll()
    }

    @discardableResult
    func addEndpoint(displayName: String, sshTarget: String) -> RemoteEndpoint {
        let endpoint = RemoteEndpoint(
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            sshTarget: sshTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        endpoints.append(endpoint)
        persistEndpoints()
        runtimeStates[endpoint.id] = RemoteEndpointRuntimeState()
        return endpoint
    }

    func removeEndpoint(id: UUID) {
        disconnect(endpointID: id)
        endpoints.removeAll { $0.id == id }
        runtimeStates.removeValue(forKey: id)
        ephemeralPasswords.removeValue(forKey: id)
        pendingRequests = pendingRequests.filter { _, value in
            value.endpointID != id
        }
        persistEndpoints()
    }

    func connect(endpointID: UUID, password: String?, forceBootstrap: Bool = true) {
        guard let endpoint = endpoint(for: endpointID) else { return }

        if let password, !password.isEmpty {
            ephemeralPasswords[endpointID] = password
        }

        let effectivePassword = ephemeralPasswords[endpointID]
        setState(
            for: endpointID,
            phase: .probing,
            detail: "正在检测远程主机能力…",
            lastError: nil,
            requiresPassword: effectivePassword == nil && endpoint.authMode == .passwordSession
        )

        Task {
            do {
                let probe = try await RemoteSSHCommandRunner.probe(
                    target: endpoint.sshTarget,
                    password: effectivePassword
                )
                await MainActor.run {
                    self.applyProbe(probe, to: endpointID, passwordWasUsed: effectivePassword != nil)
                    self.setState(
                        for: endpointID,
                        phase: .bootstrapping,
                        detail: AppLocalization.format(
                            "正在安装远程桥接… %@ (%@)",
                            probe.operatingSystem,
                            probe.architecture
                        )
                    )
                }

                try await bootstrapRemoteAgent(endpointID: endpointID, password: effectivePassword, probe: probe)
                try await ensureRemoteAgentRunning(endpointID: endpointID, password: effectivePassword)
                try await attach(endpointID: endpointID, password: effectivePassword)
            } catch {
                await MainActor.run {
                    self.logger.error("Remote connect failed endpoint=\(endpoint.id.uuidString, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
                    self.setState(
                        for: endpointID,
                        phase: .failed,
                        detail: "远程连接失败",
                        lastError: error.localizedDescription,
                        requiresPassword: effectivePassword == nil && endpoint.authMode == .passwordSession
                    )
                }
            }
        }
    }

    func disconnect(endpointID: UUID) {
        connectors.removeValue(forKey: endpointID)?.stop()
        pendingRequests = pendingRequests.filter { _, request in
            request.endpointID != endpointID
        }
        setState(for: endpointID, phase: .disconnected, detail: "已断开远程转发连接")
    }

    func respondToPermission(toolUseId: String, decision: String, reason: String? = nil) {
        guard let pending = pendingRequests[toolUseId],
              let connector = connectors[pending.endpointID] else {
            return
        }

        Task {
            do {
                try await connector.sendDecision(
                    requestID: pending.requestID,
                    decision: decision,
                    reason: reason,
                    updatedInput: nil
                )
            } catch {
                await MainActor.run {
                    self.permissionFailureHandler?(pending.sessionID, toolUseId)
                }
            }
        }
    }

    func respondToIntervention(
        toolUseId: String,
        decision: String,
        updatedInput: [String: Any]?,
        reason: String? = nil
    ) {
        guard let pending = pendingRequests[toolUseId],
              let connector = connectors[pending.endpointID] else {
            return
        }

        let encodedInput = updatedInput?.mapValues { RemoteJSONValue.fromFoundationObject($0) }
        Task {
            do {
                try await connector.sendDecision(
                    requestID: pending.requestID,
                    decision: decision,
                    reason: reason,
                    updatedInput: encodedInput
                )
            } catch {
                await MainActor.run {
                    self.permissionFailureHandler?(pending.sessionID, toolUseId)
                }
            }
        }
    }

    private func attach(endpointID: UUID, password: String?) async throws {
        guard let endpoint = endpoint(for: endpointID) else { return }

        connectors.removeValue(forKey: endpointID)?.stop()
        setState(for: endpointID, phase: .connecting, detail: "正在建立远程转发通道…")

        let connector = RemoteAttachConnector(
            endpoint: endpoint,
            password: password,
            onMessage: { [weak self] message in
                await self?.handle(message: message, endpointID: endpointID)
            },
            onDisconnect: { [weak self] error in
                guard let manager = self else { return }
                Task { @MainActor in
                    manager.handleDisconnect(endpointID: endpointID, error: error)
                }
            }
        )

        try await connector.start()
        connectors[endpointID] = connector
    }

    private func handle(message: RemoteInboundMessage, endpointID: UUID) async {
        switch message {
        case .hello(let hello):
            if var currentEndpoint = endpoint(for: endpointID) {
                currentEndpoint.agentVersion = hello.version
                currentEndpoint.lastConnectedAt = Date()
                updateEndpoint(currentEndpoint)
            }
            setState(for: endpointID, phase: .connected, detail: "远程转发已连接", agentVersion: hello.version)

        case .hookEvent(let eventMessage):
            let payload = eventMessage.payload
            guard let provider = SessionProvider(rawValue: payload.provider) else {
                return
            }
            let clientInfo = SessionClientInfo(
                kind: SessionClientKind(rawValue: payload.clientInfo.kind) ?? .custom,
                profileID: payload.clientInfo.profileID,
                name: payload.clientInfo.name,
                bundleIdentifier: payload.clientInfo.bundleIdentifier,
                launchURL: payload.clientInfo.launchURL,
                origin: payload.clientInfo.origin,
                originator: payload.clientInfo.originator,
                threadSource: payload.clientInfo.threadSource,
                transport: payload.clientInfo.transport,
                remoteHost: payload.clientInfo.remoteHost,
                sessionFilePath: payload.clientInfo.sessionFilePath,
                terminalBundleIdentifier: payload.clientInfo.terminalBundleIdentifier,
                terminalProgram: payload.clientInfo.terminalProgram,
                terminalSessionIdentifier: payload.clientInfo.terminalSessionIdentifier,
                iTermSessionIdentifier: payload.clientInfo.iTermSessionIdentifier,
                tmuxSessionIdentifier: payload.clientInfo.tmuxSessionIdentifier,
                tmuxPaneIdentifier: payload.clientInfo.tmuxPaneIdentifier,
                processName: payload.clientInfo.processName
            )

            let event = HookEvent(
                sessionId: payload.sessionID,
                cwd: payload.cwd,
                event: payload.event,
                status: payload.status,
                provider: provider,
                clientInfo: clientInfo,
                pid: payload.pid,
                tty: payload.tty,
                tool: payload.tool,
                toolInput: payload.toolInput?.mapValues { AnyCodable($0.foundationObject) },
                toolUseId: payload.toolUseID,
                notificationType: payload.notificationType,
                message: payload.message,
                ingress: .remoteBridge
            )

            if payload.expectsResponse, let toolUseID = payload.toolUseID {
                pendingRequests[toolUseID] = PendingRemoteRequest(
                    endpointID: endpointID,
                    requestID: payload.requestID,
                    sessionID: payload.sessionID
                )
            }

            eventHandler?(event)
        }
    }

    private func handleDisconnect(endpointID: UUID, error: Error?) {
        connectors.removeValue(forKey: endpointID)
        setState(
            for: endpointID,
            phase: .degraded,
            detail: "远程转发已断开",
            lastError: error?.localizedDescription,
            requiresPassword: endpoint(for: endpointID)?.authMode == .passwordSession
        )
    }

    private func applyProbe(_ probe: RemoteHostProbe, to endpointID: UUID, passwordWasUsed: Bool) {
        guard var endpoint = endpoint(for: endpointID) else { return }
        endpoint.detectedUsername = probe.username
        endpoint.detectedHostname = probe.hostname
        endpoint.detectedHomeDirectory = probe.homeDirectory
        endpoint.hostFingerprint = probe.fingerprint
        endpoint.authMode = passwordWasUsed ? .passwordSession : .publicKey
        endpoint.remoteInstallRoot = resolvedRemotePath(endpoint.remoteInstallRoot, homeDirectory: probe.homeDirectory)
        endpoint.remoteHookSocketPath = resolvedRemotePath(endpoint.remoteHookSocketPath, homeDirectory: probe.homeDirectory)
        endpoint.remoteControlSocketPath = resolvedRemotePath(endpoint.remoteControlSocketPath, homeDirectory: probe.homeDirectory)
        updateEndpoint(endpoint)
    }

    private func bootstrapRemoteAgent(endpointID: UUID, password: String?, probe: RemoteHostProbe) async throws {
        guard let endpoint = endpoint(for: endpointID) else { return }
        let bridgeBinaryURL = try await assetResolver.resolveBinaryURL(for: probe)
        guard let claudeProfile = ClientProfileRegistry.managedHookProfile(id: "claude-hooks") else {
            throw RemoteConnectorError.missingClaudeHookProfile
        }

        _ = try await RemoteSSHCommandRunner.runSSH(
            target: endpoint.sshTarget,
            password: password,
            remoteCommand: """
            mkdir -p \(quoted(endpoint.remoteInstallRoot))/bin \(quoted(endpoint.remoteInstallRoot))/run \(quoted(endpoint.remoteInstallRoot))/logs "$HOME/.claude"
            """,
            acceptNewHostKey: true
        )

        try await RemoteSSHCommandRunner.copyFile(
            localURL: bridgeBinaryURL,
            remoteTarget: endpoint.sshTarget,
            remotePath: "\(endpoint.remoteInstallRoot)/bin/PingIslandBridge",
            password: password
        )

        let launcherScript = """
        #!/bin/sh
        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
        exec "$SCRIPT_DIR/PingIslandBridge" "$@"
        """
        try await RemoteSSHCommandRunner.writeRemoteFile(
            target: endpoint.sshTarget,
            remotePath: "\(endpoint.remoteInstallRoot)/bin/ping-island-bridge",
            contents: launcherScript.data(using: .utf8) ?? Data(),
            password: password
        )
        _ = try await RemoteSSHCommandRunner.runSSH(
            target: endpoint.sshTarget,
            password: password,
            remoteCommand: """
            chmod 755 \(quoted(endpoint.remoteInstallRoot))/bin/PingIslandBridge \(quoted(endpoint.remoteInstallRoot))/bin/ping-island-bridge
            """,
            acceptNewHostKey: true
        )

        let existingConfig = try? await RemoteSSHCommandRunner.readRemoteFile(
            target: endpoint.sshTarget,
            remotePath: "\(probe.homeDirectory)/.claude/settings.json",
            password: password
        )
        let remoteCommand = HookInstaller.managedBridgeCommand(
            source: claudeProfile.bridgeSource,
            extraArguments: claudeProfile.bridgeExtraArguments,
            launcherPath: "\(endpoint.remoteInstallRoot)/bin/ping-island-bridge",
            socketPath: endpoint.remoteHookSocketPath
        )
        let updatedData = HookInstaller.updatedConfigurationData(
            existingData: existingConfig,
            profile: claudeProfile,
            customCommand: remoteCommand,
            installing: true
        )
        try await RemoteSSHCommandRunner.writeRemoteFile(
            target: endpoint.sshTarget,
            remotePath: "\(probe.homeDirectory)/.claude/settings.json",
            contents: updatedData,
            password: password
        )

        if var refreshed = self.endpoint(for: endpointID) {
            refreshed.lastBootstrapAt = Date()
            updateEndpoint(refreshed)
        }
    }

    private func ensureRemoteAgentRunning(endpointID: UUID, password: String?) async throws {
        guard let endpoint = endpoint(for: endpointID) else { return }
        let command = """
        mkdir -p \(quoted(endpoint.remoteInstallRoot))/run \(quoted(endpoint.remoteInstallRoot))/logs
        if [ -S \(quoted(endpoint.remoteControlSocketPath)) ]; then
          exit 0
        fi
        nohup \(quoted(endpoint.remoteInstallRoot))/bin/ping-island-bridge --mode remote-agent-service --hook-socket \(quoted(endpoint.remoteHookSocketPath)) --control-socket \(quoted(endpoint.remoteControlSocketPath)) > \(quoted(endpoint.remoteInstallRoot))/logs/remote-agent.log 2>&1 &
        sleep 1
        """
        _ = try await RemoteSSHCommandRunner.runSSH(
            target: endpoint.sshTarget,
            password: password,
            remoteCommand: command,
            acceptNewHostKey: true
        )
    }

    private func endpoint(for id: UUID) -> RemoteEndpoint? {
        endpoints.first { $0.id == id }
    }

    private func updateEndpoint(_ endpoint: RemoteEndpoint) {
        guard let index = endpoints.firstIndex(where: { $0.id == endpoint.id }) else {
            return
        }
        endpoints[index] = endpoint
        persistEndpoints()
    }

    private func setState(
        for endpointID: UUID,
        phase: RemoteEndpointConnectionPhase,
        detail: String,
        lastError: String? = nil,
        requiresPassword: Bool = false,
        agentVersion: String? = nil
    ) {
        let currentVersion = agentVersion ?? runtimeStates[endpointID]?.agentVersion
        runtimeStates[endpointID] = RemoteEndpointRuntimeState(
            phase: phase,
            detail: detail,
            lastError: lastError,
            requiresPassword: requiresPassword,
            agentVersion: currentVersion
        )
    }

    private func loadPersistedEndpoints() {
        guard let data = defaults.data(forKey: persistenceKey),
              let decoded = try? JSONDecoder().decode([RemoteEndpoint].self, from: data) else {
            endpoints = []
            return
        }
        endpoints = decoded
        runtimeStates = Dictionary(uniqueKeysWithValues: decoded.map { endpoint in
            (endpoint.id, RemoteEndpointRuntimeState(agentVersion: endpoint.agentVersion))
        })
    }

    private func persistEndpoints() {
        guard let data = try? JSONEncoder().encode(endpoints) else { return }
        defaults.set(data, forKey: persistenceKey)
    }

    private func resolvedRemotePath(_ path: String, homeDirectory: String) -> String {
        guard path.hasPrefix("~/") else { return path }
        return homeDirectory + "/" + path.dropFirst(2)
    }

    private func quoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}

private struct PendingRemoteRequest {
    let endpointID: UUID
    let requestID: UUID
    let sessionID: String
}

private enum RemoteConnectorError: LocalizedError {
    case localBridgeBinaryMissing
    case missingClaudeHookProfile
    case invalidRemoteMessage
    case unsupportedRemotePlatform(String)
    case remoteBridgeDownloadFailed(String)
    case sshFailure(String)

    var errorDescription: String? {
        switch self {
        case .localBridgeBinaryMissing:
            return "本地 PingIslandBridge 二进制不存在，无法安装到远程主机"
        case .missingClaudeHookProfile:
            return "未找到 Claude hooks 配置模板"
        case .invalidRemoteMessage:
            return "远程桥接返回了无法识别的消息"
        case .unsupportedRemotePlatform(let detail):
            return detail
        case .remoteBridgeDownloadFailed(let detail):
            return detail
        case .sshFailure(let detail):
            return detail
        }
    }
}

private final class RemoteAttachConnector {
    private let endpoint: RemoteEndpoint
    private let password: String?
    private let onMessage: @Sendable (RemoteInboundMessage) async -> Void
    private let onDisconnect: @Sendable (Error?) -> Void

    private var process: Process?
    private var stdinHandle: FileHandle?
    private var readTask: Task<Void, Never>?

    init(
        endpoint: RemoteEndpoint,
        password: String?,
        onMessage: @escaping @Sendable (RemoteInboundMessage) async -> Void,
        onDisconnect: @escaping @Sendable (Error?) -> Void
    ) {
        self.endpoint = endpoint
        self.password = password
        self.onMessage = onMessage
        self.onDisconnect = onDisconnect
    }

    func start() async throws {
        let stdoutPipe = Pipe()
        let stdinPipe = Pipe()
        let process = try RemoteSSHCommandRunner.makeSSHProcess(
            target: endpoint.sshTarget,
            password: password,
            remoteCommand: "\(shellQuote("\(endpoint.remoteInstallRoot)/bin/ping-island-bridge")) --mode remote-agent-attach --control-socket \(shellQuote(endpoint.remoteControlSocketPath))",
            acceptNewHostKey: true
        )
        process.standardOutput = stdoutPipe
        process.standardError = Pipe()
        process.standardInput = stdinPipe

        try process.run()
        self.process = process
        self.stdinHandle = stdinPipe.fileHandleForWriting
        self.readTask = Task.detached(priority: .userInitiated) { [weak self] in
            await self?.readLoop(handle: stdoutPipe.fileHandleForReading)
        }
        process.terminationHandler = { [weak self] process in
            self?.onDisconnect(process.terminationStatus == 0 ? nil : RemoteConnectorError.sshFailure("SSH attach 已断开"))
        }
    }

    func stop() {
        readTask?.cancel()
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
        stdinHandle = nil
    }

    func sendDecision(
        requestID: UUID,
        decision: String,
        reason: String?,
        updatedInput: [String: RemoteJSONValue]?
    ) async throws {
        let message = RemoteDecisionMessage(
            requestID: requestID,
            decision: decision,
            reason: reason,
            updatedInput: updatedInput
        )
        let data = try JSONEncoder().encode(message) + Data("\n".utf8)
        try stdinHandle?.write(contentsOf: data)
    }

    private func readLoop(handle: FileHandle) async {
        var buffer = Data()

        do {
            while !Task.isCancelled {
                let chunk = try handle.read(upToCount: 4096) ?? Data()
                if chunk.isEmpty { break }

                buffer.append(chunk)
                while let newlineRange = buffer.firstRange(of: Data([0x0A])) {
                    let line = buffer.subdata(in: 0..<newlineRange.lowerBound)
                    buffer.removeSubrange(0...newlineRange.lowerBound)
                    guard !line.isEmpty else { continue }
                    let message = try JSONDecoder().decode(RemoteInboundMessage.self, from: line)
                    await onMessage(message)
                }
            }
            onDisconnect(nil)
        } catch {
            onDisconnect(error)
        }
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}

private enum RemoteInboundMessage: Decodable {
    case hello(RemoteDaemonHello)
    case hookEvent(RemoteHookEventMessage)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "hello":
            self = .hello(try RemoteDaemonHello(from: decoder))
        case "hook_event":
            self = .hookEvent(try RemoteHookEventMessage(from: decoder))
        default:
            throw RemoteConnectorError.invalidRemoteMessage
        }
    }
}

private struct SSHExecutionResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

private enum RemoteSSHCommandRunner {
    static func probe(target: String, password: String?) async throws -> RemoteHostProbe {
        let command = #"printf "%s\n" "$USER" "$HOSTNAME" "$HOME"; uname -s; uname -m; command -v claude >/dev/null 2>&1 && echo "__PING_ISLAND_HAS_CLAUDE__=1" || echo "__PING_ISLAND_HAS_CLAUDE__=0"; command -v tmux >/dev/null 2>&1 && echo "__PING_ISLAND_HAS_TMUX__=1" || echo "__PING_ISLAND_HAS_TMUX__=0""#
        let result = try await runSSH(
            target: target,
            password: password,
            remoteCommand: command,
            acceptNewHostKey: true
        )
        let lines = result.stdout
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        guard lines.count >= 7 else {
            throw RemoteConnectorError.sshFailure("远程主机返回的信息不完整")
        }
        let fingerprint = localKnownHostFingerprint(for: target)
        return RemoteHostProbe(
            username: lines[0],
            hostname: lines[1],
            homeDirectory: lines[2],
            operatingSystem: lines[3],
            architecture: lines[4],
            hasClaude: lines[5].contains("=1"),
            hasTmux: lines[6].contains("=1"),
            fingerprint: fingerprint
        )
    }

    static func readRemoteFile(target: String, remotePath: String, password: String?) async throws -> Data {
        let result = try await runSSH(
            target: target,
            password: password,
            remoteCommand: "cat \(shellQuote(remotePath))",
            acceptNewHostKey: true,
            allowFailure: true
        )
        return Data(result.stdout.utf8)
    }

    static func writeRemoteFile(target: String, remotePath: String, contents: Data, password: String?) async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ping-island-remote-\(UUID().uuidString)")
        try contents.write(to: tempURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try await copyFile(localURL: tempURL, remoteTarget: target, remotePath: remotePath, password: password)
    }

    static func copyFile(localURL: URL, remoteTarget: String, remotePath: String, password: String?) async throws {
        let process = try makeSecureCopyProcess(
            localURL: localURL,
            remoteTarget: remoteTarget,
            remotePath: remotePath,
            password: password
        )
        let result = try await run(process: process)
        guard result.exitCode == 0 else {
            throw RemoteConnectorError.sshFailure(result.stderr.isEmpty ? "SCP 复制失败" : result.stderr)
        }
    }

    static func runSSH(
        target: String,
        password: String?,
        remoteCommand: String,
        acceptNewHostKey: Bool,
        allowFailure: Bool = false
    ) async throws -> SSHExecutionResult {
        let process = try makeSSHProcess(
            target: target,
            password: password,
            remoteCommand: remoteCommand,
            acceptNewHostKey: acceptNewHostKey
        )
        let result = try await run(process: process)
        guard allowFailure || result.exitCode == 0 else {
            let detail = result.stderr.isEmpty ? result.stdout : result.stderr
            throw RemoteConnectorError.sshFailure(detail.isEmpty ? "SSH 执行失败" : detail)
        }
        return result
    }

    static func makeSSHProcess(
        target: String,
        password: String?,
        remoteCommand: String,
        acceptNewHostKey: Bool
    ) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = sshArguments(
            target: target,
            password: password,
            remoteCommand: remoteCommand,
            acceptNewHostKey: acceptNewHostKey
        )
        process.environment = try sshEnvironment(password: password)
        return process
    }

    private static func makeSecureCopyProcess(
        localURL: URL,
        remoteTarget: String,
        remotePath: String,
        password: String?
    ) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/scp")
        process.arguments = scpArguments(
            localPath: localURL.path,
            remoteTarget: remoteTarget,
            remotePath: remotePath,
            password: password
        )
        process.environment = try sshEnvironment(password: password)
        return process
    }

    private static func run(process: Process) async throws -> SSHExecutionResult {
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                continuation.resume(
                    returning: SSHExecutionResult(
                        stdout: stdout.trimmingCharacters(in: .whitespacesAndNewlines),
                        stderr: stderr.trimmingCharacters(in: .whitespacesAndNewlines),
                        exitCode: process.terminationStatus
                    )
                )
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func sshArguments(
        target: String,
        password: String?,
        remoteCommand: String,
        acceptNewHostKey: Bool
    ) -> [String] {
        var arguments = commonSSHOptions(password: password, acceptNewHostKey: acceptNewHostKey)
        arguments.append(target)
        arguments.append(remoteCommand)
        return arguments
    }

    private static func scpArguments(
        localPath: String,
        remoteTarget: String,
        remotePath: String,
        password: String?
    ) -> [String] {
        var arguments = commonSSHOptions(password: password, acceptNewHostKey: true)
        arguments.append(localPath)
        arguments.append("\(remoteTarget):\(remotePath)")
        return arguments
    }

    private static func commonSSHOptions(password: String?, acceptNewHostKey: Bool) -> [String] {
        var options = [
            "-o", "ConnectTimeout=10",
            "-o", "ServerAliveInterval=20",
            "-o", "ServerAliveCountMax=3",
            "-o", acceptNewHostKey ? "StrictHostKeyChecking=accept-new" : "StrictHostKeyChecking=yes"
        ]
        if password == nil {
            options += ["-o", "BatchMode=yes"]
        } else {
            options += ["-o", "BatchMode=no"]
        }
        return options
    }

    private static func sshEnvironment(password: String?) throws -> [String: String] {
        guard let password, !password.isEmpty else {
            return Foundation.ProcessInfo.processInfo.environment
        }

        let askpassURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ping-island-askpass-\(UUID().uuidString)")
        let script = """
        #!/bin/sh
        printf '%s' "$PING_ISLAND_REMOTE_PASSWORD"
        """
        try script.write(to: askpassURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: askpassURL.path)

        var environment = Foundation.ProcessInfo.processInfo.environment
        environment["SSH_ASKPASS"] = askpassURL.path
        environment["SSH_ASKPASS_REQUIRE"] = "force"
        environment["PING_ISLAND_REMOTE_PASSWORD"] = password
        environment["DISPLAY"] = environment["DISPLAY"] ?? "ping-island:0"
        return environment
    }

    private static func localKnownHostFingerprint(for target: String) -> String? {
        let host = target.split(separator: "@").last.map(String.init) ?? target
        return ProcessExecutor.shared.runSyncOrNil(
            "/usr/bin/ssh-keygen",
            arguments: ["-F", host]
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}

@MainActor
private final class RemoteBridgeAssetResolver {
    private let fileManager = FileManager.default

    func resolveBinaryURL(for probe: RemoteHostProbe) async throws -> URL {
        switch probe.operatingSystem.lowercased() {
        case "darwin":
            guard let localURL = HookInstaller.remoteBridgeBinaryURL() else {
                throw RemoteConnectorError.localBridgeBinaryMissing
            }
            return localURL
        case "linux":
            return try await downloadLinuxBridge(for: probe.architecture)
        default:
            throw RemoteConnectorError.unsupportedRemotePlatform(
                AppLocalization.format(
                    "当前内置远程 bridge 仅支持 macOS 与 Linux 远程主机，检测到的是 %@ (%@)",
                    probe.operatingSystem,
                    probe.architecture
                )
            )
        }
    }

    private func downloadLinuxBridge(for architecture: String) async throws -> URL {
        let normalizedArch: String
        switch architecture.lowercased() {
        case "x86_64", "amd64":
            normalizedArch = "x86_64"
        default:
            throw RemoteConnectorError.unsupportedRemotePlatform(
                AppLocalization.format(
                    "当前 Linux 远程 bridge 暂不支持架构 %@",
                    architecture
                )
            )
        }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let assetName = "PingIslandBridge-linux-\(normalizedArch)"
        let cacheDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".ping-island", isDirectory: true)
            .appendingPathComponent("remote-cache", isDirectory: true)
            .appendingPathComponent(version, isDirectory: true)
        let cachedURL = cacheDirectory.appendingPathComponent(assetName)

        if fileManager.isReadableFile(atPath: cachedURL.path) {
            return cachedURL
        }

        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        let releaseURLString = "https://github.com/erha19/ping-island/releases/download/v\(version)/\(assetName)"
        guard let releaseURL = URL(string: releaseURLString) else {
            throw RemoteConnectorError.remoteBridgeDownloadFailed(
                AppLocalization.format("Linux 远程 bridge 下载地址无效：%@", releaseURLString)
            )
        }

        let (downloadedURL, response) = try await URLSession.shared.download(from: releaseURL)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw RemoteConnectorError.remoteBridgeDownloadFailed(
                AppLocalization.format("无法从 GitHub Release 下载 Linux 远程 bridge（HTTP %lld）", (response as? HTTPURLResponse)?.statusCode ?? -1)
            )
        }

        if fileManager.fileExists(atPath: cachedURL.path) {
            try fileManager.removeItem(at: cachedURL)
        }
        try fileManager.moveItem(at: downloadedURL, to: cachedURL)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cachedURL.path)
        return cachedURL
    }
}
