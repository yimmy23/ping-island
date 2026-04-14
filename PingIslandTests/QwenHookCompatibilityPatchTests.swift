import XCTest
@testable import Ping_Island

final class QwenHookCompatibilityPatchTests: XCTestCase {
    func testPatchedQwenCLISourceInjectsAnswerPayloadIntoHookHandledPaths() {
        let source = """
                  if (hookResult.hasDecision) {
                    if (hookResult.shouldAllow) {
                      if (hookResult.updatedInput && typeof reqInfo.args === "object") {
                        this.setArgsInternal(reqInfo.callId, hookResult.updatedInput);
                      }
                      await confirmationDetails.onConfirm(ToolConfirmationOutcome.ProceedOnce);
                    }
                  }

                  if (hookResult.hasDecision) {
                    hookHandled = true;
                    if (hookResult.shouldAllow) {
                      if (hookResult.updatedInput) {
                        args2 = hookResult.updatedInput;
                        invocation.params = hookResult.updatedInput;
                      }
                      await confirmationDetails.onConfirm(
                        ToolConfirmationOutcome.ProceedOnce
                      );
                    }
                  }
        """

        let patched = HookInstaller.patchedQwenCLISourceIfNeeded(source)

        XCTAssertNotNil(patched)
        XCTAssertTrue(patched?.contains("const hookAnswerPayload = confirmationDetails.type === \"ask_user_question\"") ?? false)
        XCTAssertTrue(patched?.contains("await confirmationDetails.onConfirm(ToolConfirmationOutcome.ProceedOnce, hookAnswerPayload);") ?? false)
        XCTAssertTrue(patched?.contains("hookAnswerPayload") ?? false)
    }

    func testPatchedQwenCLISourceSkipsAlreadyPatchedSource() {
        let source = """
        const hookAnswerPayload = confirmationDetails.type === "ask_user_question" && hookResult.updatedInput && typeof hookResult.updatedInput === "object" && "answers" in hookResult.updatedInput ? { answers: hookResult.updatedInput.answers } : void 0;
        """

        let patched = HookInstaller.patchedQwenCLISourceIfNeeded(source)

        XCTAssertEqual(patched, source)
    }
}
