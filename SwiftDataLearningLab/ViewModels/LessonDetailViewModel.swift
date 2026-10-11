import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class LessonDetailViewModel {
    private let context: ModelContext
    let lesson: Lesson
    private let progress: LessonProgressRecord

    var isCompleted: Bool
    var experimentCompleted: Bool
    var challengeCompleted: Bool
    var bugDiagnosed: Bool
    var quizSelections: [Int]
    var challengeNotes: String
    var errorMessage: String?

    var showExperimentSolution = false
    var showChallengeSolution = false
    var showBugDiagnosis = false
    var showQuizExplanations = false

    init(lesson: Lesson, context: ModelContext) throws {
        self.lesson = lesson
        self.context = context
        let record = try ProgressStore.record(for: lesson, in: context)
        self.progress = record
        self.isCompleted = record.isCompleted
        self.experimentCompleted = record.experimentCompleted
        self.challengeCompleted = record.challengeCompleted
        self.bugDiagnosed = record.bugDiagnosed
        self.quizSelections = Self.normalized(record.quizSelections, count: lesson.quiz.count)
        self.challengeNotes = record.challengeNotes
    }

    func setCompleted(_ value: Bool) { isCompleted = value; progress.isCompleted = value; persist() }
    func setExperiment(_ value: Bool) { experimentCompleted = value; progress.experimentCompleted = value; persist() }
    func setChallenge(_ value: Bool) { challengeCompleted = value; progress.challengeCompleted = value; persist() }
    func setBug(_ value: Bool) { bugDiagnosed = value; progress.bugDiagnosed = value; persist() }

    func selectQuiz(question: Int, choice: Int) {
        guard quizSelections.indices.contains(question) else { return }
        var updated = quizSelections
        updated[question] = choice
        quizSelections = updated
        progress.quizSelections = updated
        persist()
    }

    func saveChallengeNotes() {
        progress.challengeNotes = challengeNotes
        persist()
    }

    private func persist() {
        do {
            try ProgressStore.save(context)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func normalized(_ values: [Int], count: Int) -> [Int] {
        var copy = values
        if copy.count < count {
            copy.append(contentsOf: Array(repeating: -1, count: count - copy.count))
        } else if copy.count > count {
            copy = Array(copy.prefix(count))
        }
        return copy
    }
}
