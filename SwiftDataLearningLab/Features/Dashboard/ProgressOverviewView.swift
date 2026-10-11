import SwiftData
import SwiftUI

struct ProgressOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var progress: [LessonProgressRecord]
    @State private var confirmReset = false
    @State private var confirmDemoReset = false
    @State private var status = ""

    private var completedIDs: Set<String> { ProgressMath.completedIDs(in: progress) }

    var body: some View {
        List {
            Section {
                let percentage = ProgressMath.percentage(
                    completed: completedIDs.count,
                    total: LessonCatalog.allLessons.count
                )
                ProgressView(value: percentage) {
                    Text("\(completedIDs.count) of \(LessonCatalog.allLessons.count) lessons")
                }
                Text(percentage, format: .percent.precision(.fractionLength(0)))
                    .font(.title2.weight(.semibold))
            }
            Section("Modules") {
                ForEach(LessonCatalog.modules) { module in
                    let completed = ProgressMath.completedCount(module: module, completedIDs: completedIDs)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(module.title)
                        ProgressView(value: Double(completed), total: Double(module.lessons.count))
                            .accessibilityLabel(module.title)
                            .accessibilityValue("\(completed) of \(module.lessons.count)")
                    }
                    .padding(.vertical, 4)
                }
            }
            Section("Store") {
                NavigationLink("How to run the tests") {
                    TestingGuideView()
                }
                Button("Reset lesson progress", role: .destructive) {
                    confirmReset = true
                }
                Button("Reset demo data", role: .destructive) {
                    confirmDemoReset = true
                }
                if !status.isEmpty {
                    Text(status)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Progress")
        .confirmationDialog("Erase lesson progress?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Erase progress", role: .destructive) { resetProgress() }
        } message: {
            Text("Completion checkboxes and quiz selections are deleted. Books, notes, and other demo rows stay.")
        }
        .confirmationDialog("Erase demo data?", isPresented: $confirmDemoReset, titleVisibility: .visible) {
            Button("Erase demo data", role: .destructive) { resetDemo() }
        } message: {
            Text("Playground and project rows are deleted. Lesson progress stays.")
        }
    }

    private func resetProgress() {
        do {
            try modelContext.deleteAll(LessonProgressRecord.self)
            status = "Lesson progress was deleted."
        } catch {
            status = error.localizedDescription
        }
    }

    private func resetDemo() {
        do {
            try DemoStoreReset.deleteDemoData(in: modelContext)
            status = "Demo rows were deleted."
        } catch {
            status = error.localizedDescription
        }
    }
}

struct TestingGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Most unit tests use an in-memory ModelContainer. Unique and delete-rule tests use a temporary file. None of them read or write LearningLab.store.")
                Text("From the project root:")
                    .font(.headline)
                Text("xcodebuild test -scheme SwiftDataLearningLab -destination 'platform=iOS Simulator,name=iPhone 16'")
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                Text("In Xcode, choose Product > Test, or press Command-U. The shared scheme SwiftDataLearningLab includes the SwiftDataLearningLabTests target.")
                Text("Coverage includes insert, fetch, update, delete, predicates, sorting, pagination, cascade and nullify, the fact that deny is not enforced, an isolated migration, the notes view model, unique-value replacement, and the lesson catalog structure.")
                Text("If the named simulator is not installed, list devices with xcrun simctl list devices available and substitute a simulator name you have.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Running tests")
        .navigationBarTitleDisplayMode(.inline)
    }
}
