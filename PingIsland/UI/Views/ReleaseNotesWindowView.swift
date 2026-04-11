import AppKit
import SwiftUI

struct ReleaseNotesWindowView: View {
    let notes: UpdateReleaseNotes
    let onClose: () -> Void

    @Environment(\.locale) private var locale
    @State private var expandedSectionIDs: Set<String> = []
    @State private var celebrationStartedAt = Date()

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                appIcon
                versionBadge
                releaseNotesContent
            }
            .padding(.top, 18)
            .padding(.horizontal, 18)
            .padding(.bottom, 14)

            Divider()
                .overlay(Color.white.opacity(0.08))

            Button(action: onClose) {
                Text("好")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.92))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .overlay {
            FireworksCelebrationOverlay(startedAt: celebrationStartedAt)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .allowsHitTesting(false)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if expandedSectionIDs.isEmpty {
                expandedSectionIDs = Set(displayedSections.map(\.id))
            }
            celebrationStartedAt = Date()
        }
    }

    private var appIcon: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .frame(width: 60, height: 60)
            .shadow(color: .black.opacity(0.2), radius: 8, y: 5)
    }

    private var versionBadge: some View {
        HStack(spacing: 8) {
            Text(notes.currentVersion)
                .foregroundColor(.white.opacity(0.6))

            Image(systemName: "arrow.right")
                .foregroundColor(.white.opacity(0.35))

            Text(notes.targetVersion)
                .foregroundColor(.white.opacity(0.92))

            Text("🎉")
        }
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .padding(.horizontal, 16)
        .frame(height: 38)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var releaseNotesContent: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(displayedSections.isEmpty ? [fallbackSection] : displayedSections) { section in
                    ReleaseNotesSectionCard(
                        section: section,
                        isExpanded: expandedSectionIDs.contains(section.id),
                        toggle: { toggleSection(section.id) }
                    )
                }
            }
            .padding(.bottom, 2)
        }
        .frame(maxHeight: 464)
    }

    private var displayedSections: [UpdateReleaseNotesSection] {
        notes.sections(locale: locale)
    }

    private var fallbackSection: UpdateReleaseNotesSection {
        UpdateReleaseNotesSection(
            id: "fallback",
            title: AppLocalization.string("更新内容"),
            markdown: notes.localizedMarkdown(locale: locale)
        )
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.20, green: 0.21, blue: 0.24),
                Color(red: 0.15, green: 0.15, blue: 0.17)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.black.opacity(0.18))
        )
    }

    private func toggleSection(_ id: String) {
        if expandedSectionIDs.contains(id) {
            expandedSectionIDs.remove(id)
        } else {
            expandedSectionIDs.insert(id)
        }
    }
}

private struct ReleaseNotesSectionCard: View {
    let section: UpdateReleaseNotesSection
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: toggle) {
                HStack(spacing: 10) {
                    Image(systemName: section.iconSymbolName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.68))

                    Text(section.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.92))

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.45))
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .overlay(Color.white.opacity(0.08))
                    .padding(.horizontal, 14)

                MarkdownContentView(
                    section.markdown,
                    color: .white.opacity(0.84),
                    fontSize: 12
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.18), value: isExpanded)
    }
}

private struct FireworksCelebrationOverlay: View {
    let startedAt: Date

    private let duration: TimeInterval = 3.6
    private let bursts: [FireworkShow] = FireworkShow.defaultBursts

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let elapsed = context.date.timeIntervalSince(startedAt)
            let opacity = globalOpacity(for: elapsed)

