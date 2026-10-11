import SwiftData
import SwiftUI
import UIKit

struct LessonDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppCoordinator.self) private var coordinator
    let lessonID: String
    @State private var model: LessonDetailViewModel?
    @State private var loadError: String?

    var body: some View {
        Group {
            if let model {
                LessonDetailContent(model: model)
            } else if let loadError {
                ContentUnavailableView("Could not open the lesson", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else if LessonCatalog.lesson(id: lessonID) == nil {
                ContentUnavailableView("Lesson not found", systemImage: "questionmark.circle")
            } else {
                ProgressView("Opening lesson")
            }
        }
        .task(id: lessonID) {
            guard let lesson = LessonCatalog.lesson(id: lessonID) else { return }
            do {
                model = try LessonDetailViewModel(lesson: lesson, context: modelContext)
                loadError = nil
            } catch {
                loadError = error.localizedDescription
            }
        }
    }
}

private struct LessonDetailContent: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Bindable var model: LessonDetailViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let module = LessonCatalog.module(id: model.lesson.moduleID) {
                    LevelBadge(level: module.level)
                }
                Text(model.lesson.summary)
                    .font(.title3)
                Toggle("Mark lesson complete", isOn: Binding(
                    get: { model.isCompleted },
                    set: { model.setCompleted($0) }
                ))
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                if let sdkNote = model.lesson.sdkNote {
                    LabStatusBanner(text: sdkNote)
                }

                SectionCard(title: "Concept", systemImage: "lightbulb") {
                    Text(model.lesson.concept).textSelection(.enabled)
                }
                SectionCard(title: "Why it exists", systemImage: "questionmark.circle") {
                    Text(model.lesson.whyItExists).textSelection(.enabled)
                }
                SectionCard(title: "When to use it", systemImage: "app.badge") {
                    Text(model.lesson.whenToUse).textSelection(.enabled)
                }
                SectionCard(title: "Example", systemImage: "chevron.left.forwardslash.chevron.right") {
                    CodeViewer(sample: model.lesson.sample)
                }
                SectionCard(title: "Expected behavior", systemImage: "eye") {
                    Text(model.lesson.expectedBehavior).textSelection(.enabled)
                }
                SectionCard(title: "Interactive playground", systemImage: "hand.tap") {
                    PlaygroundHostView(kind: model.lesson.playground)
                }
                ExerciseCard(
                    title: "Guided experiment",
                    systemImage: "flask",
                    prompt: model.lesson.experiment.prompt,
                    hint: model.lesson.experiment.hint,
                    solution: model.lesson.experiment.solution,
                    isDone: model.experimentCompleted,
                    solutionShown: model.showExperimentSolution,
                    onToggle: { model.setExperiment($0) },
                    onReveal: { model.showExperimentSolution = true }
                )
                ExerciseCard(
                    title: "Independent challenge",
                    systemImage: "square.and.pencil",
                    prompt: model.lesson.challenge.prompt,
                    hint: model.lesson.challenge.hint,
                    solution: model.lesson.challenge.solution,
                    isDone: model.challengeCompleted,
                    solutionShown: model.showChallengeSolution,
                    onToggle: { model.setChallenge($0) },
                    onReveal: { model.showChallengeSolution = true }
                )
                TextEditor(text: $model.challengeNotes)
                    .frame(minHeight: 90)
                    .padding(8)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator))
                    .accessibilityLabel("Challenge notes")
                    .onChange(of: model.challengeNotes) { _, _ in
                        model.saveChallengeNotes()
                    }
                SectionCard(title: "Common bug", systemImage: "ant") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.lesson.bug.title).font(.headline)
                        Text(model.lesson.bug.question)
                        Text(model.lesson.bug.brokenCode)
                            .font(.system(.callout, design: .monospaced))
                            .textSelection(.enabled)
                        Toggle("I diagnosed this bug", isOn: Binding(
                            get: { model.bugDiagnosed },
                            set: { model.setBug($0) }
                        ))
                        Button(model.showBugDiagnosis ? "Diagnosis shown" : "Show diagnosis") {
                            model.showBugDiagnosis = true
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.showBugDiagnosis)
                        if model.showBugDiagnosis {
                            Text(model.lesson.bug.diagnosis)
                        }
                    }
                }
                SectionCard(title: "Common mistakes", systemImage: "exclamationmark.triangle") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(model.lesson.mistakes, id: \.self) { item in
                            Text("• \(item)")
                        }
                    }
                }
                SectionCard(title: "Debugging tips", systemImage: "wrench.and.screwdriver") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(model.lesson.debuggingTips, id: \.self) { item in
                            Text("• \(item)")
                        }
                    }
                }
                SectionCard(title: "Knowledge check", systemImage: "checkmark.seal") {
                    KnowledgeCheckView(model: model)
                }
                if let message = model.errorMessage {
                    LabStatusBanner(text: message)
                }
                navigationButtons
            }
            .padding()
        }
        .navigationTitle(model.lesson.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }

    private var navigationButtons: some View {
        HStack {
            if let previous = LessonCatalog.previous(before: model.lesson) {
                Button("Previous") { coordinator.openLesson(previous.id) }
            }
            Spacer()
            if let next = LessonCatalog.next(after: model.lesson) {
                Button("Next") { coordinator.openLesson(next.id) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
