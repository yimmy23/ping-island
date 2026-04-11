import AppKit
import SwiftUI

final class SettingsPanelWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private let defaultContentSize = NSSize(
        width: SettingsWindowDefaults.defaultContentSize.width,
        height: SettingsWindowDefaults.defaultContentSize.height
    )
    private let minimumContentSize = NSSize(
        width: AppSettings.minimumSettingsWindowSize.width,
        height: AppSettings.minimumSettingsWindowSize.height
    )
    private let maximumContentSize = NSSize(
        width: AppSettings.maximumSettingsWindowSize.width,
        height: AppSettings.maximumSettingsWindowSize.height
    )

    private init() {
        let hostingController = NSHostingController(
            rootView: SettingsWindowView()
        )
        let window = SettingsPanelWindow(
            contentRect: NSRect(origin: .zero, size: defaultContentSize),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.minSize = minimumContentSize
        window.maxSize = maximumContentSize
        window.setContentSize(defaultContentSize)
        window.identifier = NSUserInterfaceItemIdentifier("settings.window")
        window.center()
        window.toolbar = nil
        window.showsToolbarButton = false
        window.titlebarSeparatorStyle = .none
        window.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false

        super.init(window: window)

        self.window?.delegate = self
        hostingController.rootView = SettingsWindowView(
            onClose: { [weak self] in
                self?.dismiss()
            },
            onMinimize: { [weak self] in
                self?.window?.miniaturize(nil)
            }
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        guard let window else { return }

        window.minSize = minimumContentSize
        window.maxSize = maximumContentSize
        NSApp.activate(ignoringOtherApps: true)
        if !window.isVisible {
            window.center()
        }
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func dismiss() {
        window?.orderOut(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        dismiss()
        return false
    }
}
