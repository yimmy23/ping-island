import SwiftUI

struct SessionHoverDashboardView: View {
    let sessions: [SessionState]
    let selectedSession: SessionState?
    let sessionMonitor: ClaudeSessionMonitor
    @ObservedObject var viewModel: NotchViewModel

    private var displayedSessions: [SessionState] {
        Array(sessions.prefix(3))
    }

    private var resolvedSelectedSession: SessionState? {
        if let selectedSession,
           let current = displayedSessions.first(where: { $0.sessionId == selectedSession.sessionId }) {
            return current
        }
        return displayedSessions.first
    }

    private var compactSessions: [SessionState] {
        guard let selected = resolvedSelectedSession else { return displayedSessions }
        return displayedSessions.filter { $0.sessionId != selected.sessionId }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(compactSessions) { session in
                    SessionHoverCompactRow(session: session) {
                        viewModel.setHoverPreview(session: session)
                    }
                }

                if let selected = resolvedSelectedSession {
                    HoverSelectedSessionCard(
                        session: selected,
                        sessionMonitor: sessionMonitor,
                        viewModel: viewModel
                    )
                } else {
                    HoverEmptyPreviewView()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 18)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

struct SessionHoverPreviewView: View {
    let session: SessionState
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HoverSessionHeader(session: session)

            HoverSessionPreviewLines(session: session)

            if !session.cwd.isEmpty && session.cwd != "/" {
                Text(session.cwd)
                    .font(.system(size: max(11, settings.contentFontSize - 2), weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.36))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HoverConversationSnapshot {
    let userText: String?
    let assistantText: String?
    let statusText: String
}

private struct SessionHoverCompactRow: View {
    let session: SessionState
    let onSelect: () -> Void
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .center, spacing: 12) {
                HoverProviderGlyph(session: session)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(session.projectName)
                            .font(.system(size: max(12, settings.contentFontSize), weight: .semibold))
                            .foregroundColor(.white.opacity(0.88))

                        Text("·")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.36))

                        Text(session.displayTitle)
                            .font(.system(size: max(14, settings.contentFontSize + 2), weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }

                    HoverSessionPreviewLines(session: session, compact: true)
                }

                Spacer(minLength: 0)

                HoverSessionBadges(session: session)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct HoverSelectedSessionCard: View {
    let session: SessionState
    let sessionMonitor: ClaudeSessionMonitor
    @ObservedObject var viewModel: NotchViewModel

    private var snapshot: HoverConversationSnapshot {
        HoverConversationSnapshotBuilder.snapshot(for: session)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let intervention = session.intervention, intervention.kind == .question {
                HoverSessionHeader(session: session)

                HoverQuestionInterventionCard(
                    session: session,
                    intervention: intervention,
                    sessionMonitor: sessionMonitor,
                    viewModel: viewModel
                )
                .padding(.leading, HoverSessionLayout.headerContentInset)
                .padding(.trailing, 4)
            } else if session.provider == .codex, session.intervention == nil {
                HoverSessionHeader(session: session, showPath: false)

                CodexThreadInspectorView(
                    session: session,
                    sessionMonitor: sessionMonitor,
                    mode: .hover
                )
            } else {
                HoverSessionHeader(session: session)

                HoverConversationCard(session: session, snapshot: snapshot)
            }
        }
        .padding(.horizontal, session.provider == .codex && session.intervention == nil ? 16 : 0)
        .padding(.vertical, session.provider == .codex && session.intervention == nil ? 16 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.05), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
        )
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private enum HoverSessionLayout {
    static let glyphSize: CGFloat = 26
    static let headerSpacing: CGFloat = 12
    static let headerContentInset: CGFloat = glyphSize + headerSpacing
}

private struct HoverConversationCard: View {
    let session: SessionState
    let snapshot: HoverConversationSnapshot
    @ObservedObject private var settings = AppSettings.shared

    private var userFontSize: CGFloat {
        max(12, settings.contentFontSize)
    }

    private var assistantFontSize: CGFloat {
        max(12, settings.contentFontSize - 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let userText = snapshot.userText {
                HStack(alignment: .top, spacing: 10) {
                    Text("你：")
                        .font(.system(size: max(12, settings.contentFontSize - 1), weight: .bold))
                        .foregroundColor(.white.opacity(0.76))
                        .padding(.top, 1)

                    MarkdownText(userText, color: .white.opacity(0.9), fontSize: userFontSize)
                        .lineLimit(3)

                    Spacer(minLength: 8)

                    Text(snapshot.statusText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.38))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.05))
            }

            if let assistantText = snapshot.assistantText {
                MarkdownText(assistantText, color: .white.opacity(0.78), fontSize: assistantFontSize)
                    .lineLimit(8)
                    .padding(.horizontal, 16)
                    .padding(.bottom, session.cwd.isEmpty || session.cwd == "/" ? 16 : 0)
                    .padding(.top, snapshot.userText == nil ? 16 : 4)
            } else {
                HoverSessionPreviewLines(session: session)
                    .padding(.horizontal, 16)
                    .padding(.bottom, session.cwd.isEmpty || session.cwd == "/" ? 16 : 0)
                    .padding(.top, snapshot.userText == nil ? 16 : 4)
            }

            if !session.cwd.isEmpty && session.cwd != "/" {
                Text(session.cwd)
                    .font(.system(size: max(10, settings.contentFontSize - 2), weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.34))
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct HoverQuestionInterventionCard: View {
    let session: SessionState
    let intervention: SessionIntervention
    let sessionMonitor: ClaudeSessionMonitor
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(intervention.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text(intervention.message)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                }

                Spacer(minLength: 0)
            }

            SessionQuestionForm(
                intervention: intervention,
                submitLabel: "提交所有回答",
                onSubmit: { payload in
                    sessionMonitor.answerIntervention(sessionId: session.sessionId, answers: payload)
                },
                secondaryActionTitle: "查看会话",
                onSecondaryAction: {
                    viewModel.showChat(for: session)
                }
            )
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct HoverSessionHeader: View {
    let session: SessionState
    var showPath: Bool = false
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: showPath ? 10 : 0) {
            HStack(alignment: .center, spacing: HoverSessionLayout.headerSpacing) {
                HoverProviderGlyph(session: session)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(session.projectName)
                            .font(.system(size: max(14, settings.contentFontSize + 1), weight: .semibold))
                            .foregroundColor(.white.opacity(0.88))

                        Text("·")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.42))

                        Text(session.displayTitle)
                            .font(.system(size: max(16, settings.contentFontSize + 4), weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }

                    HoverSessionBadges(session: session)
                }

                Spacer(minLength: 0)
            }

            if showPath, !session.cwd.isEmpty && session.cwd != "/" {
                Text(session.cwd)
                    .font(.system(size: max(11, settings.contentFontSize - 2), weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.36))
                    .lineLimit(1)
            }
        }
    }
}

private struct HoverSessionPreviewLines: View {
    let session: SessionState
    var compact = false
    @ObservedObject private var settings = AppSettings.shared

