import AppKit
import Foundation
import SwiftUI

@MainActor
@main
struct QwenPosterExporterMain {
    static func main() throws {
        let options = try PosterOptions(arguments: Array(CommandLine.arguments.dropFirst()))
        try options.prepareOutputDirectory()

        let outputURL = options.outputDirectory.appendingPathComponent(options.outputName)
        let posterView = QwenPosterView(options: options)
            .frame(width: options.canvasSize.width, height: options.canvasSize.height)

        let renderer = ImageRenderer(content: posterView)
        renderer.scale = 1
        renderer.isOpaque = true
        renderer.proposedSize = .init(width: options.canvasSize.width, height: options.canvasSize.height)

        guard let cgImage = renderer.cgImage else {
            throw PosterExportError.failedToRender(outputURL.path)
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw PosterExportError.failedToEncode(outputURL.path)
        }

        try data.write(to: outputURL, options: .atomic)
        print("wrote \(outputURL.path)")
    }
}

private struct PosterOptions {
    let outputDirectory: URL
    let outputName: String
    let canvasSize: CGSize
    let logoURL: URL
    let mascotURL: URL

    init(arguments: [String]) throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        var outputDirectory = cwd.appendingPathComponent("docs/images", isDirectory: true)
        var outputName = "ping-island-qwen-poster.png"
        var width = 2800
        var height = 1800
        var logoURL = cwd.appendingPathComponent("PingIsland/Assets.xcassets/QwenLogo.imageset/qwen-logo.png")
        var mascotURL = cwd.appendingPathComponent("docs/images/mascots/qwen.gif")

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--output-dir":
                index += 1
                outputDirectory = URL(
                    fileURLWithPath: try Self.value(after: argument, at: index, in: arguments),
                    isDirectory: true
                )
            case "--output-name":
                index += 1
                outputName = try Self.value(after: argument, at: index, in: arguments)
            case "--width":
                index += 1
                width = try Self.intValue(after: argument, at: index, in: arguments)
            case "--height":
                index += 1
                height = try Self.intValue(after: argument, at: index, in: arguments)
            case "--logo":
                index += 1
                logoURL = URL(fileURLWithPath: try Self.value(after: argument, at: index, in: arguments))
            case "--mascot":
                index += 1
                mascotURL = URL(fileURLWithPath: try Self.value(after: argument, at: index, in: arguments))
            case "--help", "-h":
                throw PosterExportError.helpText
            default:
                throw PosterExportError.unknownArgument(argument)
            }
            index += 1
        }

        guard width > 0, height > 0 else {
            throw PosterExportError.invalidValue("canvas", "\(width)x\(height)")
        }

        self.outputDirectory = outputDirectory
        self.outputName = outputName
        self.canvasSize = CGSize(width: width, height: height)
        self.logoURL = logoURL
        self.mascotURL = mascotURL
    }

    func prepareOutputDirectory() throws {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    }

    private static func value(after flag: String, at index: Int, in arguments: [String]) throws -> String {
        guard arguments.indices.contains(index) else {
            throw PosterExportError.missingValue(flag)
        }
        return arguments[index]
    }

    private static func intValue(after flag: String, at index: Int, in arguments: [String]) throws -> Int {
        let raw = try value(after: flag, at: index, in: arguments)
        guard let value = Int(raw) else {
            throw PosterExportError.invalidValue(flag, raw)
        }
        return value
    }
}

private enum PosterExportError: LocalizedError {
    case missingValue(String)
    case invalidValue(String, String)
    case unknownArgument(String)
    case failedToRender(String)
    case failedToEncode(String)
    case helpText

    var errorDescription: String? {
        switch self {
        case .missingValue(let flag):
            return "Missing value for \(flag)"
        case .invalidValue(let flag, let value):
            return "Invalid value for \(flag): \(value)"
        case .unknownArgument(let argument):
            return "Unknown argument: \(argument)"
        case .failedToRender(let path):
            return "Failed to render poster for \(path)"
        case .failedToEncode(let path):
            return "Failed to encode PNG for \(path)"
        case .helpText:
            return """
            Usage: render-qwen-poster.sh [options]

              --output-dir <path>   Output directory (default: docs/images)
              --output-name <name>  Output filename (default: ping-island-qwen-poster.png)
              --width <pixels>      Canvas width (default: 2800)
              --height <pixels>     Canvas height (default: 1800)
              --logo <path>         Qwen logo asset path
              --mascot <path>       Qwen mascot asset path
            """
        }
    }
}

private struct QwenPosterView: View {
    let options: PosterOptions

    var body: some View {
        ZStack {
            PosterBackground()

            VStack(spacing: 44) {
                header

                HStack(alignment: .top, spacing: 34) {
                    leftColumn
                    rightColumn
                        .frame(width: 920)
                }

                footer
            }
            .padding(.horizontal, 108)
            .padding(.vertical, 88)
        }
    }

