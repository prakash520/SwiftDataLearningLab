import SwiftUI

struct KnowledgeCheckView: View {
    @Bindable var model: LessonDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(model.lesson.quiz.enumerated()), id: \.element.id) { index, question in
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(index + 1). \(question.prompt)")
                        .font(.body.weight(.semibold))
                    ForEach(Array(question.choices.enumerated()), id: \.offset) { choice, title in
                        Button {
                            model.selectQuiz(question: index, choice: choice)
                        } label: {
                            HStack(alignment: .firstTextBaseline) {
                                Image(systemName: model.quizSelections[safe: index] == choice ? "largecircle.fill.circle" : "circle")
                                Text(title)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(model.quizSelections[safe: index] == choice ? .isSelected : [])
                    }
                    if model.showQuizExplanations {
                        let selected = model.quizSelections[safe: index] ?? -1
                        Text(selected == question.correctIndex ? "Correct. \(question.explanation)" : "Review: \(question.explanation)")
                            .font(.callout)
                            .foregroundStyle(selected == question.correctIndex ? Color.green : Color.primary)
                    }
                }
            }
            Button(model.showQuizExplanations ? "Explanations shown" : "Show explanations") {
                model.showQuizExplanations = true
            }
            .buttonStyle(.bordered)
            .disabled(model.showQuizExplanations)
        }
    }
}

struct ExerciseCard: View {
    let title: String
    let systemImage: String
    let prompt: String
    let hint: String
    let solution: String
    let isDone: Bool
    let solutionShown: Bool
    let onToggle: (Bool) -> Void
    let onReveal: () -> Void

    var body: some View {
        SectionCard(title: title, systemImage: systemImage) {
            VStack(alignment: .leading, spacing: 10) {
                Text(prompt)
                Text("Hint: \(hint)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Toggle("Mark done", isOn: Binding(get: { isDone }, set: onToggle))
                Button(solutionShown ? "Solution shown" : "Show solution") {
                    onReveal()
                }
                .buttonStyle(.bordered)
                .disabled(solutionShown)
                if solutionShown {
                    Text(solution)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