    private var lines: [HoverPreviewLine] {
        HoverPreviewLineBuilder.previewLines(
            for: session,
            compact: compact,
            detailsEnabled: settings.showAgentDetail
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            ForEach(lines) { line in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let prefix = line.prefix {
                        Text(prefix)
                            .font(.system(size: compact ? max(10, settings.contentFontSize - 2) : max(11, settings.contentFontSize - 1), weight: .semibold))
                            .foregroundColor(.white.opacity(0.72))
                    }

                    Text(line.text)
                        .font(.system(size: compact ? max(10, settings.contentFontSize - 2) : max(11, settings.contentFontSize - 1), weight: .medium))
                        .foregroundColor(line.color)
                        .lineLimit(compact ? 1 : 2)
                }
            }
        }
    }
}

private struct HoverSessionBadges: View {
    let session: SessionState

    private var providerColor: Color {
        session.provider == .claude
            ? Color(red: 0.85, green: 0.47, blue: 0.34)
            : Color(red: 0.36, green: 0.62, blue: 1.0)
    }

    private var providerLabel: String {
        session.provider == .claude ? "Claude" : "Codex"
    }

    private var timeLabel: String {
        let value = SessionPhaseHelpers.timeAgo(session.lastActivity)
        return value == "now" ? "<1m" : value
    }

    var body: some View {
        HStack(spacing: 8) {
            previewBadge(providerLabel, tint: providerColor)
            previewBadge(timeLabel, tint: .white.opacity(0.12), foreground: .white.opacity(0.62))
        }
    }

    private func previewBadge(_ text: String, tint: Color, foreground: Color = .white.opacity(0.92)) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint)
            .clipShape(Capsule())
    }
}

private struct HoverProviderGlyph: View {
    let session: SessionState
    @ObservedObject private var settings = AppSettings.shared

    private var petTone: NotchIndicatorTone {
        if session.needsQuestionResponse {
            return .intervention
        }
        if session.phase.isWaitingForApproval {
            return .warning
        }
        return .normal
    }

