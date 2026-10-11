import Foundation
import SwiftData

struct DiscardReport: Equatable {
    var visibleBeforeRollback: Int
    var visibleAfterRollback: Int
    var visibleFromMainContext: Int
}

struct MemoryIsolationReport: Equatable {
    var memoryCount: Int
    var mainCountBefore: Int
    var mainCountAfter: Int
}

enum LifecycleLab {
    @MainActor
    static func insert(
        title: String,
        authorName: String,
        publicationYear: Int,
        in context: ModelContext
    ) throws -> Book {
        let book = Book(title: title, authorName: authorName, publicationYear: publicationYear)
        context.insert(book)
        try context.save()
        return book
    }
}

enum CRUDLab {
    @MainActor
    static func insert(title: String, notes: String, in context: ModelContext) throws -> LabRecord {
        let record = LabRecord(title: title, notes: notes)
        context.insert(record)
        try context.save()
        return record
    }

    @MainActor
    static func update(_ record: LabRecord, title: String, notes: String, in context: ModelContext) throws {
        record.title = title
        record.notes = notes
        record.updatedAt = .now
        try context.save()
    }

    @MainActor
    static func delete(_ record: LabRecord, in context: ModelContext) throws {
        context.delete(record)
        try context.save()
    }

    /// Proves that a second context with autosave disabled does not publish inserts
    /// until `save()`, and that `rollback()` drops them.
    @MainActor
    static func demonstrateDiscard(mainContext: ModelContext) throws -> DiscardReport {
        let title = "Unsaved-\(UUID().uuidString)"
        let secondary = ModelContext(mainContext.container)
        secondary.autosaveEnabled = false
        secondary.insert(LabRecord(title: title, notes: "This row should disappear on rollback."))

        let predicate = titlePredicate(title)
        let before = try secondary.fetchCount(FetchDescriptor<LabRecord>(predicate: predicate))
        secondary.rollback()
        let after = try secondary.fetchCount(FetchDescriptor<LabRecord>(predicate: predicate))
        let main = try mainContext.fetchCount(FetchDescriptor<LabRecord>(predicate: predicate))
        return DiscardReport(
            visibleBeforeRollback: before,
            visibleAfterRollback: after,
            visibleFromMainContext: main
        )
    }

    /// Saves on a writer context, then counts rows from a brand-new reader context.
    /// A new context reads the store instead of another context's unsaved graph.
    @MainActor
    static func saveFromSecondaryContext(title: String, notes: String, mainContext: ModelContext) throws -> Int {
        let writer = ModelContext(mainContext.container)
        writer.autosaveEnabled = false
        writer.insert(LabRecord(title: title, notes: notes))
        try writer.save()

        let reader = ModelContext(mainContext.container)
        reader.autosaveEnabled = false
        return try reader.fetchCount(FetchDescriptor<LabRecord>(predicate: titlePredicate(title)))
    }

    private static func titlePredicate(_ title: String) -> Predicate<LabRecord> {
        let title = title
        return #Predicate<LabRecord> { $0.title == title }
    }
}

enum QueryLab {
    @MainActor
    static func insertSamples(in context: ModelContext) throws {
        let samples = [
            Book(title: "Persistent Models", authorName: "Ada", publicationYear: 2023),
            Book(title: "Predicates", subtitle: "Filters", authorName: "Grace", publicationYear: 2024),
            Book(title: "Actors", authorName: "Lin", publicationYear: 2021),
            Book(title: "Migrations", authorName: "Ada", publicationYear: 2020)
        ]
        let existing = try context.fetch(FetchDescriptor<Book>())
        let titles = Set(existing.map(\.title))
        for sample in samples where !titles.contains(sample.title) {
            context.insert(sample)
        }
        if context.hasChanges {
            try context.save()
        }
    }

