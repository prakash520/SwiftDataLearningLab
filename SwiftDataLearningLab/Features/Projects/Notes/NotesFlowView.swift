import SwiftData
import SwiftUI

struct NotesFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppCoordinator.self) private var appCoordinator
    @State private var coordinator: NotesCoordinator?
    @State private var listModel: NotesListViewModel?

    var body: some View {
        Group {
            if let coordinator, let listModel {
                NotesListView(viewModel: listModel, coordinator: coordinator)
            } else {
                ProgressView("Loading notes")
            }
        }
        .navigationDestination(for: NoteRoute.self) { route in
            NoteEditorLoader(noteID: route.noteID, context: modelContext)
        }
        .task {
            if coordinator == nil {
                coordinator = NotesCoordinator { id in
                    appCoordinator.projectPath.append(NoteRoute(noteID: id))
                }
            }
            guard listModel == nil else { return }
            let repository = NotesRepository(context: modelContext)
            let model = NotesListViewModel(repository: repository)
            model.load()
            listModel = model
        }
    }
}

private struct NotesListView: View {
    @Bindable var viewModel: NotesListViewModel
    let coordinator: NotesCoordinator
    @State private var showingComposer = false
    @State private var draftTitle = ""
    @State private var draftBody = ""

    var body: some View {
        Group {
            if viewModel.isLoaded && viewModel.notes.isEmpty {
                ContentUnavailableView {
                    Label("No notes", systemImage: "note.text")
                } description: {
                    Text("Create a note. It stays empty until you save, including after a relaunch.")
                } actions: {
                    Button("New note") { showingComposer = true }
                }
            } else {
                List {
                    ForEach(viewModel.notes) { note in
                        Button {
                            coordinator.open(note.persistentModelID)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    if note.isPinned {
                                        Image(systemName: "pin.fill")
                                            .accessibilityLabel("Pinned")
                                    }
                                    Text(note.title).font(.headline)
                                }
                                Text(note.body)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            viewModel.delete(viewModel.notes[index])
                        }
                    }
                }
            }
        }
        .navigationTitle("Notes")
        .searchable(text: $viewModel.searchText, prompt: "Search notes")
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.load()
        }
        .toolbar {
            Button("New note", systemImage: "plus") { showingComposer = true }
        }
        .sheet(isPresented: $showingComposer) {
            NavigationStack {
                Form {
                    TextField("Title", text: $draftTitle)
                    TextField("Body", text: $draftBody, axis: .vertical)
                }
                .navigationTitle("New note")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingComposer = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            viewModel.create(title: draftTitle.isEmpty ? "Untitled" : draftTitle, body: draftBody)
                            draftTitle = ""
                            draftBody = ""
                            showingComposer = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .alert("Notes error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

private struct NoteEditorLoader: View {
    let noteID: PersistentIdentifier
    let context: ModelContext
    @State private var editor: NoteEditorViewModel?

    var body: some View {
        Group {
            if let editor {
                NoteEditorView(viewModel: editor)
            } else {
                ContentUnavailableView("Note unavailable", systemImage: "questionmark")
            }
        }
        .task {
            guard editor == nil else { return }
            let repository = NotesRepository(context: context)
            guard let note = repository.note(for: noteID) else { return }
            editor = NoteEditorViewModel(repository: repository, note: note)
        }
    }
}

private struct NoteEditorView: View {
    @Bindable var viewModel: NoteEditorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            TextField("Title", text: $viewModel.title)
            TextField("Body", text: $viewModel.body, axis: .vertical)
            Toggle("Pinned", isOn: $viewModel.isPinned)
            Text("These fields are a draft. The stored note changes when you tap Save. That is the MVVM boundary. The SwiftUI lab binds a form straight to the model instead.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Edit note")
        .toolbar {
            Button("Save") {
                viewModel.save()
                if viewModel.didSave { dismiss() }
            }
        }
        .alert("Could not save", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
