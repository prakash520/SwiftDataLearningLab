import Foundation

struct DashboardQuery {
    var searchText: String

    func matchingLessons(in modules: [LearningModule]) -> [Lesson] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lessons = modules.sorted { $0.order < $1.order }.flatMap(\.lessons)
        guard !trimmed.isEmpty else { return lessons }
        return lessons.filter { $0.matches(trimmed) }
    }

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