    private var header: some View {
        HStack(spacing: 56) {
            hero

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Badge(text: "Ping Island 0.2.0", tint: Color(red: 0.16, green: 0.70, blue: 0.84))
                    Badge(text: "Qwen Code", tint: Color(red: 0.10, green: 0.62, blue: 0.74))
                    Badge(text: "~/.qwen/settings.json", tint: Color(red: 0.38, green: 0.79, blue: 0.63))
                }

                Text("Qwen Code，正式進島")
                    .font(.system(size: 124, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.10, green: 0.20, blue: 0.25))

                Text("官方 hooks 接法，不再只是旁路提示")
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.24, green: 0.44, blue: 0.50))

                Text("Ping Island 直接管理 `~/.qwen/settings.json`，把通知、追問、Stop/SessionEnd 收尾與會話狀態統一拉回 Island，連 SSH 轉發也能沿用同一條鏈路。")
                    .font(.system(size: 31, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.35, green: 0.50, blue: 0.54))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var hero: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.65, green: 0.95, blue: 0.89).opacity(0.80),
                            Color(red: 0.16, green: 0.74, blue: 0.86).opacity(0.26),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 18,
                        endRadius: 320
                    )
                )
                .frame(width: 540, height: 540)

            if let mascotImage = loadedImage(from: options.mascotURL) {
                mascotImage
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 300, height: 300)
                    .shadow(color: Color(red: 0.14, green: 0.72, blue: 0.88).opacity(0.20), radius: 22, x: 0, y: 10)
            } else {
                MascotView(kind: .qwen, status: .working, size: 300, animationTime: 0.25)
            }
        }
        .frame(width: 540, height: 540)
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 14) {
                featurePill("notifications", icon: "bell.badge.fill")
                featurePill("follow-up prompts", icon: "questionmark.bubble.fill")
                featurePill("session state", icon: "waveform.path.ecg")
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("Qwen 的重點，不是能不能接，而是能不能完整接")
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.10, green: 0.20, blue: 0.25))

                Text("0.2.0 之後，Qwen Code 不只是一條到站通知。官方 hooks 路徑、追問事件、消息彈窗與結束摘要都會進到同一個 Island 流程，避免只看到開始看不到收尾。")
                    .font(.system(size: 30, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.34, green: 0.47, blue: 0.50))
                    .fixedSize(horizontal: false, vertical: true)
            }

            pathCard
            flowDiagram

            VStack(alignment: .leading, spacing: 18) {
                Text("0.2.0 的 Qwen 可見能力")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.14, green: 0.25, blue: 0.30))

                HStack(spacing: 14) {
                    eventPill("官方 settings 托管", tint: Color(red: 0.12, green: 0.68, blue: 0.82))
                    eventPill("通知直接彈窗", tint: Color(red: 0.34, green: 0.80, blue: 0.62))
                    eventPill("追問留在會話中", tint: Color(red: 0.58, green: 0.79, blue: 0.39))
                    eventPill("Stop / SessionEnd 摘要", tint: Color(red: 0.15, green: 0.54, blue: 0.73))
                }
            }
        }
        .padding(34)
        .frame(maxWidth: .infinity, minHeight: 1040, alignment: .topLeading)
        .background(cardBackground)
    }

    private var pathCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("官方接入位置")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.85, green: 0.98, blue: 0.96))

            Text("~/.qwen/settings.json")
            Text("Notification / Stop / SessionEnd")
            Text("PreToolUse / PostToolUse / follow-up")
        }
        .font(.system(size: 22, weight: .semibold, design: .monospaced))
        .foregroundStyle(Color.white.opacity(0.95))
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.13, green: 0.34, blue: 0.39))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var flowDiagram: some View {
        HStack(spacing: 16) {
            FlowStepCard(
                icon: "terminal.fill",
                title: "Qwen CLI",
                detail: "提示、工具、通知與追問先在終端內發生"
            )

            flowArrow

            FlowStepCard(
                icon: "gearshape.2.fill",
                title: "Official Hooks",
                detail: "沿官方事件名把重要狀態橋接回 Ping Island"
            )

            flowArrow

            FlowStepCard(
                icon: "menubar.rectangle",
                title: "Island UI",
                detail: "消息彈窗、追問、摘要和列表狀態都保持一致"
            )
        }
    }

    private var flowArrow: some View {
        Image(systemName: "arrow.right.circle.fill")
            .font(.system(size: 34, weight: .bold))
            .foregroundStyle(Color(red: 0.16, green: 0.70, blue: 0.84))
    }

    private var rightColumn: some View {
        VStack(spacing: 28) {
            spotlightCard
            conversationCard
        }
    }

    private var spotlightCard: some View {
        HStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.62, green: 0.95, blue: 0.86).opacity(0.20))
                    .frame(width: 300, height: 300)
                    .blur(radius: 10)

                if let logoImage = loadedImage(from: options.logoURL) {
                    logoImage
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 210, height: 210)
                }
            }
            .frame(width: 300, height: 300)

            VStack(alignment: .leading, spacing: 18) {
                Text("薄荷圍巾卡皮巴拉，對應 Qwen 的節奏")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.10, green: 0.20, blue: 0.25))
                    .fixedSize(horizontal: false, vertical: true)

                Text("這套形象專門對應 Qwen 的通知密度、長對話追問與比較平穩的工作流節奏，不再混進 Claude 家族的視覺識別。")
                    .font(.system(size: 25, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.34, green: 0.47, blue: 0.50))

                VStack(alignment: .leading, spacing: 12) {
                    snippetLine("Notification -> 即時消息彈窗")
                    snippetLine("Question / follow-up -> 保留互動狀態")
                    snippetLine("Stop / SessionEnd -> 最終摘要預覽")
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 360, alignment: .leading)
        .background(cardBackground)
    }

    private var conversationCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Island 裡看到的 Qwen 回覆")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.10, green: 0.20, blue: 0.25))
                Spacer()
                Text("0.2.0")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.16, green: 0.70, blue: 0.84))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color(red: 0.16, green: 0.70, blue: 0.84).opacity(0.12)))
            }

            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.14, blue: 0.16))

                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 14) {
                        Text("qwen train")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)

                        Spacer()

                        Text("Hooks")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.white.opacity(0.10)))

                        Text("Qwen")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.69, green: 0.98, blue: 0.90))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.09, green: 0.45, blue: 0.50))
                            )
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("你：先整理三個重點，再提醒我還有哪些待確認項。")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.74))

                        Text("Qwen：已整理完成。我會先發通知，再保留最後摘要，讓你在 Island 內直接看到這次回覆和下一步追問。")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.95))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 12) {
                        transcriptBadge("通知可直接進 Island")
                        transcriptBadge("追問狀態不會丟失")
                    }
                }
                .padding(32)
            }
            .frame(maxWidth: .infinity, minHeight: 350)
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 2)
            )
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 470, alignment: .topLeading)
        .background(cardBackground)
    }

    private var footer: some View {
        HStack(spacing: 18) {
            ribbonTag(icon: "gearshape.2.fill", text: "official settings hooks")
            ribbonTag(icon: "bell.badge.fill", text: "message popup support")
            ribbonTag(icon: "questionmark.bubble.fill", text: "follow-up prompt state")
            ribbonTag(icon: "network", text: "SSH hook rewrite path")
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 40, style: .continuous)
            .fill(.white.opacity(0.58))
            .overlay(
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .stroke(Color.white.opacity(0.94), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 12)
    }

    private func loadedImage(from url: URL) -> Image? {
        guard let nsImage = NSImage(contentsOf: url) else { return nil }
        return Image(nsImage: nsImage)
    }

    private func featurePill(_ text: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 18, weight: .bold, design: .rounded))
        .foregroundStyle(Color(red: 0.11, green: 0.61, blue: 0.73))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color(red: 0.92, green: 0.99, blue: 0.97))
        )
    }

    private func eventPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }

    private func ribbonTag(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 22, weight: .bold, design: .rounded))
        .foregroundStyle(Color(red: 0.14, green: 0.25, blue: 0.29))
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(
            Capsule(style: .continuous)
                .fill(.white.opacity(0.60))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(.white.opacity(0.94), lineWidth: 2)
        )
    }

    private func transcriptBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.79, green: 0.99, blue: 0.90))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
    }

    private func snippetLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.95))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(red: 0.13, green: 0.31, blue: 0.34))
            )
    }
}

