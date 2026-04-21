import AppKit
import XCTest
@testable import Ping_Island

@MainActor
final class DetachedIslandWindowControllerTests: XCTestCase {
    func testDetachedHostingViewStaysTransparent() throws {
        let viewModel = makeViewModel()
        let sessionMonitor = SessionMonitor()
        sessionMonitor.instances = []

        let controller = DetachedIslandWindowController(
            viewModel: viewModel,
            sessionMonitor: sessionMonitor,
            onClose: {}
        )
        defer { controller.dismiss() }

        let contentView = try XCTUnwrap(controller.window?.contentView)
        XCTAssertFalse(contentView.isOpaque)
        XCTAssertTrue(contentView.wantsLayer)

        let layer = try XCTUnwrap(contentView.layer)
        XCTAssertFalse(layer.isOpaque)
        XCTAssertEqual(layer.backgroundColor, NSColor.clear.cgColor)
    }

    func testDetachedHostingViewAcceptsFirstMouse() throws {
        let viewModel = makeViewModel()
        let sessionMonitor = SessionMonitor()
        sessionMonitor.instances = []

        let controller = DetachedIslandWindowController(
            viewModel: viewModel,
            sessionMonitor: sessionMonitor,
            onClose: {}
        )
        defer { controller.dismiss() }

        let contentView = try XCTUnwrap(controller.window?.contentView)
        XCTAssertTrue(contentView.acceptsFirstMouse(for: nil))
    }

    func testDetachedWindowDisablesSystemShadow() throws {
        let viewModel = makeViewModel()
        let sessionMonitor = SessionMonitor()
        sessionMonitor.instances = []

        let controller = DetachedIslandWindowController(
            viewModel: viewModel,
            sessionMonitor: sessionMonitor,
            onClose: {}
        )
        defer { controller.dismiss() }

        let window = try XCTUnwrap(controller.window)
        XCTAssertFalse(window.hasShadow)
        XCTAssertFalse(window.isOpaque)
        XCTAssertEqual(window.backgroundColor, .clear)
    }

    func testDetachedWindowUsesCustomDragInsteadOfBackgroundDragging() throws {
        let viewModel = makeViewModel()
        let sessionMonitor = SessionMonitor()
        sessionMonitor.instances = []

        let controller = DetachedIslandWindowController(
            viewModel: viewModel,
            sessionMonitor: sessionMonitor,
            onClose: {}
        )
        defer { controller.dismiss() }

        let window = try XCTUnwrap(controller.window)
        XCTAssertFalse(window.isMovableByWindowBackground)
    }

