import Foundation
import SwiftData

/// One-to-one profile. The relationship is optional so a student can exist
/// before a profile is created, and so the two objects can be initialized separately.
@Model
final class StudentProfile {
    var bio: String
    var student: Student?

    init(bio: String, student: Student? = nil) {
        self.bio = bio
        self.student = student
    }
}

@Model
final class Student {
    var name: String
    var email: String

    /// Deleting a student deletes the profile. The inverse is declared on one side only.
    @Relationship(deleteRule: .cascade, inverse: \StudentProfile.student)
    var profile: StudentProfile?

    /// Deleting a student removes that student from each course, and does not delete the course.
    @Relationship(deleteRule: .nullify, inverse: \Course.students)
    var courses: [Course] = []

    init(name: String, email: String, profile: StudentProfile? = nil) {
        self.name = name
        self.email = email
        self.profile = profile
    }
}

@Model
final class Course {
    var title: String
    var code: String

    /// Default delete rule is nullify. Deleting a course leaves the students in the store.
    var students: [Student] = []

    init(title: String, code: String) {
        self.title = title
        self.code = code
    }
}