    @MainActor
    static func fetchBooks(
        matching term: String,
        minimumYear: Int,
        limit: Int,
        offset: Int,
        sortForward: Bool,
        in context: ModelContext
    ) throws -> [Book] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        var descriptor = FetchDescriptor<Book>()
        descriptor.predicate = predicate(term: trimmed, minimumYear: minimumYear)
        descriptor.sortBy = [SortDescriptor(\Book.title, order: sortForward ? .forward : .reverse)]
        descriptor.fetchLimit = limit > 0 ? limit : nil
        descriptor.fetchOffset = max(offset, 0)
        return try context.fetch(descriptor)
    }

    static func predicate(term: String, minimumYear: Int) -> Predicate<Book> {
        if term.isEmpty {
            let minimumYear = minimumYear
            return #Predicate<Book> { book in
                book.publicationYear >= minimumYear
            }
        }
        let term = term
        let minimumYear = minimumYear
        return #Predicate<Book> { book in
            book.publicationYear >= minimumYear && book.title.localizedStandardContains(term)
        }
    }
}

enum RelationshipLab {
    @MainActor
    static func enroll(
        studentName: String,
        email: String,
        courseTitle: String,
        courseCode: String,
        in context: ModelContext
    ) throws {
        let student = Student(name: studentName, email: email)
        let course = Course(title: courseTitle, code: courseCode)
        let profile = StudentProfile(bio: "Profile for \(studentName)")
        student.profile = profile
        student.courses.append(course)
        context.insert(student)
        context.insert(course)
        context.insert(profile)
        try context.save()
    }

    @MainActor
    static func addTask(
        title: String,
        priority: TaskPriority,
        categoryName: String,
        in context: ModelContext
    ) throws {
        let category = try category(named: categoryName, in: context)
        let task = StudyTask(title: title, priority: priority, category: category)
        context.insert(task)
        try context.save()
    }

    @MainActor
    static func category(named name: String, in context: ModelContext) throws -> TaskCategory {
        let name = name
        var descriptor = FetchDescriptor<TaskCategory>(
            predicate: #Predicate { $0.name == name }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let created = TaskCategory(name: name)
        context.insert(created)
        return created
    }

    /// Refuses while employees remain.
    /// The store's `.deny` rule does not reject the save, so the product check lives here.
    @MainActor
    static func deleteDepartmentIfEmpty(_ department: Department, in context: ModelContext) throws {
        guard department.employees.isEmpty else {
            throw LabError.message("Detach employees before deleting this department. The store did not enforce deleteRule .deny.")
        }
        context.delete(department)
        try context.save()
    }

    @MainActor
    static func link(bookTitle: String, year: Int, authorName: String, in context: ModelContext) throws {
        let author = Author(name: authorName)
        let book = LibraryBook(title: bookTitle, publishedYear: year)
        book.authors.append(author)
        context.insert(author)
        context.insert(book)
        try context.save()
    }
}

enum DesignLab {
    @MainActor
    static func insertItem(sku: String, name: String, in context: ModelContext) throws {
        context.insert(DesignedItem(sku: sku, name: name, tags: ["demo"], metadata: ItemMetadata(source: "Lab", rating: 4)))
        try context.save()
    }

    struct UniqueSKUReport: Equatable {
        var count: Int
        var savedName: String
    }

