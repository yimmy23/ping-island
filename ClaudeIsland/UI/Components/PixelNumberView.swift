import SwiftUI

struct PixelNumberView: View {
    let value: Int
    var color: Color = .white
    var pixelSize: CGFloat = 2
    var pixelSpacing: CGFloat = 1
    var digitSpacing: CGFloat = 2

    private var glyphs: [PixelGlyph] {
        let clampedValue = max(0, min(value, 99))
        return String(clampedValue).compactMap(PixelGlyph.init(character:))
    }

    var body: some View {
        HStack(spacing: digitSpacing) {
            ForEach(Array(glyphs.enumerated()), id: \.offset) { _, glyph in
                PixelGlyphView(
                    glyph: glyph,
                    color: color,
                    pixelSize: pixelSize,
                    pixelSpacing: pixelSpacing
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value)")
    }
}

private struct PixelGlyphView: View {
    let glyph: PixelGlyph
    let color: Color
    let pixelSize: CGFloat
    let pixelSpacing: CGFloat

    var body: some View {
        VStack(spacing: pixelSpacing) {
            ForEach(Array(glyph.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: pixelSpacing) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, isFilled in
                        Rectangle()
                            .fill(isFilled ? color : .clear)
                            .frame(width: pixelSize, height: pixelSize)
                    }
                }
            }
        }
        .fixedSize()
        .drawingGroup(opaque: false)
    }
}

private struct PixelGlyph {
    let rows: [[Bool]]

    nonisolated init?(character: Character) {
        switch character {
        case "0":
            rows = Self.makeRows([
                "111",
                "101",
                "101",
                "101",
                "111",
            ])
        case "1":
            rows = Self.makeRows([
                "010",
                "110",
                "010",
                "010",
                "111",
            ])
        case "2":
            rows = Self.makeRows([
                "111",
                "001",
                "111",
                "100",
                "111",
            ])
        case "3":
            rows = Self.makeRows([
                "111",
                "001",
                "111",
                "001",
                "111",
            ])
        case "4":
            rows = Self.makeRows([
                "101",
                "101",
                "111",
                "001",
                "001",
            ])
        case "5":
            rows = Self.makeRows([
                "111",
                "100",
                "111",
                "001",
                "111",
            ])
        case "6":
            rows = Self.makeRows([
                "111",
                "100",
                "111",
                "101",
                "111",
            ])
        case "7":
            rows = Self.makeRows([
                "111",
                "001",
                "001",
                "001",
                "001",
            ])
        case "8":
            rows = Self.makeRows([
                "111",
                "101",
                "111",
                "101",
                "111",
            ])
        case "9":
            rows = Self.makeRows([
                "111",
                "101",
                "111",
                "001",
                "111",
            ])
        default:
            return nil
        }
    }

    nonisolated private static func makeRows(_ rows: [String]) -> [[Bool]] {
        rows.map { row in
            row.map { $0 == "1" }
        }
    }
}