    func testDetachedWindowSupportsFullscreenFloatingPresentation() throws {
        let viewModel = makeViewModel()
        let sessionMonitor = SessionMonitor()
        sessionMonitor.instances = []

        let controller = DetachedIslandWindowController(
            viewModel: viewModel,
            sessionMonitor: sessionMonitor,
            onClose: {}
        )
        defer { controller.dismiss() }

        let window = try XCTUnwrap(controller.window)
        XCTAssertEqual(window.level.rawValue, NSWindow.Level.statusBar.rawValue)
        XCTAssertTrue(window.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(window.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(window.collectionBehavior.contains(.ignoresCycle))
    }

    func testPetInteractionFrameConvertsTopAnchoredLayoutIntoWindowCoordinates() {
        let layout = DetachedIslandWindowLayout(
            containerSize: CGSize(width: 92, height: 164),
            petFrame: CGRect(x: 0, y: 36, width: 92, height: 92),
            bubbleFrame: CGRect(x: 104, y: 12, width: 280, height: 140),
            bubbleDirection: .right,
            petAnchorInWindow: CGPoint(x: 46, y: 82),
            bubbleContentMode: .hoverPreview
        )

        let frame = DetachedIslandWindowController.petInteractionFrame(for: layout)

        XCTAssertEqual(frame.origin.x, 0, accuracy: 0.5)
        XCTAssertEqual(frame.origin.y, 36, accuracy: 0.5)
        XCTAssertEqual(frame.width, 92, accuracy: 0.5)
        XCTAssertEqual(frame.height, 92, accuracy: 0.5)
    }

    func testFloatingDragTranslationUsesScreenCoordinates() {
        let translation = DetachedIslandWindowController.floatingDragTranslation(
            from: CGPoint(x: 400, y: 600),
            to: CGPoint(x: 438, y: 572)
        )

        XCTAssertEqual(translation.width, 38, accuracy: 0.5)
        XCTAssertEqual(translation.height, 28, accuracy: 0.5)
    }

    func testFloatingDragUpdatesWindowOrigin() throws {
        let viewModel = makeViewModel()
        let sessionMonitor = SessionMonitor()
        sessionMonitor.instances = []

        let controller = DetachedIslandWindowController(
            viewModel: viewModel,
            sessionMonitor: sessionMonitor,
            onClose: {}
        )
        defer { controller.dismiss() }

        let window = try XCTUnwrap(controller.window)
        window.setFrame(
            NSRect(x: 180, y: 420, width: 100, height: 100),
            display: false
        )

        controller.beginFloatingDrag()
        controller.updateFloatingDrag(translation: CGSize(width: 24, height: 16))
        controller.endFloatingDrag()

        XCTAssertEqual(window.frame.origin.x, 204, accuracy: 0.5)
        XCTAssertEqual(window.frame.origin.y, 404, accuracy: 0.5)
    }

    func testFloatingDragKeepsMouseEventsEnabled() throws {
        let viewModel = makeViewModel()
        let sessionMonitor = SessionMonitor()
        sessionMonitor.instances = []

        let controller = DetachedIslandWindowController(
            viewModel: viewModel,
            sessionMonitor: sessionMonitor,
            onClose: {}
        )
        defer { controller.dismiss() }

        let window = try XCTUnwrap(controller.window)
        window.ignoresMouseEvents = false

        controller.beginFloatingDrag()

        XCTAssertFalse(window.ignoresMouseEvents)
    }

    func testPetSecondaryClickPresentsSettingsWindow() throws {
        let settingsController = SettingsWindowController.shared
        settingsController.dismiss()

        let viewModel = makeViewModel()
        let sessionMonitor = SessionMonitor()
        sessionMonitor.instances = []

        let controller = DetachedIslandWindowController(
            viewModel: viewModel,
            sessionMonitor: sessionMonitor,
            onClose: {}
        )
        defer {
            controller.dismiss()
            settingsController.dismiss()
        }

        controller.handlePetSecondaryClick()

        let window = try XCTUnwrap(settingsController.window)
        XCTAssertTrue(window.isVisible)
        XCTAssertFalse(window.isMiniaturized)
    }

    func testDefaultPetAnchorUsesBottomTrailingVisibleFrameInsets() {
        let visibleFrame = CGRect(x: 100, y: 60, width: 960, height: 640)

        let anchor = DetachedIslandWindowController.defaultPetAnchor(in: visibleFrame)

        XCTAssertEqual(anchor.x, 982, accuracy: 0.5)
        XCTAssertEqual(anchor.y, 154, accuracy: 0.5)
    }

    func testDefaultPetAnchorCanAlignToActiveWindowBottomTrailingCorner() {
        let visibleFrame = CGRect(x: 80, y: 40, width: 1200, height: 800)
        let activeWindowFrame = CGRect(x: 320, y: 180, width: 640, height: 420)

        let anchor = DetachedIslandWindowController.defaultPetAnchor(
            in: visibleFrame,
            alignedTo: activeWindowFrame
        )

        XCTAssertEqual(anchor.x, 882, accuracy: 0.5)
        XCTAssertEqual(anchor.y, 274, accuracy: 0.5)
    }

    func testFloatingPetAnchorRoundTripsThroughVisibleFrameRatios() {
        let visibleFrame = CGRect(x: 40, y: 24, width: 1280, height: 720)
        let petAnchor = CGPoint(x: 1110, y: 144)

        let storedAnchor = DetachedIslandWindowController.floatingPetAnchor(
            from: petAnchor,
            in: visibleFrame
        )
        let restoredAnchor = DetachedIslandWindowController.petAnchor(
            from: storedAnchor,
            in: visibleFrame
        )

        XCTAssertEqual(restoredAnchor.x, petAnchor.x, accuracy: 0.5)
        XCTAssertEqual(restoredAnchor.y, petAnchor.y, accuracy: 0.5)
    }

    func testStoredFloatingPetAnchorClampsBackIntoVisibleFrame() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 400, height: 240)
        let storedAnchor = FloatingPetAnchor(xRatio: 1.4, yRatio: -0.3)

        let restoredAnchor = DetachedIslandWindowController.petAnchor(
            from: storedAnchor,
            in: visibleFrame
        )

        XCTAssertEqual(restoredAnchor.x, 354, accuracy: 0.5)
        XCTAssertEqual(restoredAnchor.y, 46, accuracy: 0.5)
    }

