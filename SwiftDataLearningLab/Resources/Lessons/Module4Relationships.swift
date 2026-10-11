import Foundation

enum Module4Relationships {
    static let id = "relationships"
    static let module = LearningModule(
        id: id,
        title: "Relationships",
        summary: "One-to-one, one-to-many, many-to-many, inverses, optionals, delete rules, and the cycles that go wrong.",
        level: .intermediate,
        order: 4,
        lessons: [oneToOne, oneToMany, manyToMany, inverse, optional, macro, rules, traversal, circular]
    )

    static let oneToOne = Lesson.make(
        id: "m4-one-to-one", moduleID: id, title: "One-to-one relationships",
        summary: "Student and StudentProfile are optional peers with a cascade from the student.",
        concept: "A one-to-one link is two properties that point at each other, usually optional so each object can be created alone. Student.profile is optional. StudentProfile.student is optional. The delete rule on the student side is cascade, so deleting the student deletes the profile. The profile does not own the student. Do not make both sides non-optional. You cannot initialize a cycle of required objects cleanly, and SwiftData materializes rows without calling your init the way a hand-built graph does.",
        whyItExists: "Some data is a satellite of one owner: a profile, a settings row, a cover image record. It should not be an array.",
        whenToUse: "When each side has at most one of the other, and you may want to fetch either side. If the satellite is a handful of fields, a Codable struct on the owner is simpler and cannot be queried as its own entity.",
        sample: Samples.make("m4-11", "Optional profile cascade", #"""
        import SwiftData

        @Model
        final class Student {
            var name: String
            @Relationship(deleteRule: .cascade, inverse: \StudentProfile.student)
            var profile: StudentProfile?
            init(name: String) { self.name = name }
        }
        """#, [
            ("deleteRule: .cascade", "Deleting the student deletes the profile."),
            ("inverse: \\StudentProfile.student", "Declared on one side only. The other side is the plain property."),
            ("var profile: StudentProfile?", "Optional, so a student can be saved before a profile exists.")
        ]),
        expectedBehavior: "Enroll Ada in the relationship playground. The row says the profile is present.",
        experiment: "Enroll Ada and read the profile status on her row.",
        experimentHint: "The Student segment has the enroll button.",
        experimentSolution: "The status says the profile is present because enroll assigns StudentProfile before save.",
        challenge: "When would you store a bio as a String on Student instead of a StudentProfile model?",
        challengeHint: "A separate model is an entity with its own identity.",
        challengeSolution: "If nothing else references the bio and you never fetch profiles alone, a String is enough. A model is for an object you create, delete, or query on its own.",
        bugTitle: "Two non-optional ends",
        bugCode: "var profile: StudentProfile\nvar student: Student",
        bugQuestion: "Why is a required cycle a bad model?",
        bugDiagnosis: "Each init needs the other object first. Make the link optional or assign it after both objects exist.",
        mistakes: ["Cascading from both sides.", "Declaring the inverse on both properties.", "Using an array for a true one-to-one."],
        debuggingTips: ["Print profile == nil after fetch.", "Delete the student in a test and assert the profile count is zero.", "If the macro complains about the inverse, keep the key path on one side."],
        quiz: [
            Quiz.make("m4a1", "Why is the profile optional?", ["So it can be unique", "So the student can exist first", "So cascade is illegal", "So it is transient"], correct: 1, "Optional breaks the initialization cycle and models absence."),
            Quiz.make("m4a2", "Deleting a student with cascade will:", ["Keep the profile and clear the link", "Delete the profile", "Delete every course", "Fail the save always"], correct: 1, "Cascade deletes the related profile."),
            Quiz.make("m4a3", "The inverse key path is written:", ["On both sides", "On one side", "In the container", "In the view"], correct: 1, "Both sides pointing at each other confuse the macro.")
        ],
        playground: .relationships
    )

    static let oneToMany = Lesson.make(
        id: "m4-one-to-many", moduleID: id, title: "One-to-many relationships",
        summary: "A category owns many tasks. A course has many students, who also have many courses.",
        concept: "One-to-many is a to-many array on the parent and a to-one optional on the child. TaskCategory.tasks is the array. StudyTask.category is the optional parent. The delete rule you choose is the product decision: cascade means the tasks are part of the category, nullify means the tasks outlive it. Course and Student are not a pure one-to-many because a student can take many courses. That pair is many-to-many. The task pair is the one-to-many to study first. Give the array a default of [] so init does not have to mention it.",
        whyItExists: "Parent and child data is the most common graph in an app: projects and issues, categories and expenses, authors and a single-author book.",
        whenToUse: "When the child has one parent. If the child can have several, you are in many-to-many and an array on only one side will lose links.",
        sample: Samples.make("m4-1n", "Category owns tasks", #"""
        import SwiftData

        @Model
        final class TaskCategory {
            @Attribute(.unique) var name: String
            @Relationship(deleteRule: .cascade, inverse: \StudyTask.category)
            var tasks: [StudyTask] = []
            init(name: String) { self.name = name }
        }
        """#, [
            ("@Attribute(.unique)", "Two categories cannot share a name once save succeeds."),
            ("deleteRule: .cascade", "The tasks are owned. Deleting the category deletes them."),
            ("var tasks: [StudyTask] = []", "A default empty array avoids a required relationship during init.")
        ]),
        expectedBehavior: "Adding a task in School shows a category count of at least one. Deleting that category removes the tasks.",
        experiment: "Add a high-priority task, note the count, then on the Delete rules segment delete the first category.",
        experimentHint: "Cascade is called out in the status text.",
        experimentSolution: "The tasks that pointed at that category are gone after the save.",
        challenge: "Expenses nullify instead of cascading. What user-facing difference does that make?",
        challengeHint: "Look at ExpenseCategory.expenses.",
        challengeSolution: "Deleting a category keeps the expenses and clears their category. Money history survives a renamed or removed bucket.",
        bugTitle: "Child array without an inverse",
        bugCode: "var tasks: [StudyTask]\nvar category: TaskCategory?",
        bugQuestion: "What goes wrong when both properties exist and neither names the inverse?",
        bugDiagnosis: "SwiftData may not keep them in sync, or the macro flags the relationship. Set inverse on one side so both properties are one relationship.",
        mistakes: ["Cascade on data the user still needs.", "A non-optional parent that makes previews painful.", "Appending the child and forgetting to insert it. Relating to an inserted parent usually inserts it, but tests should insert explicitly when the graph is unclear."],
        debuggingTips: ["Print category.tasks.count and task.category?.name. They should agree.", "Delete in a test and fetch the child type.", "Unique name collisions throw at save, not at init."],
        quiz: [
            Quiz.make("m4b1", "On TaskCategory, cascade means:", ["Tasks become uncategorized", "Tasks are deleted with the category", "The delete is denied", "Tasks are duplicated"], correct: 1, "The children are owned."),
            Quiz.make("m4b2", "StudyTask.category is optional because:", ["A task may not have a category yet", "Optionals cannot be stored", "It makes the link many-to-many", "It disables cascade"], correct: 0, "Absence is a valid state. Cascade still applies when the parent is deleted."),
            Quiz.make("m4b3", "The default empty array is there so:", ["The store skips the table", "Init does not need a live array of children", "Delete rules are ignored", "The inverse is optional"], correct: 1, "You can create the parent, then append children.")
        ],
        playground: .relationships
    )

    static let manyToMany = Lesson.make(
        id: "m4-many-to-many", moduleID: id, title: "Many-to-many relationships",
        summary: "Books and authors, bookmarks and tags. Arrays on both sides, nullify on delete.",
        concept: "Many-to-many means each side holds an array and the inverse connects them. LibraryBook.authors and Author.books are the library. Bookmark.tags and Tag.bookmarks are the bookmark manager. Delete rules on both sides are nullify. Deleting a book must not delete a shared author. Deleting a tag must not delete every bookmark that used it. Cascade on a many-to-many is the bug that deletes half the user's library because one shared author was removed. There is no separate join model in these examples. SwiftData maintains the link. Add a join model only when the relationship itself has attributes, such as the date a student enrolled.",
        whyItExists: "Shared labels and shared people do not fit a single parent pointer.",
        whenToUse: "Tags, authors, members of several groups. Not for a task that has one category.",
        sample: Samples.make("m4-nn", "Nullify both sides", #"""
        import SwiftData

        @Model
        final class LibraryBook {
            var title: String
            @Relationship(deleteRule: .nullify, inverse: \Author.books)
            var authors: [Author] = []
            init(title: String) { self.title = title }
        }
        """#, [
            ("deleteRule: .nullify", "Deleting the book removes the link, not the author."),
            ("inverse: \\Author.books", "Author.books is the other array. One relationship, two properties."),
            ("var authors: [Author] = []", "Appending an author updates the inverse when both are in the same context.")
        ]),
        expectedBehavior: "Link a book and an author. The book row lists Grace. Deleting the book in the library project leaves the author.",
        experiment: "Link a book and an author, then open the library project and delete the book. Confirm the author remains.",
        experimentHint: "The library segment creates Models by Grace.",
        experimentSolution: "Nullify removed the link. The author row is still in the store.",
        challenge: "When would you introduce an Enrollment model between Student and Course?",
        challengeHint: "When the link has its own fields.",
        challengeSolution: "When you must store the term, grade, or enrollment date on the link itself. A plain many-to-many cannot store those.",
        bugTitle: "Cascade on a shared tag",
        bugCode: "@Relationship(deleteRule: .cascade, inverse: \\Bookmark.tags)\nvar bookmarks: [Bookmark]",
        bugQuestion: "What does deleting one tag do?",
        bugDiagnosis: "It deletes every bookmark that had the tag. Use nullify so the bookmarks remain.",
        mistakes: ["Only storing the array on one side and expecting the other side to appear.", "Duplicating Tag rows instead of reusing the unique name.", "Cascading across a shared person."],
        debuggingTips: ["After append, print both directions.", "Delete one side in a test and fetch the other.", "Unique tag names turn a typo into a thrown save instead of two tags."],
        quiz: [
            Quiz.make("m4c1", "A shared author should use:", ["cascade", "nullify", "deny always", "noAction"], correct: 1, "The author outlives any one book."),
            Quiz.make("m4c2", "Many-to-many in this lab is represented by:", ["A foreign-key string you maintain", "Arrays on both sides with an inverse", "A transient dictionary", "@Query only"], correct: 1, "SwiftData keeps the two arrays in sync."),
            Quiz.make("m4c3", "A join model is worth it when:", ["You need one extra column on the link", "You are tired of optionals", "The delete rule is deny", "The objects are in memory only"], correct: 0, "The relationship itself has data.")
        ],
        playground: .relationships
    )

    static let inverse = Lesson.make(
        id: "m4-inverse", moduleID: id, title: "Inverse relationships",
        summary: "One relationship, two properties, one inverse declaration.",
        concept: "The inverse tells SwiftData that Student.courses and Course.students are the same link. Set the key path on one @Relationship only. When you append a course to a student in the same context, the course's students array gains that student. You do not append on both sides. If you do, you can introduce duplicates. If you forget the inverse, the two properties drift: one side shows the link and the other does not. The macro uses the key path at compile time, so a rename of the property that you do not update becomes a compiler error. That is the point.",
        whyItExists: "A graph has two directions. The store should not depend on you remembering both writes.",
        whenToUse: "Every relationship you will traverse from both types. A truly one-way link is rare in this curriculum.",
        sample: Samples.make("m4-inv", "Inverse on the student side", #"""
        import SwiftData

        @Relationship(deleteRule: .nullify, inverse: \Course.students)
        var courses: [Course] = []
        // Course.students does not repeat inverse: \Student.courses.
        """#, [
            ("inverse: \\Course.students", "Names the other property of the same relationship."),
            ("Course.students does not repeat", "A second inverse declaration is a conflict, not a backup.")
        ]),
        expectedBehavior: "After enroll, the student lists the course code. The course's students include that student even though enroll only appended from the student side.",
        experiment: "Enroll Ada and look at her course codes. The inverse filled the other direction.",
        experimentHint: "The row prints courses.map code.",
        experimentSolution: "You appended from the student. The course side matches because the inverse is configured.",
        challenge: "What bug appears if a view appends the student to the course and also appends the course to the student?",
        challengeHint: "The inverse already does the second write.",
        challengeSolution: "You can get duplicate entries or a relationship the context cannot reconcile. Append once.",
        bugTitle: "Inverse on both properties",
        bugCode: "@Relationship(inverse: \\Course.students) var courses: [Course]\n@Relationship(inverse: \\Student.courses) var students: [Student]",
        bugQuestion: "Why do both macros disagree?",
        bugDiagnosis: "Each side claims to be the declaration. Leave one side as a plain property.",
        mistakes: ["Maintaining both arrays by hand.", "Pointing the inverse at the wrong property.", "Using a String id as a homemade inverse."],
        debuggingTips: ["After save, fetch both types and compare counts.", "If only one side updates, the inverse key path is missing or wrong.", "Let the compiler fail when you rename a property."],
        quiz: [
            Quiz.make("m4d1", "How many sides declare inverse?", ["Both", "One", "Neither, ever", "The view"], correct: 1, "One declaration links the two properties."),
            Quiz.make("m4d2", "After appending a course onto a student, you should also:", ["Append the student onto the course yourself", "Let the inverse update the other side", "Call insert on the course title", "Turn autosave off"], correct: 1, "The relationship machinery writes the other side."),
            Quiz.make("m4d3", "A wrong inverse key path is:", ["A runtime string typo", "A compile error when the property is gone", "Ignored", "A CloudKit conflict"], correct: 1, "The key path is type-checked.")
        ],
        playground: .relationships
    )

    static let optional = Lesson.make(
        id: "m4-optional", moduleID: id, title: "Optional relationships",
        summary: "Nil means no link. It is not a crash and it is not an empty object.",
        concept: "To-one relationships in this lab are optional: task.category, expense.category, employee.department, profile links. Nil is a stored state. Predicates that use category?.name do not match nil. UI should say Uncategorized rather than force-unwrapping. To-many relationships use an empty array instead of nil. Do not use an empty related object as a sentinel. CloudKit-backed stores require optional relationships, which is another reason the local lab can be stricter than a syncing schema. The CloudKit module covers that constraint. Locally, optional is still the right default because real data is incomplete while the user is editing.",
        whyItExists: "Creation is stepwise. A task exists before the user picks a category.",
        whenToUse: "Almost every to-one. Make it required only when a row without the link is meaningless and you can construct both objects before save.",
        sample: Samples.make("m4-opt", "A task without a category", #"""
        import SwiftData

        let task = StudyTask(title: "Later", priority: .low, category: nil)
        modelContext.insert(task)
        try modelContext.save()
        """#, [
            ("category: nil", "A legal row. The foreign key is null."),
            ("modelContext.insert(task)", "Nil does not block insert."),
            ("try modelContext.save()", "The store accepts the row.")
        ]),
        expectedBehavior: "The task manager can save a task whose category field was left blank only if you type a name. The model itself allows nil. The expense list prints Uncategorized when the category was nullified.",
        experiment: "Delete an expense category in the expense project after you have expenses. The expenses remain and show Uncategorized.",
        experimentHint: "The relationship is nullify. You may need to add an expense first.",
        experimentSolution: "Nullify set category to nil. The rows stayed. The UI uses a fallback string.",
        challenge: "Why is force-unwrapping task.category a bug even if today's sample data always has one?",
        challengeHint: "Delete rules and partial forms.",
        challengeSolution: "Nullify, a half-finished form, or a future import can store nil. The unwrap crashes on real data.",
        bugTitle: "Sentinel object",
        bugCode: "let none = TaskCategory(name: \"\")\ntask.category = none",
        bugQuestion: "Why is a fake category worse than nil?",
        bugDiagnosis: "It is a real row. It shows up in pickers, breaks unique names, and survives as junk. Use nil.",
        mistakes: ["Treating nil as a fetch error.", "Predicates that accidentally drop nil rows and calling that a bug.", "Required relationships for draft objects."],
        debuggingTips: ["Print the optional with String(describing:).", "Write a predicate for == nil if you need the uncategorized bucket. Some optional comparisons need a dedicated shape.", "After nullify, fetch the children and assert category == nil."],
        quiz: [
            Quiz.make("m4e1", "nil on a to-one relationship means:", ["The store is corrupt", "There is no related object", "Cascade failed", "The inverse is missing"], correct: 1, "It is a valid stored state."),
            Quiz.make("m4e2", "A to-many uses:", ["nil", "An empty array", "A sentinel model", "A transient string"], correct: 1, "Absence of children is []."),
            Quiz.make("m4e3", "category?.name == \"Food\" matches a nil category?", ["Yes", "No", "Only in memory stores", "Only after migration"], correct: 1, "Optional chaining fails the comparison when the link is nil.")
        ],
        playground: .relationships
    )

    static let macro = Lesson.make(
        id: "m4-relationship-macro", moduleID: id, title: "@Relationship",
        summary: "Delete rule, inverse, and the default of nullify.",
        concept: "The @Relationship macro attaches schema metadata to a property. The important arguments in this lab are deleteRule and inverse. The default delete rule is nullify. minimumModelCount and maximumModelCount exist for constraints on the number of related objects. You rarely need them for a learning graph, and a bad maximum is a save failure you did not expect. originalName matters when you rename a relationship during migration. Leaving the macro off and using a plain array of models can appear to work until the inverse or the delete rule is wrong. Be explicit on the side that owns the rule.",
        whyItExists: "A plain Swift array does not say what deletion means. The macro puts that decision in the schema.",
        whenToUse: "On the side where you want to document the delete rule. Keep the other side a plain property so the inverse is declared once.",
        sample: Samples.make("m4-rel", "The arguments that matter", #"""
        import SwiftData

        @Relationship(deleteRule: .deny, inverse: \Employee.department)
        var employees: [Employee] = []
        """#, [
            ("@Relationship", "Schema metadata, not a runtime wrapper you call."),
            ("deleteRule: .deny", "Declares deny. This SDK still deletes the department and leaves the employees. The app checks employees.isEmpty before delete."),
            ("inverse: \\Employee.department", "The employee's to-one property.")
        ]),
        expectedBehavior: "The guarded button throws while an employee remains. Delete anyway removes the department and leaves the employee, which is what .deny failed to prevent.",
        experiment: "Create a department, tap Refuse deletion while employees exist, then tap Delete first department anyway.",
        experimentHint: "The status should say the store did not enforce deny.",
        experimentSolution: "The guard throws and both rows stay. The raw delete removes only the department.",
        challenge: "What does originalName do, even though these models do not set it?",
        challengeHint: "Migration renames.",
        challengeSolution: "It tells a migration the previous relationship name so existing links are not treated as a brand-new relationship.",
        bugTitle: "Relying on the default without reading it",
        bugCode: "var tasks: [StudyTask] = []",
        bugQuestion: "If this is the only declaration, what delete rule are you actually shipping?",
        bugDiagnosis: "The default is nullify, not cascade. Owned children would survive as orphans unless you set cascade on purpose.",
        mistakes: ["Setting a maximum count you did not mean.", "Putting the macro on both sides.", "Assuming the default is cascade because Core Data samples you remember used cascade."],
        debuggingTips: ["Read the property in the model file before debugging the view.", "Write one test per delete rule you ship.", "When a save fails, check deny before you check the disk."],
        quiz: [
            Quiz.make("m4f1", "The default delete rule is:", ["cascade", "nullify", "deny", "noAction"], correct: 1, "You must opt into cascade, deny, or noAction."),
            Quiz.make("m4f2", "@Relationship is:", ["A function you call at save time", "A macro that records schema metadata", "A view modifier", "A migration stage"], correct: 1, "It decorates the property."),
            Quiz.make("m4f3", "originalName is for:", ["SwiftUI labels", "Preserving a relationship across a rename", "Unique constraints", "Autosave"], correct: 1, "Migrations use it to find the old name.")
        ],
        playground: .relationships
    )

    static let rules = Lesson.make(
        id: "m4-delete-rules", moduleID: id, title: "Delete rules",
        summary: "Cascade, nullify, deny, and noAction. Only three of them belong in an app.",
        concept: "cascade deletes the related objects when this object is deleted. nullify clears the relationship and keeps the related objects. deny is supposed to abort the save if the relationship is not empty. On this SDK it does not: deleting a Department removes the department and leaves its employees, the same outcome as nullify. RelationshipLab.deleteDepartmentIfEmpty is the check that actually refuses. noAction does not update the inverse. The related object can keep pointing at something you deleted. That is a dangling reference, and this lab will only run it inside a temporary in-memory container of ScratchPad and ScratchPage, which are not in the app schema. Do not ship noAction. Choose the rule based on ownership, not on what is shortest to type. The rule of the object being deleted is the one that runs. Deleting a course uses the course side. Deleting a student uses the student side. Cascade and nullify in this lab do what their names say. Deny does not, so do not trust the enum case without a test.",
        whyItExists: "Deletion is a product decision. The schema should enforce it even if a future screen forgets the cleanup loop.",
        whenToUse: "cascade for owned children, nullify for shared or independent peers, deny when the user must detach objects first, noAction never in the shipping store.",
        sample: Samples.make("m4-rules", "Four outcomes", #"""
        import SwiftData

        // cascade: TaskCategory.tasks deletes StudyTask rows.
        // nullify: Course.students leaves Student rows in the store.
        // deny: Department.employees is declared. This SDK still deletes the department.
        // noAction: ScratchPad.pages is isolated in a temporary memory container.
        modelContext.delete(department)
        try modelContext.save()
        """#, [
            ("cascade: TaskCategory.tasks", "Owned children leave with the parent."),
            ("deny: Department.employees", "Declared on the model. The store still deletes the department and keeps the employees."),
            ("try modelContext.save()", "Rules are enforced when the delete is committed, not when delete() is called.")
        ]),
        expectedBehavior: "The delete-rules segment nullifies a course, cascades a category, shows that deny does not throw, and reports a dangling page from the isolated noAction demo.",
        experiment: "Run each button on the Delete rules segment once.",
        experimentHint: "Create the department before deleting it. Enroll a student before deleting a course.",
        experimentSolution: "Course deletion keeps students. Category deletion removes tasks. The guarded department delete throws. Delete anyway removes the department and keeps the employee. noAction runs only in the temporary container.",
        challenge: "Which rule should Bookmark.tags use, and why?",
        challengeHint: "Tags are shared.",
        challengeSolution: "nullify. Deleting a bookmark should not delete a tag that other bookmarks use.",
        bugTitle: "noAction in the main store",
        bugCode: "@Relationship(deleteRule: .noAction, inverse: \\ScratchPage.pad)\nvar pages: [ScratchPage]",
        bugQuestion: "What can the page's pad property hold after the pad is deleted?",
        bugDiagnosis: "A reference to a deleted object, because noAction does not nullify or cascade. The lab refuses to put that rule in the main schema.",
        mistakes: ["Cascade on many-to-many.", "Deny without a UI path that empties the relationship.", "Testing noAction against LearningLab.store."],
        debuggingTips: ["Read the rule in the model, then test the delete. deny did not throw.", "Assert the app guard, not the enum case.", "Keep the noAction models out of AppModelContainer.modelTypes."],
        quiz: [
            Quiz.make("m4g1", "On this SDK, deleteRule .deny:", ["Deletes the employees", "Does not stop the department delete, so the app must check", "Leaves a dangling inverse", "Is the default"], correct: 1, "The store removed the department and kept the employee. deleteDepartmentIfEmpty is the real refusal."),
            Quiz.make("m4g2", "noAction is isolated because:", ["It is faster", "It can leave a dangling inverse", "It requires CloudKit", "It only works on structs"], correct: 1, "The main store should not contain that graph."),
            Quiz.make("m4g3", "Which object's rule runs when you delete a course?", ["The course's relationship to students", "The student's rule only", "Always cascade", "The view's rule"], correct: 0, "The deleted object's relationship rule is the one that applies.")
        ],
        playground: .relationships
    )

    static let traversal = Lesson.make(
        id: "m4-traversal", moduleID: id, title: "Traversal and fetching related models",
        summary: "Walk the object graph, or fetch the related type with a predicate.",
        concept: "Once the inverse is correct, traversal is property access: book.authors, author.books, category.tasks. Those accesses fault the related objects through the context. You can also fetch the related type with a predicate, which is better when you want a sorted page of tasks in one category and do not want to load the whole collection. Expense.category?.name inside a predicate is that second style. Do not write a recursive CustomStringConvertible that prints both sides of a many-to-many. It can recurse forever. Fetch the type you want to display.",
        whyItExists: "Relationships exist so you do not store duplicated ids and join them by hand.",
        whenToUse: "Traverse when you already have the parent on screen. Fetch when you are building a filtered list from scratch.",
        sample: Samples.make("m4-walk", "Walk and fetch", #"""
        import SwiftData

        let names = book.authors.map(\.name)
        let name = categoryName
        let tasks = try context.fetch(
            FetchDescriptor<StudyTask>(predicate: #Predicate { task in
                task.category?.name == name
            })
        )
        """#, [
            ("book.authors.map", "Traversal uses the relationship. The authors are models, not copied strings."),
            ("task.category?.name == name", "A fetch of the child type, filtered by the parent, without first loading every task.")
        ]),
        expectedBehavior: "The library list shows author names by walking book.authors. The author row walks the other way.",
        experiment: "In the library project, save a book with an author selected and read both sections.",
        experimentHint: "The author row prints that author's book titles.",
        experimentSolution: "Both directions show the link. You appended once, from the book.",
        challenge: "When is category.tasks.count the wrong way to build a paged task list?",
        challengeHint: "The array is the whole relationship.",
        challengeSolution: "When the category has more tasks than the page. Fetch StudyTask with a predicate and a fetchLimit instead of materializing the whole array.",
        bugTitle: "Recursive description",
        bugCode: "extension LibraryBook: CustomStringConvertible {\n    var description: String { authors.description }\n}",
        bugQuestion: "Why can printing a book hang or overflow?",
        bugDiagnosis: "Author's description can print its books, which print their authors. Do not walk both sides in description. Print stored strings.",
        mistakes: ["Force-unwrapping the to-one during traversal.", "Fetching every parent to count children.", "Assuming traversal sees unsaved links from another context."],
        debuggingTips: ["Print names, not the model.", "Use fetchCount on the child predicate.", "Save before you judge the inverse. Unsaved graphs are context-local."],
        quiz: [
            Quiz.make("m4h1", "book.authors is:", ["A fetch of every author in the store", "The authors linked to that book", "A transient cache", "A predicate"], correct: 1, "It is the relationship contents."),
            Quiz.make("m4h2", "A paged child list should:", ["Read the entire to-many array", "Fetch the child type with a predicate and a limit", "Use noAction", "Duplicate the children onto the parent as strings"], correct: 1, "The array is not a page."),
            Quiz.make("m4h3", "A description that prints both sides can:", ["Recurse without a base case", "Migrate the store", "Disable the inverse", "Make the link unique"], correct: 0, "Each side prints the other.")
        ],
        playground: .relationships
    )

    static let circular = Lesson.make(
        id: "m4-circular-mistakes", moduleID: id, title: "Circular references and deletion mistakes",
        summary: "Cycles of models are normal. Cycles of cascade, and cycles of required links, are not.",
        concept: "Student and Course form a cycle and that is fine: each side is an array, the inverse is declared once, and the delete rules nullify. A cycle becomes a bug in three ways. First, both sides are non-optional, so you cannot construct the graph. Second, both sides cascade, so deleting one object deletes the other, which deletes the first, and you lose more than the user asked. Third, your own Swift code recurses over the cycle, as in description, debug dumps, or a function that walks every relationship with no visited set. SwiftData can store the cycle. Your algorithm needs a visited set. Deletion mistakes in this lab are cascade on tags, deny without a way to remove the last employee, and noAction in the main store.",
        whyItExists: "Relationship bugs are quiet until a delete. The curriculum puts them in one place so you can recognize the shape.",
        whenToUse: "Review this lesson before you add a delete button to a graph you did not design.",
        sample: Samples.make("m4-cycle", "A safe many-to-many cycle", #"""
        import SwiftData

        // Safe cycle: arrays, one inverse, nullify on the book side.
        // Unsafe cycle: cascade on both sides, or non-optional properties that require each other.
        book.authors.append(author)
        try context.save()
        """#, [
            ("Safe cycle", "Many-to-many with nullify does not delete the other side."),
            ("book.authors.append(author)", "One mutation. The inverse updates Author.books."),
            ("try context.save()", "The cycle is durable without a special API.")
        ]),
        expectedBehavior: "Linking a book and an author creates a cycle you can traverse. Deleting either side does not delete the other.",
        experiment: "Create a library link, delete the author in the library project, and confirm the book remains.",
        experimentHint: "The author section supports swipe to delete.",
        experimentSolution: "The book remains because the delete rule is nullify, not a cascade cycle.",
        challenge: "Draw Student, Course, and StudentProfile and mark which delete would remove which row.",
        challengeHint: "Profile is cascade from the student. Courses nullify.",
        challengeSolution: "Deleting a student deletes the profile and removes the student from courses. Deleting a course does not delete students. Deleting a profile does not have a cascade back to the student in this schema.",
        bugTitle: "Cascade cycle",
        bugCode: "@Relationship(deleteRule: .cascade, inverse: \\Author.books) var authors: [Author]\n// and on Author:\n@Relationship(deleteRule: .cascade) var books: [LibraryBook]",
        bugQuestion: "Deleting one book can do what?",
        bugDiagnosis: "Cascade to authors, then cascade from those authors to their other books. You can wipe the library. Nullify the shared side.",
        mistakes: ["Required cycles.", "Recursive dumps without a visited set.", "Testing deletes only on empty relationships."],
        debuggingTips: ["Write the delete test with two books sharing one author.", "Count both types after the save.", "If the macro fights the inverse, you declared it twice. That is not a cycle, it is a double declaration."],
        quiz: [
            Quiz.make("m4i1", "A Student-Course cycle is acceptable when:", ["Both sides cascade", "Both sides are arrays, one inverse, nullify", "Both sides are non-optional", "noAction is set"], correct: 1, "The cycle is the data model. The rules must not delete the world."),
            Quiz.make("m4i2", "A required cycle fails because:", ["SQLite cannot store two tables", "Each object needs the other before init can finish", "Predicates cannot compile", "@Query forbids it"], correct: 1, "Construction and materialization need an optional or a default."),
            Quiz.make("m4i3", "Walking a cycle in your own code requires:", ["A visited set or a depth limit", "deny", "A new container", "Autosave off"], correct: 0, "The store can hold the cycle. The algorithm must stop.")
        ],
        playground: .relationships
    )
}
