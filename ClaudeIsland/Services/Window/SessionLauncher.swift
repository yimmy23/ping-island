//
//  SessionLauncher.swift
//  ClaudeIsland
//
//  Activates the app or terminal that owns a session.
//

import AppKit
import Foundation
import os.log

actor SessionLauncher {
    static let shared = SessionLauncher()

    nonisolated private static let logger = Logger(subsystem: "com.wudanwu.island", category: "SessionLauncher")

    private init() {}

    func activate(_ session: SessionState) async -> Bool {
        if session.isInTmux, await activateTmuxSession(session) {
            return true
        }

        if let pid = session.pid, await activateTerminal(forProcess: pid) {
            return true
        }

        if session.provider == .codex, await activateApplication(bundleIdentifier: "com.openai.codex") {
            return true
        }

        Self.logger.debug("Unable to activate session \(session.sessionId, privacy: .public)")
        return false
    }

    private func activateTmuxSession(_ session: SessionState) async -> Bool {
        if await WindowFinder.shared.isYabaiAvailable() {
            if let pid = session.pid,
               await YabaiController.shared.focusWindow(forClaudePid: pid) {
                return true
            }

            if await YabaiController.shared.focusWindow(forWorkingDirectory: session.cwd) {
                return true
            }
        }

        let tree = ProcessTreeBuilder.shared.buildTree()

        if let pid = session.pid,
           let target = await TmuxController.shared.findTmuxTarget(forClaudePid: pid) {
            _ = await TmuxController.shared.switchToPane(target: target)

            if let terminalPid = await findTmuxClientTerminal(forSession: target.session, tree: tree) {
                return await activateApplication(processIdentifier: terminalPid)
            }

            return true
        }

        if let target = await TmuxController.shared.findTmuxTarget(forWorkingDirectory: session.cwd) {
            _ = await TmuxController.shared.switchToPane(target: target)

            if let terminalPid = await findTmuxClientTerminal(forSession: target.session, tree: tree) {
                return await activateApplication(processIdentifier: terminalPid)
            }

            return true
        }

        return false
    }

    private func activateTerminal(forProcess pid: Int) async -> Bool {
        let tree = ProcessTreeBuilder.shared.buildTree()
        guard let terminalPid = ProcessTreeBuilder.shared.findTerminalPid(forProcess: pid, tree: tree) else {
            return false
        }

        return await activateApplication(processIdentifier: terminalPid)
    }

    private func findTmuxClientTerminal(forSession session: String, tree: [Int: ProcessInfo]) async -> Int? {
        guard let tmuxPath = await TmuxPathFinder.shared.getTmuxPath() else {
            return nil
        }

        guard let output = await ProcessExecutor.shared.runOrNil(
            tmuxPath,
            arguments: ["list-clients", "-t", session, "-F", "#{client_pid}"]
        ) else {
            return nil
        }

        let clientPids = output
            .components(separatedBy: "\n")
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }

        for clientPid in clientPids {
            if let terminalPid = await terminalAncestor(forProcess: clientPid, tree: tree) {
                return terminalPid
            }
        }

        return nil
    }

    private func terminalAncestor(forProcess pid: Int, tree: [Int: ProcessInfo]) async -> Int? {
        var currentPid = pid
        var depth = 0

        while currentPid > 1 && depth < 20 {
            guard let info = tree[currentPid] else { break }

            if await MainActor.run(body: { TerminalAppRegistry.isTerminal(info.command) }) {
                return currentPid
            }

            currentPid = info.ppid
            depth += 1
        }

        return nil
    }

    private func activateApplication(processIdentifier pid: Int) async -> Bool {
        await MainActor.run {
            guard let app = NSRunningApplication(processIdentifier: pid_t(pid)) else {
                return false
            }

            return app.activate(options: [.activateAllWindows])
        }
    }

    private func activateApplication(bundleIdentifier: String) async -> Bool {
        if await MainActor.run(body: {
            NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
                .first?
                .activate(options: [.activateAllWindows]) ?? false
        }) {
            return true
        }

        guard let appURL = await MainActor.run(body: {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        }) else {
            return false
        }

        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { app, error in
                    if let error {
                        Self.logger.error("Failed to open \(bundleIdentifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
                        continuation.resume(returning: false)
                        return
                    }

                    let didActivate = app?.activate(options: [.activateAllWindows]) ?? true
                    continuation.resume(returning: didActivate)
                }
            }
        }
    }
}
