//
//  ClaudeIslandApp.swift
//  ClaudeIsland
//
//  Dynamic Island for monitoring Claude Code instances
//

import SwiftUI

@main
struct ClaudeIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsWindowView()
        }
        .defaultSize(width: 648, height: 522)
    }
}
