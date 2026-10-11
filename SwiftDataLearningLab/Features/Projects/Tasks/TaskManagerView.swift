import SwiftData
import SwiftUI

struct TaskManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StudyTask.dueDate) private var tasks: [StudyTask]
    @Query(sort: \TaskCategory.name) private var categories: [TaskCategory]
    @State private var title = ""
    @State private var details = ""
    @State private var priority = TaskPriority.medium
    @State private var hasDueDate = false
    @State private var dueDate = Date.now
    @State private var categoryName = "School"
    @State private var status = "Tasks belong to a category. Deleting the category cascades to its tasks."

    var body: some View {
        List {
            Section("New task") {
                TextField("Title", text: $title)
                TextField("Details", text: $details)
                Picker("Priority", selection: $priority) {
                    ForEach(TaskPriority.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                Toggle("Due date", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                }
                TextField("Category", text: $categoryName)
                Button("Add task") { addTask() }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Section("Tasks") {
                if tasks.isEmpty {
                    ContentUnavailableView("No tasks", systemImage: "checklist", description: Text("Add a task with a category."))
                }
                ForEach(tasks) { task in
                    HStack {
                        Button {
                            task.isComplete.toggle()
                            try? modelContext.save()
                        } label: {
                            Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                        }
                        .accessibilityLabel(task.isComplete ? "Mark incomplete" : "Mark complete")
                        VStack(alignment: .leading) {
                            Text(task.title)
                            Text("\(task.priority.title) · \(task.category?.name ?? "No category")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let dueDate = task.dueDate {
                                Text(dueDate, style: .date)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        modelContext.delete(tasks[index])
                    }
                    try? modelContext.save()
                }
            }
            Section("Categories") {
                ForEach(categories) { category in
                    Text("\(category.name) · \(category.tasks.count)")
                }
                .onDelete { offsets in
                    for index in offsets {
                        modelContext.delete(categories[index])
                    }
                    try? modelContext.save()
                    status = "Deleting a category cascades to its tasks."
                }
            }
            Section {
                Text(status).font(.footnote)
            }
        }
        .navigationTitle("Tasks")
    }

    private func addTask() {
        do {
            let category = try RelationshipLab.category(named: categoryName.isEmpty ? "General" : categoryName, in: modelContext)
            let task = StudyTask(
                title: title,
                details: details,
                priority: priority,
                dueDate: hasDueDate ? dueDate : nil,
                category: category
            )
            modelContext.insert(task)
            try modelContext.save()
            title = ""
            details = ""
            status = "Saved. The due date is optional, so tasks without one sort separately from dated tasks."
        } catch {
            status = error.localizedDescription
        }
    }
}
