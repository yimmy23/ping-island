import AppKit
import Combine
import SwiftUI

enum DetachedIslandPanelMetrics {
    static let petVisualFrame: CGFloat = 74
    static let petHitFrame: CGFloat = 92
    static let mascotDisplaySize: CGFloat = 46
    static let mascotRenderScale: CGFloat = 1.75
    static let badgeOffset = CGSize(width: -10, height: -8)
    static let bubbleGap: CGFloat = 8
    static let bubbleTailWidth: CGFloat = 30
    static let bubbleTailHeight: CGFloat = 16
    static let bubbleTailOverlap: CGFloat = 7
    static let bubbleTailInset: CGFloat = 4
    static let bubbleCornerRadius: CGFloat = 22
    static let bubbleHorizontalPadding: CGFloat = 12
    static let bubbleVerticalPadding: CGFloat = 10
}

enum DetachedIslandBubbleDirection: Equatable {
    case left
    case right
}

enum DetachedIslandBubbleContentMode: Equatable {
    case hoverPreview
    case pinnedList

    init?(bubbleState: DetachedIslandBubbleState) {
        switch bubbleState {
        case .hidden:
            return nil
        case .hoverPreview:
            self = .hoverPreview
        case .pinned:
            self = .pinnedList
        }
    }
}

struct DetachedIslandWindowLayout {
    let containerSize: CGSize
    let petFrame: CGRect
    let bubbleFrame: CGRect?
    let bubbleDirection: DetachedIslandBubbleDirection
    let petAnchorInWindow: CGPoint
    let bubbleContentMode: DetachedIslandBubbleContentMode?
}

enum DetachedIslandContentModel {
    static func bubbleDirection(
        for petScreenCenterX: CGFloat,
        screenMidX: CGFloat
    ) -> DetachedIslandBubbleDirection {
        petScreenCenterX < screenMidX ? .right : .left
    }

    static func sortedSessions(from sessions: [SessionState]) -> [SessionState] {
        IslandExpandedRouteResolver.orderedSessions(from: sessions)
    }

    static func representativeSession(from sessions: [SessionState]) -> SessionState? {
        IslandExpandedRouteResolver.highestPriorityAttentionSession(from: sessions)
            ?? sortedSessions(from: sessions).first
    }

    static func activeCount(from sessions: [SessionState]) -> Int {
        sessions.filter { $0.phase.isActive }.count
    }

    static func canPresentBubble(
        from sessions: [SessionState],
        mode: DetachedIslandBubbleContentMode
    ) -> Bool {
        switch mode {
        case .hoverPreview:
            return IslandExpandedRouteResolver.highestPriorityAttentionSession(from: sessions) != nil
                || !IslandExpandedRouteResolver.activePreviewSessions(from: sessions).isEmpty
        case .pinnedList:
            return !sortedSessions(from: sessions).isEmpty
        }
    }

    static func route(
        for sessions: [SessionState],
        viewModel: NotchViewModel,
        mode: DetachedIslandBubbleContentMode
    ) -> IslandExpandedRoute {
        let trigger: IslandExpandedTrigger = switch mode {
        case .hoverPreview: .hover
        case .pinnedList: .pinnedList
        }

        return IslandExpandedRouteResolver.resolve(
            surface: .floating,
            trigger: trigger,
            contentType: viewModel.contentType,
            sessions: sessions
        )
    }

