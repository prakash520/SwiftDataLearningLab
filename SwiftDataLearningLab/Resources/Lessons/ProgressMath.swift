import Foundation

enum ProgressMath {
    static func percentage(completed: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    static func completedIDs(in records: [LessonProgressRecord]) -> Set<String> {
        Set(records.filter(\.isCompleted).map(\.lessonID))
    }

    static func completedCount(module: LearningModule, completedIDs: Set<String>) -> Int {
        module.lessons.filter { completedIDs.contains($0.id) }.count
    }

    static func recommendedLesson(in lessons: [Lesson], completedIDs: Set<String>) -> Lesson? {
        lessons.first { !completedIDs.contains($0.id) }
    }

    static func recentLessons(
        records: [LessonProgressRecord],
        lessons: [Lesson],
        limit: Int
    ) -> [Lesson] {
        let ordered = records.sorted { $0.lastOpenedAt > $1.lastOpenedAt }
        var result: [Lesson] = []
        for record in ordered {
            guard let lesson = lessons.first(where: { $0.id == record.lessonID }) else { continue }
            result.append(lesson)
            if result.count == limit { break }
        }
        return result
    }
}
