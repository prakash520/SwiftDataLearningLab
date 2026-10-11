import Foundation
import SwiftData

/// Scratch row for the CRUD lab. Kept separate from `Book` so CRUD reset
/// does not delete the query lesson's sample library.
@Model
final class LabRecord {
    var title: String
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(title: String, notes: String, createdAt: Date = .now, updatedAt: Date = .now) {
        self.title = title
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
