import CoreGraphics

enum SettingsWindowDefaults {
    static let sidebarWidth: CGFloat = 236
    static let defaultDetailWidth: CGFloat = 540
    static let defaultContentSize = CGSize(
        width: sidebarWidth + defaultDetailWidth,
        height: 522
    )
}