    static func bubbleContentSize(
        for route: IslandExpandedRoute,
        sessions: [SessionState],
        viewModel: NotchViewModel
    ) -> CGSize {
        let widthLimit = viewModel.screenRect.width - 132

        switch route {
        case .sessionList:
            let width = min(widthLimit, 400)
            let sorted = sortedSessions(from: sessions)
            let estimatedHeight = sessionListEstimatedHeight(for: sorted)
            let height = min(viewModel.screenRect.height - 160, max(96, estimatedHeight))
            return CGSize(width: width, height: height)
        case .hoverDashboard:
            let width = min(widthLimit, 352)
            let visibleCount = max(min(IslandExpandedRouteResolver.activePreviewSessions(from: sessions).count, 3), 1)
            let estimatedHeight = 18 + (CGFloat(visibleCount) * 94)
            let height = min(viewModel.screenRect.height - 160, max(120, estimatedHeight))
            return CGSize(width: width, height: height)
        case .attentionNotification(let session):
            let width = min(widthLimit, 360)
            let height: CGFloat
            if session.needsQuestionResponse {
                height = min(viewModel.screenRect.height - 160, 316)
            } else {
                height = min(viewModel.screenRect.height - 160, 228)
            }
            return CGSize(width: width, height: max(170, height))
        case .completionNotification:
            let width = min(widthLimit, 360)
            let height = min(viewModel.screenRect.height - 160, 260)
            return CGSize(width: width, height: max(190, height))
        case .chat:
            return viewModel.panelSize(for: .detached)
        }
    }

    private static func sessionListEstimatedHeight(for sessions: [SessionState]) -> CGFloat {
        guard !sessions.isEmpty else { return 96 }

        let contentHeight = sessions.reduce(CGFloat(0)) { partial, session in
            partial + sessionListRowHeight(for: session)
        }
        let spacing = CGFloat(max(0, sessions.count - 1)) * 2
        let verticalInsets: CGFloat = 12
        return contentHeight + spacing + verticalInsets
    }

    private static func sessionListRowHeight(for session: SessionState) -> CGFloat {
        if session.needsQuestionResponse || session.needsApprovalResponse || session.needsManualAttention {
            return 108
        }
        if session.phase.isActive {
            return 100
        }
        if session.shouldUseMinimalCompactPresentation || session.usesTitleOnlySubagentPresentation {
            return 56
        }
        return 68
    }

    static func contentWidth(
        for bubbleFrameWidth: CGFloat
    ) -> CGFloat {
        max(
            0,
            bubbleFrameWidth - (DetachedIslandPanelMetrics.bubbleHorizontalPadding * 2)
        )
    }

    static func layout(
        for sessions: [SessionState],
        viewModel: NotchViewModel,
        bubbleState: DetachedIslandBubbleState,
        bubbleDirection: DetachedIslandBubbleDirection
    ) -> DetachedIslandWindowLayout {
        let petSize = CGSize(
            width: DetachedIslandPanelMetrics.petHitFrame,
            height: DetachedIslandPanelMetrics.petHitFrame
        )
        let hiddenAnchor = CGPoint(x: petSize.width / 2, y: petSize.height / 2)

        guard let mode = DetachedIslandBubbleContentMode(bubbleState: bubbleState),
              canPresentBubble(from: sessions, mode: mode) else {
            return DetachedIslandWindowLayout(
                containerSize: petSize,
                petFrame: CGRect(origin: .zero, size: petSize),
                bubbleFrame: nil,
                bubbleDirection: bubbleDirection,
                petAnchorInWindow: hiddenAnchor,
                bubbleContentMode: nil
            )
        }

        let route = route(for: sessions, viewModel: viewModel, mode: mode)
        let bubbleSize = bubbleContentSize(for: route, sessions: sessions, viewModel: viewModel)
        let containerHeight = max(petSize.height, bubbleSize.height)
        let petOriginY = containerHeight - petSize.height
        let bubbleOriginY = containerHeight - bubbleSize.height

        let petOriginX: CGFloat
        let bubbleOriginX: CGFloat
        switch bubbleDirection {
        case .right:
            petOriginX = 0
            bubbleOriginX = petSize.width + DetachedIslandPanelMetrics.bubbleGap
        case .left:
            bubbleOriginX = 0
            petOriginX = bubbleSize.width + DetachedIslandPanelMetrics.bubbleGap
        }

        let petFrame = CGRect(
            origin: CGPoint(x: petOriginX, y: petOriginY),
            size: petSize
        )
        let bubbleFrame = CGRect(
            origin: CGPoint(x: bubbleOriginX, y: bubbleOriginY),
            size: bubbleSize
        )

        return DetachedIslandWindowLayout(
            containerSize: CGSize(
                width: petSize.width + DetachedIslandPanelMetrics.bubbleGap + bubbleSize.width,
                height: containerHeight
            ),
            petFrame: petFrame,
            bubbleFrame: bubbleFrame,
            bubbleDirection: bubbleDirection,
            petAnchorInWindow: CGPoint(x: petFrame.midX, y: petFrame.midY),
            bubbleContentMode: mode
        )
    }
}

