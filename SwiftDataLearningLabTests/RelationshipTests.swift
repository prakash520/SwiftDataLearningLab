import SwiftData
import XCTest
@testable import SwiftDataLearningLab

@MainActor
final class RelationshipTests: IsolatedTestCase {
    func testEnrollmentLinksProfileAndCourse() throws {
        try RelationshipLab.enroll(
            studentName: "Ada",
            email: "ada@example.com",
            courseTitle: "SwiftData 101",
            courseCode: "SD101",
            in: context
        )
        let students = try context.fetch(FetchDescriptor<Student>())
        XCTAssertEqual(students.count, 1)
        XCTAssertNotNil(students[0].profile)
        XCTAssertEqual(students[0].courses.map(\.code), ["SD101"])
        XCTAssertEqual(students[0].courses.first?.students.count, 1)
    }

    func testDeletingCourseNullifiesStudents() throws {
        try RelationshipLab.enroll(
            studentName: "Ada",
            email: "ada@example.com",
            courseTitle: "SwiftData 101",
            courseCode: "SD101",
            in: context
        )
        let course = try context.fetch(FetchDescriptor<Course>())[0]
        context.delete(course)
        try context.save()
        let students = try context.fetch(FetchDescriptor<Student>())
        XCTAssertEqual(students.count, 1)
        XCTAssertTrue(students[0].courses.isEmpty)
    }

    func testDeletingCategoryCascadesTasks() throws {
        try RelationshipLab.addTask(title: "Read", priority: .high, categoryName: "School", in: context)
        let category = try context.fetch(FetchDescriptor<TaskCategory>())[0]
        context.delete(category)
        try context.save()
        let tasks = try context.fetch(FetchDescriptor<StudyTask>())
        XCTAssertTrue(tasks.isEmpty)
    }

    func testStoreDeletesADepartmentDespiteTheDenyRule() throws {
        let stack = try AppModelContainer.makeTemporaryDisk()
        defer { try? FileManager.default.removeItem(at: stack.directory) }
        let diskContext = ModelContext(stack.container)
        diskContext.autosaveEnabled = false

        let department = Department(name: "Lab")
        let employee = Employee(name: "Lin", department: department)
        diskContext.insert(department)
        diskContext.insert(employee)
        try diskContext.save()

        diskContext.delete(department)
        XCTAssertNoThrow(try diskContext.save())
        XCTAssertEqual(try diskContext.fetch(FetchDescriptor<Department>()).count, 0)
        XCTAssertEqual(try diskContext.fetch(FetchDescriptor<Employee>()).count, 1)
    }

    func testAppRefusesToDeleteADepartmentThatStillHasEmployees() throws {
        let stack = try AppModelContainer.makeTemporaryDisk()
        defer { try? FileManager.default.removeItem(at: stack.directory) }
        let diskContext = ModelContext(stack.container)
        diskContext.autosaveEnabled = false

        let department = Department(name: "Lab")
        let employee = Employee(name: "Lin", department: department)
        diskContext.insert(department)
        diskContext.insert(employee)
        try diskContext.save()

        XCTAssertThrowsError(try RelationshipLab.deleteDepartmentIfEmpty(department, in: diskContext))
        XCTAssertEqual(try diskContext.fetch(FetchDescriptor<Department>()).count, 1)
        XCTAssertEqual(try diskContext.fetch(FetchDescriptor<Employee>()).count, 1)

        employee.department = nil
        try diskContext.save()
        try RelationshipLab.deleteDepartmentIfEmpty(department, in: diskContext)
        XCTAssertEqual(try diskContext.fetch(FetchDescriptor<Department>()).count, 0)
        XCTAssertEqual(try diskContext.fetch(FetchDescriptor<Employee>()).count, 1)
    }

    func testLibraryNullifyKeepsTheOtherSide() throws {
        try RelationshipLab.link(bookTitle: "Models", year: 2024, authorName: "Grace", in: context)
        let author = try context.fetch(FetchDescriptor<Author>())[0]
        XCTAssertEqual(author.books.count, 1)
        context.delete(author)
        try context.save()
        let books = try context.fetch(FetchDescriptor<LibraryBook>())
        XCTAssertEqual(books.count, 1)
        XCTAssertTrue(books[0].authors.isEmpty)
    }
}
