import Foundation
import SwiftData

/// Stored directly on `StudyTask`. SwiftData persists raw-value enums that are `Codable`.
/// Associated-value enums are not a supported attribute type.
enum TaskPriority: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }
}

@Model
final class TaskCategory {
    @Attribute(.unique) var name: String

    /// The category owns its tasks. Deleting the category deletes those tasks.
    @Relationship(deleteRule: .cascade, inverse: \StudyTask.category)
    var tasks: [StudyTask] = []

    init(name: String) {
        self.name = name
    }
}

@Model
final class StudyTask {
    var title: String
    var details: String
    var isComplete: Bool
    var priority: TaskPriority
    var dueDate: Date?
    var category: TaskCategory?

    init(
        title: String,
        details: String = "",
        isComplete: Bool = false,
        priority: TaskPriority = .medium,
        dueDate: Date? = nil,
        category: TaskCategory? = nil
    ) {
        self.title = title
        self.details = details
        self.isComplete = isComplete
        self.priority = priority
        self.dueDate = dueDate
        self.category = category
    }
}
