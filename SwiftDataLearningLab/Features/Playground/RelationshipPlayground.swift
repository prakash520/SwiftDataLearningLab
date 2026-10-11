import SwiftData
import SwiftUI

struct RelationshipPlayground: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Student.name) private var students: [Student]
    @Query(sort: \Course.title) private var courses: [Course]
    @Query(sort: \TaskCategory.name) private var categories: [TaskCategory]
    @Query(sort: \LibraryBook.title) private var libraryBooks: [LibraryBook]
    @Query(sort: \Department.name) private var departments: [Department]
    @State private var status = "Create a graph, then delete the parent and watch the delete rule."
    @State private var page = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Example", selection: $page) {
                Text("Student").tag(0)
                Text("Tasks").tag(1)
                Text("Library").tag(2)
                Text("Delete rules").tag(3)
            }
            .pickerStyle(.segmented)
            switch page {
            case 0: studentSection
            case 1: taskSection
            case 2: librarySection
            default: deleteSection
            }
            LabStatusBanner(text: status)
        }
    }

    private var studentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Enroll Ada in SwiftData 101") {
                do {
                    try RelationshipLab.enroll(
                        studentName: "Ada",
                        email: "ada@example.com",
                        courseTitle: "SwiftData 101",
                        courseCode: "SD101",
                        in: modelContext
                    )
                    status = "One-to-one profile and one-to-many course link were saved together."
                } catch {
                    status = error.localizedDescription
                }
            }
            ForEach(students) { student in
                Text("\(student.name): \(student.courses.map(\.code).joined(separator: ", ")) · profile \(student.profile == nil ? "missing" : "present")")
                    .font(.callout)
            }
            if students.isEmpty {
                Text("No students yet.").foregroundStyle(.secondary)
            }
        }
    }

    private var taskSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Add a high-priority task in School") {
                do {
                    try RelationshipLab.addTask(title: "Read delete rules", priority: .high, categoryName: "School", in: modelContext)
                    status = "The task's category relationship points at School. Open the task project to edit due dates."
                } catch {
                    status = error.localizedDescription
                }
            }
            ForEach(categories) { category in
                Text("\(category.name): \(category.tasks.count) task(s)")
            }
        }
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Link a book and an author") {
                do {
                    try RelationshipLab.link(bookTitle: "Models", year: 2024, authorName: "Grace", in: modelContext)
                    status = "Many-to-many: the book lists the author, and the author lists the book. Both sides nullify on delete."
                } catch {
                    status = error.localizedDescription
                }
            }
            ForEach(libraryBooks) { book in
                Text("\(book.title) by \(book.authors.map(\.name).joined(separator: ", "))")
            }
        }
    }

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Create a department that denies deletion") {
                let department = Department(name: "Lab \(Int.random(in: 10...99))")
                let employee = Employee(name: "Lin", department: department)
                modelContext.insert(department)
                modelContext.insert(employee)
                do {
                    try modelContext.save()
                    status = "Department \(department.name) has an employee. The store's deny rule will not stop a raw delete. Use the guarded button."
                } catch {
                    status = error.localizedDescription
                }
            }
            Button("Refuse deletion while employees exist") {
                guard let department = departments.first else {
                    status = "Create a department first."
                    return
                }
                do {
                    try RelationshipLab.deleteDepartmentIfEmpty(department, in: modelContext)
                    status = "Deleted \(department.name). It had no employees, so the app allowed the delete."
                } catch {
                    status = error.localizedDescription
                }
            }
            Button("Delete first department anyway", role: .destructive) {
                guard let department = departments.first else {
                    status = "Create a department first."
                    return
                }
                let name = department.name
                modelContext.delete(department)
                do {
                    try modelContext.save()
                    status = "Deleted \(name). deleteRule .deny did not throw. Employees remain with a nil department."
                } catch {
                    modelContext.rollback()
                    status = error.localizedDescription
                }
            }
            Button("Delete first course (nullify)") {
                guard let course = courses.first else {
                    status = "Enroll a student so a course exists."
                    return
                }
                let title = course.title
                modelContext.delete(course)
                do {
                    try modelContext.save()
                    status = "Deleted \(title). Students remain, and that course is gone from their arrays."
                } catch {
                    status = error.localizedDescription
                }
            }
            Button("Delete first category (cascade)", role: .destructive) {
                guard let category = categories.first else {
                    status = "Add a task so a category exists."
                    return
                }
                let count = category.tasks.count
                modelContext.delete(category)
                do {
                    try modelContext.save()
                    status = "Deleted the category and its \(count) task(s) because the delete rule is cascade."
                } catch {
                    status = error.localizedDescription
                }
            }
            Button("Run isolated no-action demo") {
                status = NoActionDemo.run()
            }
            ForEach(departments) { department in
                Text("\(department.name): \(department.employees.count) employee(s)")
                    .font(.callout)
            }
        }
    }
}

enum NoActionDemo {
    static func run() -> String {
        do {
            let schema = Schema([ScratchPad.self, ScratchPage.self])
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            context.autosaveEnabled = false
            let pad = ScratchPad(title: "Scratch")
            let page = ScratchPage(text: "A page", pad: pad)
            context.insert(pad)
            context.insert(page)
            try context.save()
            context.delete(pad)
            try context.save()
            let pages = try context.fetch(FetchDescriptor<ScratchPage>())
            let dangling = pages.contains { $0.pad != nil }
            return dangling
                ? "noAction left \(pages.count) page(s) still pointing at a deleted pad. Do not use this rule in an app store."
                : "The page count is \(pages.count). Inspect pad after the delete. noAction does not maintain the inverse."
        } catch {
            return error.localizedDescription
        }
    }
}
