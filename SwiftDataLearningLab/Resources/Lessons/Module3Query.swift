import Foundation

enum Module3Query {
    static let id = "query"
    static let module = LearningModule(
        id: id,
        title: "Fetching and querying",
        summary: "@Query, FetchDescriptor, predicates, sort, limits, and which of those belong in a view.",
        level: .beginner,
        order: 3,
        lessons: [query, descriptor, equivalents, predicate, sort, compound, pagination, dynamic, viewVsCode]
    )

    static let query = Lesson.make(
        id: "m3-query", moduleID: id, title: "@Query",
        summary: "A view property wrapper that fetches and redraws.",
        concept: "@Query is a DynamicProperty. It reads the environment's model context, fetches the model you name, and invalidates the view when those objects change. It cannot live in a view model or a ModelActor. The initializer can take a predicate, sort key paths, and an order. For a predicate that changes with search text, build a child view whose init assigns _books = Query(filter:sort:). Recreating that child when the filter changes is the iOS 17 approach. @Query has no loading flag for a local store. The data is there or the fetch failed earlier when the container opened.",
        whyItExists: "Hand-fetching in body is easy to get wrong and easy to over-call. @Query is the supported observation path.",
        whenToUse: "Lists and screens that display a model directly. Skip it when the screen must be unit-tested without SwiftUI, or when the work runs off the main actor.",
        sample: Samples.make("m3-query", "@Query sorted by title", #"""
        import SwiftData
        import SwiftUI

        struct BookList: View {
            @Query(sort: \Book.title, order: .forward) private var books: [Book]

            var body: some View {
                List(books) { book in
                    Text(book.title)
                }
            }
        }
        """#, [
            ("@Query(sort: \\Book.title", "The wrapper fetches Book and sorts in the store."),
            ("private var books: [Book]", "Reading books in body subscribes the view to those models."),
            ("List(books)", "Inserts, updates, and deletes in the view context refresh this list.")
        ]),
        expectedBehavior: "The SwiftUI lab list is an @Query of LabRecord. Insert and delete change it without a manual reload.",
        experiment: "In the SwiftUI playground, insert a title and delete it. Watch the list.",
        experimentHint: "The list is the query. The text field is not.",
        experimentSolution: "The row appears and disappears because the view context that @Query uses is the one insert and delete call.",
        challenge: "Why is @Query a poor place to run an import of 10,000 rows?",
        challengeHint: "It is a view, on the main actor, tied to rendering.",
        challengeSolution: "Import with a ModelActor and its own context. Let the view's @Query refresh after the actor saves.",
        bugTitle: "@Query stored on a class",
        bugCode: "@Observable\nfinal class BooksModel {\n    @Query var books: [Book]\n}",
        bugQuestion: "Why will this not track the store?",
        bugDiagnosis: "@Query only works as a view's dynamic property. A view model should call context.fetch or own a repository.",
        mistakes: ["Putting @Query in a repository.", "Assuming it shows another container's memory-only rows.", "Expecting a loading spinner for local SQLite."],
        debuggingTips: ["If the list is empty, confirm .modelContainer is above the view.", "Confirm you inserted into the same container.", "Use the FetchDescriptor button when you need to see the non-view path side by side."],
        quiz: [
            Quiz.make("m3a1", "@Query belongs in:", ["Any class", "A SwiftUI view", "A SchemaMigrationPlan", "An XCTestCase only"], correct: 1, "It is a DynamicProperty."),
            Quiz.make("m3a2", "Changing the search string's predicate on iOS 17 is done by:", ["Mutating the property wrapper from a button", "Rebuilding a child view that inits Query with the new filter", "Editing the SQLite file", "Calling rollback"], correct: 1, "The wrapper is configured in the view's init."),
            Quiz.make("m3a3", "A local @Query list's empty state means:", ["The network timed out", "No rows match, or the container has none", "CloudKit is required", "The macro failed"], correct: 1, "There is no network round trip.")
        ],
        playground: .swiftUI
    )

    static let descriptor = Lesson.make(
        id: "m3-fetch-descriptor", moduleID: id, title: "FetchDescriptor",
        summary: "The value that describes a fetch outside SwiftUI.",
        concept: "FetchDescriptor is a struct: model type, optional predicate, sort descriptors, fetchLimit, and fetchOffset. You pass it to context.fetch or context.fetchCount. It is the type repositories and tests should build. It does not observe. If you want the screen to refresh, assign the result to an @Observable view model property or use @Query. The query playground's Run FetchDescriptor button is this path. It copies results into a small snapshot so the list is not holding models from a surprise context.",
        whyItExists: "Non-view code needs a fetch that does not depend on SwiftUI property wrappers.",
        whenToUse: "View models, ModelActor methods, migrations, and tests.",
        sample: Samples.make("m3-desc", "Descriptor with predicate, sort, and limit", #"""
        import SwiftData

        var descriptor = FetchDescriptor<Book>(
            predicate: QueryLab.predicate(term: term, minimumYear: minimumYear),
            sortBy: [SortDescriptor(\Book.title, order: .forward)]
        )
        descriptor.fetchLimit = 2
        descriptor.fetchOffset = 0
        let books = try context.fetch(descriptor)
        """#, [
            ("FetchDescriptor<Book>", "Value type. Building it does not hit the store."),
            ("descriptor.fetchLimit = 2", "Applied by the fetch, not by dropping array elements after a full load."),
            ("context.fetch(descriptor)", "Runs the fetch in this context and returns tracked instances.")
        ]),
        expectedBehavior: "Changing limit and offset in the query playground changes how many titles come back and which page you see.",
        experiment: "Insert sample books. Set limit 2 and offset 0, fetch, then set offset 2 and fetch again.",
        experimentHint: "The stepper labels are Limit and Offset.",
        experimentSolution: "The second page is the next titles in the same sort, not a new sort.",
        challenge: "When would you call fetchCount instead of fetch?",
        challengeHint: "You need a number, not the objects.",
        challengeSolution: "Badges, pagination totals, and assertions. fetchCount does not materialize every model.",
        bugTitle: "Reusing a descriptor and expecting it to observe",
        bugCode: "let books = try context.fetch(descriptor)\n// later, after inserts, the local books array is still shown",
        bugQuestion: "Why is the array stale?",
        bugDiagnosis: "fetch returns a snapshot array of instances. It does not subscribe. Fetch again, or use @Query.",
        mistakes: ["Building the descriptor in body on every keystroke without need.", "Forgetting that fetchLimit nil means no cap.", "Sorting in two places and disagreeing with yourself."],
        debuggingTips: ["Print fetchCount for the same predicate.", "Set fetchLimit to 1 while debugging a predicate.", "Keep the descriptor in one function so the captures are obvious."],
        quiz: [
            Quiz.make("m3b1", "FetchDescriptor is:", ["A view", "A description of a fetch", "A store file", "A migration stage"], correct: 1, "The context executes it."),
            Quiz.make("m3b2", "Who should call context.fetch?", ["Only SwiftUI", "View models, actors, tests, and views that are not using @Query", "Only the App init", "The @Model macro"], correct: 1, "Anywhere you already have a context and do not need the property wrapper."),
            Quiz.make("m3b3", "fetch returns instances that are:", ["Untracked copies", "Tracked by the context that fetched them", "Always transient", "Codable structs"], correct: 1, "They belong to that context.")
        ],
        playground: .query
    )

    static let equivalents = Lesson.make(
        id: "m3-fetch-request-equivalents", moduleID: id, title: "Fetch request equivalents",
        summary: "The Core Data names, and the SwiftData types this app actually calls.",
        concept: "If you already know Core Data: @FetchRequest corresponds to @Query, NSFetchRequest corresponds to FetchDescriptor, NSPredicate corresponds to #Predicate, and NSSortDescriptor corresponds to SortDescriptor. NSPersistentContainer corresponds to ModelContainer, and NSManagedObjectContext corresponds to ModelContext. This app does not import Core Data and does not construct those older types. The mapping is here so the vocabulary is familiar, not so you can mix the stacks. Mixing them in one store is how schema and context bugs become undebuggable.",
        whyItExists: "Apple's older sample code and many bugs you will search for still use the Core Data names.",
        whenToUse: "Use the mapping when reading older code. Write SwiftData types in this target.",
        sample: Samples.make("m3-map", "The SwiftData side of the mapping", #"""
        import SwiftData

        // @FetchRequest        -> @Query
        // NSFetchRequest       -> FetchDescriptor
        // NSPredicate          -> #Predicate
        // NSSortDescriptor     -> SortDescriptor
        // NSManagedObjectContext -> ModelContext
        let descriptor = FetchDescriptor<Book>(sortBy: [SortDescriptor(\.title)])
        let books = try modelContext.fetch(descriptor)
        """#, [
            ("@FetchRequest        -> @Query", "Both are view-layer fetches. Only @Query is used here."),
            ("FetchDescriptor<Book>", "This is the request value. There is no NSFetchRequest in the target."),
            ("modelContext.fetch", "ModelContext replaces the managed object context for this app.")
        ]),
        expectedBehavior: "The query playground runs a FetchDescriptor. Nothing in the target uses NSFetchRequest.",
        experiment: "Search the lesson text for NSFetchRequest and confirm the runnable button still says FetchDescriptor.",
        experimentHint: "The playground status mentions FetchDescriptor.",
        experimentSolution: "The mapping is documentation. The executed API is FetchDescriptor.",
        challenge: "A pull request adds import CoreData next to a SwiftData model. What do you ask the author to change?",
        challengeHint: "One stack.",
        challengeSolution: "Remove the Core Data import and express the fetch with FetchDescriptor and #Predicate.",
        bugTitle: "Translating NSPredicate format strings",
        bugCode: "let request = \"title CONTAINS[cd] %@\"\ncontext.fetch(request)",
        bugQuestion: "Why is this not a SwiftData fetch?",
        bugDiagnosis: "SwiftData does not take predicate format strings. Build a #Predicate. Format strings also skip the compiler.",
        mistakes: ["Keeping an .xcdatamodeld beside @Model for the same entity.", "Assuming NSPredicate format options all exist in #Predicate.", "Fetching with the wrong context type from a copied snippet."],
        debuggingTips: ["If a snippet mentions NSManagedObject, it is the wrong stack.", "Rewrite the predicate in Swift and let the macro type-check it.", "Keep this lesson's mapping next to the code review."],
        quiz: [
            Quiz.make("m3c1", "The SwiftData stand-in for NSFetchRequest is:", ["@Model", "FetchDescriptor", "ModelConfiguration", "UndoManager"], correct: 1, "FetchDescriptor describes the fetch."),
            Quiz.make("m3c2", "Does this target import Core Data?", ["Yes, for predicates", "No", "Only in tests", "Only for migration"], correct: 1, "The lab is SwiftData only."),
            Quiz.make("m3c3", "@FetchRequest maps to:", ["@Query", "@Attribute", "@Transient", "@Bindable"], correct: 0, "Both observe a fetch from a view.")
        ],
        playground: .query
    )

    static let predicate = Lesson.make(
        id: "m3-predicate", moduleID: id, title: "#Predicate",
        summary: "A compiler-checked predicate over stored properties.",
        concept: "#Predicate builds a Predicate value the store can execute. The closure is not ordinary Swift. You can compare stored properties, call a small set of String and Date operations such as localizedStandardContains, and combine booleans. You cannot call arbitrary functions, hop to async code, or read computed and transient properties. Captured values should be local lets of simple types. Capture the search text before the macro, using let term = term, so the macro sees a stable value. Predicates run in the store. That is why a match does not require loading every Book into an array first.",
        whyItExists: "Format-string predicates crash at runtime when a key path is wrong. The macro fails at compile time.",
        whenToUse: "Any filter the store can express. If the macro cannot represent it, filter in memory after a bounded fetch and say so, as the bookmarks tag filter does.",
        sample: Samples.make("m3-pred", "Title search and minimum year", #"""
        import Foundation
        import SwiftData

        let term = term
        let minimumYear = minimumYear
        let predicate = #Predicate<Book> { book in
            book.publicationYear >= minimumYear && book.title.localizedStandardContains(term)
        }
        """#, [
            ("let term = term", "A local copy is the reliable capture for the macro."),
            ("book.publicationYear >= minimumYear", "The key path must be a stored property."),
            ("localizedStandardContains(term)", "Case-insensitive search that the predicate translator accepts.")
        ]),
        expectedBehavior: "In the query playground, a term of Pred and a minimum year of 2020 returns Predicates and hides Migrations from 2020 only if the term is empty. With the term set, title and year both apply.",
        experiment: "Insert sample books. Fetch with term Pred and minimum year 2024. Then clear the term and set the year to 2020.",
        experimentHint: "Sample titles include Predicates and Migrations.",
        experimentSolution: "The first fetch is the narrower set. Clearing the term applies only the year comparison.",
        challenge: "Why can you not predicate on Book's future computed display line?",
        challengeHint: "The store does not know Swift computed properties.",
        challengeSolution: "Predicates translate to the store. Computed properties are not columns. Store the facts you need to filter, or filter in memory after the fetch.",
        bugTitle: "Calling a helper inside the predicate",
        bugCode: "func matches(_ book: Book) -> Bool { book.title.count > 3 }\nlet predicate = #Predicate<Book> { matches($0) }",
        bugQuestion: "Why does this fail to compile or fail to translate?",
        bugDiagnosis: "The closure cannot call out to arbitrary Swift. Inline the comparison the macro knows.",
        mistakes: ["Capturing a class instance.", "Using a computed property.", "Building a predicate from a user-supplied format string."],
        debuggingTips: ["Simplify the closure until it compiles, then add one condition back.", "If the compiler times out, split the predicate into a helper that returns Predicate<Book>.", "Test the predicate against known rows in an in-memory container."],
        quiz: [
            Quiz.make("m3d1", "Which property can a predicate use?", ["A stored property", "A computed property", "A @Transient property", "A SwiftUI view"], correct: 0, "Only schema properties translate."),
            Quiz.make("m3d2", "localizedStandardContains is used because:", ["It is case sensitive", "It is a supported case-insensitive string test", "It queries CloudKit", "It sorts the results"], correct: 1, "contains is case sensitive and not always what a search box wants."),
            Quiz.make("m3d3", "A failing predicate macro means:", ["The store is corrupt", "The closure used something the translator cannot represent", "autosave is off", "The model needs an inverse"], correct: 1, "It is a compile-time translation limit.")
        ],
        playground: .query
    )

    static let sort = Lesson.make(
        id: "m3-sort-descriptor", moduleID: id, title: "SortDescriptor",
        summary: "Order rows in the fetch instead of in the view.",
        concept: "SortDescriptor takes a key path and a SortOrder, forward or reverse. A descriptor can carry several, and the store applies them in order. @Query(sort:order:) is the one-key shorthand. Sorting an Array after fetch is fine for a handful of rows and wrong for a paged table, because you would be sorting one page. Optional key paths, such as StudyTask.dueDate, place nil relative to values in a way that can look arbitrary. If nil should sink to the bottom, sort in memory after a deliberate fetch or store a non-optional sentinel you document. This lab uses non-optional Book.title for the main sort so the page order is obvious.",
        whyItExists: "Users expect a stable order. The store can use an index later. Your view should not reimplement it.",
        whenToUse: "Every list the user scans. Add a second descriptor as a tiebreaker when both key paths are Comparable. Bool is not, so NotesRepository sorts updatedAt in the store and partitions pinned notes in memory.",
        sample: Samples.make("m3-sort", "Forward and reverse title sort", #"""
        import SwiftData

        let order: SortOrder = sortForward ? .forward : .reverse
        let descriptor = FetchDescriptor<Book>(
            sortBy: [SortDescriptor(\Book.title, order: order)]
        )
        """#, [
            ("SortOrder", "forward is A to Z for strings. reverse is Z to A."),
            ("SortDescriptor(\\Book.title", "The key path is the column. Title, not a computed display name."),
            ("sortBy:", "An array, so you can add a tiebreaker later.")
        ]),
        expectedBehavior: "The query playground toggle switches the title order of the fetched page.",
        experiment: "Insert samples, fetch with sort on, then turn it off and fetch again.",
        experimentHint: "The toggle is Sort title A to Z.",
        experimentSolution: "The same rows come back in the opposite title order. Limit and offset still apply after the sort.",
        challenge: "Notes are sorted by isPinned descending, then updatedAt descending. What does the second key do?",
        challengeHint: "Look at NotesRepository.fetchNotes.",
        challengeSolution: "The store sorts updatedAt descending. Bool is not Comparable, and the Bool SortDescriptor requires NSObject, so the repository then stably moves pinned notes to the front in memory. Within one pin state, the newer note stays first. Do not do this after fetchLimit, because you would only reorder one page.",
        bugTitle: "Sorting only the current page",
        bugCode: "descriptor.fetchLimit = 2\nlet page = try context.fetch(descriptor)\nlet shown = page.sorted { $0.title > $1.title }",
        bugQuestion: "Why can this order disagree with the next page?",
        bugDiagnosis: "The store already chose two rows using its sort, which may be unsorted if you forgot sortBy. Sorting those two afterward does not reorder the table. Put the SortDescriptor on the fetch.",
        mistakes: ["Forgetting sortBy and blaming the predicate.", "Sorting by a property the user did not edit.", "Using a different sort in @Query and in the repository."],
        debuggingTips: ["Fetch without a limit while debugging order.", "Print titles in the returned order before transforming them.", "Keep the sort next to the predicate in one function."],
        quiz: [
            Quiz.make("m3e1", "SortOrder.forward on a String is:", ["Z to A", "A to Z", "Random", "By string length"], correct: 1, "Forward is ascending."),
            Quiz.make("m3e2", "A second SortDescriptor is a:", ["Migration", "Tiebreaker", "Predicate", "Delete rule"], correct: 1, "Later descriptors apply when earlier keys are equal."),
            Quiz.make("m3e3", "Where should a paged list be sorted?", ["In the store, via SortDescriptor", "Only after fetchLimit slices the array", "In CloudKit", "In the model init"], correct: 0, "The page is defined by the sorted order.")
        ],
        playground: .query
    )

    static let compound = Lesson.make(
        id: "m3-compound-predicates", moduleID: id, title: "Compound predicates",
        summary: "AND and OR inside one predicate closure.",
        concept: "Use && and || inside the #Predicate closure. That is the compound predicate. You do not build an NSCompoundPredicate. Parentheses matter as they do in Swift. A compound that mixes an optional relationship and a date is still one predicate, which is what ExpenseQuery.categoryAndDate does. If the compiler cannot type-check a large closure, split it into functions that each return a Predicate for one shape, and choose a shape in a switch. That pattern is more reliable than concatenating strings.",
        whyItExists: "Real filters are rarely one comparison. The store should still do the work.",
        whenToUse: "Search boxes that check title or notes. Screens that require a category and a date range together.",
        sample: Samples.make("m3-and", "Category and date together", #"""
        import Foundation
        import SwiftData

        let name = name
        let start = start
        let end = end
        let predicate = #Predicate<Expense> { expense in
            expense.category?.name == name && expense.spentOn >= start && expense.spentOn <= end
        }
        """#, [
            ("expense.category?.name == name", "Optional relationship traversal. Rows with no category do not match."),
            ("&&", "Every comparison must hold. This is the compound AND."),
            ("expense.spentOn >= start", "Dates compare in the store. The end bound is inclusive here.")
        ]),
        expectedBehavior: "The predicate playground's May 2026 plus Food filter returns Lunch and hides the June dinner and the train.",
        experiment: "Insert sample expenses. Run the predicate with category Food and the May limit on.",
        experimentHint: "The sample data is Lunch in May, Train in May, Dinner in June.",
        experimentSolution: "Only Lunch matches Food and May. Train fails the category. Dinner fails the month.",
        challenge: "Write the English meaning of title contains OR notes contain, which the notes repository uses.",
        challengeHint: "Look at the || in fetchNotes.",
        challengeSolution: "A note matches when either field contains the term. A note with the word only in the body still matches.",
        bugTitle: "AND where the user expected OR",
        bugCode: "book.publicationYear >= 2024 && book.title.localizedStandardContains(\"A\") && book.title.localizedStandardContains(\"Z\")",
        bugQuestion: "Why can this match nothing even when both letters exist in the library?",
        bugDiagnosis: "AND requires one title to contain both substrings. Two books that each contain one letter do not satisfy it. Use OR for alternatives, or issue two fetches.",
        mistakes: ["Building one giant closure the compiler cannot type-check.", "Forgetting parentheses around OR groups.", "Filtering again in memory with the opposite operator."],
        debuggingTips: ["Test each side of the AND as its own predicate.", "Print the matched titles, not only the count.", "Keep a switch of shapes, as ExpenseQuery.Shape does."],
        quiz: [
            Quiz.make("m3f1", "Compound AND inside #Predicate is:", ["&&", "NSCompoundPredicate", "a second FetchDescriptor", "fetchOffset"], correct: 0, "The closure uses Swift boolean operators."),
            Quiz.make("m3f2", "category?.name == name fails when:", ["The amount is zero", "The category is nil", "The date is today", "The context is the main context"], correct: 1, "Optional chaining does not match a missing relationship."),
            Quiz.make("m3f3", "If the macro cannot type-check a closure, you should:", ["Switch to a format string", "Split the filter into known predicate shapes", "Drop the filter", "Sort instead"], correct: 1, "A switch of small predicates stays inside the supported subset.")
        ],
        playground: .predicates
    )

    static let pagination = Lesson.make(
        id: "m3-limits-pagination", moduleID: id, title: "Limits and pagination",
        summary: "fetchLimit and fetchOffset page through a sorted fetch.",
        concept: "fetchLimit caps the number of rows. fetchOffset skips that many of the sorted rows first. Together they are a page. Offset pagination is simple and good enough for this lab. It gets expensive and unstable if rows are inserted at the top while the user is paging, because offsets shift. A production feed often pages with a predicate on the last seen sort key instead of a growing offset. Either way, the sort must be stable and include a unique tiebreaker if you care about duplicates on the boundary. Limit 0 in the playground means no cap, because the lab treats a non-positive stepper as nil.",
        whyItExists: "Unbounded fetches are how a demo becomes a memory problem.",
        whenToUse: "Any list that can grow without a fixed ceiling: books, expenses, notes. The sample library is tiny so the pages are easy to see.",
        sample: Samples.make("m3-page", "Page size and offset", #"""
        import SwiftData

