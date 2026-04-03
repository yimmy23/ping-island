import SwiftUI

struct MarkdownText: View {
    let text: String
    let baseColor: Color
    let fontSize: CGFloat

    init(_ text: String, color: Color = .white.opacity(0.9), fontSize: CGFloat = 13) {
        self.text = text
        self.baseColor = color
        self.fontSize = fontSize
    }

    var body: some View {
        Text(text)
            .foregroundColor(baseColor)
            .font(.system(size: fontSize))
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct CodeBlockView: View {
    let code: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            SwiftUI.Text(code)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .padding(10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .cornerRadius(6)
    }
}