    func testActiveCountOnlyTracksActiveSessions() {
        let sessions = [
            makeSession(id: "processing", phase: .processing),
            makeSession(id: "waiting", phase: .waitingForInput),
            makeSession(id: "ended", phase: .ended)
        ]

        XCTAssertEqual(DetachedIslandContentModel.activeCount(from: sessions), 1)
    }

    func testBubbleDirectionUsesPetSideOfScreen() {
        XCTAssertEqual(
            DetachedIslandContentModel.bubbleDirection(for: 220, screenMidX: 720),
            .right
        )
        XCTAssertEqual(
            DetachedIslandContentModel.bubbleDirection(for: 980, screenMidX: 720),
            .left
        )
    }

    func testHoverPreviewUsesSharedAttentionRouteWhenNeeded() {
        let attention = makeSession(
            id: "attention",
            phase: .waitingForInput,
            intervention: makeIntervention(
                id: "question-1",
                kind: .question,
                message: "Need your answer"
            )
        )
        let active = makeSession(id: "active", phase: .processing)
        let interactionModel = DetachedIslandInteractionModel()
        let viewModel = makeViewModel()

        interactionModel.presentHoverPreview(canPresentBubble: true)

        XCTAssertEqual(interactionModel.bubbleContentMode, .hoverPreview)
        XCTAssertEqual(
            DetachedIslandContentModel.route(
                for: [active, attention],
                viewModel: viewModel,
                mode: .hoverPreview
            ),
            .attentionNotification(attention)
        )
    }

    func testPinnedBubbleUsesSharedSessionListRoute() {
        let active = makeSession(id: "active", phase: .processing)
        let interactionModel = DetachedIslandInteractionModel()
        let viewModel = makeViewModel()

        interactionModel.togglePinned(canPresentBubble: true)

        XCTAssertEqual(interactionModel.bubbleContentMode, .pinnedList)
        XCTAssertEqual(
            DetachedIslandContentModel.route(
                for: [active],
                viewModel: viewModel,
                mode: .pinnedList
            ),
            .sessionList
        )
    }

    func testSessionListBubbleHeightScalesWithSessionCount() {
        let viewModel = makeViewModel()
        let single = [makeSession(id: "active-1", phase: .processing)]
        let many = [
            makeSession(id: "active-1", phase: .processing),
            makeSession(id: "active-2", phase: .processing),
            makeSession(id: "attention", phase: .waitingForInput, intervention: makeIntervention(id: "q-1", kind: .question, message: "Need your answer")),
            makeSession(id: "idle-1", phase: .idle),
            makeSession(id: "ended-1", phase: .ended)
        ]

        let singleHeight = DetachedIslandContentModel.bubbleContentSize(
            for: .sessionList,
            sessions: single,
            viewModel: viewModel
        ).height
        let manyHeight = DetachedIslandContentModel.bubbleContentSize(
            for: .sessionList,
            sessions: many,
            viewModel: viewModel
        ).height

        XCTAssertGreaterThan(manyHeight, singleHeight)
        XCTAssertLessThan(manyHeight, 520)
    }

