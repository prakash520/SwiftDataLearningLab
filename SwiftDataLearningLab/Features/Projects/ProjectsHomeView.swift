import SwiftUI

struct ProjectsHomeView: View {
    var body: some View {
        List(ProjectKind.allCases) { kind in
            NavigationLink(value: kind) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(kind.title, systemImage: kind.systemImage)
                        .font(.headline)
                    Text(kind.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(kind.concepts)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Projects")
    }
}

struct ProjectScreen: View {
    let kind: ProjectKind

    var body: some View {
        switch kind {
        case .notes:
            NotesFlowView()
        case .tasks:
            TaskManagerView()
        case .expenses:
            ExpenseTrackerView()
        case .bookmarks:
            BookmarksView()
        case .library:
            LibraryView()
        }
    }
}
