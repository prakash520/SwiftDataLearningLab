import SwiftData
import SwiftUI
import UIKit

struct DashboardView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Query(sort: \LessonProgressRecord.lastOpenedAt, order: .reverse) private var progress: [LessonProgressRecord]
    @State private var searchText = ""

    private var completedIDs: Set<String> { ProgressMath.completedIDs(in: progress) }
    private var percentage: Double {
        ProgressMath.percentage(completed: completedIDs.count, total: LessonCatalog.allLessons.count)
    }

    var body: some View {
        let query = DashboardQuery(searchText: searchText)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                progressHeader
                if let recommended = ProgressMath.recommendedLesson(in: LessonCatalog.allLessons, completedIDs: completedIDs) {
                    recommendedCard(recommended)
                } else {
                    LabStatusBanner(text: "Every lesson is marked complete. Reopen any module to review the playgrounds.")
                }
                recentSection
                if query.isSearching {
                    searchResults(query.matchingLessons(in: LessonCatalog.modules))
                } else {
                    ForEach(SkillLevel.allCases) { level in
                        levelSection(level)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("SwiftData Learning Lab")
        .searchable(text: $searchText, prompt: "Search lessons")
        .background(Color(.systemGroupedBackground))
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Curriculum progress")
                .font(.headline)
            ProgressView(value: percentage)
                .accessibilityLabel("Overall progress")
                .accessibilityValue("\(Int((percentage * 100).rounded())) percent")
            Text("\(completedIDs.count) of \(LessonCatalog.allLessons.count) lessons complete")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(percentage, format: .percent.precision(.fractionLength(0)))
                .font(.title2.weight(.semibold))
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func recommendedCard(_ lesson: Lesson) -> some View {
        Button {
            coordinator.openLesson(lesson.id)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Recommended next")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(lesson.title)
                    .font(.headline)
                Text(lesson.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the next unfinished lesson")
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recently opened")
                .font(.headline)
            let recent = ProgressMath.recentLessons(records: progress, lessons: LessonCatalog.allLessons, limit: 5)
            if recent.isEmpty {
                Text("Open a lesson and it will appear here.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recent) { lesson in
                            Button {
                                coordinator.openLesson(lesson.id)
                            } label: {
                                Text(lesson.title)
                                    .font(.subheadline)
                                    .multilineTextAlignment(.leading)
                                    .frame(width: 180, alignment: .leading)
                                    .padding()
                                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func searchResults(_ lessons: [Lesson]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lessons.isEmpty ? "No lessons match that search." : "\(lessons.count) matching lessons")
                .font(.headline)
            ForEach(lessons) { lesson in
                lessonLink(lesson)
            }
        }
    }

    private func levelSection(_ level: SkillLevel) -> some View {
        let modules = LessonCatalog.modules.filter { $0.level == level }.sorted { $0.order < $1.order }
        return VStack(alignment: .leading, spacing: 12) {
            Text(level.title)
                .font(.title3.weight(.semibold))
            ForEach(modules) { module in
                Button {
                    coordinator.openModule(module.id)
                } label: {
                    moduleCard(module)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func moduleCard(_ module: LearningModule) -> some View {
        let completed = ProgressMath.completedCount(module: module, completedIDs: completedIDs)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                LevelBadge(level: module.level)
                Spacer()
                Text("\(completed)/\(module.lessons.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(module.title)
                .font(.headline)
            Text(module.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
            ProgressView(value: Double(completed), total: Double(max(module.lessons.count, 1)))
                .accessibilityLabel("\(module.title) progress")
                .accessibilityValue("\(completed) of \(module.lessons.count) lessons complete")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func lessonLink(_ lesson: Lesson) -> some View {
        Button {
            coordinator.openLesson(lesson.id)
        } label: {
            HStack {
                Image(systemName: completedIDs.contains(lesson.id) ? "checkmark.circle.fill" : "circle")
                VStack(alignment: .leading) {
                    Text(lesson.title)
                    Text(lesson.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct ModuleDetailView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Query private var progress: [LessonProgressRecord]
    let moduleID: String

    private var completedIDs: Set<String> { ProgressMath.completedIDs(in: progress) }

    var body: some View {
        Group {
            if let module = LessonCatalog.module(id: moduleID) {
                List {
                    Section {
                        Text(module.summary)
                        let completed = ProgressMath.completedCount(module: module, completedIDs: completedIDs)
                        ProgressView(value: Double(completed), total: Double(module.lessons.count)) {
                            Text("\(completed) of \(module.lessons.count) complete")
                        }
                    }
                    Section("Lessons") {
                        ForEach(Array(module.lessons.enumerated()), id: \.element.id) { index, lesson in
                            Button {
                                coordinator.openLesson(lesson.id)
                            } label: {
                                HStack(alignment: .firstTextBaseline) {
                                    Image(systemName: completedIDs.contains(lesson.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(completedIDs.contains(lesson.id) ? Color.green : Color.secondary)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(index + 1). \(lesson.title)")
                                        Text(lesson.summary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .accessibilityHint("Opens the lesson")
                        }
                    }
                }
                .navigationTitle(module.title)
            } else {
                ContentUnavailableView("Module not found", systemImage: "questionmark.circle")
            }
        }
    }
}