    func testSessionListBubbleTreatsEndedSessionsAsMoreCompactRows() {
        let viewModel = makeViewModel()
        let activeOnly = [
            makeSession(id: "active-1", phase: .processing),
            makeSession(id: "active-2", phase: .processing),
            makeSession(id: "active-3", phase: .processing)
        ]
        let mixed = [
            makeSession(id: "active-1", phase: .processing),
            makeSession(id: "idle-1", phase: .idle),
            makeSession(id: "ended-1", phase: .ended)
        ]

        let activeOnlyHeight = DetachedIslandContentModel.bubbleContentSize(
            for: .sessionList,
            sessions: activeOnly,
            viewModel: viewModel
        ).height
        let mixedHeight = DetachedIslandContentModel.bubbleContentSize(
            for: .sessionList,
            sessions: mixed,
            viewModel: viewModel
        ).height

        XCTAssertLessThan(mixedHeight, activeOnlyHeight)
    }

    func testNewAttentionAutoOpensHoverBubble() {
        let attention = makeSession(
            id: "attention",
            phase: .waitingForApproval(
                PermissionContext(
                    toolUseId: "tool-1",
                    toolName: "Bash",
                    toolInput: nil,
                    receivedAt: Date()
                )
            )
        )
        var tracker = SessionManualAttentionTracker()
        let interactionModel = DetachedIslandInteractionModel()

        let target = tracker.consumeNewAttentionSession(from: [attention])
        interactionModel.presentHoverPreview(canPresentBubble: target != nil)

        XCTAssertEqual(target, attention)
        XCTAssertEqual(interactionModel.bubbleContentMode, .hoverPreview)
    }

    func testPinnedBubbleKeepsSessionListAndHighlightStateSeparateFromRoute() {
        let active = makeSession(id: "active", phase: .processing)
        let attention = makeSession(
            id: "attention",
            phase: .waitingForInput,
            intervention: makeIntervention(
                id: "question-1",
                kind: .question,
                message: "Need your answer"
            )
        )
        var tracker = SessionManualAttentionTracker()
        let interactionModel = DetachedIslandInteractionModel()
        let bubbleViewState = DetachedIslandBubbleViewState()
        let viewModel = makeViewModel()

        interactionModel.togglePinned(canPresentBubble: true)
        _ = tracker.consumeNewAttentionSession(from: [active])
        let target = tracker.consumeNewAttentionSession(from: [active, attention])
        bubbleViewState.highlightedSessionStableID = target?.stableId

        XCTAssertEqual(interactionModel.bubbleContentMode, .pinnedList)
        XCTAssertEqual(
            DetachedIslandContentModel.route(
                for: [active, attention],
                viewModel: viewModel,
                mode: .pinnedList
            ),
            .sessionList
        )
        XCTAssertEqual(bubbleViewState.highlightedSessionStableID, attention.stableId)
    }

    func testHoverBubbleBottomAlignsWithPetWhenBubblePointsRight() throws {
        let active = makeSession(id: "active", phase: .processing)

        let layout = DetachedIslandContentModel.layout(
            for: [active],
            viewModel: makeViewModel(),
            bubbleState: .hoverPreview,
            bubbleDirection: .right
        )

        let bubbleFrame = try XCTUnwrap(layout.bubbleFrame)
        XCTAssertEqual(bubbleFrame.maxY, layout.petFrame.maxY, accuracy: 0.5)
        XCTAssertLessThan(bubbleFrame.minY, layout.petFrame.minY)
        XCTAssertEqual(
            bubbleFrame.minX - layout.petFrame.maxX,
            DetachedIslandPanelMetrics.bubbleGap,
            accuracy: 0.5
        )
    }

    func testHoverBubbleBottomAlignsWithPetWhenBubblePointsLeft() throws {
        let active = makeSession(id: "active", phase: .processing)

        let layout = DetachedIslandContentModel.layout(
            for: [active],
            viewModel: makeViewModel(),
            bubbleState: .hoverPreview,
            bubbleDirection: .left
        )

        let bubbleFrame = try XCTUnwrap(layout.bubbleFrame)
        XCTAssertEqual(
            layout.petFrame.maxY - bubbleFrame.maxY,
            DetachedIslandPanelMetrics.leftBubbleVerticalLift,
            accuracy: 0.5
        )
        XCTAssertLessThan(bubbleFrame.minY, layout.petFrame.minY)
        XCTAssertEqual(
            layout.petFrame.minX - bubbleFrame.maxX,
            DetachedIslandPanelMetrics.leftBubbleGap,
            accuracy: 0.5
        )
    }

