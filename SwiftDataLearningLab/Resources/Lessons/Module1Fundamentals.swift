import Foundation

enum Module1Fundamentals {
    static let id = "fundamentals"

    static let module = LearningModule(
        id: id,
        title: "SwiftData fundamentals",
        summary: "What the framework is, how @Model, ModelContainer, and ModelContext divide the work, and when a value becomes a stored row.",
        level: .beginner,
        order: 1,
        lessons: [whatIs, modelMacro, creatingModels, container, context, appEntry, lifecycle]
    )

    static let whatIs = Lesson.make(
        id: "m1-what-swiftdata-is",
        moduleID: id,
        title: "What SwiftData is",
        summary: "A persistence framework that stores model classes and observes them from SwiftUI.",
        concept: "SwiftData is Apple's object graph and persistence API introduced for Swift. You describe models with @Model, open a ModelContainer for a schema, and read or write through a ModelContext. The default store is SQLite in the app sandbox. SwiftUI's @Query observes that context. Core Data is the older stack underneath much of the same storage technology: it uses NSManagedObject, NSPersistentContainer, and NSPredicate. SwiftData does not require an .xcdatamodeld file. This lab never imports Core Data and does not fall back to it.",
        whyItExists: "Core Data's modeling file, context queue rules, and Objective-C class generation are a poor fit for Swift value semantics and SwiftUI. SwiftData keeps the durable store and change tracking, and exposes them as Swift types the compiler can check.",
        whenToUse: "Use it for on-device records: notes, tasks, expenses, caches of user-created content. Do not use it as a network client. A server API is a separate layer that may write into SwiftData after a response arrives.",
        sample: Samples.make("m1-what", "Three states of a Book", #"""
        import SwiftData

        // A Book() value is only an object in memory.
        let draft = Book(title: "Local first", authorName: "Ada", publicationYear: 2024)

        // insert registers the object with a context. Other contexts cannot see it yet.
        modelContext.insert(draft)

        // save writes a transaction to the store. Relaunching the app can fetch it.
        try modelContext.save()
        """#, [
            ("A Book() value", "Init does not open a database and does not register the object."),
            ("modelContext.insert", "The context now tracks the instance. hasChanges becomes true."),
            ("modelContext.save", "The store receives the row. A new context attached to the same container can fetch it.")
        ]),
        expectedBehavior: "After Create in memory only, the book list stays unchanged. After Insert, hasChanges is true. After Save, hasChanges is false and the book appears in the list. Relaunching the app shows that same book.",
        experiment: "In the playground, create a book in memory, insert it, save it, then stop the app from Xcode and run it again.",
        experimentHint: "Use the three numbered buttons in order.",
        experimentSolution: "The book is absent from the list until it is inserted. It remains after relaunch only because save wrote the store file under Application Support.",
        challenge: "Explain, in your challenge notes, which object you would pass to a second screen: the Book instance, or its persistentModelID. Say why.",
        challengeHint: "The identifier outlives a particular context. The instance does not.",
        challengeSolution: "Pass persistentModelID, then call model(for:) in the destination context. The instance is tied to the context that inserted or fetched it.",
        bugTitle: "Treating init as a save",
        bugCode: "let book = Book(title: \"Notes\", authorName: \"Ada\", publicationYear: 2024)\n// The developer expects this book to appear after relaunch.",
        bugQuestion: "Why is the book gone after relaunch?",
        bugDiagnosis: "Init never contacts the store. Without insert and save, the object dies with the process.",
        mistakes: [
            "Assuming SwiftData replaces networking.",
            "Importing Core Data out of habit and maintaining two stacks.",
            "Expecting a brand-new Book() to be fetched by @Query."
        ],
        debuggingTips: [
            "Print modelContext.hasChanges before and after save.",
            "Fetch from a second ModelContext. If it cannot see the row, the first context never saved.",
            "Read the container error screen. A failed launch is often a schema mismatch, not a SwiftUI bug."
        ],
        quiz: [
            Quiz.make("m1q1", "What does SwiftData persist by default?", ["A remote REST resource", "Model instances written to a local store", "Only UserDefaults keys", "Swift source files"], correct: 1, "The default configuration is a local store, SQLite, inside the app sandbox."),
            Quiz.make("m1q2", "Which stack does this app use for the lab records?", ["Core Data managed objects", "SwiftData only", "Both, with SwiftData as a wrapper you still query through NSFetchRequest", "CloudKit directly"], correct: 1, "The target imports SwiftData. There is no NSPersistentContainer."),
            Quiz.make("m1q3", "When does a new model instance become visible to a different ModelContext?", ["As soon as init returns", "When it is inserted into the first context", "After the first context saves", "When the view redraws"], correct: 2, "Insert is local to one context. Save publishes the transaction to the store.")
        ],
        playground: .lifecycle
    )

    static let modelMacro = Lesson.make(
        id: "m1-model-macro",
        moduleID: id,
        title: "The @Model macro",
        summary: "How the macro turns a class into a persistent, observable model.",
        concept: "@Model is an attached macro. It makes the class conform to PersistentModel and Observable, adds backing data, and records stored properties as schema metadata. The class must be a final class because SwiftData does not support model inheritance. The macro, not the developer, implements identity: persistentModelID is the identifier, so you should not declare your own id property. Stored properties become columns or relationships. Computed properties and @Transient properties do not.",
        whyItExists: "Without a macro, every model would hand-write observation, persistent backing, and schema metadata. The macro keeps the source readable and still gives the compiler a concrete schema.",
        whenToUse: "Put @Model on every class that should be a row in the store. Do not put it on view models, coordinators, or plain value types such as ItemMetadata.",
        sample: Samples.make("m1-macro", "A model the macro can expand", #"""
        import SwiftData

        // @Model registers Book as a PersistentModel and an Observable class.
        @Model
        final class Book {
            // Stored properties are columns. Predicates can use these key paths.
            var title: String
            var publicationYear: Int

            init(title: String, publicationYear: Int) {
                self.title = title
                self.publicationYear = publicationYear
            }
        }
        """#, [
            ("@Model", "The macro supplies schema metadata, observation, and persistent identity."),
            ("final class Book", "final prevents subclassing, which the schema cannot represent."),
            ("var title: String", "This is a column. A computed title would not be stored or queryable.")
        ]),
        expectedBehavior: "The Book type in this target is expanded by the same macro. Creating and saving one in the playground produces a row the next screen can fetch.",
        experiment: "Save a book, then open the query playground and run a fetch. The title you typed is a real column.",
        experimentHint: "The query playground reads the same Book model.",
        experimentSolution: "FetchDescriptor and @Query both read the schema the macro generated from the stored properties.",
        challenge: "Name one member you would keep as a computed property on Book, and one you would store. Write the reason in the challenge notes.",
        challengeHint: "Derived display text is a poor column. Facts you filter on are good columns.",
        challengeSolution: "Store title and publicationYear. Compute a display line such as \"\\(title) (\\(publicationYear))\" so the schema does not duplicate derived text.",
        bugTitle: "Adding a property named id",
        bugCode: "@Model\nfinal class Book {\n    var id: UUID\n    var title: String\n}",
        bugQuestion: "Why does this fight the macro?",
        bugDiagnosis: "PersistentModel already exposes id as the persistentModelID. A second stored id property collides with that requirement. Use a name such as identifier if you need a UUID column.",
        mistakes: [
            "Marking a struct with @Model.",
            "Subclassing a model.",
            "Expecting a computed property to appear in the store."
        ],
        debuggingTips: [
            "If the macro diagnostic mentions inheritance or id, remove the subclass or rename the property.",
            "Jump to the generated interface only after the source model is valid. The macro output is noisy.",
            "Confirm the type is listed in AppModelContainer.modelTypes or it will not be in the app schema."
        ],
        quiz: [
            Quiz.make("m1b1", "What does @Model require the type to be?", ["A struct", "An actor", "A final class", "An NSManagedObject subclass"], correct: 2, "SwiftData models are classes, and they are final because inheritance is unsupported."),
            Quiz.make("m1b2", "Which member becomes a column?", ["A stored property", "A computed property", "A method", "A @Transient property"], correct: 0, "Only stored, non-transient properties are part of the schema."),
            Quiz.make("m1b3", "Where does persistent identity come from?", ["A UUID you must name id", "The macro's persistentModelID", "The Swift file name", "The row's title"], correct: 1, "Do not declare id yourself. The persistent identifier is the identity.")
        ],
        playground: .lifecycle
    )

    static let creatingModels = Lesson.make(
        id: "m1-creating-models",
        moduleID: id,
        title: "Creating model classes",
        summary: "Choose properties, write an initializer, and leave relationships explicit.",
        concept: "A model class lists the facts you need after relaunch. Give every stored property a value in init. Optionals represent absence. Arrays of String, Int, and other supported values are stored as collections. Arrays of other models are relationships and need @Relationship when you care about the delete rule or the inverse. Keep the class small. A 40-property model is hard to migrate.",
        whyItExists: "The schema is derived from these declarations. A casual property type today becomes a column you must migrate later.",
        whenToUse: "Create a model when the value has identity and a lifetime beyond one view. A search field's text does not need a model. A note the user expects tomorrow does.",
        sample: Samples.make("m1-create", "Book's stored shape", #"""
        import SwiftData

        @Model
        final class Book {
            var title: String
            var subtitle: String?
            var authorName: String
            var publicationYear: Int
            var createdAt: Date

            init(title: String, subtitle: String? = nil, authorName: String, publicationYear: Int, createdAt: Date = .now) {
                self.title = title
                self.subtitle = subtitle
                self.authorName = authorName
                self.publicationYear = publicationYear
                self.createdAt = createdAt
            }
        }
        """#, [
            ("var subtitle: String?", "nil is a real state. Do not use an empty string to mean missing."),
            ("createdAt: Date = .now", "The default applies when you call this init, not when an old row is fetched."),
            ("self.title = title", "Every stored property is assigned. The macro does not invent values for you inside a custom init.")
        ]),
        expectedBehavior: "Saving a book without a subtitle stores nil. The list shows title, author, and year. The subtitle is available on the instance even though the list does not print it.",
        experiment: "Save two books, one with a mental note that subtitle was left nil. Fetch them in the query playground with a minimum year of 1900.",
        experimentHint: "The initializer default for subtitle is nil.",
        experimentSolution: "Both rows exist. The missing subtitle did not block the insert.",
        challenge: "Add a reason you would not store a UIColor or a SwiftUI View on Book.",
        challengeHint: "The schema only accepts a documented set of value types.",
        challengeSolution: "Views and UIKit colors are not persistent property types. Store a stable fact, such as a color name string, and map it to a Color in the view.",
        bugTitle: "Uninitialized stored property",
        bugCode: "@Model\nfinal class Book {\n    var title: String\n    init() {}\n}",
        bugQuestion: "What fails?",
        bugDiagnosis: "title has no value. The compiler requires every stored property to be initialized. Fetching later does not fix an invalid init.",
        mistakes: [
            "Using a class for a property that should be a Codable struct.",
            "Stuffing view state into the model.",
            "Giving two concepts the same model because it was faster."
        ],
        debuggingTips: [
            "Read the initializer when a preview crashes. A missing assignment is a compile error, not a runtime mystery.",
            "Start with non-optional properties and add optionals when absence is meaningful.",
            "Check modelTypes when a new class saves in a unit test container but not in the app."
        ],
        quiz: [
            Quiz.make("m1c1", "What does a custom init have to do?", ["Register the object with the context", "Assign stored properties", "Call save()", "Create the ModelContainer"], correct: 1, "Registration is insert. Durability is save. Init only builds the instance."),
            Quiz.make("m1c2", "What does an optional property mean?", ["The column is unique", "The value may be absent", "The property is transient", "The relationship cascades"], correct: 1, "Optional is about absence, not uniqueness or delete behavior."),
            Quiz.make("m1c3", "When does a default parameter on init apply?", ["Every time the row is fetched", "Only when that init is called", "During lightweight migration automatically", "When autosave runs"], correct: 1, "Fetch materializes stored values. It does not re-run your init arguments.")
        ],
        playground: .lifecycle
    )

    static let container = Lesson.make(
        id: "m1-model-container",
        moduleID: id,
        title: "ModelContainer",
        summary: "The object that owns the schema, the store file, and the main context.",
        concept: "ModelContainer is the app's connection to a store. You build it with a Schema and a ModelConfiguration. The configuration chooses the file URL, whether the store is memory-only, and whether CloudKit is involved. This app passes cloudKitDatabase: .none because the SDK default is .automatic. One container can vend many ModelContext values. They share the store and do not share unsaved changes. The container's mainContext is main-actor isolated and is the context SwiftUI installs in the environment when you call .modelContainer.",
        whyItExists: "Something has to own the file, the schema, and the migration plan. Views should not open SQLite themselves.",
        whenToUse: "Create one container at launch for the user-facing store. Create additional containers for tests, previews, and the migration demo so those jobs cannot rewrite LearningLab.store.",
        sample: Samples.make("m1-container", "Open a local container", #"""
        import SwiftData

        let schema = Schema([Book.self, LabRecord.self])
        let configuration = ModelConfiguration(
            "LearningLab",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        """#, [
            ("Schema([Book.self, LabRecord.self])", "Only listed types belong to this store. The array initializer is the iOS 17 form."),
            ("cloudKitDatabase: .none", "The current SDK defaults this to .automatic. The lab sets none so it stays offline."),
            ("ModelContainer(for: schema", "A thrown error here usually means the file's schema does not match the models.")
        ]),
        expectedBehavior: "The persistence playground prints the store URL. An in-memory container can save a book that never shows up in the main list.",
        experiment: "Run Prove an in-memory store is isolated. Compare the two counts.",
        experimentHint: "The button lives on persistence lessons and on this playground when you open a persistence lesson. From this lesson, switch to the persistence module if you want that button, or trust the main list: creating a memory container does not add a row here.",
        experimentSolution: "The memory container's count increases. The main store count does not. They are different containers, even though both know the Book type.",
        challenge: "Write down two reasons the migration demo uses a temporary directory.",
        challengeHint: "The demo's schema is not the app schema.",
        challengeSolution: "The versioned note schema must not replace LearningLab.store, and a failed experiment must be deletable without erasing lesson progress.",
        bugTitle: "A container that silently asks for CloudKit",
        bugCode: "let configuration = ModelConfiguration(isStoredInMemoryOnly: false)",
        bugQuestion: "What is risky about the one-argument habit on this SDK?",
        bugDiagnosis: "The full initializer defaults cloudKitDatabase to .automatic and groupContainer to .automatic. Pass .none unless you have the entitlement and a compatible schema.",
        mistakes: [
            "Building a new container inside every view.",
            "Pointing tests at the app's store URL.",
            "Forgetting a model type in the schema and then inserting it anyway."
        ],
        debuggingTips: [
            "Log the configuration URL at launch.",
            "If launch fails, read ContainerErrorView before changing SwiftUI.",
            "Use makeInMemory() in tests and compare it with makeShared()."
        ],
        quiz: [
            Quiz.make("m1d1", "What does a ModelContainer own?", ["A single unsaved object", "The schema and the store", "The SwiftUI navigation path", "Only the main view"], correct: 1, "Contexts come from the container. The container owns the store."),
            Quiz.make("m1d2", "Why does this app pass cloudKitDatabase: .none?", ["CloudKit is illegal on iOS 17", "The SDK default is automatic, and this lab is offline", "none is faster at compile time", ".none deletes the store"], correct: 1, "Automatic would try to configure sync. The lab has no iCloud capability."),
            Quiz.make("m1d3", "Which models are in the app container?", ["Every @Model type in the module", "The types listed in the schema", "Only types marked public", "Types that have been inserted at least once"], correct: 1, "ScratchPad and the migration notes are compiled but left out of the app schema.")
        ],
        playground: .persistence
    )

    static let context = Lesson.make(
        id: "m1-model-context",
        moduleID: id,
        title: "ModelContext",
        summary: "The working set that tracks inserts, updates, deletes, and save.",
        concept: "ModelContext is the interface you actually call. insert, delete, fetch, save, rollback, and hasChanges all live here. The context SwiftUI gives the view is bound to the main actor. A second context created with ModelContext(container) has its own unsaved graph and the same store. autosaveEnabled defaults to true, so a view context may save without an explicit call. Turn it off when you need to prove that unsaved work disappears. ModelContext is not Sendable. This SDK marks sharing one across concurrency domains as unavailable.",
        whyItExists: "The container is long-lived and relatively heavy. A context is the unit of work: one graph of pending changes and one place to fetch.",
        whenToUse: "Use the environment context in views. Use a new context inside a ModelActor or a short-lived experiment. Do not stash the environment context in a background task.",
        sample: Samples.make("m1-context", "A context with autosave off", #"""
        import SwiftData

        let context = ModelContext(container)
        // Autosave would hide the lesson. This experiment saves only when asked.
        context.autosaveEnabled = false
        context.insert(LabRecord(title: "Draft", notes: "Not durable yet"))
        // hasChanges is true. A second context still cannot see the row.
        let pending = context.hasChanges
        try context.save()
        """#, [
            ("ModelContext(container)", "This context shares the store and not the other context's pending changes."),
            ("autosaveEnabled = false", "Without this, the system may save before you can observe the unsaved state."),
            ("context.hasChanges", "True after insert, update, or delete until save or rollback.")
        ]),
        expectedBehavior: "The CRUD playground's change line counts inserted, updated, and deleted models. The discard button shows a row that exists only before rollback.",
        experiment: "Open the CRUD playground, run the discard experiment, and read the three counts in the status banner.",
        experimentHint: "The button is labeled Run discard experiment.",
        experimentSolution: "The secondary context sees one row, rollback drops it to zero, and the main context never sees it because nothing was saved.",
        challenge: "Describe a bug that happens if a view model stores a ModelContext and a .task hops to a background executor before using it.",
        challengeHint: "The type is not Sendable.",
        challengeSolution: "The compiler should reject the hop. If you silence it, the context's executor and the background executor can interleave. Use a ModelActor with its own context instead.",
        bugTitle: "Fetching before insert on a different context",
        bugCode: "let other = ModelContext(container)\nother.insert(record)\nlet found = try modelContext.fetch(FetchDescriptor<LabRecord>())",
        bugQuestion: "Why can found be empty?",
        bugDiagnosis: "other has not saved. modelContext reads the store plus its own pending changes, not other's pending changes.",
        mistakes: [
            "Calling save on the wrong context.",
            "Leaving autosave on during a discard experiment and drawing the wrong conclusion.",
            "Holding a model fetched in context A and mutating it on context B."
        ],
        debuggingTips: [
            "Inspect insertedModelsArray, changedModelsArray, and deletedModelsArray.",
            "Call rollback() to drop the current unsaved graph.",
            "After a failed save, rollback before the next insert so the context is not stuck."
        ],
        quiz: [
            Quiz.make("m1e1", "Which object do you insert into?", ["ModelContainer", "ModelContext", "FetchDescriptor", "Schema"], correct: 1, "The container owns the store. The context tracks the insert."),
            Quiz.make("m1e2", "What does hasChanges mean?", ["The file is missing", "The context has unsaved inserts, updates, or deletes", "CloudKit is syncing", "The view is loading"], correct: 1, "It is the pending-transaction flag."),
            Quiz.make("m1e3", "Can you pass a ModelContext to another concurrency domain?", ["Yes, it is Sendable", "No. This SDK makes that sharing unavailable", "Only if autosave is on", "Only after save()"], correct: 1, "The conformance is explicitly unavailable: contexts cannot be shared across concurrency contexts.")
        ],
        playground: .crud
    )

    static let appEntry = Lesson.make(
        id: "m1-app-entry",
        moduleID: id,
        title: "Container in the app entry",
        summary: "Create the container once, then hand it to the WindowGroup.",
        concept: "The @main App type is the right owner for the long-lived container. SwiftDataLearningLabApp builds it in init with AppModelContainer.makeShared(). The WindowGroup applies .modelContainer, which puts that container's main context in the environment. Child views read it with @Environment(\\.modelContext) or @Query. If makeShared throws, the app shows ContainerErrorView instead of a blank screen. Previews call makeInMemory so a preview cannot dirty the real store.",
        whyItExists: "Creating the container inside a view body would reopen it on every render. Launch is the one place that runs once per process.",
        whenToUse: "Any SwiftUI app with a single user store. A document-based app can instead attach a container per document. This lab is not document-based.",
        sample: Samples.make("m1-app", "App entry used by this target", #"""
        import SwiftData
        import SwiftUI

        @main
        struct SwiftDataLearningLabApp: App {
            private let launch: Result<ModelContainer, Error>

            init() {
                launch = Result { try AppModelContainer.makeShared() }
            }

            var body: some Scene {
                WindowGroup {
                    switch launch {
                    case .success(let container):
                        RootView().modelContainer(container)
                    case .failure(let error):
                        ContainerErrorView(error: error)
                    }
                }
            }
        }
        """#, [
            ("try AppModelContainer.makeShared()", "One store for the process. Tests do not call this."),
            (".modelContainer(container)", "Installs the container for @Query and the environment context."),
            ("ContainerErrorView", "A schema mismatch surfaces here instead of trapping in a view.")
        ]),
        expectedBehavior: "If the store opens, you see the dashboard. If it cannot open, you see the error view and the store path.",
        experiment: "Read the store path in the persistence playground. Confirm it contains SwiftDataLearningLab and LearningLab.store.",
        experimentHint: "Application Support is inside the simulator's app sandbox, not the repository folder.",
        experimentSolution: "The path ends with SwiftDataLearningLab/LearningLab.store. That file is the durable lab.",
        challenge: "Why is fatalError a worse launch policy than ContainerErrorView for a learning app?",
        challengeHint: "The interesting failure is the schema error text.",
        challengeSolution: "fatalError hides the localized message. The error view shows it and tells you that a model change can strand an existing file.",
        bugTitle: "Container created in body",
        bugCode: "var body: some Scene {\n    WindowGroup {\n        RootView().modelContainer(try! AppModelContainer.makeShared())\n    }\n}",
        bugQuestion: "What goes wrong?",
        bugDiagnosis: "body can be evaluated again. You do not want a second container fighting over the same file. Build it in init and store it.",
        mistakes: [
            "Using try! and losing the error text.",
            "Forgetting .modelContainer and then watching every @Query stay empty.",
            "Calling makeShared() from a unit test."
        ],
        debuggingTips: [
            "If @Query is empty and a manual fetch in a test passes, check that the view has a container.",
            "Preview crashes that mention the store are often the shared URL. Switch the preview to makeInMemory().",
            "Keep the Result in a property so the scene does not reopen the file."
        ],
        quiz: [
            Quiz.make("m1f1", "Where is the app container created?", ["In every lesson view", "In the App init", "Inside @Query", "By the first insert"], correct: 1, "SwiftDataLearningLabApp.init calls makeShared once."),
            Quiz.make("m1f2", "What does .modelContainer provide?", ["A new schema", "The environment context and container for child views", "CloudKit entitlements", "A navigation path"], correct: 1, "Child views inherit that container."),
            Quiz.make("m1f3", "What container should a preview use?", ["makeShared()", "makeInMemory()", "The migration container", "No container"], correct: 1, "Previews must not write the learner's store.")
        ],
        playground: .persistence
    )

    static let lifecycle = Lesson.make(
        id: "m1-persistence-lifecycle",
        moduleID: id,
        title: "How an instance becomes a row",
        summary: "Memory, tracked by a context, and persisted in the store are three different states.",
        concept: "State 1: the instance exists only as a Swift object. @Query cannot see it, and relaunch cannot see it. State 2: insert has registered it. The same context's fetch includes it, hasChanges is true, and another context still cannot see it. State 3: save has committed a transaction. hasChanges is false, a new context can fetch the row, and the next process launch can too, as long as it opens the same store file. rollback() from state 2 returns you toward state 1 for those pending edits. Deleting the app deletes the file. A normal reinstall from Xcode usually keeps the sandbox, which is why old rows surprise you the next morning.",
        whyItExists: "Most SwiftData bugs are a confusion between these states. The API uses one class for all three, so the difference is not in the type system.",
        whenToUse: "Walk the three states whenever a row is missing, duplicated, or present only until the next launch.",
        sample: Samples.make("m1-life", "Observe the three states", #"""
        import SwiftData

        let book = Book(title: "States", authorName: "Ada", publicationYear: 2024)
        // State 1. modelContext.hasChanges does not include this object.
        let untracked = book.modelContext == nil

        modelContext.insert(book)
        // State 2. The object now has a context, and hasChanges is true.
        let tracked = book.modelContext != nil && modelContext.hasChanges

        try modelContext.save()
        // State 3. The identifier can be resolved by another context.
        let identifier = book.persistentModelID
        """#, [
            ("book.modelContext == nil", "A model reports the context that tracks it, if any."),
            ("modelContext.insert(book)", "Tracking starts here. The store file is unchanged."),
            ("book.persistentModelID", "Pass this identifier across actors only after save, when the store can resolve it.")
        ]),
        expectedBehavior: "The lifecycle playground status text names the state after each button. After save, relaunch keeps the book.",
        experiment: "Create, insert, and save one book. Force-quit the app, run it, and confirm the title is still listed.",
        experimentHint: "Stop the run in Xcode. Do not delete the app.",
        experimentSolution: "The row survives because state 3 wrote LearningLab.store. Deleting the app would remove it.",
        challenge: "A teammate says \"SwiftData autosaves, so I never need save().\" Give one case where that advice loses data.",
        challengeHint: "Autosave timing is not a transaction boundary you control.",
        challengeSolution: "A secondary context with work you must publish now, a ModelActor, or a flow that needs to handle a unique-constraint error before continuing. Explicit save is the boundary.",
        bugTitle: "Reading hasChanges on the wrong context",
        bugCode: "other.insert(book)\nprint(viewContext.hasChanges)",
        bugQuestion: "Why can the print be false while the book is still unsaved?",
        bugDiagnosis: "hasChanges is per context. other may have changes while viewContext does not.",
        mistakes: [
            "Equating \"the object exists\" with \"the row exists\".",
            "Passing a persistent identifier to another context before the first save.",
            "Deleting the app and expecting the lesson data to remain."
        ],
        debuggingTips: [
            "Check model.modelContext and context.hasChanges together.",
            "Fetch with a brand-new context when you need to know what the store contains.",
            "Look at the store URL before you go hunting through SwiftUI."
        ],
        quiz: [
            Quiz.make("m1g1", "Which state survives relaunch?", ["Init only", "Inserted but not saved", "Saved", "Any object the view still holds"], correct: 2, "Only a committed transaction is in the file the next process opens."),
            Quiz.make("m1g2", "What does rollback do?", ["Deletes the store file", "Discards unsaved changes in that context", "Pushes to CloudKit", "Compacts the SQLite file"], correct: 1, "rollback is the context's undo of pending work, not a file delete."),
            Quiz.make("m1g3", "Why can a reinstall still show old books?", ["The catalog is hard-coded", "Xcode often preserves the app sandbox", "Books are stored in the git repo", "@Query invents sample data"], correct: 1, "The store file lives in the container, and reinstall does not always wipe it.")
        ],
        playground: .lifecycle
    )
}
