import Foundation
import SwiftData

/// Two schema versions used only by the migration lab.
/// They are not part of `AppModelContainer.schema`.
enum NotesSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [LabNote.self]
    }

    @Model
    final class LabNote {
        var title: String
        var body: String

        init(title: String, body: String) {
            self.title = title
            self.body = body
        }
    }
}

enum NotesSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [LabNote.self]
    }

    @Model
    final class LabNote {
        var title: String
        var body: String
        /// New in version 2. The default is part of the schema, not only `init`.
        /// Existing rows need a value before `didMigrate` can replace it with a word count.
        /// An initializer default does not fill rows that are already in the store.
        var wordCount: Int = 0

        init(title: String, body: String, wordCount: Int = 0) {
            self.title = title
            self.body = body
            self.wordCount = wordCount
        }
    }
}

enum NotesMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [NotesSchemaV1.self, NotesSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    /// Custom stage for a lightweight-compatible change (a new property with a default).
    /// `willMigrate` still sees version 1 objects. `didMigrate` sees version 2 objects.
    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: NotesSchemaV1.self,
        toVersion: NotesSchemaV2.self,
        willMigrate: { context in
            let notes = try context.fetch(FetchDescriptor<NotesSchemaV1.LabNote>())
            for note in notes {
                note.title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            try context.save()
        },
        didMigrate: { context in
            let notes = try context.fetch(FetchDescriptor<NotesSchemaV2.LabNote>())
            for note in notes {
                note.wordCount = note.body.split { $0.isWhitespace }.count
            }
            try context.save()
        }
    )
}

struct MigrationNoteSummary: Equatable, Identifiable {
    var title: String
    var body: String
    var wordCount: Int
    var id: String { title }
}

struct MigrationDemoResult: Equatable {
    var writtenTitles: [String]
    var migrated: [MigrationNoteSummary]
}

enum MigrationLab {
    /// Writes a version 1 store in a temporary directory, then opens it as version 2.
    /// The app's real `LearningLab.store` is never touched.
    static func runIsolatedDemo() throws -> MigrationDemoResult {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftdata-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("Notes.store")
        let written = try writeVersion1(at: storeURL)
        let migrated = try readVersion2(at: storeURL)
        return MigrationDemoResult(writtenTitles: written, migrated: migrated)
    }

    private static func writeVersion1(at url: URL) throws -> [String] {
        let schema = Schema(versionedSchema: NotesSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let notes = [
            NotesSchemaV1.LabNote(title: "  Fetching  ", body: "Use predicates"),
            NotesSchemaV1.LabNote(title: "SwiftData", body: "Models and stores")
        ]
        for note in notes {
            context.insert(note)
        }
        try context.save()
        return notes.map(\.title)
    }

    private static func readVersion2(at url: URL) throws -> [MigrationNoteSummary] {
        let schema = Schema(versionedSchema: NotesSchemaV2.self)
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: NotesMigrationPlan.self,
            configurations: [configuration]
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let notes = try context.fetch(
            FetchDescriptor<NotesSchemaV2.LabNote>(
                sortBy: [SortDescriptor(\.title, order: .forward)]
            )
        )
        return notes.map {
            MigrationNoteSummary(title: $0.title, body: $0.body, wordCount: $0.wordCount)
        }
    }
}
