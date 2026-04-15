import XCTest
@testable import Ping_Island

final class QwenHookCompatibilityPatchTests: XCTestCase {
    func testPatchedQwenCLISourceInjectsAnswerPayloadIntoHookHandledPaths() {
        let source = """
                  constructor(_config, params) {
                    super(params);
                    this._config = _config;
                  }

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

                  const payload = response.response || {};
                  const behavior = String(payload["behavior"] || "").toLowerCase();
                  if (behavior === "allow") {
                    const updatedInput = payload["updatedInput"];
                    if (updatedInput && typeof updatedInput === "object") {
                      toolCall.request.args = updatedInput;
                    }
                    await toolCall.confirmationDetails.onConfirm(
                      ToolConfirmationOutcome.ProceedOnce
                    );
                  }
        """

        let patched = HookInstaller.patchedQwenCLISourceIfNeeded(source)

        XCTAssertNotNil(patched)
        XCTAssertTrue(patched?.contains("const hookAnswerPayload = confirmationDetails.type === \"ask_user_question\"") ?? false)
        XCTAssertTrue(patched?.contains("await confirmationDetails.onConfirm(ToolConfirmationOutcome.ProceedOnce, hookAnswerPayload);") ?? false)
        XCTAssertTrue(patched?.contains("const controlAnswerPayload = toolCall.confirmationDetails.type === \"ask_user_question\"") ?? false)
        XCTAssertTrue(patched?.contains("controlAnswerPayload") ?? false)
        XCTAssertTrue(patched?.contains("const seededAnswers = params?.answers;") ?? false)
        XCTAssertTrue(patched?.contains("this.wasAnswered = Object.keys(seededAnswers).length > 0;") ?? false)
        XCTAssertTrue(patched?.contains("hookAnswerPayload") ?? false)
    }

    func testPatchedQwenCLISourceSkipsAlreadyPatchedSource() {
        let source = """
        const hookAnswerPayload = confirmationDetails.type === "ask_user_question" && hookResult.updatedInput && typeof hookResult.updatedInput === "object" && "answers" in hookResult.updatedInput ? { answers: hookResult.updatedInput.answers } : void 0;
        const controlAnswerPayload = toolCall.confirmationDetails.type === "ask_user_question" && updatedInput && typeof updatedInput === "object" && "answers" in updatedInput ? { answers: updatedInput.answers } : void 0;
        const seededAnswers = params?.answers;
        """

        let patched = HookInstaller.patchedQwenCLISourceIfNeeded(source)

        XCTAssertEqual(patched, source)
    }
}
