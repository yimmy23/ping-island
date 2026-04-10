import AppKit
import Foundation

guard CommandLine.arguments.count >= 3 else {
    fputs("usage: generate-dmg-background.swift <output-path> <title>\n", stderr)
    exit(1)
}

let outputPath = CommandLine.arguments[1]
let title = CommandLine.arguments[2]

let size = NSSize(width: 780, height: 500)
let image = NSImage(size: size)

image.lockFocus()
defer { image.unlockFocus() }

let backgroundRect = NSRect(origin: .zero, size: size)
NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.14, alpha: 1).setFill()
backgroundRect.fill()

let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.21, green: 0.32, blue: 0.52, alpha: 1),
    NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.24, alpha: 1)
])!
gradient.draw(in: backgroundRect, angle: -25)

let glowPath = NSBezierPath(ovalIn: NSRect(x: 500, y: 260, width: 240, height: 180))
NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.20, alpha: 0.16).setFill()
glowPath.fill()

let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 34, weight: .bold),
    .foregroundColor: NSColor.white.withAlphaComponent(0.95)
]
let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 18, weight: .medium),
    .foregroundColor: NSColor.white.withAlphaComponent(0.72)
]

let titleString = NSString(string: title)
titleString.draw(at: NSPoint(x: 56, y: 390), withAttributes: titleAttributes)

let subtitle = NSString(string: "Drag Ping Island into Applications")
subtitle.draw(at: NSPoint(x: 56, y: 350), withAttributes: subtitleAttributes)

let arrowPath = NSBezierPath()
arrowPath.move(to: NSPoint(x: 320, y: 240))
arrowPath.line(to: NSPoint(x: 500, y: 240))
arrowPath.lineWidth = 10
NSColor.white.withAlphaComponent(0.55).setStroke()
arrowPath.stroke()

let arrowHead = NSBezierPath()
arrowHead.move(to: NSPoint(x: 500, y: 240))
arrowHead.line(to: NSPoint(x: 468, y: 262))
arrowHead.line(to: NSPoint(x: 468, y: 218))
arrowHead.close()
NSColor.white.withAlphaComponent(0.55).setFill()
arrowHead.fill()

guard
    let tiffData = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiffData),
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    fputs("failed to render background png\n", stderr)
    exit(1)
}

try pngData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
