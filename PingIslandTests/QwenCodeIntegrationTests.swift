import XCTest
@testable import Ping_Island

final class QwenCodeIntegrationTests: XCTestCase {
    func testQwenAskUserQuestionPermissionRequestSurfacesExternalQuestion() {
        let clientInfo = SessionClientInfo(
            kind: .custom,
            profileID: "qwen-code",
            name: "Qwen Code",
            origin: "cli",
            originator: "Qwen Code",
            threadSource: "qwen-code-hooks"
        )

        let event = HookEvent(
            sessionId: "qwen-session",
            cwd: "/tmp/qwen-project",
            event: "PermissionRequest",
            status: "waiting_for_approval",
            provider: .claude,
            clientInfo: clientInfo,
            pid: nil,
            tty: nil,
            tool: "AskUserQuestion",
            toolInput: [
                "questions": AnyCodable([
                    [
                        "question": "你想做什么项目？",
                        "header": "项目类型",
                        "options": [
                            ["label": "网站开发"]
                        ]
                    ]
                ])
            ],
            toolUseId: nil,
            notificationType: nil,
            message: "Qwen Code needs your permission to use ask_user_question"
        )

        XCTAssertTrue(event.isAskUserQuestionRequest)
        XCTAssertFalse(event.expectsResponse)
        XCTAssertEqual(event.determinePhase(), .waitingForInput)
        XCTAssertEqual(event.intervention?.kind, .question)
        XCTAssertFalse(event.intervention?.supportsInlineResponse ?? true)
        XCTAssertEqual(event.intervention?.metadata["responseMode"], "external_only")
        XCTAssertTrue(event.intervention?.message.contains("暂不支持直接提交") ?? false)
    }

    func testQwenCodeManagedProfileUsesOfficialHooksSettings() {
        let profile = ClientProfileRegistry.managedHookProfile(id: "qwen-code-hooks")

        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.title, "Qwen Code")
        XCTAssertEqual(profile?.brand, .qwen)
        XCTAssertEqual(profile?.logoAssetName, "QwenLogo")
        XCTAssertEqual(profile?.primaryConfigurationURL.path, NSHomeDirectory() + "/.qwen/settings.json")
        XCTAssertTrue(profile?.alwaysVisibleInSettings == true)
    }

    func testQwenCodeRuntimeProfileResolvesBrandAndMascot() {
        let profile = ClientProfileRegistry.matchRuntimeProfile(
            provider: .claude,
            explicitKind: "qwen-code",
            explicitName: "Qwen Code",
            explicitBundleIdentifier: nil,
            terminalBundleIdentifier: nil,
            origin: "cli",
            originator: "Qwen Code",
            threadSource: "qwen-code-hooks",
            processName: nil
        )

        XCTAssertEqual(profile?.id, "qwen-code")
        XCTAssertEqual(profile?.brand, .qwen)

        let clientInfo = SessionClientInfo(
            kind: .custom,
            profileID: "qwen-code",
            name: "Qwen Code",
            origin: "cli",
            originator: "Qwen Code",
            threadSource: "qwen-code-hooks"
        )

        XCTAssertEqual(clientInfo.brand, .qwen)
        XCTAssertTrue(clientInfo.isQwenCodeClient)
        XCTAssertTrue(clientInfo.prefersHookMessageAsLastMessageFallback)
        XCTAssertEqual(MascotClient(clientInfo: clientInfo, provider: .claude), .qwen)
        XCTAssertEqual(MascotKind(clientInfo: clientInfo, provider: .claude), .qwen)
        XCTAssertEqual(MascotClient.qwen.subtitle, "Qwen Code 官方 hooks 与薄荷围巾卡皮巴拉")
        XCTAssertEqual(MascotKind.qwen.subtitle, "薄荷围巾卡皮巴拉")
    }

    func testQwenCodeLastMessageFallsBackToHookMessageForPopupPreview() {
        let clientInfo = SessionClientInfo(
            kind: .custom,
            profileID: "qwen-code",
            name: "Qwen Code",
            origin: "cli",
            originator: "Qwen Code",
            threadSource: "qwen-code-hooks"
        )
        let session = SessionState(
            sessionId: "qwen-stop",
            cwd: "/tmp/project",
            provider: .claude,
            clientInfo: clientInfo,
            latestHookMessage: "Qwen Code finished the task and is ready for your next prompt.",
            phase: .ended
        )

        XCTAssertEqual(
            session.lastMessage,
            "Qwen Code finished the task and is ready for your next prompt."
        )
    }
}