        descriptor.fetchLimit = limit > 0 ? limit : nil
        descriptor.fetchOffset = max(offset, 0)
        let page = try context.fetch(descriptor)
        """#, [
            ("fetchLimit", "nil means the store may return every match."),
            ("fetchOffset", "Skips this many rows in the current sort."),
            ("context.fetch(descriptor)", "Returns only that page, already tracked.")
        ]),
        expectedBehavior: "Limit 2 and offset 0 returns the first two titles. Offset 2 returns the following ones.",
        experiment: "Insert the four sample books, sort A to Z, limit 2, and compare offset 0 with offset 2.",
        experimentHint: "There are four sample titles.",
        experimentSolution: "You see two pairs, in sort order, without loading a different predicate.",
        challenge: "Why is offset pagination a weak fit for a list that inserts at the top while the user scrolls?",
        challengeHint: "Offsets are positions, not identities.",
        challengeSolution: "An insert at the top shifts every later offset, so the next page can repeat or skip a row. Page from the last title or date instead.",
        bugTitle: "Applying the limit in the view",
        bugCode: "let all = try context.fetch(FetchDescriptor<Book>())\nlet page = Array(all.dropFirst(offset).prefix(limit))",
        bugQuestion: "What did this fail to avoid?",
        bugDiagnosis: "The store still materialized every book. Put limit and offset on the descriptor.",
        mistakes: ["Changing offset without a stable sort.", "Using a different sort on the next page.", "Treating limit as a delete."],
        debuggingTips: ["Fetch count for the predicate so you know how many pages exist.", "Log offset, limit, and the returned titles together.", "Set the sort before judging the page."],
        quiz: [
            Quiz.make("m3g1", "fetchOffset skips rows:", ["After they are shown", "In the sorted result, before the page is returned", "Only in memory stores", "Only for @Query"], correct: 1, "The store applies it with the sort."),
            Quiz.make("m3g2", "A nil fetchLimit means:", ["Delete all", "No cap", "Limit 1", "Limit equal to the offset"], correct: 1, "You get every match the predicate allows."),
            Quiz.make("m3g3", "Offset pagination becomes unstable when:", ["The sort is stable and nothing is inserted", "Rows are inserted into the sort order while paging", "You use a predicate", "The model is a class"], correct: 1, "Positions shift under the offset.")
        ],
        playground: .query
    )

    static let dynamic = Lesson.make(
        id: "m3-dynamic-search", moduleID: id, title: "Dynamic search",
        summary: "Rebuild a supported predicate when the text changes.",
        concept: "Search text is a value. Each change should build a new predicate or choose a new shape. Do not try to compile the user's Swift. An empty string should become a predicate that does not test the title, or a nil predicate, so you are not asking localizedStandardContains to search for nothing in a way that surprises you. The notes list calls load() from onChange of searchText, and the repository branches on the trimmed string. The expense screen picks ExpenseQuery.Shape in a switch. Both are dynamic and both stay inside the macro's supported subset.",
        whyItExists: "A single hard-coded predicate cannot serve a search box.",
        whenToUse: "Any filter UI. Prefer a small set of shapes over an open-ended expression builder.",
        sample: Samples.make("m3-dyn", "Empty search versus text search", #"""
        import SwiftData

