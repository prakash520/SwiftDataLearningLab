import SwiftData
import SwiftUI

struct LifecyclePlayground: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @State private var title = "SwiftData in Practice"
    @State private var author = "Ada"
    @State private var year = 2024
    @State private var looseBook: Book?
    @State private var status = "No unsaved instance yet. Create one in memory, then insert it, then save it."

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
            TextField("Author", text: $author)
                .textFieldStyle(.roundedBorder)
            Stepper("Year \(year)", value: $year, in: 1900...2100)
            Button("1. Create in memory only") {
                looseBook = Book(title: title, authorName: author, publicationYear: year)
                status = "In memory only. hasChanges is \(modelContext.hasChanges). The @Query list does not include this instance because no context is tracking it."
            }
            Button("2. Insert into this context") {
                guard let looseBook else {
                    status = "Create an in-memory book first."
                    return
                }
                modelContext.insert(looseBook)
                status = "Tracked. hasChanges is \(modelContext.hasChanges). The row is visible to this context, and it is not durable until save."
            }
            Button("3. Save") {
                do {
                    try modelContext.save()
                    status = "Persisted. hasChanges is \(modelContext.hasChanges). Stop the app and run it again. The book should still be in the list."
                } catch {
                    status = error.localizedDescription
                }
            }
            .buttonStyle(.borderedProminent)
            LabStatusBanner(text: status)
            if books.isEmpty {
                ContentUnavailableView("No saved books", systemImage: "book", description: Text("Save a book to see it survive the next launch."))
            } else {
                ForEach(books) { book in
                    VStack(alignment: .leading) {
                        Text(book.title).font(.headline)
                        Text("\(book.authorName) · \(book.publicationYear)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Button("Reset books", role: .destructive) {
                do {
                    try modelContext.deleteAll(Book.self)
                    looseBook = nil
                    status = "Books were deleted from the store."
                } catch {
                    status = error.localizedDescription
                }
            }
        }
    }
}
