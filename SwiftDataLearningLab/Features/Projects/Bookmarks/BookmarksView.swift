import SwiftData
import SwiftUI

struct BookmarksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]
    @State private var title = ""
    @State private var urlString = "https://developer.apple.com"
    @State private var tagName = "swift"
    @State private var search = ""
    @State private var favoritesOnly = false
    @State private var tagFilter = ""
    @State private var status = "Tags are shared. Deleting a tag nullifies the link and leaves the bookmark."

    private var visible: [Bookmark] {
        let all = (try? modelContext.fetch(FetchDescriptor<Bookmark>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []
        return all.filter { bookmark in
            let matchesSearch = search.isEmpty || bookmark.title.localizedStandardContains(search) || bookmark.urlString.localizedStandardContains(search)
            let matchesFavorite = !favoritesOnly || bookmark.isFavorite
            let matchesTag = tagFilter.isEmpty || bookmark.tags.contains { $0.name.localizedCaseInsensitiveCompare(tagFilter) == .orderedSame }
            return matchesSearch && matchesFavorite && matchesTag
        }
    }

    var body: some View {
        List {
            Section("New bookmark") {
                TextField("Title", text: $title)
                TextField("URL", text: $urlString)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                TextField("Tag", text: $tagName)
                Button("Save bookmark") { save() }
            }
            Section("Find") {
                TextField("Search", text: $search)
                TextField("Tag filter", text: $tagFilter)
                Toggle("Favorites only", isOn: $favoritesOnly)
            }
            Section("Bookmarks") {
                if visible.isEmpty {
                    ContentUnavailableView("No bookmarks", systemImage: "bookmark", description: Text("Save a bookmark with a tag."))
                }
                ForEach(visible) { bookmark in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(bookmark.title).font(.headline)
                            Spacer()
                            Button {
                                bookmark.isFavorite.toggle()
                                try? modelContext.save()
                            } label: {
                                Image(systemName: bookmark.isFavorite ? "star.fill" : "star")
                            }
                            .accessibilityLabel(bookmark.isFavorite ? "Remove favorite" : "Mark favorite")
                        }
                        Text(bookmark.urlString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(bookmark.tags.map(\.name).sorted().joined(separator: ", "))
                            .font(.caption)
                    }
                }
                .onDelete { offsets in
                    let current = visible
                    for index in offsets { modelContext.delete(current[index]) }
                    try? modelContext.save()
                }
            }
            Section("Tags") {
                ForEach(tags) { tag in
                    Text("\(tag.name) · \(tag.bookmarks.count)")
                }
                .onDelete { offsets in
                    for index in offsets { modelContext.delete(tags[index]) }
                    try? modelContext.save()
                    status = "The tag was deleted. Bookmarks that used it remain, with that tag removed."
                }
            }
            Section {
                Text(status).font(.footnote)
            }
        }
        .navigationTitle("Bookmarks")
    }

    private func save() {
        guard URL(string: urlString) != nil, urlString.contains(".") else {
            status = "Enter a URL the form can parse. The model stores the text. Validation lives here, not in the schema."
            return
        }
        do {
            let name = tagName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let tag = try tag(named: name.isEmpty ? "untagged" : name)
            let bookmark = Bookmark(title: title.isEmpty ? urlString : title, urlString: urlString)
            bookmark.tags.append(tag)
            modelContext.insert(bookmark)
            try modelContext.save()
            title = ""
            status = "Saved. The same tag can be attached to another bookmark without duplicating the tag row."
        } catch {
            status = error.localizedDescription
        }
    }

    private func tag(named name: String) throws -> Tag {
        let name = name
        var descriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.name == name })
        descriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(descriptor).first { return existing }
        let created = Tag(name: name)
        modelContext.insert(created)
        return created
    }
}
