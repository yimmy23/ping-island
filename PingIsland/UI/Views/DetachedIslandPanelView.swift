import SwiftUI

enum DetachedIslandPanelMetrics {
    static let outerHorizontalInset: CGFloat = 31
    static let bottomInset: CGFloat = 12
}

struct DetachedIslandPanelView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var sessionMonitor: SessionMonitor
    @ObservedObject private var settings = AppSettings.shared

    let onClose: () -> Void

    private var detachedSessions: [SessionState] {
        sessionMonitor.instances
            .filter { $0.phase.isActive || $0.needsManualAttention }
            .sorted { $0.shouldSortBeforeInQueue($1) }
    }

    private var activeCount: Int {
        detachedSessions.count
    }

    private var representativeSession: SessionState? {
        detachedSessions.first
    }

    private var compactMascotClient: MascotClient {
        representativeSession?.mascotClient ?? .claude
    }

    private var compactMascotKind: MascotKind {
        settings.mascotKind(for: compactMascotClient)
    }

    private var compactMascotStatus: MascotStatus {
        MascotStatus.closedNotchStatus(
            representativePhase: representativeSession?.phase,
            hasPendingPermission: detachedSessions.contains { $0.needsApprovalResponse },
            hasHumanIntervention: detachedSessions.contains { $0.intervention != nil }
        )
    }

    private var compactDetailText: String? {
        guard settings.notchDisplayMode == .detailed else { return nil }
        guard let representativeSession else { return nil }

        let candidates = [
            representativeSession.compactHookMessage,
            SessionTextSanitizer.sanitizedDisplayText(representativeSession.previewText),
            representativeSession.lastMessage
        ]

        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    var body: some View {
        content
            .preferredColorScheme(.dark)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .onAppear {
                sessionMonitor.startMonitoring()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.detachedDisplayMode {
        case .compact:
            if settings.notchDisplayMode == .detailed {
                compactCapsule
            } else {
                compactOrb
            }
        case .hoverExpanded:
            expandedCapsule
        }
    }

    private var compactCapsule: some View {
        HStack(spacing: 0) {
            MascotView(
                kind: compactMascotKind,
                status: compactMascotStatus,
                size: 16
            )
            .frame(width: sideWidth)

            compactCenterContent

            compactCountBadge
        }
        .frame(width: viewModel.detachedSize.width, height: viewModel.detachedSize.height)
        .background(.black)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.58), radius: 14, y: 8)
    }

    private var compactOrb: some View {
        MascotView(
            kind: compactMascotKind,
            status: compactMascotStatus,
            size: 18
        )
        .frame(width: viewModel.detachedSize.width, height: viewModel.detachedSize.height)
        .background(.black)
        .clipShape(Circle())
        .overlay(alignment: .bottomTrailing) {
            compactOrbBadge
                .offset(x: 4, y: 4)
        }
        .shadow(color: Color.black.opacity(0.58), radius: 14, y: 8)
    }

    private var sideWidth: CGFloat {
        max(0, viewModel.detachedSize.height - 12) + 10
    }

    private var compactCenterWidth: CGFloat {
        max(0, viewModel.detachedSize.width - (sideWidth * 2))
    }

    @ViewBuilder
    private var compactCenterContent: some View {
        ZStack {
            if let compactDetailText {
                Text(compactDetailText)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 10)
                    .frame(width: compactCenterWidth, alignment: .center)
            } else {
                Color.clear
                    .frame(width: compactCenterWidth)
            }
        }
        .frame(width: compactCenterWidth, alignment: .center)
    }

    private var compactCountBadge: some View {
        ZStack {
            if detachedSessions.contains(where: { $0.needsManualAttention }) {
                Circle()
                    .fill(Color.white.opacity(0.12))
                BellIndicatorIcon(size: 12, color: .white.opacity(0.92))
            } else if activeCount > 0 {
                Circle()
                    .fill(Color.white.opacity(0.12))
                PixelNumberView(
                    value: activeCount,
                    color: .white.opacity(0.92),
                    fontSize: activeCount >= 10 ? 8.8 : 9.6,
                    weight: .semibold,
                    tracking: activeCount >= 10 ? -0.15 : -0.05
                )
            }
        }
        .frame(width: sideWidth)
    }

    @ViewBuilder
    private var compactOrbBadge: some View {
        if detachedSessions.contains(where: { $0.needsManualAttention }) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.14))
                BellIndicatorIcon(size: 9, color: .white.opacity(0.92))
            }
            .frame(width: 18, height: 18)
        } else if activeCount > 0 {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.14))
                PixelNumberView(
                    value: activeCount,
                    color: .white.opacity(0.92),
                    fontSize: activeCount >= 10 ? 7.2 : 8.2,
                    weight: .semibold,
                    tracking: activeCount >= 10 ? -0.15 : -0.05
                )
            }
            .frame(width: 18, height: 18)
        }
    }

    private var expandedCapsule: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .frame(height: max(24, viewModel.closedHeight))

            SessionHoverDashboardView(
                sessions: detachedSessions,
                sessionMonitor: sessionMonitor
            )
            .frame(width: viewModel.detachedSize.width - 24)
        }
        .padding(.horizontal, 19)
        .padding([.horizontal, .bottom], DetachedIslandPanelMetrics.bottomInset)
        .background(.black)
        .clipShape(NotchShape(topCornerRadius: 19, bottomCornerRadius: 24))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.black)
                .frame(height: 1)
                .padding(.horizontal, 19)
        }
        .shadow(color: Color.black.opacity(0.65), radius: 16, y: 8)
    }

    private var header: some View {
        HStack(spacing: 12) {
            IslandDragHandleVisual()
                .padding(.leading, 14)

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
        }
        .padding(.top, 2)
    }
}
