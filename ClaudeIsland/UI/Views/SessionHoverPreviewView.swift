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
            if session.phase.isWaitingForApproval {
                HoverSessionHeader(session: session)

                HoverApprovalCard(
                    session: session,
                    sessionMonitor: sessionMonitor
                )
            } else if let intervention = session.intervention, intervention.kind == .question {
                HoverSessionHeader(session: session)

                HoverQuestionInterventionCard(
                    sessionId: session.sessionId,
                    intervention: intervention,
                    sessionMonitor: sessionMonitor
                )
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
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture {
            guard session.intervention == nil else { return }
            activateSession()
        }
    }

    private func activateSession() {
        Task {
            _ = await SessionLauncher.shared.activate(session)
        }
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
        VStack(alignment: .leading, spacing: 10) {
            if let userText = snapshot.userText {
                HoverConversationLine(
                    label: "你：",
                    labelColor: .white.opacity(0.54),
                    text: userText,
                    textColor: .white.opacity(0.84),
                    fontSize: userFontSize,
                    lineLimit: 2
                )
            }

            if let assistantText = snapshot.assistantText {
                HoverConversationLine(
                    label: HoverPreviewStyle.providerLabel(for: session) + "：",
                    labelColor: HoverPreviewStyle.assistantPrefixColor(for: session),
                    text: assistantText,
                    textColor: HoverPreviewStyle.assistantTextColor(for: session, compact: false),
                    fontSize: assistantFontSize,
                    lineLimit: 3
                )
            } else {
                HoverSessionPreviewLines(session: session)
            }

            if !session.cwd.isEmpty && session.cwd != "/" {
                Text(session.cwd)
                    .font(.system(size: max(10, settings.contentFontSize - 2), weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .lineLimit(1)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HoverApprovalCard: View {
    let session: SessionState
    let sessionMonitor: ClaudeSessionMonitor

    private var providerLabel: String {
        session.provider == .claude ? "Claude" : "Codex"
    }

    private var toolLabel: String {
        guard let toolName = session.pendingToolName else { return "当前操作" }
        return MCPToolFormatter.formatToolName(toolName)
    }

    private var detailText: String {
        if let input = session.pendingToolInput, !input.isEmpty {
            return input
        }
        return "批准后会继续执行当前会话。"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(providerLabel) 请求批准")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Text(toolLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(TerminalColors.amber.opacity(0.95))

                Text(detailText)
                    .font(.system(size: 11, weight: .medium, design: session.pendingToolInput == nil ? .default : .monospaced))
                    .foregroundColor(.white.opacity(0.68))
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                Button("Deny") {
                    sessionMonitor.denyPermission(sessionId: session.sessionId, reason: nil)
                }
                .buttonStyle(HoverApprovalButtonStyle(background: Color.white.opacity(0.1)))

                Button("Allow") {
                    sessionMonitor.approvePermission(sessionId: session.sessionId)
                }
                .buttonStyle(HoverApprovalButtonStyle(background: Color.white.opacity(0.92), foreground: .black))
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HoverQuestionInterventionCard: View {
    let sessionId: String
    let intervention: SessionIntervention
    let sessionMonitor: ClaudeSessionMonitor

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
                    sessionMonitor.answerIntervention(sessionId: sessionId, answers: payload)
                }
            )
        }
        .padding(.top, 12)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HoverApprovalButtonStyle: ButtonStyle {
    let background: Color
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(foreground.opacity(configuration.isPressed ? 0.75 : 1))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(background.opacity(configuration.isPressed ? 0.82 : 1))
            )
    }
}

private struct HoverSessionHeader: View {
    let session: SessionState
    var showPath: Bool = false
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: showPath ? 8 : 0) {
            HStack(alignment: .center, spacing: HoverSessionLayout.headerSpacing) {
                HoverProviderGlyph(session: session)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(session.projectName)
                            .font(.system(size: max(13, settings.contentFontSize), weight: .semibold))
                            .foregroundColor(.white.opacity(0.88))

                        Text("·")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.42))

                        Text(session.displayTitle)
                            .font(.system(size: max(15, settings.contentFontSize + 3), weight: .bold))
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
                            .foregroundColor(line.prefixColor)
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

    private var timeLabel: String {
        let value = SessionPhaseHelpers.timeAgo(session.lastActivity)
        return value == "now" ? "<1m" : value
    }

    var body: some View {
        HStack(spacing: 8) {
            previewBadge(
                HoverPreviewStyle.providerLabel(for: session),
                tint: HoverPreviewStyle.providerBadgeFill(for: session),
                foreground: .white.opacity(0.95)
            )
            previewBadge(timeLabel, tint: .white.opacity(0.08), foreground: .white.opacity(0.72))
        }
    }

    private func previewBadge(_ text: String, tint: Color, foreground: Color = .white.opacity(0.92)) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint)
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.04), lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

private struct HoverProviderGlyph: View {
    let session: SessionState
    @ObservedObject private var settings = AppSettings.shared

    private var petTone: NotchIndicatorTone {
        if session.phase.isWaitingForApproval {
            return .warning
        }
        return .normal
    }

    private var attentionTone: NotchIndicatorTone? {
        if session.needsQuestionResponse {
            return .intervention
        }
        if session.phase.isWaitingForApproval {
            return .warning
        }
        return nil
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
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
            .background(attentionTone == nil ? Color.white.opacity(0.04) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            if let attentionTone {
                PermissionIndicatorIcon(size: 11, color: attentionTone.emphasisColor)
                    .offset(x: 2, y: -2)
            }
        }
    }
}

private struct HoverPreviewLine: Identifiable {
    let id: String
    let prefix: String?
    let prefixColor: Color
    let text: String
    let color: Color
}

private struct HoverConversationLine: View {
    let label: String
    let labelColor: Color
    let text: String
    let textColor: Color
    let fontSize: CGFloat
    let lineLimit: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(.system(size: max(11, fontSize - 1), weight: .semibold))
                .foregroundColor(labelColor)

            MarkdownText(text, color: textColor, fontSize: fontSize)
                .lineLimit(lineLimit)
        }
    }
}