@MainActor
final class DetachedIslandInteractionModel: ObservableObject {
    @Published private(set) var bubbleState: DetachedIslandBubbleState = .hidden
    @Published private(set) var bubbleDirection: DetachedIslandBubbleDirection = .right

    private var isHoveringPet = false
    private var isHoveringBubble = false
    private var isHoverSuppressed = false
    private var hidePreviewWorkItem: DispatchWorkItem?

    var bubbleContentMode: DetachedIslandBubbleContentMode? {
        DetachedIslandBubbleContentMode(bubbleState: bubbleState)
    }

    func setBubbleDirection(_ direction: DetachedIslandBubbleDirection) {
        guard bubbleDirection != direction else { return }
        bubbleDirection = direction
    }

    func setHoveringPet(_ isHovering: Bool, canPresentBubble: Bool) {
        isHoveringPet = isHovering
        updateHoverDrivenState(canPresentBubble: canPresentBubble)
    }

    func setHoveringBubble(_ isHovering: Bool, canPresentBubble: Bool) {
        isHoveringBubble = isHovering
        updateHoverDrivenState(canPresentBubble: canPresentBubble)
    }

    func togglePinned(canPresentBubble: Bool) {
        guard canPresentBubble else { return }
        cancelPendingHide()

        switch bubbleState {
        case .pinned:
            bubbleState = .hidden
        case .hidden, .hoverPreview:
            bubbleState = .pinned
        }
    }

    func hidePinnedBubble() {
        cancelPendingHide()
        isHoveringPet = false
        isHoveringBubble = false
        bubbleState = .hidden
    }

    func presentHoverPreview(canPresentBubble: Bool) {
        guard canPresentBubble else {
            hidePinnedBubble()
            return
        }

        cancelPendingHide()
        bubbleState = .hoverPreview
    }

    func resetForDragSuppression() {
        isHoverSuppressed = true
        hidePinnedBubble()
    }

    private func updateHoverDrivenState(canPresentBubble: Bool) {
        guard canPresentBubble else {
            hidePinnedBubble()
            return
        }

        // After a drag or notch-to-floating transition, require the pointer to
        // leave the pet once before hover previews can re-arm.
        if isHoverSuppressed {
            cancelPendingHide()
            bubbleState = .hidden
            if !isHoveringPet && !isHoveringBubble {
                isHoverSuppressed = false
            }
            return
        }

        guard bubbleState != .pinned else {
            cancelPendingHide()
            return
        }

        if isHoveringPet || isHoveringBubble {
            cancelPendingHide()
            bubbleState = .hoverPreview
        } else {
            scheduleHidePreview()
        }
    }

    private func scheduleHidePreview() {
        cancelPendingHide()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.hidePreviewWorkItem = nil
            guard !self.isHoveringPet, !self.isHoveringBubble, self.bubbleState != .pinned else { return }
            self.bubbleState = .hidden
        }
        hidePreviewWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    private func cancelPendingHide() {
        hidePreviewWorkItem?.cancel()
        hidePreviewWorkItem = nil
    }
}

@MainActor
final class DetachedIslandBubbleViewState: ObservableObject {
    @Published var highlightedSessionStableID: String?
    @Published private(set) var renderedBubbleState: DetachedIslandBubbleState = .hidden
    @Published private(set) var isBubbleVisible = false

    var bubbleFadeDuration: TimeInterval { 0.18 }

