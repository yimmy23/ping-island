import XCTest
@testable import Ping_Island

final class TerminalAppRegistryTests: XCTestCase {
    func testDoesNotInferCodexProgramAsTerminalHostBundle() {
        XCTAssertNil(
            TerminalAppRegistry.inferredBundleIdentifier(forTerminalProgram: "codex")
        )
        XCTAssertNil(
            TerminalAppRegistry.canonicalDisplayName(
                bundleIdentifier: nil,
                program: "codex"
            )
        )
    }

    func testExplicitCodexBundleStillResolvesCanonicalDisplayName() {
        XCTAssertEqual(
            TerminalAppRegistry.canonicalDisplayName(
                bundleIdentifier: "com.openai.codex",
                program: nil
            ),
            "Codex"
        )
    }
}
