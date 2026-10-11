import Foundation

enum Module12Projects {
    static let id = "projects"
    static let module = LearningModule(
        id: id,
        title: "Real-world projects",
        summary: "Five small apps that reuse the earlier modules instead of introducing a new stack.",
        level: .advanced,
        order: 12,
        lessons: [notes, tasks, expenses, bookmarks, library]
    )

    static let notes = Lesson.make(
        id: "m12-notes", moduleID: id, title: "Notes",
        summary: "Create, edit, search, and delete with an explicit save.",
        concept: "The notes project is the MVVM-C reference. NotesRepository fetches with a predicate and sorts pinned notes first. NotesListViewModel reloads after create and delete. NoteEditorViewModel holds a draft so Cancel does not write. NotesCoordinator pushes a persistent identifier. Search uses OR across title and body. Empty state is a real screen, not a spinner. Nothing in the flow needs a network.",
        whyItExists: "A note is the smallest record that still needs a draft, a search, and a test.",
        whenToUse: "As the template when a feature grows a cancel button or a second caller for the same query.",
        sample: Samples.make("m12-notes", "Create through the repository", #"""
        import SwiftData

        func create(title: String, body: String, context: ModelContext) throws {
            context.insert(Note(title: title, body: body))
            try context.save()
        }
        """#, [
            ("context.insert(Note", "A new row, not a draft. The draft lived in the composer or the editor."),
            ("try context.save()", "The command boundary.")
        ]),
        expectedBehavior: "A saved note survives relaunch. A dismissed editor does not change the stored text. Search finds a word that is only in the body.",
        experiment: "Create a note, relaunch, search for a body word, delete the note, and confirm it stays gone.",
        experimentHint: "Save in the composer. Save in the editor. Swipe to delete.",
        experimentSolution: "Those are insert, update, a predicate, and delete, all on the local store.",
        challenge: "Add a sentence to your notes about which type you would unit test first.",
        challengeHint: "The view model.",
        challengeSolution: "NotesListViewModel with an in-memory repository. The test is already in the suite. The view is not the first test.",
        bugTitle: "Binding the editor to the model",
        bugCode: "TextField(\"Title\", text: $note.title)",
        bugQuestion: "What happened to Cancel?",
        bugDiagnosis: "The field writes the tracked object immediately. The notes editor keeps a copy until Save.",
        mistakes: ["A spinner for zero notes.", "Search that only checks the title.", "Saving in the model initializer."],
        debuggingTips: ["Breakpoint repository.update.", "Confirm the test container is empty of app notes.", "If search misses a body word, the predicate lost the OR."],
        quiz: [
            Quiz.make("m12a1", "The editor writes the model:", ["On every keystroke", "When Save runs", "When the view appears", "During migration"], correct: 1, "The draft is the point."),
            Quiz.make("m12a2", "Search matches:", ["Title only", "Title or body", "Tags", "The store URL"], correct: 1, "The predicate uses OR."),
            Quiz.make("m12a3", "The route payload is:", ["The Note", "A persistent identifier", "The draft string", "The tab"], correct: 1, "The destination resolves it.")
        ],
        playground: .notes
    )

    static let tasks = Lesson.make(
        id: "m12-tasks", moduleID: id, title: "Task manager",
        summary: "Priority, due date, category, and a cascade delete.",
        concept: "A task stores a title, details, a TaskPriority enum, an optional due date, and an optional category. The category's delete rule is cascade, so deleting School deletes its tasks. The screen uses @Query rather than a view model. That is intentional. The unique category name is looked up before a new one is inserted, so two School rows do not throw. Optional due dates sort with the query. Undated tasks are a product decision, not a crash.",
        whyItExists: "Relationships and enums need a screen where the delete rule is visible.",
        whenToUse: "As the pattern for parent-owned children. Not as the pattern for shared tags.",
        sample: Samples.make("m12-tasks", "Owned tasks", #"""
        import SwiftData

        @Relationship(deleteRule: .cascade, inverse: \StudyTask.category)
        var tasks: [StudyTask] = []
        """#, [
            ("deleteRule: .cascade", "Deleting the category deletes these tasks."),
            ("inverse: \\StudyTask.category", "The task's to-one is the other side.")
        ]),
        expectedBehavior: "A task saved with a due date and a priority shows those after relaunch. Deleting its category removes it.",
        experiment: "Add a dated high-priority task in School, relaunch, then delete the School category.",
        experimentHint: "Swipe the category. The confirmation is the destructive swipe.",
        experimentSolution: "The task is gone because of cascade, not because the list filtered it.",
        challenge: "Why is priority an enum and category a model?",
        challengeHint: "Who creates the values?",
        challengeSolution: "The app owns the three priorities. The user owns category names, and categories have children.",
        bugTitle: "Nullify on an owned child",
        bugCode: "@Relationship(deleteRule: .nullify, inverse: \\StudyTask.category)\nvar tasks: [StudyTask]",
        bugQuestion: "What is left behind?",
        bugDiagnosis: "Tasks with a nil category. If the product says the category owns them, that is the wrong rule. This app uses cascade.",
        mistakes: ["A required due date.", "Duplicate categories from skipping the lookup.", "A view model that only forwards insert."],
        debuggingTips: ["Count tasks before and after the category delete.", "Print priority.rawValue if the label looks wrong.", "Remember unique names throw if the lookup fails."],
        quiz: [
            Quiz.make("m12b1", "Deleting a category:", ["Nullifies tasks", "Cascades to tasks", "Is denied", "Deletes the store"], correct: 1, "The rule is cascade."),
            Quiz.make("m12b2", "Due date is:", ["Required", "Optional", "A string", "Transient"], correct: 1, "Undated tasks are allowed."),
            Quiz.make("m12b3", "The screen's architecture is:", ["Full MVVM-C", "@Query in the view", "A ModelActor per task", "CloudKit"], correct: 1, "Chosen to stay small.")
        ],
        playground: .tasks
    )

    static let expenses = Lesson.make(
        id: "m12-expenses", moduleID: id, title: "Expense tracker",
        summary: "Categories, date ranges, sort, and a filtered total.",
        concept: "Expenses are the predicate project. Amount is a Double so the comparisons stay simple. Category is an optional relationship with nullify, so deleting a category keeps the money and clears the link. The filter shape is all, category, date range, or both. Sort is amount or date. The total reduces the filtered rows. Sample data is inserted only when the table is empty, so the button does not duplicate rows. Validation of the amount happens before insert.",
        whyItExists: "Reports are filters plus an aggregate. The model should not store the aggregate.",
        whenToUse: "As the pattern for any dated, categorized number.",
        sample: Samples.make("m12-exp", "Filtered total", #"""
        import SwiftData

        let rows = try ExpenseQuery.fetch(shape, sortByAmount: true, in: context)
        let total = rows.reduce(0) { $0 + $1.amount }
        """#, [
            ("ExpenseQuery.fetch", "Predicate and sort live in one place."),
            ("rows.reduce", "The total matches the list, not the unfiltered table.")
        ]),
        expectedBehavior: "Sample data plus Food plus a May range totals the May food expense only. Sort by amount changes order without changing the total.",
        experiment: "Load samples, filter Food in May, and read the total. Then clear the filter and read it again.",
        experimentHint: "Lunch is 18 in May. The three samples sum higher.",
        experimentSolution: "The total follows the shape. Sort does not change it.",
        challenge: "Why does deleting a category not delete the expenses?",
        challengeHint: "nullify.",
        challengeSolution: "The history should outlive the label. The relationship rule is nullify, unlike tasks.",
        bugTitle: "A stored total",
        bugCode: "category.cachedTotal += amount",
        bugQuestion: "When does cachedTotal lie?",
        bugDiagnosis: "As soon as a date filter, an edit, or a delete happens and the cache is not the source of truth. Sum the fetch.",
        mistakes: ["String amounts.", "Including unfiltered rows in the total.", "A sentinel category."],
        debuggingTips: ["Print the shape and the titles.", "Assert the May food total in a test.", "Check nullify by deleting a category and fetching expenses."],
        quiz: [
            Quiz.make("m12c1", "The total is:", ["Stored on the category", "Summed from the filtered fetch", "Always all expenses", "A CloudKit aggregate"], correct: 1, "It matches the rows on screen."),
            Quiz.make("m12c2", "Deleting a category:", ["Deletes expenses", "Nullifies the link", "Is denied", "Migrates the file"], correct: 1, "History remains."),
            Quiz.make("m12c3", "Amount is a Double because:", ["Decimal cannot be stored", "The predicates stay simple", "Double is unique", "The view requires it"], correct: 1, "Decimal-in-predicates is the awkward part.")
        ],
        playground: .expenses
    )

    static let bookmarks = Lesson.make(
        id: "m12-bookmarks", moduleID: id, title: "Bookmarks manager",
        summary: "Shared tags, search, and favorites.",
        concept: "A bookmark stores a title, a URL string, a favorite flag, and a to-many link to Tag. Tags are unique by name and shared. The form validates that the string can become a URL, then stores the string so a later edit can still show exactly what was saved. Favorites are a Bool column. Tag filtering is an in-memory pass over a small table, documented as a predicate limitation, while title search can be a store predicate. Deleting a tag nullifies. Deleting a bookmark does not delete the tag.",
        whyItExists: "Many-to-many plus a search box is the bookmarks product.",
        whenToUse: "As the pattern for shared labels. Not for owned children.",
        sample: Samples.make("m12-bm", "Reuse a tag", #"""
        import SwiftData

        let tag = try existingTag(named: name, in: context)
        let bookmark = Bookmark(title: title, urlString: urlString)
        bookmark.tags.append(tag)
        context.insert(bookmark)
        try context.save()
        """#, [
            ("existingTag", "Unique name. A second bookmark does not insert a second tag."),
            ("bookmark.tags.append(tag)", "One append. The inverse updates the tag's bookmarks.")
        ]),
        expectedBehavior: "Two bookmarks with the tag swift share one tag row. Favorite is independent of tags. An invalid URL string is rejected before insert.",
        experiment: "Save two bookmarks with the same tag, star one, filter favorites, then delete the tag and confirm the bookmarks remain.",
        experimentHint: "The tag section is below the list.",
        experimentSolution: "Nullify removed the link. The bookmark rows stayed. The star is a column.",
        challenge: "Why store urlString instead of URL?",
        challengeHint: "The form's invalid state.",
        challengeSolution: "The validator needs to reject text that is not a URL. The row stores the accepted text. A URL property cannot represent the rejected draft, and the draft never becomes a row.",
        bugTitle: "Cascade on tags",
        bugCode: "@Relationship(deleteRule: .cascade, inverse: \\Bookmark.tags)\nvar bookmarks: [Bookmark]",
        bugQuestion: "Deleting the swift tag would do what?",
        bugDiagnosis: "Delete every bookmark that used it. The app nullifies instead.",
        mistakes: ["A new Tag on every save.", "Filtering tags with a full-table scan once the data is large and not saying so.", "Storing the favorite only in @State."],
        debuggingTips: ["Count tags after the second bookmark.", "Toggle favorite and relaunch.", "After deleting a tag, fetch bookmarks and expect a lower tags.count, not a lower bookmark count."],
        quiz: [
            Quiz.make("m12d1", "Two bookmarks with one tag name create:", ["Two tags", "One tag", "No link", "A cascade"], correct: 1, "The name is unique and reused."),
            Quiz.make("m12d2", "Deleting a tag:", ["Deletes bookmarks", "Nullifies the link", "Deletes the store", "Is denied always"], correct: 1, "Bookmarks outlive a label."),
            Quiz.make("m12d3", "The URL check happens:", ["In the schema by crashing", "In the form before insert", "In CloudKit", "Never"], correct: 1, "Invalid text never becomes a row.")
        ],
        playground: .bookmarks
    )

    static let library = Lesson.make(
        id: "m12-library", moduleID: id, title: "Mini library",
        summary: "Books and authors, many-to-many, traversed both ways.",
        concept: "LibraryBook and Author are the many-to-many you can see. You select authors, append them once from the book, and both sections update. Delete rules nullify, so deleting an author leaves the books and deleting a book leaves the authors. There is no cascade cycle. The screen is a direct @Query view, like tasks, because the lesson is the graph rather than a new architecture. This is a different type from the fundamentals Book, so the library cannot wipe the query lesson's rows.",
        whyItExists: "You need a graph you can walk in both directions without a join table, until the link itself needs fields.",
        whenToUse: "Shared people and shared works. If you later store the role, an illustrator versus an author, introduce a join model.",
        sample: Samples.make("m12-lib", "Append once", #"""
        import SwiftData

        let book = LibraryBook(title: title, publishedYear: year)
        for author in chosen {
            book.authors.append(author)
        }
        context.insert(book)
        try context.save()
        """#, [
            ("book.authors.append(author)", "The inverse fills author.books."),
            ("context.insert(book)", "Authors that already exist stay inserted. The new book joins the context.")
        ]),
        expectedBehavior: "A book lists its authors. An author lists that book. Deleting either side leaves the other.",
        experiment: "Add two authors, save a book linked to both, delete one author, and read the book row.",
        experimentHint: "The author list is a toggle before save.",
        experimentSolution: "The book remains and shows the surviving author. Nullify removed only the deleted link.",
        challenge: "What feature would force a join model?",
        challengeHint: "Data on the link.",
        challengeSolution: "A role, a billing order, or the year that person joined that book. The current arrays cannot store that.",
        bugTitle: "Appending on both sides",
        bugCode: "book.authors.append(author)\nauthor.books.append(book)",
        bugQuestion: "Why is the second line a bug?",
        bugDiagnosis: "The inverse already updates the other array. The manual append can duplicate the link.",
        mistakes: ["Cascade on authors.", "Using the fundamentals Book type and mixing two products.", "A required author that blocks a draft book."],
        debuggingTips: ["Print both directions after save.", "Delete one author shared by two books and expect both books to remain.", "Keep LibraryBook and Book as different models."],
        quiz: [
            Quiz.make("m12e1", "The relationship is:", ["One-to-one", "Many-to-many with nullify", "Cascade both ways", "noAction"], correct: 1, "Shared authors and shared books."),
            Quiz.make("m12e2", "You append:", ["On both sides", "On one side", "Never", "Only in a predicate"], correct: 1, "The inverse does the rest."),
            Quiz.make("m12e3", "LibraryBook is separate from Book so that:", ["The compiler requires two names", "Library deletes do not wipe the fundamentals examples", "CloudKit requires it", "Enums require it"], correct: 1, "Different entities, different reset behavior.")
        ],
        playground: .library
    )
}