        if trimmed.isEmpty {
            descriptor.predicate = #Predicate<Book> { book in
                book.publicationYear >= minimumYear
            }
        } else {
            let term = trimmed
            descriptor.predicate = #Predicate<Book> { book in
                book.publicationYear >= minimumYear && book.title.localizedStandardContains(term)
            }
        }
        """#, [
            ("if trimmed.isEmpty", "The empty box is its own shape, not a contains check for an empty string."),
            ("let term = trimmed", "Capture the current text for this predicate only."),
            ("localizedStandardContains(term)", "The store does the match. The view does not filter a full dump unless the predicate cannot say it.")
        ]),
        expectedBehavior: "Clearing the query playground term widens the result to the year filter only.",
        experiment: "Fetch with a term, then clear it and fetch again.",
        experimentHint: "The text field is Title contains.",
        experimentSolution: "The second fetch drops the title test and keeps the year test.",
        challenge: "The bookmarks screen filters tags in memory. Why is that acceptable here, and what would you change if there were tens of thousands of bookmarks?",
        challengeHint: "The predicate subset and the size of the table.",
        challengeSolution: "The tag test is awkward inside #Predicate, and the lab table is small. At real size, store a query-friendly field or fetch by tag relationship with a supported predicate so you do not load every bookmark.",
        bugTitle: "Capturing search text too early",
        bugCode: "let term = \"\"\nlet predicate = #Predicate<Book> { $0.title.localizedStandardContains(term) }",
        bugQuestion: "The user then types Pred. Why can the predicate still be empty?",
        bugDiagnosis: "The predicate captured the old local value. Build a new predicate when the text changes.",
        mistakes: ["One predicate stored forever.", "Filtering only in the view while claiming the store did it.", "Running a fresh unpaged fetch on every keystroke for a huge table."],
        debuggingTips: ["Log the trimmed term beside the result count.", "Write a unit test for empty and non-empty terms.", "Debounce the field if the fetch becomes hot. Correctness first."],
        quiz: [
            Quiz.make("m3h1", "Dynamic search should:", ["Evaluate arbitrary Swift the user typed", "Rebuild a supported predicate or shape", "Edit the model class", "Disable autosave"], correct: 1, "The macro still has to translate the closure."),
            Quiz.make("m3h2", "An empty search box should:", ["Use a shape that does not require a substring", "Search for the letters empty", "Delete all rows", "Crash on purpose"], correct: 0, "Empty means no text constraint."),
            Quiz.make("m3h3", "onChange of search text in Notes calls:", ["A schema migration", "load(), which refetches", "rollback", "CloudKit sync"], correct: 1, "The repository builds a new descriptor.")
        ],
        playground: .query
    )

    static let viewVsCode = Lesson.make(
        id: "m3-view-vs-nonview", moduleID: id, title: "Views versus other code",
        summary: "Put @Query in views. Put FetchDescriptor everywhere else.",
        concept: "The split is about observation, not about which API is more powerful. @Query redraws a view and requires the environment container. FetchDescriptor plus modelContext.fetch works in a repository, a test, a migration closure, and a ModelActor. A view may use either. A view model that exists so you can unit test it should take a context or a repository and fetch, which is what NotesListViewModel does. Do not reach around that and also install a second @Query that can disagree. The SwiftUI module shows the view path. The notes project shows the testable path. Both are production-quality for different sizes of screen.",
        whyItExists: "Teams overbuild repositories for a one-screen list, or they put @Query in a class and cannot test it. The boundary prevents both.",
        whenToUse: "Choose @Query when the screen is the feature. Choose a repository when you need tests, coordination, or reuse from more than one view.",
        sample: Samples.make("m3-split", "Same fetch, two homes", #"""
        import SwiftData
        import SwiftUI

        // View path.
        struct LibraryList: View {
            @Query(sort: \Book.title) private var books: [Book]
            var body: some View { Text("\\(books.count)") }
        }

        // Non-view path.
        func loadBooks(context: ModelContext) throws -> [Book] {
            try context.fetch(FetchDescriptor<Book>(sortBy: [SortDescriptor(\.title)]))
        }
        """#, [
            ("@Query(sort: \\Book.title)", "Legal because LibraryList is a View."),
            ("func loadBooks", "Legal in a repository or test. There is no view here."),
            ("context.fetch", "Explicit context. The caller decides which store.")
        ]),
        expectedBehavior: "The query playground button uses the non-view path. The SwiftUI playground list uses @Query. They read the same store when they share the app container.",
        experiment: "Insert a lab record in the SwiftUI playground, then look at the CRUD list. Both are the view context.",
        experimentHint: "They share LabRecord.",
        experimentSolution: "The new row is visible to both @Query sites because they share the container and the save landed.",
        challenge: "Which path does the notes list use, and why can a unit test call it?",
        challengeHint: "NotesListViewModel.load.",
        challengeSolution: "It calls NotesRepository.fetchNotes, which uses FetchDescriptor. The test builds an in-memory context and never creates a View.",
        bugTitle: "Two sources of truth",
        bugCode: "@Query var notes: [Note]\n// also\nviewModel.load()\nList(viewModel.notes)",
        bugQuestion: "What bug does the unused @Query create?",
        bugDiagnosis: "One list is shown, the other still fetches. They can diverge, and the extra fetch is wasted. Pick one owner.",
        mistakes: ["A repository that secretly reads @Environment.", "A view model that constructs ModelContainer.makeShared().", "Testing only the view path and never the predicate."],
        debuggingTips: ["Search for @Query and fetch( in the feature. One of them should own the screen.", "Tests should construct the repository with makeInMemory().", "If the UI and the test disagree, they are not using the same predicate."],
        quiz: [
            Quiz.make("m3i1", "A ModelActor should fetch with:", ["@Query", "FetchDescriptor on its modelContext", "The view's @State", "NSFetchRequest"], correct: 1, "Actors do not host DynamicProperty."),
            Quiz.make("m3i2", "NotesListViewModel is testable because:", ["It subclasses View", "It depends on a repository and a context", "It uses CloudKit", "@Query is public"], correct: 1, "The test supplies an in-memory context."),
            Quiz.make("m3i3", "Using both @Query and a parallel fetched array for one list is:", ["Required", "A second source of truth", "How pagination works", "How migrations run"], correct: 1, "Pick one owner for the rows the user sees.")
        ],
        playground: .query
    )
}
