import AppKit
import SwiftUI
import XCTest
@testable import Ping_Island

@MainActor
final class IslandTextFieldTests: XCTestCase {
    func testTextFieldAcceptsFirstMouseForInactivePanelClicks() {
        let textField = IslandNSTextField()

        XCTAssertTrue(textField.acceptsFirstMouse(for: nil))
    }

    func testTextFieldUsesVisibleTextAndPlaceholderColors() {
        let textField = IslandNSTextField()
        textField.placeholderString = "Type Something ..."

        textField.configureTextAppearance()

        XCTAssertEqual(textField.textColor, NSColor.white)
        XCTAssertEqual(
            textField.placeholderAttributedString?.attribute(
                .foregroundColor,
                at: 0,
                effectiveRange: nil
            ) as? NSColor,
            NSColor.white.withAlphaComponent(0.38)
        )
    }

    func testEditableTextFieldKeepsFirstResponderDuringTransientFocusMismatch() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 80),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let textField = IslandNSTextField(frame: NSRect(x: 20, y: 20, width: 180, height: 24))
        let parent = IslandTextField(
            placeholder: "Answer",
            text: .constant(""),
            isFocused: false,
            isEditable: true
        )
        let coordinator = IslandTextField.Coordinator(parent: parent)
        textField.delegate = coordinator
        window.contentView = NSView(frame: window.contentView?.bounds ?? .zero)
        window.contentView?.addSubview(textField)
        defer { window.orderOut(nil) }

        coordinator.focus(textField)
        XCTAssertTrue(isEditing(textField, in: window))

        coordinator.syncFocus(for: textField)

        XCTAssertTrue(isEditing(textField, in: window))
    }

    private func isEditing(_ textField: IslandNSTextField, in window: NSWindow) -> Bool {
        guard let firstResponder = window.firstResponder else { return false }
        return firstResponder === textField || firstResponder === textField.currentEditor()
    }
}
