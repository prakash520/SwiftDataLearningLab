import Foundation
import SwiftData

/// Isolated no-action demo. These types are intentionally absent from the main
/// `ModelContainer` schema. The playground opens a temporary in-memory container
/// so a dangling inverse cannot corrupt the learner's store.
@Model
final class ScratchPad {
    var title: String

    /// `.noAction` does not update `ScratchPage.pad` when the pad is deleted.
    /// The page can keep a relationship to an object that no longer exists.
    @Relationship(deleteRule: .noAction, inverse: \ScratchPage.pad)
    var pages: [ScratchPage] = []

    init(title: String) {
        self.title = title
    }
}

@Model
final class ScratchPage {
    var text: String
    var pad: ScratchPad?

    init(text: String, pad: ScratchPad? = nil) {
        self.text = text
        self.pad = pad
    }
}