            if elapsed < duration && opacity > 0 {
                GeometryReader { proxy in
                    Canvas { canvas, size in
                        for burst in bursts {
                            draw(burst: burst, elapsed: elapsed, in: canvas, size: size, opacity: opacity)
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .transition(.opacity)
            }
        }
    }

    private func draw(
        burst: FireworkShow,
        elapsed: TimeInterval,
        in canvas: GraphicsContext,
        size: CGSize,
        opacity: Double
    ) {
        drawRocketTrail(for: burst, elapsed: elapsed, in: canvas, size: size, opacity: opacity)
        drawExplosion(for: burst, elapsed: elapsed, in: canvas, size: size, opacity: opacity)
    }

    private func drawRocketTrail(
        for burst: FireworkShow,
        elapsed: TimeInterval,
        in canvas: GraphicsContext,
        size: CGSize,
        opacity: Double
    ) {
        let launchProgress = burst.launchProgress(at: elapsed)
        guard launchProgress > 0, launchProgress < 1 else { return }

        let start = burst.launchPoint(in: size)
        let peak = burst.peakPoint(in: size)
        let rocket = CGPoint(
            x: start.x + (peak.x - start.x) * launchProgress,
            y: start.y + (peak.y - start.y) * launchProgress
        )
        let trailLength = CGFloat(40 + 30 * launchProgress)
        let trailStart = CGPoint(
            x: rocket.x - (peak.x - start.x) * 0.12,
            y: min(size.height, rocket.y + trailLength)
        )
        let launchOpacity = (1 - launchProgress * 0.35) * opacity

        var trail = Path()
        trail.move(to: trailStart)
        trail.addLine(to: rocket)

        var trailContext = canvas
        trailContext.opacity = launchOpacity
        trailContext.addFilter(.blur(radius: 1.5))
        trailContext.stroke(
            trail,
            with: .linearGradient(
                Gradient(colors: [
                    burst.colors[0].opacity(0.05),
                    burst.colors[0].opacity(0.95)
                ]),
                startPoint: trailStart,
                endPoint: rocket
            ),
            style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
        )

        let rocketGlow = CGRect(x: rocket.x - 5, y: rocket.y - 5, width: 10, height: 10)
        canvas.fill(Path(ellipseIn: rocketGlow), with: .color(.white.opacity(launchOpacity)))
    }

    private func drawExplosion(
        for burst: FireworkShow,
        elapsed: TimeInterval,
        in canvas: GraphicsContext,
        size: CGSize,
        opacity: Double
    ) {
        let progress = burst.explosionProgress(at: elapsed)
        guard progress > 0, progress <= 1 else { return }

        let center = burst.peakPoint(in: size)
        let burstOpacity = max(0, (1 - progress) * opacity)
        let flashRadius = CGFloat(10 + progress * 22)
        let ringRadius = CGFloat(8 + progress * 52)

        var glow = canvas
        glow.opacity = burstOpacity * 0.34
        glow.addFilter(.blur(radius: 7))
        glow.fill(
            Path(ellipseIn: CGRect(
                x: center.x - flashRadius,
                y: center.y - flashRadius,
                width: flashRadius * 2,
                height: flashRadius * 2
            )),
            with: .color(burst.colors[0])
        )

        var ring = Path()
        ring.addEllipse(in: CGRect(
            x: center.x - ringRadius,
            y: center.y - ringRadius,
            width: ringRadius * 2,
            height: ringRadius * 2
        ))

        var ringContext = canvas
        ringContext.opacity = burstOpacity * 0.26
        ringContext.stroke(
            ring,
            with: .color(burst.colors[1 % burst.colors.count]),
            style: StrokeStyle(lineWidth: max(1, 3 - progress * 2))
        )

        for (index, particle) in burst.particles.enumerated() {
            let distance = CGFloat(progress) * particle.distance
            let x = center.x + cos(particle.angle) * distance
            let y = center.y + sin(particle.angle) * distance
            let previousDistance = max(0, distance - (particle.distance * 0.14))
            let trailStart = CGPoint(
                x: center.x + cos(particle.angle) * previousDistance,
                y: center.y + sin(particle.angle) * previousDistance
            )
            let color = burst.colors[index % burst.colors.count].opacity(burstOpacity)

            var trail = Path()
            trail.move(to: trailStart)
            trail.addLine(to: CGPoint(x: x, y: y))

            var trailContext = canvas
            trailContext.opacity = burstOpacity
            trailContext.stroke(
                trail,
                with: .color(color),
                style: StrokeStyle(lineWidth: particle.lineWidth, lineCap: .round)
            )

            let sparkRect = CGRect(
                x: x - particle.size / 2,
                y: y - particle.size / 2,
                width: particle.size,
                height: particle.size
            )
            canvas.fill(Path(ellipseIn: sparkRect), with: .color(color))

            if particle.emojiWeight > 0.45 {
                let emoji = burst.emojis[index % burst.emojis.count]
                let resolvedEmoji = canvas.resolve(
                    Text(emoji)
                        .font(.system(size: particle.emojiSize))
                )
                var emojiContext = canvas
                emojiContext.opacity = burstOpacity * 0.92
                emojiContext.draw(resolvedEmoji, at: CGPoint(x: x, y: y), anchor: .center)
            }
        }
    }

    private func globalOpacity(for elapsed: TimeInterval) -> Double {
        if elapsed < 2.6 { return 1 }
        return max(0, 1 - (elapsed - 2.6) / 1.0)
    }
}

private struct FireworkShow {
    let launchX: CGFloat
    let peak: CGPoint
    let launchDelay: TimeInterval
    let colors: [Color]
    let emojis: [String]
    let particles: [FireworkParticle]

