import Foundation

enum Module8Predicates {
    static let id = "predicates"
    static let module = LearningModule(
        id: id,
        title: "Advanced predicates and queries",
        summary: "Compound filters, optionals, dates, sort, the macro's limits, and shapes that stay legal.",
        level: .advanced,
        order: 8,
        lessons: [simple, compound, optionals, dates, sortFilter, limits, debugging, dynamic]
    )

    static let simple = Lesson.make(
        id: "m8-simple", moduleID: id, title: "Simple predicates",
        summary: "One comparison against a stored property.",
        concept: "A simple predicate is one comparison: amount >= 20, title equals a captured string, isFavorite == true. Build it with #Predicate and pass it as FetchDescriptor.predicate, or nil when there is no filter. The expense minimum-amount shape is the simple case in this lab. Keep the captured number in a local let. Do not read the value from a view property inside the closure if you can copy it first. The closure is not a place for formatting or logging.",
        whyItExists: "You need a baseline that you know translates before you combine conditions.",
        whenToUse: "Toggles and single thresholds. Add complexity only after this version fetches the rows you expect.",
        sample: Samples.make("m8-simple", "Minimum amount", #"""
        import SwiftData

        let amount = amount
        let predicate = #Predicate<Expense> { expense in
            expense.amount >= amount
        }
        """#, [
            ("let amount = amount", "Copy the threshold so the macro captures a simple value."),
            ("expense.amount >= amount", "A stored Double. This is the whole predicate.")
        ]),
        expectedBehavior: "Setting a minimum of 40 in the predicate playground hides the 18 lunch and keeps the larger sample expenses.",
        experiment: "Insert sample expenses, set minimum amount to 40, and run the predicate.",
        experimentHint: "Lunch is 18, dinner is 42, train is 64.",
        experimentSolution: "Dinner and train remain. Lunch does not.",
        challenge: "Write the simple predicate for favorite bookmarks.",
        challengeHint: "isFavorite is Bool.",
        challengeSolution: "#Predicate<Bookmark> { $0.isFavorite == true }. No string and no date.",
        bugTitle: "Formatting inside the predicate",
        bugCode: "#Predicate<Expense> { expense in\n    expense.title == String(format: \"%.2f\", expense.amount)\n}",
        bugQuestion: "Why is this the wrong place for formatting?",
        bugDiagnosis: "The closure must stay translatable. Format in the view after the fetch.",
        mistakes: ["Comparing to a computed display string.", "Using = by habit.", "Forgetting the generic type on #Predicate."],
        debuggingTips: ["Run this shape before the compound one.", "Assert exact titles in a test.", "If it will not compile, you already left the supported subset."],
        quiz: [
            Quiz.make("m8a1", "A simple predicate has:", ["One comparison the store can run", "A SwiftUI view", "A migration", "An actor hop"], correct: 0, "Start here."),
            Quiz.make("m8a2", "nil predicate means:", ["Match nothing", "No extra filter", "Delete all", "Unique only"], correct: 1, "ExpenseQuery.all uses nil."),
            Quiz.make("m8a3", "The capture should be:", ["The view", "A local let of a simple value", "A model from another context", "A closure"], correct: 1, "The macro has to serialize the value.")
        ],
        playground: .predicates
    )

    static let compound = Lesson.make(
        id: "m8-compound", moduleID: id, title: "Compound AND and OR",
        summary: "&& and || inside one closure, or a switch of shapes.",
        concept: "AND is &&. OR is ||. Notes search is OR across title and body. Category plus date is AND. You cannot build an arbitrary tree from user text. You can switch on a shape enum and return a different predicate. That is still compound, and it stays reviewable. Parentheses work. A long closure that the compiler will not type-check should be split, not forced.",
        whyItExists: "Real screens filter on more than one fact.",
        whenToUse: "When every part of the condition is a stored property the macro accepts.",
        sample: Samples.make("m8-or", "Title or body", #"""
        import SwiftData

        let trimmed = trimmed
        descriptor.predicate = #Predicate<Note> { note in
            note.title.localizedStandardContains(trimmed) || note.body.localizedStandardContains(trimmed)
        }
        """#, [
            ("||", "Either field is enough. This is the notes search."),
            ("localizedStandardContains(trimmed)", "Both sides use the same captured string.")
        ]),
        expectedBehavior: "A note matches if the word is in the title or only in the body.",
        experiment: "Create a note whose body contains the word predicate and whose title does not. Search for it.",
        experimentHint: "Open the notes project.",
        experimentSolution: "The OR keeps the note. An AND on title would have hidden it.",
        challenge: "Why is a switch of shapes safer than one closure with five optional captures?",
        challengeHint: "Type-checking and nil.",
        challengeSolution: "Each shape is a small legal predicate. Optional captures and unused branches are how the macro gives up.",
        bugTitle: "AND that excludes everything",
        bugCode: "category == \"Food\" && category == \"Travel\"",
        bugQuestion: "Why is the count zero?",
        bugDiagnosis: "One expense has one category. AND of two different names is impossible. Use OR, or fetch one category.",
        mistakes: ["Mixing up the user's and with the code's &&.", "Duplicating the filter in memory with different operators.", "A compound that includes a transient field."],
        debuggingTips: ["Run each side alone.", "Print titles.", "Keep ExpenseQuery.Shape as the map of combinations."],
        quiz: [
            Quiz.make("m8b1", "OR in #Predicate is:", ["||", "NSCompoundPredicate", "fetchOffset", "a second container"], correct: 0, "Boolean operators inside the closure."),
            Quiz.make("m8b2", "Notes search uses OR so that:", ["Both fields must match", "Either field may match", "The note is deleted", "The search is case sensitive"], correct: 1, "Body-only matches still count."),
            Quiz.make("m8b3", "A shape enum is:", ["A way to pick a legal predicate", "A model subclass", "A delete rule", "Required for @Query"], correct: 0, "It keeps each closure small.")
        ],
        playground: .predicates
    )

    static let optionals = Lesson.make(
        id: "m8-optionals", moduleID: id, title: "Optional property filtering",
        summary: "category?.name compares the related name and rejects nil.",
        concept: "Optional chaining inside a predicate does not match nil. An uncategorized expense will not appear in a Food filter, which is what you want. If the product wants a bucket of uncategorized rows, that is its own shape, and you should test it rather than assume == nil always translates. Do not force-unwrap in the predicate. Do not coalesce to a fake name inside the closure if you can express the match directly. The UI can print Uncategorized after the fetch.",
        whyItExists: "Relationships are optional. Filters must say what nil means.",
        whenToUse: "Any to-one you filter on: expense category, task category, department.",
        sample: Samples.make("m8-opt", "Optional category name", #"""
        import SwiftData

