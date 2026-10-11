import Foundation
import SwiftData

/// A small persistent model used by the fundamentals and query lessons.
///
/// Calling `Book(...)` creates an ordinary instance. Nothing is written to SQLite
/// until a `ModelContext` inserts it and that context saves.
@Model
final class Book {
    /// Stored column. Predicates and sort descriptors can use this key path.
    var title: String

    /// Optional values are legal. `nil` means "no subtitle", not an empty string.
    var subtitle: String?

    var authorName: String
    var publicationYear: Int
    var createdAt: Date

    init(
        title: String,
        subtitle: String? = nil,
        authorName: String,
        publicationYear: Int,
        createdAt: Date = .now
    ) {
        self.title = title
        self.subtitle = subtitle
        self.authorName = authorName
        self.publicationYear = publicationYear
        self.createdAt = createdAt
    }
}
