import Foundation
import SwiftData

extension ModelContext {
    /// Fetches every instance of `T` and deletes it.
    /// Pass `save: false` when the caller will save once after several types.
    func deleteAll<T: PersistentModel>(_ modelType: T.Type, save: Bool = true) throws {
        let items = try fetch(FetchDescriptor<T>())
        for item in items {
            delete(item)
        }
        if save, hasChanges {
            try self.save()
        }
    }
}

enum LabError: LocalizedError, Sendable {
    case missingModel
    case message(String)

    var errorDescription: String? {
        switch self {
        case .missingModel:
            "That identifier does not resolve to a model in this context. Save the record before passing its persistent identifier to another context."
        case .message(let message):
            message
        }
    }
}

@MainActor
enum DemoStoreReset {
    /// Removes playground and project rows. Lesson progress stays.
    static func deleteDemoData(in context: ModelContext) throws {
        try context.deleteAll(Book.self, save: false)
        try context.deleteAll(LabRecord.self, save: false)
        try context.deleteAll(StudentProfile.self, save: false)
        try context.deleteAll(Student.self, save: false)
        try context.deleteAll(Course.self, save: false)
        try context.deleteAll(StudyTask.self, save: false)
        try context.deleteAll(TaskCategory.self, save: false)
        try context.deleteAll(Employee.self, save: false)
        try context.deleteAll(Department.self, save: false)
        try context.deleteAll(DesignedItem.self, save: false)
        try context.deleteAll(Note.self, save: false)
        try context.deleteAll(Expense.self, save: false)
        try context.deleteAll(ExpenseCategory.self, save: false)
        try context.deleteAll(Bookmark.self, save: false)
        try context.deleteAll(Tag.self, save: false)
        try context.deleteAll(LibraryBook.self, save: false)
        try context.deleteAll(Author.self, save: false)
        if context.hasChanges {
            try context.save()
        }
    }
}
