//
//  WindowManager.swift
//  PingIsland
//
//  Manages the notch window lifecycle
//

import AppKit
import os.log

/// Logger for window management
private let logger = Logger(subsystem: "com.wudanwu.pingisland", category: "Window")

@MainActor
class WindowManager {
    private(set) var presentationCoordinator: IslandPresentationCoordinator?

    /// Set up or recreate the notch window
    func setupNotchWindow() -> NotchWindowController? {
        // Use ScreenSelector for screen selection
        let screenSelector = ScreenSelector.shared
        screenSelector.refreshScreens()

        guard let screen = screenSelector.selectedScreen else {
            logger.warning("No screen found")
            return nil
        }

        if let presentationCoordinator {
            presentationCoordinator.updateScreen(screen)
            return nil
        }

        let presentationCoordinator = IslandPresentationCoordinator(screen: screen)
        self.presentationCoordinator = presentationCoordinator
        return nil
    }
}
