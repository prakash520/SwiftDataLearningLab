import SwiftData
import SwiftUI

struct ModelDesignPlayground: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DesignedItem.addedOn, order: .reverse) private var items: [DesignedItem]
    @State private var name = "Field notes"
    @State private var sku = "FIELD-1"
    @State private var draft = ""
    @State private var status = "Create an item. The draft note is @Transient and will be empty after the next launch."

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("SKU", text: $sku).textFieldStyle(.roundedBorder)
            TextField("Name", text: $name).textFieldStyle(.roundedBorder)
            TextField("Draft note (not stored)", text: $draft).textFieldStyle(.roundedBorder)
            Button("Save item") {
                do {
                    let item = DesignedItem(sku: sku, name: name, tags: ["lab", "design"])
                    item.draftNote = draft
                    modelContext.insert(item)
                    try modelContext.save()
                    status = "Saved \(item.displayName). Draft note is only on this instance. displayName is computed and is not a column."
                } catch {
                    status = error.localizedDescription
                }
            }
            .buttonStyle(.borderedProminent)
            Button("Save a second item with the same SKU") {
                do {
                    let report = try DesignLab.saveDuplicateSKU(in: modelContext)
                    status = "The store kept \(report.count) row, named \(report.savedName). @Attribute(.unique) did not throw. The second insert replaced the first."
                } catch {
                    status = error.localizedDescription
                }
            }
            Button("Reject a SKU the app already stored") {
                do {
                    try DesignLab.insertIfSKUAvailable(sku: "GUARDED-SKU", name: "First", in: modelContext)
                    try DesignLab.insertIfSKUAvailable(sku: "GUARDED-SKU", name: "Second", in: modelContext)
                    status = "Both inserts saved, which means the lookup missed the first row."
                } catch {
                    status = error.localizedDescription
                }
            }
            LabStatusBanner(text: status)
            ForEach(items) { item in
                VStack(alignment: .leading) {
                    Text("\(item.sku) · \(item.displayName)")
                    Text("\(item.status.title) · tags \(item.tags.joined(separator: ", ")) · draft \(item.draftNote.isEmpty ? "empty" : item.draftNote)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Button("Reset designed items", role: .destructive) {
                try? modelContext.deleteAll(DesignedItem.self)
            }
        }
    }
}

struct PersistencePlayground: View {
    @Environment(\.modelContext) private var modelContext
    @State private var status = "The URL below is the on-disk store for this app."

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let url = try? AppModelContainer.storeURL() {
                Text(url.path)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            }
            Text("CloudKit database: none. Group container: none. In-memory containers used by tests are a different ModelContainer.")
                .font(.callout)
            Button("Prove an in-memory store is isolated") {
                do {
                    let report = try PersistenceLab.proveMemoryStoreIsIsolated(mainContext: modelContext)
                    status = "Memory container has \(report.memoryCount) book(s). Main store count stayed \(report.mainCountBefore) before and \(report.mainCountAfter) after."
                } catch {
                    status = error.localizedDescription
                }
            }
            .buttonStyle(.borderedProminent)
            LabStatusBanner(text: status)
        }
    }
}

struct MigrationPlayground: View {
    @State private var status = "This runs against a temporary file, not LearningLab.store."
    @State private var result: MigrationDemoResult?
    @State private var isRunning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Version 1 stores title and body. Version 2 adds wordCount. willMigrate trims titles. didMigrate counts words.")
                .font(.callout)
            Button(isRunning ? "Running" : "Run migration demo") {
                isRunning = true
                Task {
                    do {
                        let value = try MigrationLab.runIsolatedDemo()
                        result = value
                        status = "Migration finished. Titles were trimmed and word counts were filled in."
                    } catch {
                        status = error.localizedDescription
                        result = nil
                    }
                    isRunning = false
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunning)
            LabStatusBanner(text: status)
            if let result {
                Text("Written before migration: \(result.writtenTitles.joined(separator: ", "))")
                    .font(.callout)
                ForEach(result.migrated) { note in
                    Text("\(note.title) · \(note.wordCount) words · \(note.body)")
                }
            }
        }
    }
}

struct SwiftUILabPlayground: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LabRecord.updatedAt, order: .reverse) private var records: [LabRecord]
    @State private var title = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This list is @Query. Insert and delete update it because the view context tracks the models.")
                .font(.callout)
            TextField("New title", text: $title)
                .textFieldStyle(.roundedBorder)
            Button("Insert") {
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                modelContext.insert(LabRecord(title: trimmed, notes: "Created from the SwiftUI lab"))
                title = ""
                try? modelContext.save()
            }
            .buttonStyle(.borderedProminent)
            if records.isEmpty {
                ContentUnavailableView("Nothing here", systemImage: "tray", description: Text("Insert a row. There is no network loading state because the store is local."))
            } else {
                ForEach(records) { record in
                    NavigationLink(value: record.persistentModelID) {
                        Text(record.title)
                    }
                }
            }
        }
        .navigationDestination(for: PersistentIdentifier.self) { id in
            LabRecordEditor(identifier: id)
        }
    }
}

private struct LabRecordEditor: View {
    @Environment(\.modelContext) private var modelContext
    let identifier: PersistentIdentifier

    var body: some View {
        if let record = modelContext.model(for: identifier) as? LabRecord, !record.isDeleted {
            LabRecordForm(record: record)
        } else {
            ContentUnavailableView("Record unavailable", systemImage: "questionmark")
        }
    }
}

