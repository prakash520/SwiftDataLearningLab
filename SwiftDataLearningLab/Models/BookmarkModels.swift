import Foundation
import SwiftData

@Model
final class Tag {
    @Attribute(.unique) var name: String
    var bookmarks: [Bookmark] = []

    init(name: String) {
        self.name = name
    }
}

/// Many-to-many with `Tag`. Both delete rules nullify: deleting a bookmark
/// should not delete a shared tag, and deleting a tag should not delete bookmarks.
@Model
final class Bookmark {
    var title: String

    /// Stored as text so the form can keep an invalid draft. URL validation
    /// belongs in the view model, not in the schema.
    var urlString: String

    var isFavorite: Bool
    var note: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Tag.bookmarks)
    var tags: [Tag] = []

    init(
        title: String,
        urlString: String,
        isFavorite: Bool = false,
        note: String = "",
        createdAt: Date = .now
    ) {
        self.title = title
        self.urlString = urlString
        self.isFavorite = isFavorite
        self.note = note
        self.createdAt = createdAt
    }
}
