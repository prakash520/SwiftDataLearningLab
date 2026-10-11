import SwiftData
import SwiftUI

struct CRUDPlayground: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LabRecord.updatedAt, order: .reverse) private var records: [LabRecord]
    @State private var title = ""
    @State private var notes = ""
    @State private var selected: LabRecord?
    @State private var status = "Add a record, edit it, delete it, and then relaunch the app."

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
            TextField("Notes", text: $notes)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Add and save") { add() }
                    .buttonStyle(.borderedProminent)
                Button("Update selected") { updateSelected() }
                Button("Delete selected", role: .destructive) { deleteSelected() }
            }
            Button("Save now") {
                do {
                    try modelContext.save()
                    status = "Explicit save finished. hasChanges is \(modelContext.hasChanges)."
                } catch {
                    status = error.localizedDescription
                }
            }
            Button("Run discard experiment") { discard() }
            Button("Save from a second context") { saveSecondary() }
            Text("Tracked changes: \(modelContext.insertedModelsArray.count) inserted, \(modelContext.changedModelsArray.count) updated, \(modelContext.deletedModelsArray.count) deleted. hasChanges is \(modelContext.hasChanges.description).")
                .font(.caption)
                .foregroundStyle(.secondary)
            LabStatusBanner(text: status)
            if records.isEmpty {
                ContentUnavailableView("No lab records", systemImage: "tray", description: Text("Add a record to start the CRUD lab."))
            } else {
                ForEach(records) { record in
                    Button {
                        selected = record
                        title = record.title
                        notes = record.notes
                    } label: {
                        VStack(alignment: .leading) {
                            Text(record.title).font(.headline)
                            Text(record.notes).font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Selects this record for editing")
                }
            }
            Button("Reset lab records", role: .destructive) {
                do {
                    try modelContext.deleteAll(LabRecord.self)
                    status = "Lab records were deleted."
                } catch {
                    status = error.localizedDescription
                }
            }
        }
        .onAppear {
            modelContext.autosaveEnabled = true
            if modelContext.undoManager == nil {
                modelContext.undoManager = UndoManager()
            }
        }
    }

    private func add() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            status = "Enter a title before inserting."
            return
        }
        do {
            _ = try CRUDLab.insert(title: trimmed, notes: notes, in: modelContext)
            title = ""
            notes = ""
            status = "Inserted and saved. Relaunch the app and the row should still be here."
        } catch {
            status = error.localizedDescription
        }
    }

    private func updateSelected() {
        guard let selected else {
            status = "Select a row first."
            return
        }
        do {
            try CRUDLab.update(selected, title: title, notes: notes, in: modelContext)
            status = "Updated and saved."
        } catch {
            status = error.localizedDescription
        }
    }

    private func deleteSelected() {
        guard let selected else {
            status = "Select a row first."
            return
        }
        do {
            try CRUDLab.delete(selected, in: modelContext)
            self.selected = nil
            status = "Deleted and saved."
        } catch {
            status = error.localizedDescription
        }
    }

    private func discard() {
        do {
            let report = try CRUDLab.demonstrateDiscard(mainContext: modelContext)
            status = "Secondary context saw \(report.visibleBeforeRollback) unsaved row, \(report.visibleAfterRollback) after rollback, and the main context saw \(report.visibleFromMainContext)."
        } catch {
            status = error.localizedDescription
        }
    }

    private func saveSecondary() {
        do {
            let name = "Second context \(Int.random(in: 100...999))"
            let count = try CRUDLab.saveFromSecondaryContext(title: name, notes: "Written by another context", mainContext: modelContext)
            status = "A new reader context found \(count) row titled \(name). The list below is the view context's @Query."
        } catch {
            status = error.localizedDescription
        }
    }
}
