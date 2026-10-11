import Foundation

enum SkillLevel: String, CaseIterable, Identifiable, Hashable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .advanced: "Advanced"
        }
    }
}

enum PlaygroundKind: String, Hashable, CaseIterable, Identifiable {
    case lifecycle
    case crud
    case query
    case relationships
    case modelDesign
    case persistence
    case migration
    case swiftUI
    case predicates
    case concurrency
    case architecture
    case cloudKit
    case notes
    case tasks
    case expenses
    case bookmarks
    case library

    var id: String { rawValue }
}

struct CodeAnnotation: Hashable, Identifiable {
    /// A unique snippet that appears on the line being explained.
    let anchor: String
    let explanation: String
    var id: String { anchor }
}

struct CodeSample: Hashable, Identifiable {
    let id: String
    let title: String
    let source: String
    let annotations: [CodeAnnotation]
}

struct LessonExercise: Hashable {
    let prompt: String
    let hint: String
    let solution: String
}

struct BugScenario: Hashable {
    let title: String
    let brokenCode: String
    let question: String
    let diagnosis: String
}

struct QuizQuestion: Hashable, Identifiable {
    let id: String
    let prompt: String
    let choices: [String]
    let correctIndex: Int
    let explanation: String
}

struct Lesson: Identifiable, Hashable {
    let id: String
    let moduleID: String
    let title: String
    let summary: String
    let concept: String
    let whyItExists: String
    let whenToUse: String
    let sample: CodeSample
    let expectedBehavior: String
    let experiment: LessonExercise
    let challenge: LessonExercise
    let bug: BugScenario
    let mistakes: [String]
    let debuggingTips: [String]
    let quiz: [QuizQuestion]
    let playground: PlaygroundKind
    let sdkNote: String?

    func matches(_ query: String) -> Bool {
        let haystack = [title, summary, concept, whenToUse, sample.source].joined(separator: "\n")
        return haystack.localizedStandardContains(query)
    }
}

struct LearningModule: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let level: SkillLevel
    let order: Int
    let lessons: [Lesson]
}

enum Quiz {
    static func make(
        _ id: String,
        _ prompt: String,
        _ choices: [String],
        correct: Int,
        _ explanation: String
    ) -> QuizQuestion {
        QuizQuestion(id: id, prompt: prompt, choices: choices, correctIndex: correct, explanation: explanation)
    }
}

extension Lesson {
    static func make(
        id: String,
        moduleID: String,
        title: String,
        summary: String,
        concept: String,
        whyItExists: String,
        whenToUse: String,
        sample: CodeSample,
        expectedBehavior: String,
        experiment: String,
        experimentHint: String,
        experimentSolution: String,
        challenge: String,
        challengeHint: String,
        challengeSolution: String,
        bugTitle: String,
        bugCode: String,
        bugQuestion: String,
        bugDiagnosis: String,
        mistakes: [String],
        debuggingTips: [String],
        quiz: [QuizQuestion],
        playground: PlaygroundKind,
        sdkNote: String? = nil
    ) -> Lesson {
        Lesson(
            id: id,
            moduleID: moduleID,
            title: title,
            summary: summary,
            concept: concept,
            whyItExists: whyItExists,
            whenToUse: whenToUse,
            sample: sample,
            expectedBehavior: expectedBehavior,
            experiment: LessonExercise(prompt: experiment, hint: experimentHint, solution: experimentSolution),
            challenge: LessonExercise(prompt: challenge, hint: challengeHint, solution: challengeSolution),
            bug: BugScenario(title: bugTitle, brokenCode: bugCode, question: bugQuestion, diagnosis: bugDiagnosis),
            mistakes: mistakes,
            debuggingTips: debuggingTips,
            quiz: quiz,
            playground: playground,
            sdkNote: sdkNote
        )
    }
}
