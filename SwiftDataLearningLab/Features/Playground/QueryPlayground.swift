import SwiftData
import SwiftUI

struct QueryPlayground: View {
    @Environment(\.modelContext) private var modelContext
    @State private var term = ""
    @State private var minimumYear = 2020
    @State private var limit = 2
    @State private var offset = 0
    @State private var sortForward = true
    @State private var results: [BookSnapshot] = []
    @State private var status = "Insert sample books, then run the FetchDescriptor. @Query would live in a view. This button is the non-view path."

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Title contains", text: $term)
                .textFieldStyle(.roundedBorder)
            Stepper("Minimum year \(minimumYear)", value: $minimumYear, in: 1900...2100)
            Stepper("Limit \(limit)", value: $limit, in: 0...20)
            Stepper("Offset \(offset)", value: $offset, in: 0...20)
            Toggle("Sort title A to Z", isOn: $sortForward)
            Button("Insert sample books") {
                do {
                    try QueryLab.insertSamples(in: modelContext)
                    status = "Sample books are in the store. Run the fetch."
                } catch {
                    status = error.localizedDescription
                }
            }
            Button("Run FetchDescriptor") { runFetch() }
                .buttonStyle(.borderedProminent)
            LabStatusBanner(text: status)
            if results.isEmpty {
                Text("No fetch results yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(results) { book in
                    Text("\(book.title) · \(book.year)")
                }
            }
            Text("Limit 0 means no fetch limit. Raise the offset to see the next page of the same sort.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func runFetch() {
        do {
            let books = try QueryLab.fetchBooks(
                matching: term,
                minimumYear: minimumYear,
                limit: limit,
                offset: offset,
                sortForward: sortForward,
                in: modelContext
            )
            results = books.map { BookSnapshot(title: $0.title, year: $0.publicationYear) }
            status = "Fetched \(books.count) book(s) with a FetchDescriptor. The same predicate shape is what @Query uses inside a view."
        } catch {
            status = error.localizedDescription
        }
    }
}

private struct BookSnapshot: Identifiable {
    let title: String
    let year: Int
    var id: String { "\(title)-\(year)" }
}
