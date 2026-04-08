import XCTest
@testable import Ping_Island

final class SessionInterventionFallbackTests: XCTestCase {
    func testResolvedQuestionsFallsBackToToolInputJSON() {
        let intervention = SessionIntervention(
            id: "question-fallback",
            kind: .question,
            title: "Claude needs input",
            message: "你希望我在这个项目中如何协助你？",
            options: [],
            questions: [],
            supportsSessionScope: false,
            metadata: [
                "toolInputJSON": """
                {
                  "questions": [
                    {
                      "id": "assist_mode",
                      "header": "协助方式",
                      "question": "你希望我在这个项目中如何协助你？",
                      "options": [
                        { "label": "修复bug", "description": "诊断和修复代码中的问题" },
                        { "label": "开发新功能", "description": "实现新的功能或模块" }
                      ],
                      "multiSelect": false
                    }
                  ]
                }
                """
            ]
        )

        XCTAssertEqual(intervention.resolvedQuestions.count, 1)
        XCTAssertEqual(intervention.resolvedQuestions.first?.prompt, "你希望我在这个项目中如何协助你？")
        XCTAssertEqual(intervention.resolvedQuestions.first?.options.map(\.title), ["修复bug", "开发新功能"])
        XCTAssertEqual(intervention.summaryText, "你希望我在这个项目中如何协助你？")
    }
}
