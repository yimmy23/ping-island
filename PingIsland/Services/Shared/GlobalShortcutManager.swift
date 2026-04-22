import AppKit
import Carbon.HIToolbox
import Combine

extension Notification.Name {
    static let pingIslandOpenActiveSessionShortcut = Notification.Name("pingIslandOpenActiveSessionShortcut")
    static let pingIslandOpenSessionListShortcut = Notification.Name("pingIslandOpenSessionListShortcut")
    static let pingIslandPresentNotchDetachmentHint = Notification.Name("pingIslandPresentNotchDetachmentHint")
}

@MainActor
final class GlobalShortcutManager {
    static let shared = GlobalShortcutManager()

    private var hotKeyRefs: [GlobalShortcutAction: EventHotKeyRef] = [:]
    private var eventHandlerRef: EventHandlerRef?
    private var cancellables = Set<AnyCancellable>()
    private let signature = GlobalShortcutManager.fourCharCode(from: "PISL")

    private init() {
        installEventHandlerIfNeeded()

        Publishers.CombineLatest(
            AppSettings.shared.$openActiveSessionShortcut,
            AppSettings.shared.$openSessionListShortcut
        )
        .sink { [weak self] _, _ in
            self?.refreshRegistrations()
        }
        .store(in: &cancellables)
    }

    func start() {
        refreshRegistrations()
    }

    private func refreshRegistrations() {
        unregisterAllHotKeys()

        var registeredShortcuts = Set<GlobalShortcut>()

        for action in GlobalShortcutAction.allCases {
            guard let shortcut = AppSettings.shortcut(for: action),
                  registeredShortcuts.insert(shortcut).inserted else {
                continue
            }

            register(shortcut, for: action)
        }
    }

    private func register(_ shortcut: GlobalShortcut, for action: GlobalShortcutAction) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: action.carbonID)
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            shortcut.carbonModifierFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let hotKeyRef else { return }
        hotKeyRefs[action] = hotKeyRef
    }

    private func unregisterAllHotKeys() {
        for hotKeyRef in hotKeyRefs.values {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRefs.removeAll()
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return OSStatus(eventNotHandledErr)
                }

                let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(userData).takeUnretainedValue()
                return manager.handleHotKeyEvent(event)
            },
            1,
            &eventSpec,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )
    }

    private func handleHotKeyEvent(_ event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else {
            return status
        }

        guard let action = GlobalShortcutAction.allCases.first(where: { $0.carbonID == hotKeyID.id }) else {
            return OSStatus(eventNotHandledErr)
        }

        switch action {
        case .openActiveSession:
            NotificationCenter.default.post(name: .pingIslandOpenActiveSessionShortcut, object: nil)
        case .openSessionList:
            NotificationCenter.default.post(name: .pingIslandOpenSessionListShortcut, object: nil)
        }

        return noErr
    }

    private static func fourCharCode(from string: String) -> OSType {
        string.utf8.prefix(4).reduce(0) { partial, character in
            (partial << 8) + OSType(character)
        }
    }
}
