import Foundation
import Observation
import SwiftUI

enum AppTab: Hashable {
    case learn
    case projects
    case progress
}

enum LearnRoute: Hashable {
    case module(String)
    case lesson(String)
}

enum ProjectKind: String, CaseIterable, Identifiable, Hashable {
    case notes
    case tasks
    case expenses
    case bookmarks
    case library

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notes: "Notes"
        case .tasks: "Task manager"
        case .expenses: "Expense tracker"
        case .bookmarks: "Bookmarks"
        case .library: "Mini library"
        }
    }

    var summary: String {
        switch self {
        case .notes:
            "Create, edit, search, and delete notes with an explicit save boundary."
        case .tasks:
            "Priorities, due dates, categories, and a cascade delete rule."
        case .expenses:
            "Categories, date filtering, sorting, and totals."
        case .bookmarks:
            "Tags, search, and favorites on a many-to-many relationship."
        case .library:
            "Books and authors, also many-to-many, traversed from either side."
        }
    }

    var concepts: String {
        switch self {
        case .notes: "MVVM-C, repository, dependency injection, unit-testable view models"
        case .tasks: "One-to-many, enums, optional dates, cascade delete"
        case .expenses: "Compound predicates, sort descriptors, aggregate totals"
        case .bookmarks: "Many-to-many, unique tag names, dynamic search"
        case .library: "Many-to-many traversal and nullify delete rules"
        }
    }

    var systemImage: String {
        switch self {
        case .notes: "note.text"
        case .tasks: "checklist"
        case .expenses: "creditcard"
        case .bookmarks: "bookmark"
        case .library: "books.vertical"
        }
    }

    var playground: PlaygroundKind {
        switch self {
        case .notes: .notes
        case .tasks: .tasks
        case .expenses: .expenses
        case .bookmarks: .bookmarks
        case .library: .library
        }
    }
}

@MainActor
@Observable
final class AppCoordinator {
    var selectedTab: AppTab = .learn
    var learnPath: [LearnRoute] = []
    /// One path for the Projects tab. It holds a `ProjectKind` and, for Notes, a `NoteRoute`.
    /// A second NavigationStack inside a project screen crashes in `boundPathChange`.
    var projectPath = NavigationPath()

    func openModule(_ id: String) {
        learnPath.append(.module(id))
    }

    func openLesson(_ id: String) {
        if case .lesson = learnPath.last {
            learnPath[learnPath.count - 1] = .lesson(id)
        } else {
            learnPath.append(.lesson(id))
        }
    }

    func openProject(_ kind: ProjectKind) {
        selectedTab = .projects
        var path = NavigationPath()
        path.append(kind)
        projectPath = path
    }
}
