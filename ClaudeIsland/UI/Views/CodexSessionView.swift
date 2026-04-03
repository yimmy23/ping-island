import SwiftUI

struct CodexSessionView: View {
    let session: SessionState
    let sessionMonitor: ClaudeSessionMonitor
    @ObservedObject var viewModel: NotchViewModel

    @State private var answers: [String: String] = [:]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                summaryCard

                if let intervention = session.intervention {
                    interventionCard(intervention)
                } else {
                    infoCard
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.displayTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            HStack(spacing: 8) {
                providerBadge

                Text(session.phase.description)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }

            if let preview = session.previewText ?? session.lastMessage {
                Text(preview)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.72))
            }

            if !session.cwd.isEmpty && session.cwd != "/" {
                Text(session.cwd)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.45))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func interventionCard(_ intervention: SessionIntervention) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(intervention.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            Text(intervention.message)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.72))

            if intervention.kind == .approval {
                approvalButtons(intervention)
            } else {
                questionForm(intervention)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func approvalButtons(_ intervention: SessionIntervention) -> some View {
        HStack(spacing: 8) {
            Button("Allow Once") {
                sessionMonitor.approvePermission(sessionId: session.sessionId)
                viewModel.exitChat()
            }
            .buttonStyle(CodexCapsuleButtonStyle(background: Color.white.opacity(0.9), foreground: .black))

            if intervention.supportsSessionScope {
                Button("Allow Session") {
                    sessionMonitor.approvePermission(sessionId: session.sessionId, forSession: true)
                    viewModel.exitChat()
                }
                .buttonStyle(CodexCapsuleButtonStyle(background: TerminalColors.blue.opacity(0.28)))
            }

            Button("Deny") {
                sessionMonitor.denyPermission(sessionId: session.sessionId, reason: nil)
                viewModel.exitChat()
            }
            .buttonStyle(CodexCapsuleButtonStyle(background: Color.white.opacity(0.1)))
        }
    }

    private func questionForm(_ intervention: SessionIntervention) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(intervention.questions) { question in
                VStack(alignment: .leading, spacing: 8) {
                    Text(question.header)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(TerminalColors.blue.opacity(0.9))

                    Text(question.prompt)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)

                    if !question.options.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                            ForEach(question.options) { option in
                                Button {
                                    answers[question.id] = option.title
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(option.title)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                        if let detail = option.detail {
                                            Text(detail)
                                                .font(.system(size: 10))
                                                .foregroundColor(.white.opacity(0.55))
                                                .lineLimit(2)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(answers[question.id] == option.title ? TerminalColors.blue.opacity(0.22) : Color.white.opacity(0.05))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else if question.isSecret {
                        SecureField("Answer", text: Binding(
                            get: { answers[question.id] ?? "" },
                            set: { answers[question.id] = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                    } else {
                        TextField("Answer", text: Binding(
                            get: { answers[question.id] ?? "" },
                            set: { answers[question.id] = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                    }
                }
            }

            HStack(spacing: 8) {
                Button("Submit") {
                    let payload = intervention.questions.reduce(into: [String: [String]]()) { partial, question in
                        guard let answer = answers[question.id], !answer.isEmpty else { return }
                        partial[question.id] = [answer]
                    }
                    sessionMonitor.answerIntervention(sessionId: session.sessionId, answers: payload)
                    viewModel.exitChat()
                }
                .buttonStyle(CodexCapsuleButtonStyle(background: Color.white.opacity(0.9), foreground: .black))
                .disabled(!canSubmit(intervention))

                Button("Cancel") {
                    viewModel.exitChat()
                }
                .buttonStyle(CodexCapsuleButtonStyle(background: Color.white.opacity(0.1)))
            }
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Codex thread synced")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Text("This thread is being tracked through the local Codex app-server. Approval requests and question prompts will show up here when the agent needs you.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.72))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var providerBadge: some View {
        Text("CODEX")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(TerminalColors.blue.opacity(0.95))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(TerminalColors.blue.opacity(0.14))
            .clipShape(Capsule())
    }

    private func canSubmit(_ intervention: SessionIntervention) -> Bool {
        !intervention.questions.contains(where: { (answers[$0.id] ?? "").isEmpty })
    }
}

private struct CodexCapsuleButtonStyle: ButtonStyle {
    var background: Color
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(foreground.opacity(configuration.isPressed ? 0.8 : 1))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(background.opacity(configuration.isPressed ? 0.72 : 1))
            )
    }
}
