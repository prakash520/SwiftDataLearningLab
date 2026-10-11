import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LibraryBook.title) private var books: [LibraryBook]
    @Query(sort: \Author.name) private var authors: [Author]
    @State private var bookTitle = ""
    @State private var year = 2024
    @State private var authorName = ""
    @State private var selectedAuthorIDs: Set<PersistentIdentifier> = []
    @State private var status = "A book can have many authors, and an author can have many books. Deleting either side nullifies the link."

    var body: some View {
        List {
            Section("New author") {
                TextField("Author name", text: $authorName)
                Button("Add author") {
                    let trimmed = authorName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    modelContext.insert(Author(name: trimmed))
                    try? modelContext.save()
                    authorName = ""
                }
            }
            Section("New book") {
                TextField("Title", text: $bookTitle)
                Stepper("Year \(year)", value: $year, in: 1400...2100)
                if authors.isEmpty {
                    Text("Add an author before linking a book.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(authors) { author in
                        Button {
                            if selectedAuthorIDs.contains(author.persistentModelID) {
                                selectedAuthorIDs.remove(author.persistentModelID)
                            } else {
                                selectedAuthorIDs.insert(author.persistentModelID)
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedAuthorIDs.contains(author.persistentModelID) ? "checkmark.circle.fill" : "circle")
                                Text(author.name)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button("Save book") { saveBook() }
                    .disabled(bookTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Section("Books") {
                if books.isEmpty {
                    ContentUnavailableView("No books", systemImage: "books.vertical", description: Text("Add an author, then a book."))
                }
                ForEach(books) { book in
                    VStack(alignment: .leading) {
                        Text(book.title).font(.headline)
                        Text(book.authors.map(\.name).sorted().joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    for index in offsets { modelContext.delete(books[index]) }
                    try? modelContext.save()
                    status = "The book was deleted. Its authors remain."
                }
            }
            Section("Authors") {
                ForEach(authors) { author in
                    Text("\(author.name) · \(author.books.map(\.title).joined(separator: ", "))")
                }
                .onDelete { offsets in
                    for index in offsets { modelContext.delete(authors[index]) }
                    try? modelContext.save()
                    status = "The author was deleted. Their books remain."
                }
            }
            Section {
                Text(status).font(.footnote)
            }
        }
        .navigationTitle("Library")
    }

    private func saveBook() {
        let book = LibraryBook(title: bookTitle, publishedYear: year)
        for author in authors where selectedAuthorIDs.contains(author.persistentModelID) {
            book.authors.append(author)
        }
        modelContext.insert(book)
        do {
            try modelContext.save()
            bookTitle = ""
            selectedAuthorIDs = []
            status = "Saved. Open an author row to see the inverse traversal."
        } catch {
            status = error.localizedDescription
        }
    }
}
