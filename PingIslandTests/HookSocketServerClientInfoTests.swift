import XCTest
@testable import Ping_Island

final class HookSocketServerClientInfoTests: XCTestCase {
    func testCodexITermContextInfersCLIOverDesktopHints() {
        let kind = HookSocketServer.inferredCodexClientKind(
            explicitKind: "codex-app",
            explicitName: "Codex App",
            explicitBundleID: nil,
            hasExplicitNonTerminalBundle: false,
            terminalTTY: "/dev/ttys001",
            terminalProgram: "iTerm.app",
            terminalBundleID: "com.googlecode.iterm2",
            ideBundleID: nil,
            matchedProfileKind: .codexApp
        )

        XCTAssertEqual(kind, .codexCLI)
    }

    func testCodexAppBundleWithoutTerminalContextStaysApp() {
        let kind = HookSocketServer.inferredCodexClientKind(
            explicitKind: "desktop",
            explicitName: "Codex App",
            explicitBundleID: "com.openai.codex",
            hasExplicitNonTerminalBundle: false,
            terminalTTY: nil,
            terminalProgram: nil,
            terminalBundleID: nil,
            ideBundleID: nil,
            matchedProfileKind: .codexApp
        )

        XCTAssertEqual(kind, .codexApp)
    }

    func testCodexCLIKindStillWinsWithoutTerminalContext() {
        let kind = HookSocketServer.inferredCodexClientKind(
            explicitKind: "codex-cli",
            explicitName: "Codex",
            explicitBundleID: nil,
            hasExplicitNonTerminalBundle: false,
            terminalTTY: nil,
            terminalProgram: nil,
            terminalBundleID: nil,
            ideBundleID: nil,
            matchedProfileKind: .codexApp
        )

        XCTAssertEqual(kind, .codexCLI)
    }
}