    var body: some View {
        Group {
            if session.provider == .codex {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(TerminalColors.blue)
            } else {
                NotchPetIcon(
                    style: settings.notchPetStyle,
                    size: 18,
                    tone: petTone,
                    isProcessing: session.phase.isActive
                )
            }
        }
            .frame(width: HoverSessionLayout.glyphSize, height: HoverSessionLayout.glyphSize)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct HoverPreviewLine: Identifiable {
    let id: String
    let prefix: String?
    let text: String
    let color: Color
}

private enum HoverPreviewLineBuilder {
    static func previewLines(for session: SessionState, compact: Bool, detailsEnabled: Bool) -> [HoverPreviewLine] {
        var lines: [HoverPreviewLine] = []

        if let userLine = latestUserLine(for: session) {
            lines.append(
                HoverPreviewLine(
                    id: "user",
                    prefix: "你：",
                    text: userLine,
                    color: .white.opacity(compact ? 0.62 : 0.72)
                )
            )
        }

        if let assistantLine = latestAssistantLine(for: session, detailsEnabled: detailsEnabled) {
            lines.append(
                HoverPreviewLine(
                    id: "assistant",
                    prefix: nil,
                    text: assistantLine,
                    color: .white.opacity(compact ? 0.48 : 0.56)
                )
            )
        }

        if lines.isEmpty, let fallback = fallbackPreview(for: session) {
            lines.append(
                HoverPreviewLine(
                    id: "fallback",
                    prefix: nil,
                    text: fallback,
                    color: .white.opacity(0.64)
                )
            )
        }

        return Array(lines.prefix(compact ? 2 : 3))
    }

    private static func latestUserLine(for session: SessionState) -> String? {
        for item in session.chatItems.reversed() {
            if case .user(let text) = item.type {
                return sanitized(text)
            }
        }
        return sanitized(session.firstUserMessage)
    }

    private static func latestAssistantLine(for session: SessionState, detailsEnabled: Bool) -> String? {
        for item in session.chatItems.reversed() {
            switch item.type {
            case .assistant(let text):
                return sanitized(text)
            case .thinking(let text):
                return detailsEnabled ? sanitized(text) : nil
            case .toolCall(let tool):
                guard detailsEnabled else { continue }
                let preview = sanitized(tool.inputPreview)
                let label = MCPToolFormatter.formatToolName(tool.name)
                return preview.map { "\(label) \($0)" } ?? label
            case .interrupted, .user:
                continue
            }
        }

        if let intervention = session.intervention {
            return sanitized(intervention.summaryText)
        }

        return sanitized(session.lastMessage)
    }

    private static func fallbackPreview(for session: SessionState) -> String? {
        sanitized(session.previewText) ?? sanitized(session.lastMessage)
    }

    private static func sanitized(_ text: String?) -> String? {
        guard let text else { return nil }
        let collapsed = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return collapsed.isEmpty ? nil : collapsed
    }
}

private enum HoverConversationSnapshotBuilder {
    static func snapshot(for session: SessionState) -> HoverConversationSnapshot {
        HoverConversationSnapshot(
            userText: latestUserText(for: session),
            assistantText: latestAssistantText(for: session),
            statusText: statusText(for: session)
        )
    }

    private static func latestUserText(for session: SessionState) -> String? {
        for item in session.chatItems.reversed() {
            if case .user(let text) = item.type {
                return sanitized(text)
            }
        }
        return sanitized(session.firstUserMessage)
    }

    private static func latestAssistantText(for session: SessionState) -> String? {
        for item in session.chatItems.reversed() {
            switch item.type {
            case .assistant(let text):
                return sanitized(text)
            case .thinking(let text):
                return sanitized(text)
            case .toolCall(let tool):
                let preview = sanitized(tool.inputPreview)
                let label = MCPToolFormatter.formatToolName(tool.name)
                return preview.map { "\(label) \($0)" } ?? label
            case .interrupted:
                return "已中断"
            case .user:
                continue
            }
        }

        if let intervention = session.intervention {
            return sanitized(intervention.summaryText)
        }

        return sanitized(session.previewText) ?? sanitized(session.lastMessage)
    }

    private static func statusText(for session: SessionState) -> String {
        switch session.phase {
        case .waitingForApproval:
            return "等待授权"
        case .waitingForInput:
            return "待输入"
        case .processing:
            return "处理中"
        case .compacting:
            return "压缩中"
        case .idle:
            return "完成"
        case .ended:
            return "结束"
        }
    }

    private static func sanitized(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct HoverEmptyPreviewView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No recent session")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)

            Text("Hover here to preview your most recent Claude and Codex threads.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.56))
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
