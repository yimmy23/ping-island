import AppKit
import XCTest
@testable import Ping_Island

@MainActor
final class AppSettingsPersistenceTests: XCTestCase {
    private static var retainedStores: [AppSettingsStore] = []

    private func makeDefaults(testName: String = #function) -> UserDefaults {
        let suiteName = "PingIslandTests.AppSettingsPersistence.\(testName)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeStore(defaults: UserDefaults) -> AppSettingsStore {
        let store = AppSettingsStore(defaults: defaults)
        Self.retainedStores.append(store)
        return store
    }

    func testShortcutLegacyDictionaryMigratesToDataStorage() {
        let defaults = makeDefaults()
        let key = "openActiveSessionShortcut"
        let modifiers: NSEvent.ModifierFlags = [.control, .option]
        let expected = GlobalShortcut(
            keyCode: 42,
            modifierFlags: modifiers
        )

        defaults.set(
            [
                "keyCode": 42,
                "modifierFlags": Int(modifiers.rawValue)
            ],
            forKey: key
        )

        let store = makeStore(defaults: defaults)

        XCTAssertEqual(store.shortcut(for: .openActiveSession), expected)
        XCTAssertNotNil(defaults.data(forKey: key))
        XCTAssertNil(defaults.dictionary(forKey: key))
    }

    func testMascotOverridesLegacyDictionaryMigratesToDataStorage() {
        let defaults = makeDefaults()
        let key = "mascotOverrides"

        defaults.set(
            [
                MascotClient.codex.rawValue: MascotKind.qoder.rawValue
            ],
            forKey: key
        )

        let store = makeStore(defaults: defaults)

        XCTAssertEqual(store.mascotOverride(for: .codex), .qoder)
        XCTAssertNotNil(defaults.data(forKey: key))
        XCTAssertNil(defaults.dictionary(forKey: key))
    }

    func testShortcutWritesTypedDataForFreshValues() {
        let defaults = makeDefaults()
        let key = "openSessionListShortcut"
        let store = makeStore(defaults: defaults)
        let shortcut = GlobalShortcut(
            keyCode: 44,
            modifierFlags: [.command, .shift]
        )

        store.setShortcut(shortcut, for: .openSessionList)
        let reloadedStore = makeStore(defaults: defaults)
        XCTAssertEqual(reloadedStore.shortcut(for: .openSessionList), shortcut)
        XCTAssertNotNil(defaults.data(forKey: key))
        XCTAssertNil(defaults.dictionary(forKey: key))
    }

    func testSubagentVisibilityModePersists() {
        let defaults = makeDefaults()
        let store = makeStore(defaults: defaults)

        XCTAssertEqual(store.subagentVisibilityMode, .visible)

        store.subagentVisibilityMode = .visible
        let reloadedStore = makeStore(defaults: defaults)
        XCTAssertEqual(reloadedStore.subagentVisibilityMode, .visible)
        XCTAssertEqual(defaults.string(forKey: "subagentVisibilityMode"), SubagentVisibilityMode.visible.rawValue)
        XCTAssertEqual(defaults.string(forKey: "codexSubagentVisibilityMode"), SubagentVisibilityMode.visible.rawValue)
    }

    func testSubagentVisibilityModeFallsBackToLegacyCodexKey() {
        let defaults = makeDefaults()
        defaults.set(SubagentVisibilityMode.hidden.rawValue, forKey: "codexSubagentVisibilityMode")

        let store = makeStore(defaults: defaults)

        XCTAssertEqual(store.subagentVisibilityMode, .hidden)
        XCTAssertEqual(defaults.string(forKey: "subagentVisibilityMode"), SubagentVisibilityMode.hidden.rawValue)
    }

    func testSubagentVisibilityModeMigratesLegacyAllValueToVisible() {
        let defaults = makeDefaults()
        defaults.set("all", forKey: "subagentVisibilityMode")

        let store = makeStore(defaults: defaults)

        XCTAssertEqual(store.subagentVisibilityMode, .visible)
    }

    func testAutoOpenCompactedNotificationPanelPersists() {
        let defaults = makeDefaults()
        let store = makeStore(defaults: defaults)

        XCTAssertTrue(store.autoOpenCompactedNotificationPanel)

        store.autoOpenCompactedNotificationPanel = false
        let reloadedStore = makeStore(defaults: defaults)
        XCTAssertFalse(reloadedStore.autoOpenCompactedNotificationPanel)
        XCTAssertEqual(defaults.object(forKey: "autoOpenCompactedNotificationPanel") as? Bool, false)
    }

    func testSurfaceModePersists() {
        let defaults = makeDefaults()
        let store = makeStore(defaults: defaults)

        store.surfaceMode = .floatingPet

        let reloadedStore = makeStore(defaults: defaults)
        XCTAssertEqual(reloadedStore.surfaceMode, .floatingPet)
        XCTAssertEqual(defaults.string(forKey: AppSettingsDefaultKeys.surfaceMode), IslandSurfaceMode.floatingPet.rawValue)
    }

    func testFloatingPetAnchorPersists() {
        let defaults = makeDefaults()
        let store = makeStore(defaults: defaults)
        let anchor = FloatingPetAnchor(xRatio: 0.82, yRatio: 0.14)

        store.floatingPetAnchor = anchor

        let reloadedStore = makeStore(defaults: defaults)
        XCTAssertEqual(reloadedStore.floatingPetAnchor, anchor)
        XCTAssertNotNil(defaults.data(forKey: AppSettingsDefaultKeys.floatingPetAnchor))
    }

    func testPresentationModeOnboardingPendingPersistsAndClears() {
        let defaults = makeDefaults()
        let store = makeStore(defaults: defaults)

        store.presentationModeOnboardingPending = true
        XCTAssertEqual(defaults.object(forKey: AppSettingsDefaultKeys.presentationModeOnboardingPending) as? Bool, true)

        store.presentationModeOnboardingPending = false

        let reloadedStore = makeStore(defaults: defaults)
        XCTAssertFalse(reloadedStore.presentationModeOnboardingPending)
        XCTAssertEqual(defaults.object(forKey: AppSettingsDefaultKeys.presentationModeOnboardingPending) as? Bool, false)
    }
}
