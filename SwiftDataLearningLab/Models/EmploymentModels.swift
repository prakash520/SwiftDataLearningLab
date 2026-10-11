import Foundation
import SwiftData

/// Declared with deleteRule `.deny`.
/// This SDK still deletes the department and leaves its employees.
/// `RelationshipLab.deleteDepartmentIfEmpty` is the check that actually refuses.
@Model
final class Department {
    var name: String

    @Relationship(deleteRule: .deny, inverse: \Employee.department)
    var employees: [Employee] = []

    init(name: String) {
        self.name = name
    }
}

@Model
final class Employee {
    var name: String
    var department: Department?

    init(name: String, department: Department? = nil) {
        self.name = name
        self.department = department
    }
}
