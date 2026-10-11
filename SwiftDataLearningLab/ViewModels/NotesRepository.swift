import Foundation
import SwiftData

@MainActor
final class NotesRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchNotes(matching search: String) throws -> [Note] {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        var descriptor = FetchDescriptor<Note>(
            sortBy: [SortDescriptor(\Note.updatedAt, order: .reverse)]
        )
        if !trimmed.isEmpty {
            let trimmed = trimmed
            descriptor.predicate = #Predicate<Note> { note in
                note.title.localizedStandardContains(trimmed) || note.body.localizedStandardContains(trimmed)
            }
        }
        let fetched = try context.fetch(descriptor)
        // Bool is not Comparable. Foundation's Bool SortDescriptor also requires
        // NSObject, and @Model classes are not NSObject subclasses, so the store
        // cannot sort isPinned. This fetch is not paged, so a stable in-memory
        // partition can put pinned notes first and keep the store's updatedAt order.
        return fetched.sorted { lhs, rhs in
            lhs.isPinned && !rhs.isPinned
        }
    }

    func create(title: String, body: String) throws {
        context.insert(Note(title: title, body: body))
        try context.save()
    }

    func update(_ note: Note, title: String, body: String, isPinned: Bool) throws {
        note.title = title
        note.body = body
        note.isPinned = isPinned
        note.updatedAt = .now
        try context.save()
    }

    func delete(_ note: Note) throws {
        context.delete(note)
        try context.save()
    }

    func note(for id: PersistentIdentifier) -> Note? {
        guard let note = context.model(for: id) as? Note, !note.isDeleted else { return nil }
        return note
    }
}