        let name = name
        let predicate = #Predicate<Expense> { expense in
            expense.category?.name == name
        }
        """#, [
            ("expense.category?.name == name", "Nil category fails the comparison."),
            ("let name = name", "The category string is a capture, not a key path.")
        ]),
        expectedBehavior: "Food returns Lunch and, outside the date filter, Dinner. Rows with a nil category stay out.",
        experiment: "Nullify a category by deleting it in a way that keeps expenses, then filter by the old name.",
        experimentHint: "Expense categories use nullify.",
        experimentSolution: "Those expenses no longer match the name, because the link is nil.",
        challenge: "Where should the word Uncategorized be produced?",
        challengeHint: "Not in the schema as a fake category.",
        challengeSolution: "In the view, when category is nil. Do not insert a sentinel category row.",
        bugTitle: "Force unwrap in the predicate",
        bugCode: "expense.category!.name == name",
        bugQuestion: "What happens for a nil category?",
        bugDiagnosis: "The closure is the wrong place to trap. Optional chaining excludes the row. The view handles the label.",
        mistakes: ["A sentinel category named empty.", "Assuming nil matches every string.", "Filtering optional dates with a force unwrap."],
        debuggingTips: ["Fetch the nil rows separately and count them.", "Print category?.name ?? \"nil\".", "Add a test with one linked and one unlinked expense."],
        quiz: [
            Quiz.make("m8c1", "category?.name == \"Food\" matches nil?", ["Yes", "No", "Only in memory", "Only if the name is unique"], correct: 1, "Chaining fails closed."),
            Quiz.make("m8c2", "Uncategorized should be:", ["A stored fake row", "A view fallback", "A transient enum", "A migration"], correct: 1, "Nil is the stored state."),
            Quiz.make("m8c3", "Force-unwrapping in a predicate is:", ["The supported style", "A trap waiting for a null link", "Required for AND", "How sort works"], correct: 1, "Keep the closure total.")
        ],
        playground: .predicates
    )

    static let dates = Lesson.make(
        id: "m8-dates", moduleID: id, title: "Date-based filtering",
        summary: "Compare Date columns with a start and an end you computed outside the predicate.",
        concept: "spentOn >= start && spentOn <= end is the date range. Compute start and end with Calendar before the macro. Do not call Calendar inside the closure. Inclusive versus exclusive ends will off-by-one your results. This lab's May filter uses the first instant of May 1 and the last minute of May 31. A task due date is optional, so a date filter on StudyTask has to decide what nil means. Expenses use a non-optional spentOn so the range is boring and reliable. Store instants, not formatted strings.",
        whyItExists: "Users think in calendar days. The store thinks in instants. The conversion belongs in Swift, outside the predicate.",
        whenToUse: "Any history list: expenses, logs, tasks with real due dates.",
        sample: Samples.make("m8-date", "Range computed outside", #"""
        import Foundation
        import SwiftData

        let start = start
        let end = end
        let predicate = #Predicate<Expense> { expense in
            expense.spentOn >= start && expense.spentOn <= end
        }
        """#, [
            ("let start = start", "The calendar work already happened."),
            ("expense.spentOn >= start", "spentOn is a non-optional Date column.")
        ]),
        expectedBehavior: "May 2026 includes Lunch and Train and excludes June Dinner, before the category AND.",
        experiment: "Turn on the May limit, clear the category by setting minimum amount to 0 and using a category that you then... actually set the category field to a space or run with Food. Easiest: set minimum to 0, category empty is not how the playground works. Use category Food and May, then compare with the known sample.",
        experimentHint: "Dinner is June 2. Lunch and the train are in May.",
        experimentSolution: "With Food and May, only Lunch remains. The train is May but not Food. Dinner is Food but not May.",
        challenge: "Why is an optional due date a harder predicate than spentOn?",
        challengeHint: "Nil.",
        challengeSolution: "You must define whether undated tasks match. spentOn always exists, so the range is a pure comparison.",
        bugTitle: "Calendar inside the predicate",
        bugCode: "#Predicate<Expense> { Calendar.current.isDate($0.spentOn, equalTo: date, toGranularity: .month) }",
        bugQuestion: "Why is this fragile?",
        bugDiagnosis: "The macro may not translate Calendar calls. Compute the month's start and end outside and compare instants.",
        mistakes: ["String dates.", "Local-midnight surprises you did not test.", "An end date that is the first instant of the next day while you used <= and excluded the last day by mistake, or the opposite."],
        debuggingTips: ["Print start and end.", "Store a known Date in the test, not .now.", "Assert which titles match the month."],
        quiz: [
            Quiz.make("m8d1", "Date bounds should be computed:", ["Inside the predicate", "Outside, then captured", "In the view body during render only", "By SQLite date functions you type as strings"], correct: 1, "The closure stays a comparison."),
            Quiz.make("m8d2", "spentOn is easier than dueDate because:", ["It is a String", "It is non-optional", "It is transient", "It is unique"], correct: 1, "Every expense has an instant."),
            Quiz.make("m8d3", "The May sample excludes Dinner because:", ["Dinner is not Food", "Dinner is in June", "Dinner is under the minimum", "Dinner is transient"], correct: 1, "June 2 is outside the range. It is also Food, which is why the AND matters.")
        ],
        playground: .predicates
    )

    static let sortFilter = Lesson.make(
        id: "m8-sort-and-filter", moduleID: id, title: "Sorting and combining filters",
        summary: "The predicate chooses the set. The sort orders that set. The total uses the result.",
        concept: "ExpenseQuery.fetch sets a predicate and then sort descriptors. Sort does not change which rows match. The total in the expense tracker reduces the fetched array, so it is the filtered total, not the table total. If you sort by amount and also by date, the order of the descriptors is the tiebreak order. Changing the toggle swaps which key is primary. Do the limit after you know the sort, or the page is an accident.",
        whyItExists: "Screens mix a filter, an order, and an aggregate. They are three steps.",
        whenToUse: "Any report-like list. Expenses are the reference.",
        sample: Samples.make("m8-sort", "Filter, then sort", #"""
        import SwiftData

        var descriptor = FetchDescriptor<Expense>()
        descriptor.predicate = ExpenseQuery.predicate(for: shape)
        descriptor.sortBy = [
            SortDescriptor(\Expense.amount, order: .reverse),
            SortDescriptor(\Expense.spentOn, order: .reverse)
        ]
        let rows = try context.fetch(descriptor)
        let total = rows.reduce(0) { $0 + $1.amount }
        """#, [
            ("descriptor.predicate", "Membership."),
            ("descriptor.sortBy", "Order of that membership. Amount first, then date."),
            ("rows.reduce", "The total is the filtered set, computed in memory after a bounded fetch.")
        ]),
        expectedBehavior: "Sort by amount puts the train above lunch. The total changes when the filter changes.",
        experiment: "Load sample expenses, apply no minimum, and compare the total with the May plus Food total.",
        experimentHint: "All three samples sum to 124. Food in May is 18.",
        experimentSolution: "The total follows the predicate, not the unfiltered table.",
        challenge: "Why is the total not a stored property on ExpenseCategory?",
        challengeHint: "It depends on the current filter.",
        challengeSolution: "A stored total would be wrong as soon as the date range changes. Compute it from the fetched rows.",
        bugTitle: "Sorting before you filter in memory",
        bugCode: "let sorted = all.sorted { $0.amount > $1.amount }\nlet page = Array(sorted.prefix(2)).filter { $0.category?.name == name }",
        bugQuestion: "Why can the page miss obvious matches?",
        bugDiagnosis: "You took two rows from the whole table, then filtered. Filter first, in the store, then sort and limit.",
        mistakes: ["A stored total.", "Different sorts in the list and the export.", "Reducing a different array than the one on screen."],
        debuggingTips: ["Print count and total together.", "Assert the order of titles, not only the set.", "Keep predicate and sort in one function."],
        quiz: [
            Quiz.make("m8e1", "Sort changes:", ["Which rows match", "The order of the matched rows", "The schema", "The delete rule"], correct: 1, "The predicate owns membership."),
            Quiz.make("m8e2", "The expense total is:", ["Every expense ever", "The sum of the fetched filter", "A column on the category", "A CloudKit aggregate"], correct: 1, "It reduces rows."),
            Quiz.make("m8e3", "Limit belongs:", ["Before you know the sort", "On the sorted, filtered fetch", "In the view after loading everything", "On the model init"], correct: 1, "The page is defined by both.")
        ],
        playground: .predicates
    )

    static let limits = Lesson.make(
        id: "m8-limitations", moduleID: id, title: "Predicate limitations",
        summary: "The closure is not Swift. It is a language the store can translate.",
        concept: "You cannot call arbitrary functions, use async, capture classes, read computed or transient properties, or depend on Swift control flow the translator does not support. Relationship traversal of one optional to-one is used in this lab. Deep or clever traversal is where macros fail. Collections of models are relationships, and a predicate that tries to express every tag on a bookmark is exactly the kind of thing this lab filters in memory for a small table. That is a limitation, not a suggestion to load a million bookmarks. If the condition is not translatable, change the schema so it is: a stored Bool, a promoted column, a simpler relationship.",
        whyItExists: "The store cannot run your app. It can run a constrained expression.",
        whenToUse: "When a predicate will not compile, stop and redesign the condition. Do not drop to a string.",
        sample: Samples.make("m8-limit", "What not to call", #"""
        import SwiftData

        // Legal: comparisons, localizedStandardContains, &&, ||, optional to-one.
        // Not legal: arbitrary functions, computed properties, async, captured objects.
        let term = term
        let predicate = #Predicate<Book> { book in
            book.title.localizedStandardContains(term)
        }
        """#, [
            ("Not legal", "If you need those, the schema or the in-memory step has to change."),
            ("book.title.localizedStandardContains(term)", "A supported string operation on a stored property.")
        ]),
        expectedBehavior: "The bookmarks tag filter is in memory and the lesson says why. The expense filters stay in the store.",
        experiment: "Read BookmarksView.visible and ExpenseQuery.predicate. One is Swift filter, one is #Predicate.",
        experimentHint: "Tags are the awkward traversal.",
        experimentSolution: "Expenses are store predicates. Bookmark tag matching is in-memory because the lab keeps that condition out of the macro.",
        challenge: "What schema change would make favorite-and-tag a store predicate without an in-memory scan?",
        challengeHint: "You already have isFavorite as a column.",
        challengeSolution: "Fetch bookmarks with isFavorite, or fetch by a tag relationship if you can express tag name equality in a supported way, and keep the result paged. Do not add a computed property and predicate on it.",
        bugTitle: "A helper that feels innocent",
        bugCode: "func normalized(_ title: String) -> String { title.lowercased() }\n#Predicate<Book> { normalized($0.title) == term }",
        bugQuestion: "Why does the helper break translation?",
        bugDiagnosis: "The macro cannot follow normalized. Inline a supported comparison such as localizedStandardContains.",
        mistakes: ["String-format predicates.", "In-memory filtering of an unbounded fetch as the permanent design.", "Blaming SQLite for a compile error."],
        debuggingTips: ["Reduce the closure to one comparison.", "Move calendar and string work outside.", "Change the model if the question cannot be asked of a column."],
        quiz: [
            Quiz.make("m8f1", "Arbitrary Swift functions in a predicate are:", ["Encouraged", "Not translatable", "Required", "How migration works"], correct: 1, "The closure is restricted."),
            Quiz.make("m8f2", "A computed property in a predicate:", ["Is the preferred key", "Is not a column", "Is faster", "Is unique"], correct: 1, "Store the fact or filter after a bounded fetch."),
            Quiz.make("m8f3", "The right response to a macro failure is:", ["A format string", "A simpler legal predicate or a schema change", "noAction", "A subclass"], correct: 1, "Stay inside the supported subset.")
        ],
        playground: .predicates
    )

    static let debugging = Lesson.make(
        id: "m8-debugging", moduleID: id, title: "Debugging predicates that fail to compile",
        summary: "Shrink the closure until the compiler accepts it, then add one piece back.",
        concept: "Predicate compile errors are usually the type checker timing out or a capture it cannot serialize. Split the function. Copy every capture to a local let of a simple type. Remove optional chaining and put it back. Remove AND clauses and put them back. Do not paste the error into a string predicate. If a relationship comparison will not compile, fetch the related ids another way or denormalize a column. The expense shapes are already split so each closure stays small. That split is a debugging technique you can keep in production.",
        whyItExists: "The macro's diagnostics are worse than ordinary Swift errors. A method beats staring at them.",
        whenToUse: "The first time a predicate closure goes red. Also when it is slow to type-check.",
        sample: Samples.make("m8-debug", "One shape per function arm", #"""
        import SwiftData

        switch shape {
        case .category(let name):
            let name = name
            return #Predicate<Expense> { $0.category?.name == name }
        case .minimumAmount(let amount):
            let amount = amount
            return #Predicate<Expense> { $0.amount >= amount }
        default:
            return nil
        }
        """#, [
            ("let name = name", "A fresh simple capture inside the arm that builds the predicate."),
            ("return #Predicate<Expense>", "Each arm is type-checked separately.")
        ]),
        expectedBehavior: "The playground can switch shapes without one giant closure.",
        experiment: "Change the playground from a category filter to a minimum amount and confirm both compile by running both.",
        experimentHint: "Minimum amount greater than 0 selects that shape.",
        experimentSolution: "Both arms run. Neither needed a format string.",
        challenge: "What is the first line you delete when the compiler times out?",
        challengeHint: "The last condition you added.",
        challengeSolution: "The newest clause, or the optional relationship traversal. Get a one-comparison predicate compiling, then restore clauses one at a time.",
        bugTitle: "Silencing the error with a string",
        bugCode: "let format = \"amount >= \\(amount)\"",
        bugQuestion: "What did you lose?",
        bugDiagnosis: "The compiler no longer checks the key path, and SwiftData will not take that string anyway. You also risk building a query from raw text.",
        mistakes: ["Adding more Swift to help the macro.", "Capturing self.", "A predicate stored in a property that captured an old value."],
        debuggingTips: ["One arm, one comparison.", "Local lets immediately above the macro.", "A unit test with two rows so a compiling predicate can still be wrong."],
        quiz: [
            Quiz.make("m8g1", "A type-check timeout means:", ["The store is locked", "The closure is too complex or illegal", "Autosave is on", "You need Core Data"], correct: 1, "Shrink it."),
            Quiz.make("m8g2", "Captures should be:", ["Views", "Local simple values", "Model contexts", "Format strings"], correct: 1, "The macro serializes them."),
            Quiz.make("m8g3", "Splitting shapes is:", ["Only a debug hack you must delete", "A production pattern", "A migration", "Illegal"], correct: 1, "ExpenseQuery keeps the split.")
        ],
        playground: .predicates
    )

    static let dynamic = Lesson.make(
        id: "m8-dynamic-strategies", moduleID: id, title: "Dynamic filtering strategies",
        summary: "Rebuild a known shape. Do not evaluate Swift the user typed.",
        concept: "Dynamic means the inputs change, not that the language changes. ExpenseQuery.Shape is the strategy: all, category, date range, both, or a minimum amount. The view computes the shape from toggles and text. The query type turns the shape into a predicate. Bookmarks add an in-memory tag and favorite pass for conditions the lesson keeps out of the macro, and the code says so. Neither path compiles a string as Swift. An iOS app cannot JIT arbitrary source. The challenge notes field is a notebook, not an interpreter.",
        whyItExists: "Search boxes feel like they should accept any condition. The store accepts a fixed set.",
        whenToUse: "Every filter UI in the projects. Copy the shape enum before you invent a query language.",
        sample: Samples.make("m8-dyn", "The view picks a shape", #"""
        import Foundation

        let shape: ExpenseQuery.Shape
        if minimumAmount > 0 {
            shape = .minimumAmount(minimumAmount)
        } else if useDate && !category.isEmpty {
            shape = .categoryAndDate(name: category, start: start, end: end)
        } else {
            shape = .all
        }
        """#, [
            ("ExpenseQuery.Shape", "A closed set of filters the macro can implement."),
            ("shape = .categoryAndDate", "The view does not assemble a predicate string.")
        ]),
        expectedBehavior: "Changing the toggles changes the result count. The status says the predicate was rebuilt for the shape.",
        experiment: "Run all three interesting shapes: Food plus May, minimum 40, and the sample load with a wide filter.",
        experimentHint: "Minimum amount greater than zero wins over the date toggle in the playground.",
        experimentSolution: "Each run uses a different arm and a different count. No arm evaluates typed Swift.",
        challenge: "What would you tell a teammate who wants a text field where the user types a predicate?",
        challengeHint: "The challenge notes box is not a compiler.",
        challengeSolution: "Do not ship it. Offer structured controls. The lab's notes field stores text and never runs it.",
        bugTitle: "Evaluating the search field as code",
        bugCode: "let predicate = searchFieldText // user typed Swift\ncontext.fetch(predicate)",
        bugQuestion: "Why is this not a feature?",
        bugDiagnosis: "Fetch does not compile Swift. Even if you could, running user source inside the app is not a query API. Map the field onto a shape.",
        mistakes: ["A single predicate property that ignores later toggles.", "In-memory filtering that you forget to mention.", "Treating the challenge TextEditor as an interpreter."],
        debuggingTips: ["Log the shape, not only the text.", "Test each case in ExpenseQueryTests style assertions.", "Keep the in-memory bookmark path obviously separate."],
        quiz: [
            Quiz.make("m8h1", "Dynamic filtering in this app means:", ["Running typed Swift", "Choosing a new legal shape when inputs change", "Editing the schema per keystroke", "Disabling the store"], correct: 1, "The inputs change. The language does not."),
            Quiz.make("m8h2", "The challenge notes field:", ["Compiles Swift", "Stores text", "Migrates the store", "Is a predicate"], correct: 1, "The lab does not pretend to JIT."),
            Quiz.make("m8h3", "Bookmark tag filtering is in memory because:", ["Tags cannot be stored", "That condition is kept out of the macro and the table is small", "Predicates cannot use Bool", "The container is read-only"], correct: 1, "Say so, and do not scale it blindly.")
        ],
        playground: .predicates
    )
}