    func prepareLayout(for bubbleState: DetachedIslandBubbleState) {
        guard renderedBubbleState != bubbleState else { return }
        renderedBubbleState = bubbleState
    }

    func setBubbleVisible(_ visible: Bool) {
        guard isBubbleVisible != visible else { return }
        isBubbleVisible = visible
    }
}

struct DetachedIslandPanelView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var sessionMonitor: SessionMonitor
    @ObservedObject var interactionModel: DetachedIslandInteractionModel
    @ObservedObject var bubbleViewState: DetachedIslandBubbleViewState
    @ObservedObject private var settings = AppSettings.shared

    let onClose: () -> Void
    let onPetTap: () -> Void
    let onPetDragStarted: () -> Void
    let onPetDragChanged: (CGSize) -> Void
    let onPetDragEnded: () -> Void

    private var sortedSessions: [SessionState] {
        DetachedIslandContentModel.sortedSessions(from: sessionMonitor.instances)
    }

    private var representativeSession: SessionState? {
        DetachedIslandContentModel.representativeSession(from: sortedSessions)
    }

    private var activeCount: Int {
        DetachedIslandContentModel.activeCount(from: sortedSessions)
    }

    private var canPresentHoverBubble: Bool {
        DetachedIslandContentModel.canPresentBubble(from: sortedSessions, mode: .hoverPreview)
    }

    private var canPresentPinnedBubble: Bool {
        DetachedIslandContentModel.canPresentBubble(from: sortedSessions, mode: .pinnedList)
    }

    private var bubbleContentMode: DetachedIslandBubbleContentMode? {
        DetachedIslandBubbleContentMode(bubbleState: bubbleViewState.renderedBubbleState)
    }

    private var bubbleRoute: IslandExpandedRoute? {
        guard let bubbleContentMode else { return nil }
        return DetachedIslandContentModel.route(
            for: sortedSessions,
            viewModel: viewModel,
            mode: bubbleContentMode
        )
    }

    private var layout: DetachedIslandWindowLayout {
        DetachedIslandContentModel.layout(
            for: sortedSessions,
            viewModel: viewModel,
            bubbleState: bubbleViewState.renderedBubbleState,
            bubbleDirection: interactionModel.bubbleDirection
        )
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
            hasPendingPermission: sortedSessions.contains { $0.needsApprovalResponse },
            hasHumanIntervention: sortedSessions.contains { $0.intervention != nil }
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let bubbleFrame = layout.bubbleFrame,
               let bubbleContentMode,
               let bubbleRoute {
                bubbleView(
                    mode: bubbleContentMode,
                    route: bubbleRoute,
                    contentWidth: DetachedIslandContentModel.contentWidth(for: bubbleFrame.width)
                )
                    .opacity(bubbleViewState.isBubbleVisible ? 1 : 0)
                    .allowsHitTesting(bubbleViewState.isBubbleVisible)
                    .frame(width: bubbleFrame.width, height: bubbleFrame.height)
                    .offset(x: bubbleFrame.minX, y: bubbleFrame.minY)
                    .onHover { hovering in
                        interactionModel.setHoveringBubble(hovering, canPresentBubble: canPresentHoverBubble)
                    }
            }

            petButton
                .frame(width: layout.petFrame.width, height: layout.petFrame.height)
                .offset(x: layout.petFrame.minX, y: layout.petFrame.minY)
        }
        .frame(
            width: layout.containerSize.width,
            height: layout.containerSize.height,
            alignment: .topLeading
        )
        .preferredColorScheme(.dark)
        .onAppear {
            sessionMonitor.startMonitoring()
        }
    }

    private var petButton: some View {
        DetachedFloatingPetInteractionView(
            activeCount: activeCount,
            mascotKind: compactMascotKind,
            mascotStatus: compactMascotStatus,
            onTap: onPetTap,
            onDragStarted: onPetDragStarted,
            onDragChanged: onPetDragChanged,
            onDragEnded: onPetDragEnded
        )
        .onHover { hovering in
            interactionModel.setHoveringPet(hovering, canPresentBubble: canPresentHoverBubble)
        }
    }

    private func bubbleView(
        mode: DetachedIslandBubbleContentMode,
        route: IslandExpandedRoute,
        contentWidth: CGFloat
    ) -> some View {
        DetachedIslandBubbleChrome(direction: layout.bubbleDirection) {
            IslandOpenedContentView(
                sessionMonitor: sessionMonitor,
                viewModel: viewModel,
                surface: .floating,
                trigger: mode == .pinnedList ? .pinnedList : .hover,
                style: .detached,
                activeCompletionNotification: nil,
                highlightedSessionStableID: route == .sessionList
                    ? bubbleViewState.highlightedSessionStableID
                    : nil,
                contentWidthOverride: contentWidth,
                onCompletionNotificationHoverChanged: { _ in },
                onDismissCompletionNotification: {}
            )
        }
    }
}

