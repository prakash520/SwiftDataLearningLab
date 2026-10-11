import Foundation
import SwiftData

/// Note used by the MVVM-C project. The editor keeps a draft and writes these
/// properties only when the learner taps Save, so cancel does not mutate the row.
@Model
final class Note {
    var title: String
    var body: String
    var isPinned: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        title: String,
        body: String,
        isPinned: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.title = title
        self.body = body
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
