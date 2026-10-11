import Foundation
import Observation
import SwiftData

/// Route pushed onto the Projects `NavigationPath`.
/// The identifier is resolved into a `Note` only when the editor appears.
struct NoteRoute: Hashable {
    var noteID: PersistentIdentifier
}

@MainActor
@Observable
final class NotesCoordinator {
    private let openNote: (PersistentIdentifier) -> Void

    init(openNote: @escaping (PersistentIdentifier) -> Void) {
        self.openNote = openNote
    }

    func open(_ id: PersistentIdentifier) {
        openNote(id)
    }
}

@MainActor
@Observable
final class NotesListViewModel {
    private let repository: NotesRepository
    private(set) var notes: [Note] = []
    var searchText = ""
    var errorMessage: String?
    var isLoaded = false

    init(repository: NotesRepository) {
        self.repository = repository
    }

    func load() {
        do {
            notes = try repository.fetchNotes(matching: searchText)
            errorMessage = nil
            isLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func create(title: String, body: String) {
        do {
            try repository.create(title: title, body: body)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ note: Note) {
        do {
            try repository.delete(note)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
@Observable
final class NoteEditorViewModel {
    private let repository: NotesRepository
    private let note: Note
    var title: String
    var body: String
    var isPinned: Bool
    var errorMessage: String?
    var didSave = false

    init(repository: NotesRepository, note: Note) {
        self.repository = repository
        self.note = note
        self.title = note.title
        self.body = note.body
        self.isPinned = note.isPinned
    }

    func save() {
        do {
            try repository.update(note, title: title, body: body, isPinned: isPinned)
            didSave = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
