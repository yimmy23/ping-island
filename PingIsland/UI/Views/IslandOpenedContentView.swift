import SwiftUI

struct IslandOpenedContentView: View {
    let sessionMonitor: SessionMonitor
    @ObservedObject var viewModel: NotchViewModel
    let style: IslandOpenedPresentationStyle
    let activeCompletionNotification: SessionCompletionNotification?
    let onCompletionNotificationHoverChanged: (Bool) -> Void
    let onDismissCompletionNotification: () -> Void

    var body: some View {
        Group {
            switch viewModel.contentType {
            case .instances:
                if viewModel.openReason == .notification,
                   let notification = activeCompletionNotification {
                    SessionCompletionNotificationView(
                        notification: notification,
                        onHoverChanged: onCompletionNotificationHoverChanged,
                        onDismiss: onDismissCompletionNotification
                    )
                } else if viewModel.openReason == .hover {
                    SessionHoverDashboardView(
                        sessions: sortedHoverSessions,
                        sessionMonitor: sessionMonitor
                    )
                } else {
                    SessionListView(
                        sessionMonitor: sessionMonitor,
                        viewModel: viewModel
                    )
                }
            case .chat(let session):
                let liveSession = sessionMonitor.instances.first(where: { $0.sessionId == session.sessionId }) ?? session

                if liveSession.provider == .claude {
                    ChatView(
                        sessionId: liveSession.sessionId,
                        initialSession: liveSession,
                        sessionMonitor: sessionMonitor,
                        viewModel: viewModel
                    )
                } else {
                    CodexSessionView(
                        session: liveSession,
                        sessionMonitor: sessionMonitor,
                        viewModel: viewModel
                    )
                }
            }
        }
        .frame(width: contentWidth)
    }

    private var sortedHoverSessions: [SessionState] {
        sessionMonitor.instances.sorted { $0.shouldSortBeforeInQueue($1) }
    }

    private var contentWidth: CGFloat {
        switch style {
        case .docked:
            return viewModel.openedSize.width - 24
        case .detached:
            return viewModel.detachedSize.width - 24
        }
    }
}
