import Foundation

enum SessionProvider: String, Sendable {
    case claude
    case codex
}

enum SessionInterventionKind: String, Sendable {
    case approval
    case question
}

struct SessionInterventionOption: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String?
}

struct SessionInterventionQuestion: Equatable, Identifiable, Sendable {
    let id: String
    let header: String
    let prompt: String
    let detail: String?
    let options: [SessionInterventionOption]
    let allowsOther: Bool
    let isSecret: Bool
}

struct SessionIntervention: Equatable, Identifiable, Sendable {
    let id: String
    let kind: SessionInterventionKind
    let title: String
    let message: String
    let options: [SessionInterventionOption]
    let questions: [SessionInterventionQuestion]
    let supportsSessionScope: Bool
    let metadata: [String: String]

    nonisolated var summaryText: String {
        if !message.isEmpty {
            return message
        }
        if let firstQuestion = questions.first {
            return firstQuestion.prompt
        }
        if let firstOption = options.first {
            return firstOption.title
        }
        return title
    }
}
