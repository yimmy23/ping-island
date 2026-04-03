import Foundation
import os.log

actor CodexAppServerMonitor {
    static let shared = CodexAppServerMonitor()

    private enum PendingRequestKind {
        case commandApproval
        case fileApproval
        case permissionsApproval
        case userInput
    }

    private struct PendingRequest {
        let requestId: String
        let threadId: String
        let kind: PendingRequestKind
        let intervention: SessionIntervention
        let requestedPermissions: [String: Any]?
    }

    private let logger = Logger(subsystem: "com.wudanwu.island", category: "Codex")
    private let port = 41241

    private var process: Process?
    private var websocket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var requestSequence = 0
    private var pendingResponses: [String: CheckedContinuation<[String: Any], Error>] = [:]
    private var pendingRequestsByThread: [String: PendingRequest] = [:]

    private init() {}

    func start() async {
        if websocket != nil {
            return
        }

        if await connectToServer() {
            return
        }

        guard let executable = resolveCodexExecutable() else {
            logger.notice("Codex CLI not found; app-server monitor disabled")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["app-server", "--listen", "ws://127.0.0.1:\(port)"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            self.process = process
        } catch {
            logger.error("Failed to launch codex app-server: \(error.localizedDescription, privacy: .public)")
        }

        for _ in 0..<12 {
            try? await Task.sleep(for: .milliseconds(250))
            if await connectToServer() {
                return
            }
        }

        logger.error("Unable to connect to Codex app-server on port \(self.port)")
    }

    func stop() {
        receiveTask?.cancel()
        receiveTask = nil
        websocket?.cancel(with: .goingAway, reason: nil)
        websocket = nil
        process?.terminate()
        process = nil
        pendingRequestsByThread.removeAll()

        for (_, continuation) in pendingResponses {
            continuation.resume(throwing: CancellationError())
        }
        pendingResponses.removeAll()
    }

    func approve(threadId: String, forSession: Bool) async {
        guard let pending = pendingRequestsByThread[threadId] else { return }
        let result: [String: Any]

        switch pending.kind {
        case .commandApproval:
            result = ["decision": forSession ? "acceptForSession" : "accept"]
        case .fileApproval:
            result = ["decision": forSession ? "acceptForSession" : "accept"]
        case .permissionsApproval:
            result = [
                "permissions": pending.requestedPermissions ?? [:],
                "scope": forSession ? "session" : "turn"
            ]
        case .userInput:
            return
        }

        await sendResponse(id: pending.requestId, result: result)
        pendingRequestsByThread.removeValue(forKey: threadId)
        await SessionStore.shared.resolveCodexIntervention(sessionId: threadId, nextPhase: .processing)
    }

    func deny(threadId: String) async {
        guard let pending = pendingRequestsByThread[threadId] else { return }
        let result: [String: Any]

        switch pending.kind {
        case .commandApproval:
            result = ["decision": "decline"]
        case .fileApproval:
            result = ["decision": "decline"]
        case .permissionsApproval:
            result = [
                "permissions": [:],
                "scope": "turn"
            ]
        case .userInput:
            return
        }

        await sendResponse(id: pending.requestId, result: result)
        pendingRequestsByThread.removeValue(forKey: threadId)
        await SessionStore.shared.resolveCodexIntervention(sessionId: threadId, nextPhase: .processing)
    }

    func answer(threadId: String, answers: [String: [String]]) async {
        guard let pending = pendingRequestsByThread[threadId], pending.kind == .userInput else { return }

        let formattedAnswers = answers.reduce(into: [String: Any]()) { partial, entry in
            partial[entry.key] = ["answers": entry.value]
        }

        await sendResponse(
            id: pending.requestId,
            result: ["answers": formattedAnswers]
        )
        pendingRequestsByThread.removeValue(forKey: threadId)
        await SessionStore.shared.resolveCodexIntervention(sessionId: threadId, nextPhase: .processing)
    }

    private func connectToServer() async -> Bool {
        guard websocket == nil else { return true }
        guard let url = URL(string: "ws://127.0.0.1:\(port)") else { return false }

        let websocket = URLSession.shared.webSocketTask(with: url)
        websocket.resume()
        self.websocket = websocket

        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }

        do {
            _ = try await sendRequest(
                method: "initialize",
                params: [
                    "clientInfo": [
                        "name": "Island",
                        "title": "Island",
                        "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
                    ],
                    "capabilities": [
                        "experimentalApi": true
                    ]
                ]
            )

            if let response = try? await sendRequest(
                method: "thread/list",
                params: [
                    "archived": false,
                    "limit": 30,
                    "sortKey": "updated_at"
                ]
            ) {
                await ingestThreadList(response)
            }

            return true
        } catch {
            logger.debug("Codex websocket initialize failed: \(error.localizedDescription, privacy: .public)")
            receiveTask?.cancel()
            receiveTask = nil
            websocket.cancel(with: .goingAway, reason: nil)
            self.websocket = nil
            return false
        }
    }

    private func receiveLoop() async {
        while !Task.isCancelled {
            guard let websocket else { return }

            do {
                let message = try await websocket.receive()
                await handle(message)
            } catch {
                logger.debug("Codex websocket closed: \(error.localizedDescription, privacy: .public)")
                break
            }
        }

        websocket?.cancel(with: .goingAway, reason: nil)
        websocket = nil
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) async {
        let data: Data
        switch message {
        case .data(let raw):
            data = raw
        case .string(let text):
            data = Data(text.utf8)
        @unknown default:
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        if let method = json["method"] as? String {
            if let idValue = json["id"] {
                await handleServerRequest(
                    id: stringify(idValue),
                    method: method,
                    params: json["params"] as? [String: Any] ?? [:]
                )
            } else {
                await handleNotification(method: method, params: json["params"] as? [String: Any] ?? [:])
            }
            return
        }

        guard let idValue = json["id"] else { return }
        let id = stringify(idValue)

        if let continuation = pendingResponses.removeValue(forKey: id) {
            if let result = json["result"] as? [String: Any] {
                continuation.resume(returning: result)
            } else if json["result"] is NSNull {
                continuation.resume(returning: [:])
            } else if let errorObject = json["error"] as? [String: Any] {
                let message = (errorObject["message"] as? String) ?? "Unknown Codex app-server error"
                continuation.resume(throwing: NSError(domain: "CodexAppServer", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: message
                ]))
            } else {
                continuation.resume(returning: [:])
            }
        }
    }

    private func handleNotification(method: String, params: [String: Any]) async {
        switch method {
        case "thread/status/changed":
            let threadId = (params["threadId"] as? String) ?? ""
            guard !threadId.isEmpty else { return }
            let phase = phaseFromCodexStatus(params["status"] as? [String: Any], intervention: pendingRequestsByThread[threadId]?.intervention)
            await SessionStore.shared.upsertCodexSession(
                sessionId: threadId,
                name: nil,
                preview: nil,
                cwd: nil,
                phase: phase,
                intervention: pendingRequestsByThread[threadId]?.intervention
            )

        case "thread/started":
            if let thread = params["thread"] as? [String: Any] {
                await ingestThread(thread)
            }

        case "thread/name/updated":
            guard let threadId = params["threadId"] as? String else { return }
            await SessionStore.shared.updateCodexThreadName(
                sessionId: threadId,
                name: params["threadName"] as? String
            )

        case "thread/archived":
            guard let threadId = params["threadId"] as? String else { return }
            await SessionStore.shared.process(.sessionEnded(sessionId: threadId))

        default:
            break
        }
    }

    private func handleServerRequest(id: String, method: String, params: [String: Any]) async {
        switch method {
        case "item/commandExecution/requestApproval":
            let threadId = (params["threadId"] as? String) ?? (params["conversationId"] as? String) ?? ""
            guard !threadId.isEmpty else { return }

            let command = ((params["command"] as? [String]) ?? []).joined(separator: " ")
            let cwd = params["cwd"] as? String
            let reason = params["reason"] as? String
            let intervention = SessionIntervention(
                id: id,
                kind: .approval,
                title: "Approve Command",
                message: reason ?? (command.isEmpty ? "Codex wants to run a terminal command." : command),
                options: [],
                questions: [],
                supportsSessionScope: true,
                metadata: [
                    "command": command,
                    "cwd": cwd ?? ""
                ]
            )

            pendingRequestsByThread[threadId] = PendingRequest(
                requestId: id,
                threadId: threadId,
                kind: .commandApproval,
                intervention: intervention,
                requestedPermissions: nil
            )

            await SessionStore.shared.upsertCodexSession(
                sessionId: threadId,
                name: nil,
                preview: command.isEmpty ? reason : command,
                cwd: cwd,
                phase: .waitingForApproval(PermissionContext(
                    toolUseId: params["callId"] as? String ?? id,
                    toolName: "exec_command",
                    toolInput: nil,
                    receivedAt: Date()
                )),
                intervention: intervention
            )

        case "item/fileChange/requestApproval":
            guard let threadId = params["threadId"] as? String else { return }
            let reason = params["reason"] as? String
            let grantRoot = params["grantRoot"] as? String
            let intervention = SessionIntervention(
                id: id,
                kind: .approval,
                title: "Approve File Changes",
                message: reason ?? grantRoot ?? "Codex wants to modify files in this workspace.",
                options: [],
                questions: [],
                supportsSessionScope: true,
                metadata: [
                    "grantRoot": grantRoot ?? ""
                ]
            )

            pendingRequestsByThread[threadId] = PendingRequest(
                requestId: id,
                threadId: threadId,
                kind: .fileApproval,
                intervention: intervention,
                requestedPermissions: nil
            )

            await SessionStore.shared.upsertCodexSession(
                sessionId: threadId,
                name: nil,
                preview: reason ?? grantRoot,
                cwd: nil,
                phase: .waitingForApproval(PermissionContext(
                    toolUseId: params["itemId"] as? String ?? id,
                    toolName: "file_change",
                    toolInput: nil,
                    receivedAt: Date()
                )),
                intervention: intervention
            )

        case "item/permissions/requestApproval":
            guard let threadId = params["threadId"] as? String else { return }
            let permissions = params["permissions"] as? [String: Any] ?? [:]
            let reason = params["reason"] as? String
            let message = reason ?? permissionSummary(permissions)
            let intervention = SessionIntervention(
                id: id,
                kind: .approval,
                title: "Approve Permissions",
                message: message,
                options: [],
                questions: [],
                supportsSessionScope: true,
                metadata: [:]
            )

            pendingRequestsByThread[threadId] = PendingRequest(
                requestId: id,
                threadId: threadId,
                kind: .permissionsApproval,
                intervention: intervention,
                requestedPermissions: permissions
            )

            await SessionStore.shared.upsertCodexSession(
                sessionId: threadId,
                name: nil,
                preview: message,
                cwd: nil,
                phase: .waitingForApproval(PermissionContext(
                    toolUseId: params["itemId"] as? String ?? id,
                    toolName: "permissions_request",
                    toolInput: nil,
                    receivedAt: Date()
                )),
                intervention: intervention
            )

        case "item/tool/requestUserInput":
            guard let threadId = params["threadId"] as? String else { return }
            let questions = parseQuestions(params["questions"] as? [[String: Any]] ?? [])
            let prompt = questions.first?.prompt ?? "Codex needs your input."
            let intervention = SessionIntervention(
                id: id,
                kind: .question,
                title: "Codex Needs Input",
                message: prompt,
                options: questions.first?.options ?? [],
                questions: questions,
                supportsSessionScope: false,
                metadata: [
                    "turnId": params["turnId"] as? String ?? "",
                    "itemId": params["itemId"] as? String ?? ""
                ]
            )

            pendingRequestsByThread[threadId] = PendingRequest(
                requestId: id,
                threadId: threadId,
                kind: .userInput,
                intervention: intervention,
                requestedPermissions: nil
            )

            await SessionStore.shared.upsertCodexSession(
                sessionId: threadId,
                name: nil,
                preview: prompt,
                cwd: nil,
                phase: .waitingForInput,
                intervention: intervention
            )

        default:
            break
        }
    }

    private func sendRequest(method: String, params: [String: Any]) async throws -> [String: Any] {
        guard let websocket else {
            throw NSError(domain: "CodexAppServer", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Websocket not connected"
            ])
        }

        requestSequence += 1
        let id = String(requestSequence)
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "method": method,
            "params": params
        ]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])

        return try await withCheckedThrowingContinuation { continuation in
            pendingResponses[id] = continuation
            Task {
                do {
                    try await websocket.send(.data(data))
                } catch {
                    if let continuation = pendingResponses.removeValue(forKey: id) {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func sendResponse(id: String, result: [String: Any]) async {
        guard let websocket else { return }

        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "result": result
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else {
            return
        }

        do {
            try await websocket.send(.data(data))
        } catch {
            logger.error("Failed to send Codex response: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func ingestThreadList(_ response: [String: Any]) async {
        guard let data = response["data"] as? [[String: Any]] else { return }
        for thread in data {
            await ingestThread(thread)
        }
    }

    private func ingestThread(_ thread: [String: Any]) async {
        guard let threadId = thread["id"] as? String else { return }
        let name = thread["name"] as? String
        let preview = thread["preview"] as? String
        let cwd = thread["cwd"] as? String
        let phase = phaseFromCodexStatus(
            thread["status"] as? [String: Any],
            intervention: pendingRequestsByThread[threadId]?.intervention
        )

        await SessionStore.shared.upsertCodexSession(
            sessionId: threadId,
            name: name,
            preview: preview,
            cwd: cwd,
            phase: phase,
            intervention: pendingRequestsByThread[threadId]?.intervention
        )
    }

    private func phaseFromCodexStatus(_ status: [String: Any]?, intervention: SessionIntervention?) -> SessionPhase {
        guard let type = status?["type"] as? String else {
            if intervention?.kind == .question {
                return .waitingForInput
            }
            return .idle
        }

        if type == "active" {
            let flags = status?["activeFlags"] as? [String] ?? []
            if flags.contains("waitingOnApproval") {
                return .waitingForApproval(PermissionContext(
                    toolUseId: intervention?.id ?? UUID().uuidString,
                    toolName: intervention?.title ?? "approval",
                    toolInput: nil,
                    receivedAt: Date()
                ))
            }
            if flags.contains("waitingOnUserInput") {
                return .waitingForInput
            }
            return .processing
        }

        if type == "systemError" {
            return .idle
        }

        return .idle
    }

    private func parseQuestions(_ rawQuestions: [[String: Any]]) -> [SessionInterventionQuestion] {
        rawQuestions.map { question in
            let options = (question["options"] as? [[String: Any]] ?? []).enumerated().map { index, option in
                SessionInterventionOption(
                    id: option["label"] as? String ?? "option-\(index)",
                    title: option["label"] as? String ?? "Option \(index + 1)",
                    detail: option["description"] as? String
                )
            }

            return SessionInterventionQuestion(
                id: question["id"] as? String ?? UUID().uuidString,
                header: question["header"] as? String ?? "Question",
                prompt: question["question"] as? String ?? "",
                detail: nil,
                options: options,
                allowsOther: question["isOther"] as? Bool ?? false,
                isSecret: question["isSecret"] as? Bool ?? false
            )
        }
    }

    private func permissionSummary(_ permissions: [String: Any]) -> String {
        var parts: [String] = []

        if let fileSystem = permissions["fileSystem"] as? [String: Any] {
            if let read = fileSystem["read"] as? [String], !read.isEmpty {
                parts.append("Read: \(read.joined(separator: ", "))")
            }
            if let write = fileSystem["write"] as? [String], !write.isEmpty {
                parts.append("Write: \(write.joined(separator: ", "))")
            }
        }

        if let network = permissions["network"] as? [String: Any],
           let enabled = network["enabled"] as? Bool {
            parts.append(enabled ? "Network access requested" : "Network access disabled")
        }

        return parts.isEmpty ? "Codex requested extra permissions." : parts.joined(separator: "\n")
    }

    private func stringify(_ value: Any) -> String {
        if let string = value as? String {
            return string
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return String(describing: value)
    }

    private func resolveCodexExecutable() -> String? {
        let bundled = "/Applications/Codex.app/Contents/Resources/codex"
        if FileManager.default.isExecutableFile(atPath: bundled) {
            return bundled
        }

        return Foundation.ProcessInfo.processInfo.environment["PATH"]?
            .split(separator: ":")
            .map(String.init)
            .map { "\($0)/codex" }
            .first(where: FileManager.default.isExecutableFile(atPath:))
    }
}
