import Foundation
import SwiftData

@MainActor
enum ProgressStore {
    static func record(for lesson: Lesson, in context: ModelContext) throws -> LessonProgressRecord {
        let lessonID = lesson.id
        var descriptor = FetchDescriptor<LessonProgressRecord>(
            predicate: #Predicate { $0.lessonID == lessonID }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.lastOpenedAt = .now
            if context.hasChanges {
                try context.save()
            }
            return existing
        }

        let created = LessonProgressRecord(lessonID: lesson.id, moduleID: lesson.moduleID)
        context.insert(created)
        try context.save()
        return created
    }

    static func save(_ context: ModelContext) throws {
        if context.hasChanges {
            try context.save()
        }
    }
}