private enum HoverPreviewStyle {
    private static let claudeOrange = Color(red: 0.85, green: 0.47, blue: 0.34)
    private static let codexBlue = Color(red: 0.36, green: 0.62, blue: 1.0)

    static func providerLabel(for session: SessionState) -> String {
        session.provider == .claude ? "Claude" : "Codex"
    }

    static func providerColor(for session: SessionState) -> Color {
        session.provider == .claude ? claudeOrange : codexBlue
    }

    static func providerBadgeFill(for session: SessionState) -> Color {
        providerColor(for: session).opacity(session.provider == .claude ? 0.26 : 0.22)
    }

    static func assistantPrefixColor(for session: SessionState) -> Color {
        if session.needsQuestionResponse {
            return TerminalColors.blue.opacity(0.96)
        }
        if session.phase.isWaitingForApproval {
            return TerminalColors.amber.opacity(0.96)
        }
        return providerColor(for: session).opacity(session.phase.isActive ? 0.96 : 0.9)
    }

    static func assistantTextColor(for session: SessionState, compact: Bool) -> Color {
        if session.needsQuestionResponse {
            return .white.opacity(compact ? 0.82 : 0.88)
        }
        if session.phase.isWaitingForApproval {
            return .white.opacity(compact ? 0.74 : 0.8)
        }
        if session.phase.isActive {
            return .white.opacity(compact ? 0.68 : 0.78)
        }
        return .white.opacity(compact ? 0.58 : 0.68)
    }
}

private enum HoverPreviewLineBuilder {
    static func previewLines(for session: SessionState, compact: Bool, detailsEnabled: Bool) -> [HoverPreviewLine] {
        var lines: [HoverPreviewLine] = []

        if let userLine = latestUserLine(for: session) {
            lines.append(
                HoverPreviewLine(
                    id: "user",
                    prefix: "你：",
                    prefixColor: .white.opacity(compact ? 0.44 : 0.52),
                    text: userLine,
                    color: .white.opacity(compact ? 0.68 : 0.76)
                )
            )
        }

        if let assistantLine = latestAssistantLine(for: session, detailsEnabled: detailsEnabled) {
            lines.append(
                HoverPreviewLine(
                    id: "assistant",
                    prefix: HoverPreviewStyle.providerLabel(for: session) + "：",
                    prefixColor: HoverPreviewStyle.assistantPrefixColor(for: session),
                    text: assistantLine,
                    color: HoverPreviewStyle.assistantTextColor(for: session, compact: compact)
                )
            )
        }

        if lines.isEmpty, let fallback = fallbackPreview(for: session) {
            lines.append(
                HoverPreviewLine(
                    id: "fallback",
                    prefix: nil,
                    prefixColor: .clear,
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
            assistantText: latestAssistantText(for: session)
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
