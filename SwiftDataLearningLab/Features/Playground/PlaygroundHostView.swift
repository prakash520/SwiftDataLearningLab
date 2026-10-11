import SwiftUI

struct PlaygroundHostView: View {
    let kind: PlaygroundKind

    var body: some View {
        switch kind {
        case .lifecycle:
            LifecyclePlayground()
        case .crud:
            CRUDPlayground()
        case .query:
            QueryPlayground()
        case .relationships:
            RelationshipPlayground()
        case .modelDesign:
            ModelDesignPlayground()
        case .persistence:
            PersistencePlayground()
        case .migration:
            MigrationPlayground()
        case .swiftUI:
            SwiftUILabPlayground()
        case .predicates:
            PredicatePlayground()
        case .concurrency:
            ConcurrencyPlayground()
        case .architecture:
            ArchitecturePlayground()
        case .cloudKit:
            CloudKitPlayground()
        case .notes, .tasks, .expenses, .bookmarks, .library:
            ProjectLinkCard(kind: projectKind)
        }
    }

    private var projectKind: ProjectKind {
        switch kind {
        case .notes: .notes
        case .tasks: .tasks
        case .expenses: .expenses
        case .bookmarks: .bookmarks
        case .library: .library
        default: .notes
        }
    }
}

struct ProjectLinkCard: View {
    @Environment(AppCoordinator.self) private var coordinator
    let kind: ProjectKind

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(kind.summary)
            Text(kind.concepts)
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Open \(kind.title)") {
                coordinator.openProject(kind)
            }
            .buttonStyle(.borderedProminent)
            Text("The project performs real SwiftData work. This screen does not compile text you type into the challenge notes.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