    func launchPoint(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * launchX, y: size.height + 36)
    }

    func peakPoint(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * peak.x, y: size.height * peak.y)
    }

    func launchProgress(at elapsed: TimeInterval) -> Double {
        let local = elapsed - launchDelay
        guard local >= 0 else { return 0 }
        return min(1, local / 0.82)
    }

    func explosionProgress(at elapsed: TimeInterval) -> Double {
        let local = elapsed - (launchDelay + 0.78)
        guard local >= 0 else { return 0 }
        return min(1, local / 1.15)
    }

    static let defaultBursts: [FireworkShow] = [
        FireworkShow(
            launchX: 0.14,
            peak: CGPoint(x: 0.22, y: 0.34),
            launchDelay: 0.00,
            colors: [.pink, .orange, .yellow],
            emojis: ["✨", "🎉", "⭐️"],
            particles: FireworkParticle.particles(seed: 0, spread: 0.95)
        ),
        FireworkShow(
            launchX: 0.82,
            peak: CGPoint(x: 0.74, y: 0.28),
            launchDelay: 0.18,
            colors: [.blue, .mint, .white],
            emojis: ["🎊", "💥", "✨"],
            particles: FireworkParticle.particles(seed: 1, spread: 1.0)
        ),
        FireworkShow(
            launchX: 0.48,
            peak: CGPoint(x: 0.52, y: 0.18),
            launchDelay: 0.44,
            colors: [.purple, .pink, .yellow],
            emojis: ["🌟", "🎉", "💫"],
            particles: FireworkParticle.particles(seed: 2, spread: 1.05)
        ),
        FireworkShow(
            launchX: 0.28,
            peak: CGPoint(x: 0.34, y: 0.22),
            launchDelay: 0.82,
            colors: [.orange, .yellow, .white],
            emojis: ["💥", "✨", "🎊"],
            particles: FireworkParticle.particles(seed: 3, spread: 0.88)
        ),
        FireworkShow(
            launchX: 0.68,
            peak: CGPoint(x: 0.62, y: 0.38),
            launchDelay: 1.08,
            colors: [.mint, .cyan, .white],
            emojis: ["✨", "🌟", "💫"],
            particles: FireworkParticle.particles(seed: 4, spread: 0.92)
        )
    ]
}

private struct FireworkParticle {
    let angle: CGFloat
    let distance: CGFloat
    let size: CGFloat
    let lineWidth: CGFloat
    let emojiSize: CGFloat
    let emojiWeight: Double

    static func particles(seed: Int, spread: CGFloat) -> [FireworkParticle] {
        (0..<24).map { index in
            let step = CGFloat(index) / 24.0
            let angle = step * .pi * 2 + CGFloat(seed) * 0.11
            let distance = (CGFloat(44 + ((index + seed * 9) % 6) * 12)) * spread
            let size = CGFloat(2.2) + CGFloat((index + seed) % 3)
            let lineWidth = CGFloat(1.2) + CGFloat((index + seed * 3) % 2) * 0.8
            let emojiSize = CGFloat(10 + ((index + seed * 5) % 5) * 2)
            let emojiWeight = ((Double((index * 7 + seed * 5) % 100)) / 100.0)
            return FireworkParticle(
                angle: angle,
                distance: distance,
                size: size,
                lineWidth: lineWidth,
                emojiSize: emojiSize,
                emojiWeight: emojiWeight
            )
        }
    }
}
