//
//  NotchViewModel.swift
//  ClaudeIsland
//
//  State management for the dynamic island
//

import AppKit
import Combine
import SwiftUI

enum NotchStatus: Equatable {
    case closed
    case opened
    case popping
}

enum NotchOpenReason {
    case click
    case hover
    case notification
    case boot
    case unknown
}

enum NotchContentType: Equatable {
    case instances
    case chat(SessionState)

    var id: String {
        switch self {
        case .instances: return "instances"
        case .chat(let session): return "chat-\(session.sessionId)"
        }
    }
}

@MainActor
class NotchViewModel: ObservableObject {
    // MARK: - Published State

    @Published var status: NotchStatus = .closed
    @Published var openReason: NotchOpenReason = .unknown
    @Published var contentType: NotchContentType = .instances
    @Published var isHovering: Bool = false
    @Published var hoverPreviewSession: SessionState?
    @Published private(set) var areInteractionsSuppressed = false
    @Published private(set) var isSettingsPopoverPresented = false

    // MARK: - Geometry

    let geometry: NotchGeometry
    let spacing: CGFloat = 12
    let hasPhysicalNotch: Bool
    let closedWidth: CGFloat = 266
    let closedHeight: CGFloat = 30

    var deviceNotchRect: CGRect { geometry.deviceNotchRect }
    var screenRect: CGRect { geometry.screenRect }
    var windowHeight: CGFloat { geometry.windowHeight }
    var closedSize: CGSize {
        CGSize(width: closedWidth, height: closedHeight)
    }
    var closedScreenRect: CGRect {
        CGRect(
            x: screenRect.midX - closedSize.width / 2,
            y: screenRect.maxY - closedSize.height,
            width: closedSize.width,
            height: closedSize.height
        )
    }

    /// Dynamic opened size based on content type
    var openedSize: CGSize {
        let maxPanelHeight = CGFloat(AppSettings.maxPanelHeight)

        if openReason == .hover {
            return CGSize(
                width: min(screenRect.width - 64, 600),
                height: min(screenRect.height - 120, max(460, maxPanelHeight - 60))
            )
        }

        switch contentType {
        case .chat:
            // Large size for chat view
            return CGSize(
                width: min(screenRect.width - 64, 600),
                height: min(screenRect.height - 120, maxPanelHeight)
            )
        case .instances:
            return CGSize(
                width: min(screenRect.width * 0.4, 480),
                height: 320
            )
        }
    }

    // MARK: - Animation

    var animation: Animation {
        .easeOut(duration: 0.25)
    }

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    private let events = EventMonitors.shared
    private var hoverTimer: DispatchWorkItem?

    // MARK: - Initialization

    init(deviceNotchRect: CGRect, screenRect: CGRect, windowHeight: CGFloat, hasPhysicalNotch: Bool) {
        self.geometry = NotchGeometry(
            deviceNotchRect: deviceNotchRect,
            screenRect: screenRect,
            windowHeight: windowHeight
        )
        self.hasPhysicalNotch = hasPhysicalNotch
        setupEventHandlers()
        observeEnvironment()
        refreshInteractionSuppression()
    }

