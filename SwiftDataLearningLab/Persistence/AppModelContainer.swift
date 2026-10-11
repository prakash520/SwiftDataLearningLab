import Foundation
import SwiftData

/// Builds the process-wide store and the isolated stores used by previews and tests.
///
/// CloudKit is `.none` on purpose. The default `ModelConfiguration` in the current
/// SDK uses `.automatic`, which is a sync configuration, not an offline lab.
enum AppModelContainer {
    /// Models registered with the on-disk lab store.
    /// `ScratchPad` and the migration schemas are omitted so their experiments
    /// cannot rewrite this schema.
    static let modelTypes: [any PersistentModel.Type] = [
        LessonProgressRecord.self,
        Book.self,
        LabRecord.self,
        Student.self,
        StudentProfile.self,
        Course.self,
        TaskCategory.self,
        StudyTask.self,
        Department.self,
        Employee.self,
        DesignedItem.self,
        Note.self,
        ExpenseCategory.self,
        Expense.self,
        Bookmark.self,
        Tag.self,
        LibraryBook.self,
        Author.self
    ]

    static var schema: Schema {
        Schema(modelTypes)
    }

    /// Sandbox Application Support URL. Deleting the app deletes this file.
    /// A normal Xcode reinstall keeps it, which is why a schema change can
    /// make the next launch fail until the store is removed.
    static func storeURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("SwiftDataLearningLab", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("LearningLab.store")
    }

    static func makeShared() throws -> ModelContainer {
        let url = try storeURL()
        let configuration = ModelConfiguration(
            "LearningLab",
            schema: schema,
            url: url,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// File-backed container in a throwaway directory.
    /// Used when a test must observe on-disk unique and delete-rule behavior.
    static func makeTemporaryDisk() throws -> (container: ModelContainer, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftdata-lab-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("Lab.store")
        let configuration = ModelConfiguration(
            "TemporaryLab",
            schema: schema,
            url: url,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return (container, directory)
    }

    static func makeInMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "LearningLabMemory",
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    @MainActor
    static let preview: ModelContainer = {
        do {
            return try makeInMemory()
        } catch {
            fatalError("Preview ModelContainer failed: \(error)")
        }
    }()
}
