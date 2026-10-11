import Foundation

enum Module9Concurrency {
    static let id = "concurrency"
    static let module = LearningModule(
        id: id,
        title: "Concurrency",
        summary: "Main actor, ModelActor, identifiers, and the refreshes that background saves require.",
        level: .advanced,
        order: 9,
        lessons: [isolation, mainActor, modelActor, background, identifiers, refresh, mistakes, sdk]
    )

    static let isolation = Lesson.make(
        id: "m9-isolation", moduleID: id, title: "ModelContext and actor isolation",
        summary: "A context belongs to one concurrency domain.",
        concept: "ModelContext is not Sendable. The SDK marks the Sendable conformance unavailable with the message that contexts cannot be shared across concurrency domains. The view's context is used from the main actor because SwiftUI puts you there. A ModelActor has a different context, created for that actor. You may pass Sendable values: String, Int, Date, PersistentIdentifier. You may not pass the context. You should not pass a live model instance either. Even if a macro adds a Sendable conformance on the class, the object's backing data belongs to one context. Using it from another domain is a data race the type system might not phrase the way you expect. This target sets the default actor isolation to nonisolated so models are not silently main-actor isolated, and then marks UI types @MainActor on purpose.",
        whyItExists: "SwiftData's tracking is not thread-safe. Isolation is how that is expressed.",
        whenToUse: "Any time work leaves the view. Imports, maintenance, and tests that hop actors.",
        sample: Samples.make("m9-iso", "Pass titles, not the context", #"""
        import SwiftData

        let container = modelContext.container
        let importer = LessonBackgroundImporter(modelContainer: container)
        let count = try await importer.importLabTitles(["Actor row A", "Actor row B"])
        """#, [
            ("modelContext.container", "The container is Sendable. The context is not."),
            ("LessonBackgroundImporter", "The actor builds its own ModelContext."),
            ("importLabTitles", "The argument is [String], which can cross the boundary.")
        ]),
        expectedBehavior: "The import button reports two saved rows and a fresh context can read the titles.",
        experiment: "Run Import two titles on a ModelActor and read the fresh list.",
        experimentHint: "The status includes the count from a new context.",
        experimentSolution: "The actor saved. A different context fetched the titles. The view context object was not passed in.",
        challenge: "What would you change if a function signature asked for a ModelContext and you wanted to call it from the actor?",
        challengeHint: "Do not pass the view context.",
        challengeSolution: "Move the function onto the ModelActor and use the actor's modelContext, or pass a container and create the context inside the destination domain.",
        bugTitle: "Hopping with the view context",
        bugCode: "Task.detached {\n    try modelContext.save()\n}",
        bugQuestion: "Why is this illegal?",
        bugDiagnosis: "The context cannot leave the main actor. detached is a different domain. The compiler should reject it. Do not silence the error.",
        mistakes: ["Assuming a class is safe because you only touch one property.", "A global ModelContext.", "Using the view context inside the actor because it was captured."],
        debuggingTips: ["Read the unavailable Sendable message and believe it.", "Search for Task.detached near modelContext.", "Keep actor methods free of SwiftUI."],
        quiz: [
            Quiz.make("m9a1", "ModelContext is:", ["Sendable", "Not shareable across concurrency domains", "A value type", "A view"], correct: 1, "The SDK says so."),
            Quiz.make("m9a2", "Which value may cross into the actor?", ["The view context", "[String]", "A SwiftUI Binding", "The view"], correct: 1, "Strings are Sendable."),
            Quiz.make("m9a3", "The actor's context is:", ["The view context", "A context the actor owns", "nil", "The migration context"], correct: 1, "The macro provides it.")
        ],
        playground: .concurrency
    )

    static let mainActor = Lesson.make(
        id: "m9-main-actor", moduleID: id, title: "@MainActor",
        summary: "UI, the environment context, and view models stay on the main actor.",
        concept: "@MainActor on NotesRepository, the view models, and AppCoordinator means their methods run on the main actor, which is where the environment ModelContext is used. SwiftUI views are already main-actor isolated. Marking the repository documents the rule for call sites that are not views, including tests. A main-actor type can still start a Task that awaits a ModelActor. The await is the hop. After the await, you are back on the main actor and can touch the view model. Do not mark the ModelActor @MainActor. That would erase the point of it.",
        whyItExists: "The common bug is a repository that is quietly called from a background queue.",
        whenToUse: "Types that touch the environment context or update UI state.",
        sample: Samples.make("m9-main", "Repository isolated to the main actor", #"""
        import SwiftData

        @MainActor
        final class NotesRepository {
            private let context: ModelContext
            init(context: ModelContext) { self.context = context }
            func create(title: String, body: String) throws {
                context.insert(Note(title: title, body: body))
                try context.save()
            }
        }
        """#, [
            ("@MainActor", "Callers must be on the main actor or await a hop."),
            ("private let context", "This context is the view context, not an actor context.")
        ]),
        expectedBehavior: "The notes UI and the notes tests call the repository on the main actor. The compiler enforces it.",
        experiment: "Create a note in the project. The save happens on the main actor inside the repository.",
        experimentHint: "The Save button calls the view model, which calls the repository.",
        experimentSolution: "The note is stored. No background context was involved. That is correct for a small form.",
        challenge: "Why is the importer not @MainActor?",
        challengeHint: "It is a ModelActor.",
        challengeSolution: "The work is supposed to leave the main actor. Marking it @MainActor would run the import on the UI actor and defeat the example.",
        bugTitle: "Main actor on the importer",
        bugCode: "@MainActor\n@ModelActor\nactor LessonBackgroundImporter {}",
        bugQuestion: "What does the extra attribute do?",
        bugDiagnosis: "It fights the actor's own isolation. The importer should be a ModelActor and nothing else.",
        mistakes: ["A nonisolated repository holding a context.", "Assuming the test is main actor without marking it.", "Hopping back to the main actor by capturing the context in the child task."],
        debuggingTips: ["Let the compiler place the hops.", "Mark test classes @MainActor when they touch contexts.", "Keep UI updates after the await."],
        quiz: [
            Quiz.make("m9b1", "The environment context is used from:", ["Any thread", "The main actor", "A ModelActor only", "The migration queue only"], correct: 1, "SwiftUI is main-actor isolated."),
            Quiz.make("m9b2", "@MainActor on the repository:", ["Disables save", "Documents and enforces where the context is used", "Creates a store", "Is optional decoration with no effect"], correct: 1, "Call sites must hop or already be there."),
            Quiz.make("m9b3", "After await importer.importLabTitles, UI code:", ["Is still inside the actor", "Can continue on the main actor and update state", "Must not touch state", "Has lost the container"], correct: 1, "The button's Task is main-actor work around the await.")
        ],
        playground: .concurrency
    )

    static let modelActor = Lesson.make(
        id: "m9-model-actor", moduleID: id, title: "ModelActor",
        summary: "The macro gives the actor a container, an executor, and a context.",
        concept: "@ModelActor on an actor generates an initializer that takes a ModelContainer, plus modelContainer, modelExecutor, and access to modelContext. The context is created to run on that actor's executor. Methods can be synchronous on the actor and are awaited from outside. Use self[id, as: LabRecord.self] to resolve an identifier inside the actor. That subscript is the actor-friendly form of model(for:). ModelActor is an iOS 17 API. This lab uses it. It does not use iOS 18 history APIs.",
        whyItExists: "Hand-building an executor and a context is how people accidentally use the wrong queue.",
        whenToUse: "Imports, batch edits, and any persistence that should not block the interaction for long. A single text field does not need one.",
        sample: Samples.make("m9-actor", "The importer in this target", #"""
        import SwiftData

        @ModelActor
        actor LessonBackgroundImporter {
            func importLabTitles(_ titles: [String]) throws -> Int {
                for title in titles {
                    modelContext.insert(LabRecord(title: title, notes: "Imported by a ModelActor."))
                }
                try modelContext.save()
                return titles.count
            }
        }
        """#, [
            ("@ModelActor", "Supplies init(modelContainer:), the executor, and modelContext."),
            ("modelContext.insert", "The actor's context, created for this executor."),
            ("try modelContext.save()", "Publishes the rows. The view context did not perform this save.")
        ]),
        expectedBehavior: "Import reports a count of 2. The fresh-context list includes the titles.",
        experiment: "Run the import button.",
        experimentHint: "The button creates the actor with modelContext.container.",
        experimentSolution: "The actor saved two rows through its own context.",
        challenge: "Why does the method take [String] instead of [LabRecord]?",
        challengeHint: "Live models stay in their context.",
        challengeSolution: "LabRecord instances belong to whatever context created them. The actor inserts new ones. Titles are Sendable.",
        bugTitle: "Constructing the actor with a context",
        bugCode: "LessonBackgroundImporter(modelContext: modelContext)",
        bugQuestion: "What is the actual initializer?",
        bugDiagnosis: "The macro's initializer takes a ModelContainer. Passing a context is the sharing bug the type is designed to prevent.",
        mistakes: ["Using the actor's context from a view.", "Forgetting save on the actor.", "A new actor per row instead of a batch."],
        debuggingTips: ["If the initializer does not match, you are trying to pass a context.", "Log inside the actor before save.", "Fetch from a new context afterward."],
        quiz: [
            Quiz.make("m9c1", "ModelActor's initializer takes:", ["A ModelContext", "A ModelContainer", "A View", "A predicate"], correct: 1, "It creates the context itself."),
            Quiz.make("m9c2", "modelContext inside the actor is:", ["The environment context", "The actor's own context", "Always nil", "The preview context"], correct: 1, "Different executor."),
            Quiz.make("m9c3", "ModelActor is available:", ["Only on iOS 26", "On iOS 17, which is this deployment target", "Only with CloudKit", "Only in tests"], correct: 1, "The lab calls it for real.")
        ],
        playground: .concurrency,
        sdkNote: "ModelActor is iOS 17. History transactions and the custom data store are iOS 18 and are not called. iOS 26 sectioned query types are not called."
    )

    static let background = Lesson.make(
        id: "m9-background-work", moduleID: id, title: "Background persistence",
        summary: "Batch the writes on the actor and save once.",
        concept: "importLabTitles loops inserts and saves once. That is one transaction. Saving per row is slower and gives observers a half-finished import. The actor should not touch SwiftUI. It returns a count or throws. The caller updates the banner. Turn reasoning about autosave off: the actor context should save explicitly. If the import is large, this is still one function the user can wait on. Chunk only when you have measured a problem, and still save each chunk explicitly. Do not use the view context on a detached task as a fake background queue.",
        whyItExists: "Imports and maintenance are the real reason to leave the main actor, not a single toggle.",
        whenToUse: "More work than a form save. The two-row button is the shape, scaled down so you can see it.",
        sample: Samples.make("m9-batch", "One save for the batch", #"""
        import SwiftData

        func importLabTitles(_ titles: [String]) throws -> Int {
            for title in titles {
                modelContext.insert(LabRecord(title: title, notes: "batch"))
            }
            try modelContext.save()
            return titles.count
        }
        """#, [
            ("for title in titles", "All inserts join one pending set."),
            ("try modelContext.save()", "One transaction for the batch.")
        ]),
        expectedBehavior: "One button press saves both titles. The count is 2, not two separate alerts.",
        experiment: "Import, then import again. The fresh list can contain both pairs.",
        experimentHint: "The reader fetches the newest titles.",
        experimentSolution: "Each call is its own transaction. Both are in the store.",
        challenge: "What would a thrown error halfway through a single save mean for the batch?",
        challengeHint: "One transaction.",
        challengeSolution: "The save fails as a unit. You roll back that context. You do not keep a random prefix unless you saved in chunks on purpose.",
        bugTitle: "Save inside the loop",
        bugCode: "for title in titles {\n    context.insert(LabRecord(title: title, notes: \"\"))\n    try context.save()\n}",
        bugQuestion: "Why is this worse than one save?",
        bugDiagnosis: "You pay for a transaction per row, and a failure in the middle leaves the earlier rows committed. Batch unless you explicitly want that.",
        mistakes: ["Updating a progress label from the actor.", "A detached task with the view context.", "Ignoring the thrown error."],
        debuggingTips: ["Return a count and a thrown error. That is enough UI fuel.", "Watch the store with a fresh context.", "Keep the loop free of SwiftUI types."],
        quiz: [
            Quiz.make("m9d1", "The lab import saves:", ["Once per title", "Once per batch", "Never", "On the view context"], correct: 1, "One transaction."),
            Quiz.make("m9d2", "The actor may update a Text view directly?", ["Yes", "No. Return a value and let the caller update the UI", "Only if autosave is on", "Only for the first row"], correct: 1, "The actor does not own the view."),
            Quiz.make("m9d3", "A fake background queue is:", ["Task.detached with the view context", "A ModelActor", "A new container in a test", "The main actor"], correct: 0, "That both violates isolation and blocks nothing useful.")
        ],
        playground: .concurrency
    )

    static let identifiers = Lesson.make(
        id: "m9-identifiers", moduleID: id, title: "Identifiers across boundaries",
        summary: "Save, pass persistentModelID, resolve it on the other side.",
        concept: "PersistentIdentifier is the value that can move between actors. The actor resolves it with self[id, as: LabRecord.self] and gets nil if this store does not know the id. Resolve after the originating context has saved. An identifier for an unsaved insert may not be fetchable in another context, because the row is not in the store. Do not pass the LabRecord. The rename button in the playground fetches an id with a fresh context, then hands only the id to the actor. The actor mutates its own instance.",
        whyItExists: "You need to point at a row without moving the object that represents it.",
        whenToUse: "Any edit that a background actor performs on a row the UI already showed.",
        sample: Samples.make("m9-id", "Resolve inside the actor", #"""
        import SwiftData

        func renameLabRecord(id: PersistentIdentifier, to title: String) throws {
            guard let record = self[id, as: LabRecord.self] else {
                throw LabError.missingModel
            }
            record.title = title
            record.updatedAt = .now
            try modelContext.save()
        }
        """#, [
            ("PersistentIdentifier", "The only reference the method accepts."),
            ("self[id, as: LabRecord.self]", "Resolves the id in the actor's context. Nil means this store cannot see it."),
            ("try modelContext.save()", "The mutation is local until this save.")
        ]),
        expectedBehavior: "Rename changes the newest row's title to Renamed off the main actor. A fresh fetch shows it.",
        experiment: "Import, then rename, then read the fresh titles.",
        experimentHint: "Rename uses the newest id.",
        experimentSolution: "The title changed in the store. The view did not hand over a LabRecord.",
        challenge: "Why can rename throw missingModel?",
        challengeHint: "The id was never saved, or it is from another store.",
        challengeSolution: "The actor's context cannot resolve an identifier that was never committed, or that belongs to a different container.",
        bugTitle: "Passing the object",
        bugCode: "func rename(_ record: LabRecord) { record.title = \"X\" }",
        bugQuestion: "What is unsafe about this signature on an actor?",
        bugDiagnosis: "The instance is bound to the context that fetched it. The actor would mutate another domain's object. Pass the identifier.",
        mistakes: ["Renaming before save.", "Using the title as the identifier.", "Resolving the id on the view context and then using that instance inside the actor."],
        debuggingTips: ["Save, then print the identifier, then hop.", "Treat nil from the subscript as a real error.", "Fetch again and compare titles."],
        quiz: [
            Quiz.make("m9e1", "The value to pass is:", ["LabRecord", "PersistentIdentifier", "ModelContext", "the title only, always"], correct: 1, "The id is the cross-domain reference."),
            Quiz.make("m9e2", "Resolve the id:", ["In the sending context and pass the object", "In the receiving actor", "In the view body", "During migration only"], correct: 1, "The receiving context materializes the row."),
            Quiz.make("m9e3", "An unsaved insert's id in another context:", ["Always works", "Can fail because the row is not committed", "Deletes the row", "Migrates the store"], correct: 1, "Save first.")
        ],
        playground: .concurrency
    )

    static let refresh = Lesson.make(
        id: "m9-refresh-ui", moduleID: id, title: "Refreshing the UI",
        summary: "After the actor saves, read the store again. Do not assume the view context noticed on the same line.",
        concept: "A successful actor save means the store has the rows. The view context may update @Query when it hears the save, and it may not have done so by the next line of your experiment. The playground therefore creates a new ModelContext and fetches. That result is what the banner trusts. You can also refetch with the view context after the await. If those two disagree, believe the new context and then investigate observation. Do not rebuild the ModelContainer to refresh a list. That reopens the file and fights the one you already have.",
        whyItExists: "Background writes are the case where observation timing confuses people into thinking save failed.",
        whenToUse: "After every actor save, before you tell the user the work is visible.",
        sample: Samples.make("m9-refresh", "A reader context", #"""
        import SwiftData

        let context = ModelContext(container)
        context.autosaveEnabled = false
        var descriptor = FetchDescriptor<LabRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 8
        let titles = try context.fetch(descriptor).map(\.title)
        """#, [
            ("ModelContext(container)", "A new context reads the store, not the actor's unsaved graph."),
            ("autosaveEnabled = false", "This reader should not flush anything."),
            ("fetchLimit = 8", "A refresh does not need the entire table.")
        ]),
        expectedBehavior: "The fresh list under the buttons shows the titles the new context read.",
        experiment: "Import and confirm the two titles appear in the fresh list even if you do not trust the CRUD @Query timing.",
        experimentHint: "The list is the fresh fetch, not a @Query.",
        experimentSolution: "Those strings came from the store after the actor saved.",
        challenge: "What is the wrong way to force a refresh?",
        challengeHint: "A second makeShared.",
        challengeSolution: "Opening another container on the same URL. Refetch, or use a short-lived reader context, on the container you already have.",
        bugTitle: "Reading the actor's models on the view",
        bugCode: "let records = try await importer.liveRecords()\nList(records) { Text($0.title) }",
        bugQuestion: "Why should the actor not return [LabRecord]?",
        bugDiagnosis: "Those instances belong to the actor's context. Return titles, counts, or identifiers, and fetch in the view context if you need models there.",
        mistakes: ["Rebuilding the container.", "Assuming @Query has already redrawn.", "Showing the user a success before the reader fetch returns."],
        debuggingTips: ["Compare a new context's fetchCount with the list on screen.", "Keep the reader autosave off.", "Limit the refresh fetch."],
        quiz: [
            Quiz.make("m9f1", "After an actor save, the authoritative quick check is:", ["The actor's objects used in the view", "A fetch from a context that can see the store", "A new app install", "A predicate string"], correct: 1, "The store is the source. A new context reads it."),
            Quiz.make("m9f2", "Rebuilding the container to refresh is:", ["Recommended", "A way to fight the open file", "Required for @Query", "The ModelActor initializer"], correct: 1, "Reuse the container."),
            Quiz.make("m9f3", "The actor should return:", ["Live model instances for the list", "Sendable results such as counts, titles, or identifiers", "The context", "The view"], correct: 1, "Models stay in their context.")
        ],
        playground: .concurrency
    )

    static let mistakes = Lesson.make(
        id: "m9-mistakes", moduleID: id, title: "Common concurrency mistakes",
        summary: "The short list of ways to corrupt a context.",
        concept: "The mistakes that matter are: passing a ModelContext across a hop, mutating a live model on the wrong executor, saving the view context from a detached task, forgetting to save the actor, refreshing by opening a second container, and treating a Sendable conformance on the model class as permission. Also avoid sharing one in-memory container between tests that run in parallel and mutate it. The playground's two buttons are the allowed shape. Anything that needs the view context stays in the view model on the main actor.",
        whyItExists: "Concurrency bugs in SwiftData look like missing rows and then become crashes under load.",
        whenToUse: "Review this list before you add a Task to a persistence screen.",
        sample: Samples.make("m9-bad", "The allowed hop", #"""
        import SwiftData

        let container = modelContext.container
        Task {
            let importer = LessonBackgroundImporter(modelContainer: container)
            _ = try await importer.importLabTitles(["One"])
        }
        """#, [
            ("modelContext.container", "Copy the container out. Do not capture the context in the child if the child is not main-actor."),
            ("LessonBackgroundImporter(modelContainer: container)", "The hop is the actor call, not a detached use of the view context.")
        ]),
        expectedBehavior: "The buttons use this shape. They do not call Task.detached with the view context.",
        experiment: "Read the playground source path in your head: container, actor, fresh fetch. Confirm you never see the view context inside the actor.",
        experimentHint: "LessonBackgroundImporter only touches its modelContext.",
        experimentSolution: "The actor file does not mention the environment context. It inserts new LabRecord values.",
        challenge: "List the three values this lesson allows you to pass into the actor.",
        challengeHint: "Sendable data and the container.",
        challengeSolution: "The ModelContainer at init, Sendable inputs such as strings, and PersistentIdentifier after a save. Not a ModelContext and not a live model.",
        bugTitle: "Detached save",
        bugCode: "Task.detached { try modelContext.save() }",
        bugQuestion: "What rule does this break?",
        bugDiagnosis: "The view context is confined to its domain. detached does not inherit that domain. Use a ModelActor or stay on the main actor.",
        mistakes: ["Parallel tests sharing one context.", "Returning models from the actor.", "A second container as a refresh."],
        debuggingTips: ["Grep for Task.detached and modelContext.", "Grep for function parameters of model types on actors.", "Make the illegal snippet a lesson, not a helper."],
        quiz: [
            Quiz.make("m9g1", "Task.detached with the view context is:", ["The recommended background path", "A confinement bug", "Required for save", "How previews work"], correct: 1, "Use a ModelActor."),
            Quiz.make("m9g2", "A Sendable stamp on a model class means:", ["Pass instances freely", "You still do not share a live instance across contexts", "The context is Sendable", "The store is in memory"], correct: 1, "Backing data stays with one context."),
            Quiz.make("m9g3", "Parallel tests should:", ["Share a context", "Use separate containers", "Use the app file", "Disable actors"], correct: 1, "Isolation includes tests.")
        ],
        playground: .concurrency
    )

    static let sdk = Lesson.make(
        id: "m9-sdk-notes", moduleID: id, title: "SDK and deployment notes",
        summary: "The lab runs the iOS 17 concurrency API and names the newer ones it does not call.",
        concept: "Deployment target is iOS 17. ModelActor, PersistentIdentifier, and ModelContext confinement are part of that surface and are executed. iOS 18 adds history transactions, deleteHistory, the DataStore protocol, #Unique, and #Index. iOS 26 and later SDKs add more query conveniences such as sectioned results. Those symbols are not referenced in this target, so raising or lowering the SDK does not accidentally start calling them. If you adopt history later, wrap the call in an availability check and keep a fallback for iOS 17. Do not copy a newer sample into this target without that check. The default actor isolation for this project is nonisolated so the models stay usable from a ModelActor. UI types opt into @MainActor.",
        whyItExists: "Samples on the internet assume the SDK you installed, not the deployment target you promised.",
        whenToUse: "Before you paste any SwiftData snippet from a newer release.",
        sample: Samples.make("m9-sdk", "What this target calls", #"""
        import SwiftData

        // Called: ModelActor, PersistentIdentifier, ModelContext.save on iOS 17.
        // Not called: HistoryDescriptor, #Unique, #Index, sectioned queries.
        let importer = LessonBackgroundImporter(modelContainer: container)
        try await importer.renameLabRecord(id: identifier, to: title)
        """#, [
            ("ModelActor", "iOS 17. The importer is real."),
            ("Not called: HistoryDescriptor", "iOS 18 history stays out of the binary's source."),
            ("renameLabRecord", "The executed cross-actor edit.")
        ]),
        expectedBehavior: "The concurrency buttons run on the iOS 17 deployment target. There is no history UI.",
        experiment: "Use the rename button and confirm it does not mention history tokens or sections.",
        experimentHint: "The status talks about the identifier and a fresh fetch.",
        experimentSolution: "The feature you ran is the iOS 17 actor path. Newer APIs are named only in this lesson.",
        challenge: "How would you add an iOS 18 history dump without breaking an iOS 17 install?",
        challengeHint: "Availability.",
        challengeSolution: "Wrap the history fetch in if #available(iOS 18, *), and on iOS 17 show a short explanation instead of calling the API.",
        bugTitle: "Pasting an iOS 18 sample",
        bugCode: "let transactions = try context.fetchHistory(descriptor)",
        bugQuestion: "What happens at an iOS 17 deployment target?",
        bugDiagnosis: "The compiler rejects the call, or you have raised the deployment target without meaning to. Keep it behind availability or out of the target. This lesson quotes it as text, and the app does not compile that call.",
        mistakes: ["Equating the installed Xcode SDK with the deployment target.", "A silent bump of IPHONEOS_DEPLOYMENT_TARGET.", "Using default MainActor isolation and then being surprised the actor cannot construct models."],
        debuggingTips: ["Read the target's deployment setting before the snippet.", "Search the target for fetchHistory and #Unique. They should be absent.", "Keep sdkNote banners on the lessons that mention newer APIs."],
        quiz: [
            Quiz.make("m9h1", "This app's deployment target is:", ["iOS 17", "iOS 18 only", "iOS 26 only", "macOS 10.15"], correct: 0, "Newer symbols are not required to run the lab."),
            Quiz.make("m9h2", "History APIs are:", ["Called on launch", "iOS 18 and not called here", "The only way to save", "Required for ModelActor"], correct: 1, "Named, not compiled."),
            Quiz.make("m9h3", "Default actor isolation in this project is:", ["MainActor, so models are UI-bound", "nonisolated, with @MainActor on UI types", "The ModelActor for every class", "Unspecified and unsafe"], correct: 1, "The setting is deliberate so the importer can construct models.")
        ],
        playground: .concurrency,
        sdkNote: "Executed: iOS 17 ModelActor and persistent identifiers. Not executed: iOS 18 history, #Index, #Unique, and newer sectioned query APIs."
    )
}
