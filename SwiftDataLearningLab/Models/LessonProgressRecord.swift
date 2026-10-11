import Foundation
import SwiftData

/// Local learning progress. This record is stored in the same SwiftData store as the
/// demos, but it is a separate model so resetting demo data does not erase progress.
@Model
final class LessonProgressRecord {
    /// Stable lesson identifier from the catalog. Unique so each lesson has one row.
    @Attribute(.unique) var lessonID: String

    var moduleID: String
    var isCompleted: Bool
    var experimentCompleted: Bool
    var challengeCompleted: Bool
    var bugDiagnosed: Bool

    /// Selected quiz choice per question. -1 means the learner has not answered.
    /// Reassign the whole array after an edit. In-place element writes on a value-type
    /// property are not always observed by SwiftData's change tracking.
    var quizSelections: [Int]

    var challengeNotes: String
    var lastOpenedAt: Date

    init(
        lessonID: String,
        moduleID: String,
        isCompleted: Bool = false,
        experimentCompleted: Bool = false,
        challengeCompleted: Bool = false,
        bugDiagnosed: Bool = false,
        quizSelections: [Int] = [-1, -1, -1],
        challengeNotes: String = "",
        lastOpenedAt: Date = .now
    ) {
        self.lessonID = lessonID
        self.moduleID = moduleID
        self.isCompleted = isCompleted
        self.experimentCompleted = experimentCompleted
        self.challengeCompleted = challengeCompleted
        self.bugDiagnosed = bugDiagnosed
        self.quizSelections = quizSelections
        self.challengeNotes = challengeNotes
        self.lastOpenedAt = lastOpenedAt
    }
}