    func testWindowOriginPreservesPetAnchorWhenBubbleExpandsRight() {
        let hiddenLayout = DetachedIslandWindowLayout(
            containerSize: CGSize(width: 92, height: 92),
            petFrame: CGRect(x: 0, y: 0, width: 92, height: 92),
            bubbleFrame: nil,
            bubbleDirection: .right,
            petAnchorInWindow: CGPoint(x: 46, y: 46),
            bubbleContentMode: nil
        )
        let hiddenFrame = NSRect(origin: CGPoint(x: 220, y: 420), size: hiddenLayout.containerSize)
        let anchor = DetachedIslandWindowController.petAnchorScreenPoint(for: hiddenFrame, layout: hiddenLayout)

        let expandedLayout = DetachedIslandWindowLayout(
            containerSize: CGSize(width: 464, height: 164),
            petFrame: CGRect(x: 0, y: 36, width: 92, height: 92),
            bubbleFrame: CGRect(x: 104, y: 12, width: 360, height: 140),
            bubbleDirection: .right,
            petAnchorInWindow: CGPoint(x: 46, y: 82),
            bubbleContentMode: .hoverPreview
        )

        let expandedOrigin = DetachedIslandWindowController.windowOrigin(
            preservingPetAnchorAt: anchor,
            layout: expandedLayout
        )
        let expandedFrame = NSRect(origin: expandedOrigin, size: expandedLayout.containerSize)

        XCTAssertEqual(
            DetachedIslandWindowController.petAnchorScreenPoint(
                for: expandedFrame,
                layout: expandedLayout
            ).x,
            anchor.x,
            accuracy: 0.5
        )
        XCTAssertEqual(
            DetachedIslandWindowController.petAnchorScreenPoint(
                for: expandedFrame,
                layout: expandedLayout
            ).y,
            anchor.y,
            accuracy: 0.5
        )
    }

    func testWindowOriginPreservesPetAnchorWhenBubbleExpandsLeft() {
        let hiddenLayout = DetachedIslandWindowLayout(
            containerSize: CGSize(width: 92, height: 92),
            petFrame: CGRect(x: 0, y: 0, width: 92, height: 92),
            bubbleFrame: nil,
            bubbleDirection: .left,
            petAnchorInWindow: CGPoint(x: 46, y: 46),
            bubbleContentMode: nil
        )
        let hiddenFrame = NSRect(origin: CGPoint(x: 980, y: 420), size: hiddenLayout.containerSize)
        let anchor = DetachedIslandWindowController.petAnchorScreenPoint(for: hiddenFrame, layout: hiddenLayout)

        let expandedLayout = DetachedIslandWindowLayout(
            containerSize: CGSize(width: 464, height: 164),
            petFrame: CGRect(x: 372, y: 36, width: 92, height: 92),
            bubbleFrame: CGRect(x: 0, y: 12, width: 360, height: 140),
            bubbleDirection: .left,
            petAnchorInWindow: CGPoint(x: 418, y: 82),
            bubbleContentMode: .hoverPreview
        )

        let expandedOrigin = DetachedIslandWindowController.windowOrigin(
            preservingPetAnchorAt: anchor,
            layout: expandedLayout
        )
        let expandedFrame = NSRect(origin: expandedOrigin, size: expandedLayout.containerSize)

        XCTAssertEqual(
            DetachedIslandWindowController.petAnchorScreenPoint(
                for: expandedFrame,
                layout: expandedLayout
            ).x,
            anchor.x,
            accuracy: 0.5
        )
        XCTAssertEqual(
            DetachedIslandWindowController.petAnchorScreenPoint(
                for: expandedFrame,
                layout: expandedLayout
            ).y,
            anchor.y,
            accuracy: 0.5
        )
    }

