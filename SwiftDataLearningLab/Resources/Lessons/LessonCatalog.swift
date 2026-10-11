import Foundation

enum LessonCatalog {
    static let modules: [LearningModule] = [
        Module1Fundamentals.module,
        Module2CRUD.module,
        Module3Query.module,
        Module4Relationships.module,
        Module5Design.module,
        Module6Persistence.module,
        Module7SwiftUI.module,
        Module8Predicates.module,
        Module9Concurrency.module,
        Module10Architecture.module,
        Module11CloudKit.module,
        Module12Projects.module
    ]

    static var allLessons: [Lesson] {
        modules.sorted { $0.order < $1.order }.flatMap(\.lessons)
    }

    static func lesson(id: String) -> Lesson? {
        allLessons.first { $0.id == id }
    }

    static func module(id: String) -> LearningModule? {
        modules.first { $0.id == id }
    }

    static func previous(before lesson: Lesson) -> Lesson? {
        guard let index = allLessons.firstIndex(of: lesson), index > 0 else { return nil }
        return allLessons[index - 1]
    }

    static func next(after lesson: Lesson) -> Lesson? {
        guard let index = allLessons.firstIndex(of: lesson), index + 1 < allLessons.count else { return nil }
        return allLessons[index + 1]
    }
}
