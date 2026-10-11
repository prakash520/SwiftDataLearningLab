import SwiftUI

struct RootView: View {
    @State private var coordinator = AppCoordinator()

    var body: some View {
        RootTabs(coordinator: coordinator)
    }
}

private struct RootTabs: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            NavigationStack(path: $coordinator.learnPath) {
                DashboardView()
                    .navigationDestination(for: LearnRoute.self) { route in
                        switch route {
                        case .module(let id):
                            ModuleDetailView(moduleID: id)
                        case .lesson(let id):
                            LessonDetailView(lessonID: id)
                        }
                    }
            }
            .tabItem { Label("Learn", systemImage: "book") }
            .tag(AppTab.learn)

            NavigationStack(path: $coordinator.projectPath) {
                ProjectsHomeView()
                    .navigationDestination(for: ProjectKind.self) { kind in
                        ProjectScreen(kind: kind)
                    }
            }
            .tabItem { Label("Projects", systemImage: "square.stack.3d.up") }
            .tag(AppTab.projects)

            NavigationStack {
                ProgressOverviewView()
            }
            .tabItem { Label("Progress", systemImage: "chart.bar") }
            .tag(AppTab.progress)
        }
        .environment(coordinator)
    }
}
