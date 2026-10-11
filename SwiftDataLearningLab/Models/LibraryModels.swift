import Foundation
import SwiftData

@Model
final class Author {
    var name: String
    var books: [LibraryBook] = []

    init(name: String) {
        self.name = name
    }
}

/// Many-to-many library. Cascade is intentionally not used on either side.
/// A book can have several authors, and an author can write several books.
@Model
final class LibraryBook {
    var title: String
    var publishedYear: Int

    @Relationship(deleteRule: .nullify, inverse: \Author.books)
    var authors: [Author] = []

    init(title: String, publishedYear: Int) {
        self.title = title
        self.publishedYear = publishedYear
    }
}