private struct Badge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            )
    }
}

private struct FlowStepCard: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.73, green: 0.98, blue: 0.91).opacity(0.34))
                    .frame(width: 72, height: 72)

                Image(systemName: icon)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color(red: 0.12, green: 0.66, blue: 0.80))
            }

            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.10, green: 0.20, blue: 0.25))

            Text(detail)
                .font(.system(size: 21, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.34, green: 0.47, blue: 0.50))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 248, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.98), lineWidth: 2)
        )
    }
}

private struct PosterBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 1.00, blue: 0.99),
                    Color(red: 0.91, green: 0.97, blue: 0.96),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color(red: 0.57, green: 0.98, blue: 0.90).opacity(0.30),
                    .clear,
                ],
                center: .topLeading,
                startRadius: 26,
                endRadius: 980
            )

            RadialGradient(
                colors: [
                    Color(red: 0.12, green: 0.74, blue: 0.87).opacity(0.26),
                    .clear,
                ],
                center: .bottomTrailing,
                startRadius: 50,
                endRadius: 840
            )
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.white.opacity(0.26))
                .frame(width: 430, height: 430)
                .blur(radius: 12)
                .offset(x: 100, y: -120)
        }
        .overlay(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 170, style: .continuous)
                .fill(Color.white.opacity(0.24))
                .frame(width: 640, height: 250)
                .rotationEffect(.degrees(-14))
                .offset(x: -100, y: 92)
        }
    }
}