    func testConversationPreviewBuilderPrefersInterventionSummaryForAttentionSessions() {
        let session = makeSession(
            id: "approval",
            phase: .waitingForApproval(
                PermissionContext(
                    toolUseId: "tool-1",
                    toolName: "Edit",
                    toolInput: nil,
                    receivedAt: Date()
                )
            ),
            intervention: makeIntervention(
                id: "approval-1",
                kind: .approval,
                message: "Allow editing config?"
            ),
            chatItems: [
                ChatHistoryItem(id: "user-1", type: .user("Do it"), timestamp: Date()),
                ChatHistoryItem(id: "assistant-1", type: .assistant("Working"), timestamp: Date())
            ]
        )

        XCTAssertEqual(
            SessionConversationPreviewBuilder.attentionSummary(for: session),
            "Allow editing config?"
        )
    }

    func testConversationPreviewBuilderFallsBackToConversationLastMessage() {
        let session = makeSession(
            id: "fallback",
            phase: .ended,
            conversationInfo: ConversationInfo(
                summary: nil,
                lastMessage: "Final answer",
                lastMessageRole: "assistant",
                lastToolName: nil,
                firstUserMessage: nil,
                lastUserMessageDate: nil
            )
        )

        XCTAssertEqual(
            SessionConversationPreviewBuilder.fallbackPreview(for: session),
            "Final answer"
        )
    }

    func testBubbleHideKeepsRenderedLayoutUntilFadeCompletes() {
        let viewModel = makeViewModel()
        let sessionMonitor = SessionMonitor()
        sessionMonitor.instances = [
            makeSession(id: "active", phase: .processing)
        ]

        let controller = DetachedIslandWindowController(
            viewModel: viewModel,
            sessionMonitor: sessionMonitor,
            onClose: {}
        )
        defer { controller.dismiss() }

        controller.presentHoverBubbleForTesting()
        XCTAssertEqual(controller.renderedBubbleStateForTesting, .hoverPreview)
        XCTAssertTrue(controller.isBubbleVisibleForTesting)

        controller.hideBubbleForTesting()
        XCTAssertEqual(controller.renderedBubbleStateForTesting, .hoverPreview)
        XCTAssertFalse(controller.isBubbleVisibleForTesting)

        let collapseExpectation = expectation(description: "bubble collapses after fade")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertEqual(controller.renderedBubbleStateForTesting, .hidden)
            XCTAssertFalse(controller.isBubbleVisibleForTesting)
            collapseExpectation.fulfill()
        }

        wait(for: [collapseExpectation], timeout: 1.0)
    }

    private func makeViewModel() -> NotchViewModel {
        NotchViewModel(
            deviceNotchRect: .zero,
            screenRect: CGRect(x: 0, y: 0, width: 1440, height: 900),
            windowHeight: 320,
            hasPhysicalNotch: false,
            enableEventMonitoring: false,
            observeSystemEnvironment: false,
            fullscreenActivityProvider: { _ in false }
        )
    }

    private func makeSession(
        id: String,
        phase: SessionPhase,
        intervention: SessionIntervention? = nil,
        chatItems: [ChatHistoryItem] = [],
        conversationInfo: ConversationInfo = ConversationInfo(
            summary: nil,
            lastMessage: nil,
            lastMessageRole: nil,
            lastToolName: nil,
            firstUserMessage: nil,
            lastUserMessageDate: nil
        )
    ) -> SessionState {
        SessionState(
            sessionId: id,
            cwd: "/tmp/\(id)",
            intervention: intervention,
            phase: phase,
            chatItems: chatItems,
            conversationInfo: conversationInfo
        )
    }

    private func makeIntervention(
        id: String,
        kind: SessionInterventionKind,
        message: String
    ) -> SessionIntervention {
        SessionIntervention(
            id: id,
            kind: kind,
            title: message,
            message: message,
            options: [],
            questions: [],
            supportsSessionScope: false,
            metadata: [:]
        )
    }
}