    /// Saves one item, then saves a second item with the same SKU.
    /// `@Attribute(.unique)` keeps a single row. On this SDK the second save
    /// does not throw: the later object's values replace the stored row.
    @MainActor
    static func saveDuplicateSKU(in context: ModelContext) throws -> UniqueSKUReport {
        let sku = "SKU-\(UUID().uuidString)"
        context.insert(DesignedItem(sku: sku, name: "First"))
        try context.save()
        context.insert(DesignedItem(sku: sku, name: "Duplicate"))
        try context.save()
        let key = sku
        let rows = try context.fetch(FetchDescriptor<DesignedItem>(predicate: #Predicate { $0.sku == key }))
        return UniqueSKUReport(count: rows.count, savedName: rows.first?.name ?? "")
    }

    /// Throws before insert when the SKU is already stored.
    /// This is the failure `save()` does not produce for a duplicate unique value.
    @MainActor
    static func insertIfSKUAvailable(sku: String, name: String, in context: ModelContext) throws {
        let sku = sku
        var descriptor = FetchDescriptor<DesignedItem>(predicate: #Predicate { $0.sku == sku })
        descriptor.fetchLimit = 1
        if try context.fetch(descriptor).first != nil {
            throw LabError.message("SKU \(sku) is already stored. A second insert would replace that row instead of throwing.")
        }
        context.insert(DesignedItem(sku: sku, name: name))
        try context.save()
    }
}

enum PersistenceLab {
    @MainActor
    static func proveMemoryStoreIsIsolated(mainContext: ModelContext) throws -> MemoryIsolationReport {
        let before = try mainContext.fetchCount(FetchDescriptor<Book>())
        let memory = try AppModelContainer.makeInMemory()
        let memoryContext = ModelContext(memory)
        memoryContext.autosaveEnabled = false
        memoryContext.insert(Book(title: "Memory only \(UUID().uuidString)", authorName: "Lab", publicationYear: 2024))
        try memoryContext.save()
        let memoryCount = try memoryContext.fetchCount(FetchDescriptor<Book>())
        let after = try mainContext.fetchCount(FetchDescriptor<Book>())
        return MemoryIsolationReport(memoryCount: memoryCount, mainCountBefore: before, mainCountAfter: after)
    }
}

enum ExpenseQuery {
    enum Shape: Equatable {
        case all
        case category(String)
        case dateRange(start: Date, end: Date)
        case categoryAndDate(name: String, start: Date, end: Date)
        case minimumAmount(Double)
    }

    @MainActor
    static func fetch(_ shape: Shape, sortByAmount: Bool, in context: ModelContext) throws -> [Expense] {
        var descriptor = FetchDescriptor<Expense>()
        descriptor.predicate = predicate(for: shape)
        descriptor.sortBy = [
            SortDescriptor(\Expense.amount, order: sortByAmount ? .reverse : .forward),
            SortDescriptor(\Expense.spentOn, order: .reverse)
        ]
        if !sortByAmount {
            descriptor.sortBy = [
                SortDescriptor(\Expense.spentOn, order: .reverse),
                SortDescriptor(\Expense.amount, order: .reverse)
            ]
        }
        return try context.fetch(descriptor)
    }

    static func predicate(for shape: Shape) -> Predicate<Expense>? {
        switch shape {
        case .all:
            return nil
        case .category(let name):
            let name = name
            return #Predicate<Expense> { expense in
                expense.category?.name == name
            }
        case .dateRange(let start, let end):
            let start = start
            let end = end
            return #Predicate<Expense> { expense in
                expense.spentOn >= start && expense.spentOn <= end
            }
        case .categoryAndDate(let name, let start, let end):
            let name = name
            let start = start
            let end = end
            return #Predicate<Expense> { expense in
                expense.category?.name == name && expense.spentOn >= start && expense.spentOn <= end
            }
        case .minimumAmount(let amount):
            let amount = amount
            return #Predicate<Expense> { expense in
                expense.amount >= amount
            }
        }
    }

    @MainActor
    static func insertSampleExpenses(in context: ModelContext) throws {
        let existing = try context.fetchCount(FetchDescriptor<Expense>())
        guard existing == 0 else { return }
        let food = ExpenseCategory(name: "Food")
        let travel = ExpenseCategory(name: "Travel")
        context.insert(food)
        context.insert(travel)
        let calendar = Calendar(identifier: .gregorian)
        let may1 = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1)) ?? .now
        let may20 = calendar.date(from: DateComponents(year: 2026, month: 5, day: 20)) ?? .now
        let june2 = calendar.date(from: DateComponents(year: 2026, month: 6, day: 2)) ?? .now
        context.insert(Expense(title: "Lunch", amount: 18, spentOn: may1, category: food))
        context.insert(Expense(title: "Train", amount: 64, spentOn: may20, category: travel))
        context.insert(Expense(title: "Dinner", amount: 42, spentOn: june2, category: food))
        try context.save()
    }
}

/// Background importer. Each method uses the actor's own `modelContext`.
/// Callers pass values and identifiers, not live model instances.
@ModelActor
actor LessonBackgroundImporter {
    func importLabTitles(_ titles: [String]) throws -> Int {
        for title in titles {
            let record = LabRecord(
                title: title,
                notes: "Imported by a ModelActor. This context is not the view's context."
            )
            modelContext.insert(record)
        }
        try modelContext.save()
        return titles.count
    }

    func renameLabRecord(id: PersistentIdentifier, to title: String) throws {
        guard let record = self[id, as: LabRecord.self] else {
            throw LabError.missingModel
        }
        record.title = title
        record.updatedAt = .now
        try modelContext.save()
    }
}
