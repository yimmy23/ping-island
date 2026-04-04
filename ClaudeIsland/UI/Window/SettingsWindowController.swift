import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private let fixedContentSize = NSSize(width: 648, height: 522)
    private let frameBackdropView = NSVisualEffectView()

    private init() {
        let hostingController = NSHostingController(rootView: SettingsWindowView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 648, height: 522),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
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
        window.hasShadow = true
        window.minSize = fixedContentSize
        window.maxSize = fixedContentSize
        window.setContentSize(fixedContentSize)
        window.center()
        window.toolbar = nil
        window.showsToolbarButton = false
        window.titlebarSeparatorStyle = .none
        window.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.toolbarButton)?.isHidden = true

        super.init(window: window)

        configureFrameBackdrop()
        self.window?.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        guard let window else { return }

        window.setContentSize(fixedContentSize)
        window.minSize = fixedContentSize
        window.maxSize = fixedContentSize
        NSApp.activate(ignoringOtherApps: true)
        if !window.isVisible {
            window.center()
        }
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    private func configureFrameBackdrop() {
        guard
            let window,
            let frameView = window.contentView?.superview
        else {
            return
        }

        frameBackdropView.translatesAutoresizingMaskIntoConstraints = false
        frameBackdropView.material = .hudWindow
        frameBackdropView.blendingMode = .withinWindow
        frameBackdropView.state = .active
        frameBackdropView.wantsLayer = true
        frameBackdropView.layer?.backgroundColor = NSColor.clear.cgColor

        frameView.addSubview(frameBackdropView, positioned: .below, relativeTo: nil)

        NSLayoutConstraint.activate([
            frameBackdropView.leadingAnchor.constraint(equalTo: frameView.leadingAnchor),
            frameBackdropView.trailingAnchor.constraint(equalTo: frameView.trailingAnchor),
            frameBackdropView.topAnchor.constraint(equalTo: frameView.topAnchor),
            frameBackdropView.bottomAnchor.constraint(equalTo: frameView.bottomAnchor)
        ])
    }
}