private struct DetachedFloatingPetInteractionView: View {
    let activeCount: Int
    let mascotKind: MascotKind
    let mascotStatus: MascotStatus
    let onTap: () -> Void
    let onDragStarted: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            DetachedFloatingMascotView(
                kind: mascotKind,
                status: mascotStatus
            )
            .frame(
                width: DetachedIslandPanelMetrics.petVisualFrame,
                height: DetachedIslandPanelMetrics.petVisualFrame
            )

            if activeCount > 0 {
                activeCountBadge
                    .offset(
                        x: DetachedIslandPanelMetrics.badgeOffset.width,
                        y: DetachedIslandPanelMetrics.badgeOffset.height
                    )
            }
        }
        .frame(
            width: DetachedIslandPanelMetrics.petHitFrame,
            height: DetachedIslandPanelMetrics.petHitFrame
        )
        .overlay {
            DetachedPetInteractionBridge(
                size: CGSize(
                    width: DetachedIslandPanelMetrics.petHitFrame,
                    height: DetachedIslandPanelMetrics.petHitFrame
                ),
                onTap: onTap,
                onDragStarted: onDragStarted,
                onDragChanged: onDragChanged,
                onDragEnded: onDragEnded
            )
            .frame(
                width: DetachedIslandPanelMetrics.petHitFrame,
                height: DetachedIslandPanelMetrics.petHitFrame
            )
        }
    }

    @ViewBuilder
    private var activeCountBadge: some View {
        PixelNumberView(
            value: activeCount,
            color: .white.opacity(0.96),
            fontSize: activeCount >= 10 ? 8.2 : 9.2,
            weight: .semibold,
            tracking: activeCount >= 10 ? -0.15 : -0.05
        )
    }
}

private struct DetachedPetInteractionBridge: NSViewRepresentable {
    let size: CGSize
    let onTap: () -> Void
    let onDragStarted: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void

    func makeNSView(context: Context) -> DetachedPetInteractionView {
        let view = DetachedPetInteractionView(frame: NSRect(origin: .zero, size: size))
        update(view)
        return view
    }

    func updateNSView(_ nsView: DetachedPetInteractionView, context: Context) {
        nsView.frame = NSRect(origin: .zero, size: size)
        update(nsView)
    }

    private func update(_ view: DetachedPetInteractionView) {
        view.onTap = onTap
        view.onDragStarted = onDragStarted
        view.onDragChanged = onDragChanged
        view.onDragEnded = onDragEnded
    }
}

private final class DetachedPetInteractionView: NSView {
    var onTap: () -> Void = {}
    var onDragStarted: () -> Void = {}
    var onDragChanged: (CGSize) -> Void = { _ in }
    var onDragEnded: () -> Void = {}

    private let dragThreshold: CGFloat = 3
    private var mouseDownPoint: CGPoint?
    private var hasStartedDrag = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        hasStartedDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let mouseDownPoint else { return }

        let currentPoint = convert(event.locationInWindow, from: nil)
        let translation = CGSize(
            width: currentPoint.x - mouseDownPoint.x,
            height: currentPoint.y - mouseDownPoint.y
        )

