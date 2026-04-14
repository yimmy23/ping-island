import AppKit
import Foundation
import SwiftUI

@MainActor
@main
struct HermesPosterExporterMain {
    static func main() throws {
        let options = try PosterOptions(arguments: Array(CommandLine.arguments.dropFirst()))
        try options.prepareOutputDirectory()

        let outputURL = options.outputDirectory.appendingPathComponent(options.outputName)
        let posterView = HermesPosterView(options: options)
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
    let iconURL: URL
    let logoURL: URL
    let mascotURL: URL

    init(arguments: [String]) throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        var outputDirectory = cwd.appendingPathComponent("docs/images", isDirectory: true)
        var outputName = "ping-island-hermes-poster.png"
        var width = 2800
        var height = 1800
        var iconURL = cwd.appendingPathComponent("PingIsland/Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png")
        var logoURL = cwd.appendingPathComponent("PingIsland/Assets.xcassets/HermesLogo.imageset/hermes-logo.png")
        var mascotURL = cwd.appendingPathComponent("docs/images/mascots/hermes.gif")

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
            case "--icon":
                index += 1
                iconURL = URL(fileURLWithPath: try Self.value(after: argument, at: index, in: arguments))
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
        self.iconURL = iconURL
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
            Usage: render-hermes-poster.sh [options]

              --output-dir <path>   Output directory (default: docs/images)
              --output-name <name>  Output filename (default: ping-island-hermes-poster.png)
              --width <pixels>      Canvas width (default: 2800)
              --height <pixels>     Canvas height (default: 1800)
              --icon <path>         Ping Island app icon path
              --logo <path>         Hermes logo asset path
              --mascot <path>       Hermes mascot asset path
            """
        }
    }
}

private struct HermesPosterView: View {
    let options: PosterOptions

    var body: some View {
        ZStack {
            PosterBackground()

            VStack(spacing: 42) {
                header

                HStack(alignment: .top, spacing: 34) {
                    leftColumn
                    rightColumn
                        .frame(width: 910)
                }

                footer
            }
            .padding(.horizontal, 106)
            .padding(.vertical, 88)
        }
    }

    private var header: some View {
        HStack(spacing: 56) {
            heroOrb

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Badge(text: "Ping Island 0.2.0", tint: Color(red: 0.27, green: 0.48, blue: 0.93))
                    Badge(text: "Hermes Agent", tint: Color(red: 0.84, green: 0.56, blue: 0.16))
                    Badge(text: "Official plugin hooks", tint: Color(red: 0.28, green: 0.63, blue: 0.69))
                }

                Text("Hermes Agent，正式進島")
                    .font(.system(size: 128, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.14, blue: 0.20))

                Text("走 CLI plugin，不走 gateway hook 旁路")
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.32, green: 0.37, blue: 0.52))

                Text("Ping Island 直接托管 `~/.hermes/plugins/ping_island/`，用官方 `ctx.register_hook()` 把輸入、工具、回覆完成與會話結束事件收回到同一個 Island。")
                    .font(.system(size: 30, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.43, green: 0.47, blue: 0.60))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var heroOrb: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.99, green: 0.85, blue: 0.52).opacity(0.82),
                            Color(red: 0.37, green: 0.58, blue: 0.97).opacity(0.26),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 16,
                        endRadius: 320
                    )
                )
                .frame(width: 540, height: 540)

            if let mascotImage = loadedImage(from: options.mascotURL) {
                mascotImage
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 310, height: 310)
                    .shadow(color: Color(red: 0.27, green: 0.48, blue: 0.93).opacity(0.18), radius: 24, x: 0, y: 10)
            } else {
                MascotView(kind: .hermes, status: .working, size: 300, animationTime: 0.25)
            }
        }
        .frame(width: 540, height: 540)
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 14) {
                featurePill("plugin dir", icon: "shippingbox.fill")
                featurePill("reply preview", icon: "text.bubble.fill")
                featurePill("session end", icon: "checkmark.circle.fill")
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("Hermes 的關鍵不是再補一套 hook，而是走對官方入口")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.13, green: 0.15, blue: 0.21))

                Text("因為 `~/.hermes/hooks/` 在 gateway 才會生效，Ping Island 在 0.2.0 直接改走 CLI 可用的 plugin 機制，避免表面裝好了，實際終端卻沒有任何事件回來。")
                    .font(.system(size: 30, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.39, green: 0.43, blue: 0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }

            pathCard
            flowDiagram

            VStack(alignment: .leading, spacing: 18) {
                Text("0.2.0 帶來的 Hermes 可見能力")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.19, green: 0.22, blue: 0.31))

                HStack(spacing: 14) {
                    eventPill("官方 plugin 安裝", tint: Color(red: 0.26, green: 0.56, blue: 0.94))
                    eventPill("CLI 事件收口", tint: Color(red: 0.83, green: 0.58, blue: 0.19))
                    eventPill("回覆完成預覽", tint: Color(red: 0.26, green: 0.69, blue: 0.61))
                    eventPill("結束提示保留", tint: Color(red: 0.44, green: 0.44, blue: 0.78))
                }
            }
        }
        .padding(34)
        .frame(maxWidth: .infinity, minHeight: 1040, alignment: .topLeading)
        .background(cardBackground)
    }

    private var pathCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("接入位置")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.83, green: 0.90, blue: 0.99))

            Text("~/.hermes/plugins/ping_island/")
            Text("ctx.register_hook(...)")
            Text("user / tool / reply / session-end")
        }
        .font(.system(size: 22, weight: .semibold, design: .monospaced))
        .foregroundStyle(Color.white.opacity(0.95))
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.18, green: 0.22, blue: 0.31))
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
                title: "Hermes CLI",
                detail: "輸入、工具、回覆先在終端側發生"
            )

            flowArrow

            FlowStepCard(
                icon: "puzzlepiece.extension.fill",
                title: "Plugin Hooks",
                detail: "官方 `register_hook()` 即時把事件橋接出去"
            )

            flowArrow

            FlowStepCard(
                icon: "menubar.rectangle",
                title: "Ping Island",
                detail: "通知、預覽、結束態都回到同一個 Island"
            )
        }
    }

    private var flowArrow: some View {
        Image(systemName: "arrow.right.circle.fill")
            .font(.system(size: 34, weight: .bold))
            .foregroundStyle(Color(red: 0.26, green: 0.56, blue: 0.94))
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
                    .fill(Color(red: 0.98, green: 0.78, blue: 0.33).opacity(0.18))
                    .frame(width: 300, height: 300)
                    .blur(radius: 10)

                if let logoImage = loadedImage(from: options.logoURL) {
                    logoImage
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                } else {
                    Text("Hermes")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.24, green: 0.30, blue: 0.46))
                }
            }
            .frame(width: 300, height: 300)

            VStack(alignment: .leading, spacing: 18) {
                Text("翼盔信使狐，對應 Hermes 節奏")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.13, green: 0.15, blue: 0.21))
                    .fixedSize(horizontal: false, vertical: true)

                Text("它不是另一個 Claude 分身，而是專門對應 plugin-hook 事件流、終端內回覆完成，以及會話收尾提醒。")
                    .font(.system(size: 25, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.40, green: 0.43, blue: 0.54))

                VStack(alignment: .leading, spacing: 12) {
                    snippetLine("on_session_start -> 建 session")
                    snippetLine("post_llm_call -> 更新最後回覆")
                    snippetLine("on_session_end -> 保留收尾提示")
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
                Text("Island 內看到的 Hermes 回覆")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.13, green: 0.15, blue: 0.21))
                Spacer()
                Text("0.2.0")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.31, green: 0.48, blue: 0.90))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color(red: 0.31, green: 0.48, blue: 0.90).opacity(0.12)))
            }

            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color(red: 0.09, green: 0.11, blue: 0.15))

                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 14) {
                        Text("hermes train")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)

                        Spacer()

                        Text("Plugin")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.white.opacity(0.10)))

                        Text("Hermes")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.99, green: 0.84, blue: 0.51))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.43, green: 0.33, blue: 0.12))
                            )
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("你：幫我把這段模型輸出整理成三條 release highlights。")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.74))

                        Text("Hermes：已整理完成。我保留了 plugin 安裝、回覆完成預覽，以及 session end 提示這三個重點。")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.95))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 12) {
                        transcriptBadge("最後回覆可直接預覽")
                        transcriptBadge("結束前不會丟失摘要")
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
            ribbonTag(icon: "puzzlepiece.extension.fill", text: "official plugin surface")
            ribbonTag(icon: "terminal.fill", text: "CLI-first event flow")
            ribbonTag(icon: "text.bubble.fill", text: "reply preview in Island")
            ribbonTag(icon: "bell.badge.fill", text: "session end summary")
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
        .foregroundStyle(Color(red: 0.25, green: 0.42, blue: 0.86))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color(red: 0.93, green: 0.96, blue: 1.0))
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
        .foregroundStyle(Color(red: 0.18, green: 0.22, blue: 0.31))
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
            .foregroundStyle(Color(red: 0.98, green: 0.83, blue: 0.52))
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
                    .fill(Color(red: 0.17, green: 0.20, blue: 0.28))
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
                    .fill(Color(red: 0.99, green: 0.86, blue: 0.60).opacity(0.32))
                    .frame(width: 72, height: 72)

                Image(systemName: icon)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color(red: 0.83, green: 0.58, blue: 0.18))
            }

            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.13, green: 0.15, blue: 0.21))

            Text(detail)
                .font(.system(size: 21, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.39, green: 0.42, blue: 0.53))
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
                    Color(red: 0.97, green: 0.98, blue: 1.0),
                    Color(red: 0.92, green: 0.95, blue: 0.99),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color(red: 0.35, green: 0.58, blue: 0.98).opacity(0.28),
                    .clear,
                ],
                center: .topLeading,
                startRadius: 26,
                endRadius: 980
            )

            RadialGradient(
                colors: [
                    Color(red: 0.99, green: 0.79, blue: 0.38).opacity(0.34),
                    .clear,
                ],
                center: .bottomTrailing,
                startRadius: 50,
                endRadius: 820
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