private struct LabRecordForm: View {
    @Bindable var record: LabRecord
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Form {
            TextField("Title", text: $record.title)
            TextField("Notes", text: $record.notes)
            Button("Delete", role: .destructive) {
                modelContext.delete(record)
                try? modelContext.save()
            }
        }
        .navigationTitle("Edit record")
        .onDisappear {
            record.updatedAt = .now
            try? modelContext.save()
        }
    }
}

struct PredicatePlayground: View {
    @Environment(\.modelContext) private var modelContext
    @State private var category = "Food"
    @State private var useDate = true
    @State private var minimumAmount = 0.0
    @State private var rows: [ExpenseSnapshot] = []
    @State private var status = "Insert the sample expenses, then apply a predicate shape."

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Category name", text: $category)
                .textFieldStyle(.roundedBorder)
            Toggle("Limit to May 2026", isOn: $useDate)
            Stepper("Minimum amount \(Int(minimumAmount))", value: $minimumAmount, in: 0...100, step: 10)
            Button("Insert sample expenses") {
                do {
                    try ExpenseQuery.insertSampleExpenses(in: modelContext)
                    status = "Sample expenses are ready."
                } catch {
                    status = error.localizedDescription
                }
            }
            Button("Run predicate") { run() }
                .buttonStyle(.borderedProminent)
            LabStatusBanner(text: status)
            Text("Total \(rows.reduce(0) { $0 + $1.amount }, format: .currency(code: "USD"))")
            ForEach(rows) { row in
                Text("\(row.title) · \(row.category) · \(row.amount, format: .currency(code: "USD"))")
            }
        }
    }

    private func run() {
        do {
            let calendar = Calendar(identifier: .gregorian)
            let start = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1)) ?? .now
            let end = calendar.date(from: DateComponents(year: 2026, month: 5, day: 31, hour: 23, minute: 59)) ?? .now
            let shape: ExpenseQuery.Shape
            if minimumAmount > 0 {
                shape = .minimumAmount(minimumAmount)
            } else if useDate && !category.isEmpty {
                shape = .categoryAndDate(name: category, start: start, end: end)
            } else if useDate {
                shape = .dateRange(start: start, end: end)
            } else if !category.isEmpty {
                shape = .category(category)
            } else {
                shape = .all
            }
            let expenses = try ExpenseQuery.fetch(shape, sortByAmount: true, in: modelContext)
            rows = expenses.map {
                ExpenseSnapshot(title: $0.title, category: $0.category?.name ?? "Uncategorized", amount: $0.amount)
            }
            status = "Matched \(rows.count) expense(s). The predicate was rebuilt for this filter shape. It was not assembled from a string."
        } catch {
            status = error.localizedDescription
        }
    }
}

private struct ExpenseSnapshot: Identifiable {
    let title: String
    let category: String
    let amount: Double
    var id: String { title + category }
}

struct ConcurrencyPlayground: View {
    @Environment(\.modelContext) private var modelContext
    @State private var status = "Import runs on a ModelActor. The button passes titles, not LabRecord instances."
    @State private var fresh: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Import two titles on a ModelActor") {
                let container = modelContext.container
                Task {
                    do {
                        let importer = LessonBackgroundImporter(modelContainer: container)
                        let count = try await importer.importLabTitles(["Actor row A", "Actor row B"])
                        fresh = try await Self.readTitles(container: container)
                        status = "The actor saved \(count) rows. A new context read \(fresh.count) recent lab titles."
                    } catch {
                        status = error.localizedDescription
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            Button("Rename the newest row through its identifier") {
                let container = modelContext.container
                Task {
                    do {
                        let identifier = try await Self.newestIdentifier(container: container)
                        let importer = LessonBackgroundImporter(modelContainer: container)
                        try await importer.renameLabRecord(id: identifier, to: "Renamed off the main actor")
                        fresh = try await Self.readTitles(container: container)
                        status = "The actor resolved the persistent identifier in its own context and saved."
                    } catch {
                        status = error.localizedDescription
                    }
                }
            }
            LabStatusBanner(text: status)
            ForEach(fresh, id: \.self) { title in
                Text(title)
            }
            Text("ModelContext is not Sendable. This SDK marks sharing one across concurrency domains as unavailable.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private static func readTitles(container: ModelContainer) async throws -> [String] {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        var descriptor = FetchDescriptor<LabRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 8
        return try context.fetch(descriptor).map(\.title)
    }

    private static func newestIdentifier(container: ModelContainer) async throws -> PersistentIdentifier {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<LabRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let record = try context.fetch(descriptor).first else {
            throw LabError.message("Import a row before renaming.")
        }
        return record.persistentModelID
    }
}

struct ArchitecturePlayground: View {
    var body: some View {
        ProjectLinkCard(kind: .notes)
    }
}

struct CloudKitPlayground: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This build does not sync. AppModelContainer passes cloudKitDatabase: .none.")
            Text("Turning on .automatic requires an iCloud capability, a CloudKit container identifier, the remote-notification background mode, a signed app, and an iCloud account. None of that is configured here, so the lab stays offline.")
            Text("CloudKit also rejects @Attribute(.unique), non-optional relationships, and the deny delete rule. The local models in this app use those features on purpose. They are valid for a local store and invalid for a CloudKit-backed store without a separate schema.")
                .font(.callout)
            if let url = try? AppModelContainer.storeURL() {
                Text(url.path)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
    }
}