    private func observeEnvironment() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        workspaceCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] _ in
                self?.refreshInteractionSuppression()
            }
            .store(in: &cancellables)

        workspaceCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .sink { [weak self] _ in
                self?.refreshInteractionSuppression()
            }
            .store(in: &cancellables)

        AppSettings.shared.$hideInFullscreen
            .sink { [weak self] _ in
                self?.refreshInteractionSuppression()
            }
            .store(in: &cancellables)

        AppSettings.shared.$maxPanelHeight
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    private func refreshInteractionSuppression() {
        let shouldSuppress = AppSettings.hideInFullscreen &&
            FullscreenAppDetector.isFullscreenAppActive(screenFrame: screenRect)

        guard shouldSuppress != areInteractionsSuppressed else { return }
        areInteractionsSuppressed = shouldSuppress

        if shouldSuppress {
            hoverTimer?.cancel()
            hoverTimer = nil
            isHovering = false
            if status == .opened {
                notchClose()
            }
        }
    }

    // MARK: - Event Handling

    private func setupEventHandlers() {
        events.mouseLocation
            .throttle(for: .milliseconds(50), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] location in
                self?.handleMouseMove(location)
            }
            .store(in: &cancellables)

        events.mouseDown
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleMouseDown()
            }
            .store(in: &cancellables)
    }

    /// Whether we're in chat mode (sticky behavior)
    private var isInChatMode: Bool {
        if case .chat = contentType { return true }
        return false
    }

    /// The chat session we're viewing (persists across close/open)
    private var currentChatSession: SessionState?

    private func handleMouseMove(_ location: CGPoint) {
        if areInteractionsSuppressed {
            hoverTimer?.cancel()
            hoverTimer = nil
            if isHovering {
                isHovering = false
            }
            return
        }

        let inNotch = isPointInClosedNotch(location)
        let inOpened = status == .opened && geometry.isPointInOpenedPanel(location, size: openedSize)

        let newHovering = inNotch || inOpened

        // Only update if changed to prevent unnecessary re-renders
        guard newHovering != isHovering else { return }

        isHovering = newHovering

        // Cancel any pending hover timer
        hoverTimer?.cancel()
        hoverTimer = nil

        if !newHovering,
           status == .opened,
           openReason == .hover,
           !isSettingsPopoverPresented,
           AppSettings.autoCollapseOnLeave {
            notchClose()
        }

        // Start hover timer to auto-expand after a short dwell
        if isHovering && (status == .closed || status == .popping) {
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self, self.isHovering else { return }
                self.notchOpen(reason: .hover)
            }
            hoverTimer = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: workItem)
        }
    }

    private func handleMouseDown() {
        if areInteractionsSuppressed {
            return
        }

        if isSettingsPopoverPresented {
            return
        }

        let location = NSEvent.mouseLocation

        switch status {
        case .opened:
            if geometry.isPointOutsidePanel(location, size: openedSize) {
                notchClose()
                // Re-post the click so it reaches the window/app behind us
                repostClickAt(location)
            } else if geometry.notchScreenRect.contains(location) {
                // Clicking notch while opened - only close if NOT in chat mode
                if !isInChatMode {
                    notchClose()
                }
            }
        case .closed, .popping:
            if isPointInClosedNotch(location) {
                notchOpen(reason: .click)
            }
        }
    }

    private func isPointInClosedNotch(_ point: CGPoint) -> Bool {
        closedScreenRect.insetBy(dx: -10, dy: -5).contains(point)
    }

    /// Re-posts a mouse click at the given screen location so it reaches windows behind us
    private func repostClickAt(_ location: CGPoint) {
        // Small delay to let the window's ignoresMouseEvents update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // Convert to CGEvent coordinate system (screen coordinates with Y from top-left)
            guard let screen = NSScreen.main else { return }
            let screenHeight = screen.frame.height
            let cgPoint = CGPoint(x: location.x, y: screenHeight - location.y)

            // Create and post mouse down event
            if let mouseDown = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseDown,
                mouseCursorPosition: cgPoint,
                mouseButton: .left
            ) {
                mouseDown.post(tap: .cghidEventTap)
            }

            // Create and post mouse up event
            if let mouseUp = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseUp,
                mouseCursorPosition: cgPoint,
                mouseButton: .left
            ) {
                mouseUp.post(tap: .cghidEventTap)
            }
        }
    }

    // MARK: - Actions

    func notchOpen(reason: NotchOpenReason = .unknown) {
        openReason = reason
        status = .opened

        if reason != .hover {
            hoverPreviewSession = nil
        }

        // Don't restore chat on notification - show instances list instead
        if reason == .notification {
            currentChatSession = nil
            return
        }

        // Hover opens a lightweight preview instead of restoring the full chat view.
        if reason == .hover {
            return
        }

        // Restore chat session if we had one open before
        if let chatSession = currentChatSession {
            // Avoid unnecessary updates if already showing this chat
            if case .chat(let current) = contentType, current.sessionId == chatSession.sessionId {
                return
            }
            contentType = .chat(chatSession)
        }
    }

    func notchClose() {
        // Save chat session before closing if in chat mode
        if case .chat(let session) = contentType {
            currentChatSession = session
        }
        status = .closed
        contentType = .instances
        hoverPreviewSession = nil
    }

    func notchPop() {
        guard status == .closed else { return }
        status = .popping
    }

    func notchUnpop() {
        guard status == .popping else { return }
        status = .closed
    }

    func setSettingsPopoverPresented(_ isPresented: Bool) {
        isSettingsPopoverPresented = isPresented
    }

    func showChat(for session: SessionState) {
        hoverPreviewSession = nil
        currentChatSession = session

        // Avoid unnecessary updates only when the snapshot is already current.
        if case .chat(let current) = contentType, current == session {
            return
        }
        contentType = .chat(session)
    }

    /// Go back to instances list and clear saved chat state
    func exitChat() {
        currentChatSession = nil
        contentType = .instances
    }

    func setHoverPreview(session: SessionState?) {
        if hoverPreviewSession?.sessionId == session?.sessionId {
            return
        }
        hoverPreviewSession = session
    }

    /// Perform boot animation: expand briefly then collapse
    func performBootAnimation() {
        notchOpen(reason: .boot)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, self.openReason == .boot else { return }
            self.notchClose()
        }
    }
}