        if !hasStartedDrag, hypot(translation.width, translation.height) >= dragThreshold {
            hasStartedDrag = true
            onDragStarted()
        }

        guard hasStartedDrag else { return }
        onDragChanged(translation)
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownPoint = nil
            hasStartedDrag = false
        }

        if hasStartedDrag {
            onDragEnded()
            return
        }

        onTap()
    }
}

private struct DetachedFloatingMascotView: View {
    let kind: MascotKind
    let status: MascotStatus

    private var renderSize: CGFloat {
        DetachedIslandPanelMetrics.mascotDisplaySize * DetachedIslandPanelMetrics.mascotRenderScale
    }

    private var displayScale: CGFloat {
        DetachedIslandPanelMetrics.mascotDisplaySize / renderSize
    }

    var body: some View {
        MascotView(
            kind: kind,
            status: status,
            size: renderSize
        )
        .frame(width: renderSize, height: renderSize)
        .scaleEffect(displayScale)
        .frame(
            width: DetachedIslandPanelMetrics.mascotDisplaySize,
            height: DetachedIslandPanelMetrics.mascotDisplaySize
        )
        .compositingGroup()
        .drawingGroup(opaque: false, colorMode: .linear)
        .allowsHitTesting(false)
    }
}

private struct DetachedIslandBubbleChrome<Content: View>: View {
    let direction: DetachedIslandBubbleDirection
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, DetachedIslandPanelMetrics.bubbleHorizontalPadding)
            .padding(.vertical, DetachedIslandPanelMetrics.bubbleVerticalPadding)
            .background(
                RoundedRectangle(
                    cornerRadius: DetachedIslandPanelMetrics.bubbleCornerRadius,
                    style: .continuous
                )
                .fill(Color.black)
            )
            .overlay(alignment: direction == .right ? .bottomLeading : .bottomTrailing) {
                DetachedIslandBubbleTail(pointsTowardPet: direction == .right)
                    .fill(Color.black)
                    .frame(
                        width: DetachedIslandPanelMetrics.bubbleTailWidth,
                        height: DetachedIslandPanelMetrics.bubbleTailHeight
                    )
                    .offset(
                        x: direction == .right
                            ? DetachedIslandPanelMetrics.bubbleTailInset
                            : 12,
                        y: DetachedIslandPanelMetrics.bubbleTailHeight - DetachedIslandPanelMetrics.bubbleTailOverlap
                    )
                    .allowsHitTesting(false)
            }
    }
}

private struct DetachedIslandBubbleTail: Shape {
    let pointsTowardPet: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let shoulderX = rect.width * 0.58
        let returnX = rect.width * 0.76
        let tipY = rect.height * 0.96
        let returnY = rect.height * 0.18

        if pointsTowardPet {
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + shoulderX, y: rect.minY))
            path.addCurve(
                to: CGPoint(x: rect.minX, y: tipY),
                control1: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY),
                control2: CGPoint(x: rect.minX, y: rect.height * 0.52)
            )
            path.addCurve(
                to: CGPoint(x: rect.minX + returnX, y: rect.minY + returnY),
                control1: CGPoint(x: rect.minX + rect.width * 0.14, y: rect.height * 1.02),
                control2: CGPoint(x: rect.minX + rect.width * 0.56, y: rect.height * 0.42)
            )
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - shoulderX, y: rect.minY))
            path.addCurve(
                to: CGPoint(x: rect.maxX, y: tipY),
                control1: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.minY),
                control2: CGPoint(x: rect.maxX, y: rect.height * 0.52)
            )
            path.addCurve(
                to: CGPoint(x: rect.maxX - returnX, y: rect.minY + returnY),
                control1: CGPoint(x: rect.maxX - rect.width * 0.14, y: rect.height * 1.02),
                control2: CGPoint(x: rect.maxX - rect.width * 0.56, y: rect.height * 0.42)
            )
        }
        path.closeSubpath()
        return path
    }
}
