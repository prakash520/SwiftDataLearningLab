import Foundation

enum Module6Persistence {
    static let id = "persistence"
    static let module = LearningModule(
        id: id,
        title: "Persistence and migrations",
        summary: "Memory versus disk, configuration, schema versions, and a real two-version migration in a temporary file.",
        level: .intermediate,
        order: 6,
        lessons: [memory, configuration, location, schemaChanges, versioned, plan, lightweight, testing, breakage]
    )

    static let memory = Lesson.make(
        id: "m6-memory-vs-disk", moduleID: id, title: "In-memory versus persistent storage",
        summary: "isStoredInMemoryOnly builds a store that dies with the container.",
        concept: "A persistent configuration writes LearningLab.store. An in-memory configuration keeps the same schema in process memory. Tests and previews use makeInMemory so they cannot modify the learner's file. The migration demo uses a third option: a real file in a temporary directory that the function deletes. In-memory is not a different API. It is the same ModelContainer with a different configuration. Rows saved there are invisible to the app container. That isolation is the experiment.",
        whyItExists: "You need the real schema in tests without sharing the real file.",
        whenToUse: "Tests, previews, and throwaway demos. Never as the only store for data the user expects tomorrow.",
        sample: Samples.make("m6-mem", "A memory container beside the app store", #"""
        import SwiftData

        let memory = try AppModelContainer.makeInMemory()
        let memoryContext = ModelContext(memory)
        memoryContext.autosaveEnabled = false
        memoryContext.insert(Book(title: "Memory only", authorName: "Lab", publicationYear: 2024))
        try memoryContext.save()
        """#, [
            ("makeInMemory()", "Same schema, no LearningLab.store URL."),
            ("memoryContext.insert", "This insert cannot appear in the app @Query."),
            ("try memoryContext.save()", "Commits inside the memory container only.")
        ]),
        expectedBehavior: "The isolation button reports a memory count of at least 1 and an unchanged main-store count.",
        experiment: "Run Prove an in-memory store is isolated.",
        experimentHint: "The persistence playground shows the two counts.",
        experimentSolution: "Main count before and after are equal. The memory container saw its own book.",
        challenge: "Why is an in-memory test not proof that the app's file migrates?",
        challengeHint: "Empty memory has no old schema.",
        challengeSolution: "There is no previous file. Migration tests must write version 1 to a real temporary URL and open version 2 on that URL.",
        bugTitle: "Tests using makeShared",
        bugCode: "let container = try AppModelContainer.makeShared()",
        bugQuestion: "What can this test destroy?",
        bugDiagnosis: "The learner's LearningLab.store, including progress and demo rows. Tests must call makeInMemory or a private temporary URL.",
        mistakes: ["Assuming memory-only is faster and therefore fine for the shipping app.", "Sharing one in-memory container across tests that mutate it.", "Forgetting autosave off and depending on timing."],
        debuggingTips: ["Print configuration.isStoredInMemoryOnly.", "Give each test its own container.", "Assert main count is unchanged in the isolation test."],
        quiz: [
            Quiz.make("m6a1", "In-memory rows are visible to the app @Query?", ["Yes", "No", "Only after relaunch", "Only if CloudKit is on"], correct: 1, "Different container, different store."),
            Quiz.make("m6a2", "Previews should use:", ["makeShared", "makeInMemory", "The migration file", "UserDefaults"], correct: 1, "Previews must not dirty the real store."),
            Quiz.make("m6a3", "A temporary file migration is:", ["Memory only", "A real store at a disposable URL", "The app store", "A CloudKit zone"], correct: 1, "Migration needs a file so a second container can open it.")
        ],
        playground: .persistence
    )

    static let configuration = Lesson.make(
        id: "m6-configuration", moduleID: id, title: "Model container configuration",
        summary: "URL, allowsSave, group container, and CloudKit are configuration, not model code.",
        concept: "ModelConfiguration is the value you pass to ModelContainer. This app sets an explicit URL, allowsSave true, and cloudKitDatabase .none. The in-memory helper also sets groupContainer .none, because this SDK defaults the group container and CloudKit database to .automatic. Automatic CloudKit is a syncing configuration. Automatic group container looks for an app group. The lab has neither entitlement. allowsSave false is how you open a store for a read-only experiment. The shipping container leaves saves enabled. Configuration is not the schema. The schema is the list of model types. You can open the same schema with two configurations and get two stores.",
        whyItExists: "The models should not know whether they live in memory, in Application Support, or in iCloud.",
        whenToUse: "At container construction, and only there. Views should not build configurations.",
        sample: Samples.make("m6-config", "The app configuration", #"""
        import SwiftData

        let configuration = ModelConfiguration(
            "LearningLab",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        """#, [
            ("url: storeURL", "An explicit file, so the persistence screen can show the path."),
            ("cloudKitDatabase: .none", "Overrides the SDK default of .automatic."),
            ("allowsSave: true", "The lab can commit. A read-only tool would pass false.")
        ]),
        expectedBehavior: "The playground path matches storeURL(), and the banner says CloudKit is none.",
        experiment: "Read the path and the CloudKit line in the persistence playground.",
        experimentHint: "The path contains SwiftDataLearningLab.",
        experimentSolution: "The file is local. Nothing in the configuration names a CloudKit container.",
        challenge: "What would you change to open a second empty store for a destructive experiment without touching the app file?",
        challengeHint: "A different URL or memory.",
        challengeSolution: "Pass a temporary URL or isStoredInMemoryOnly, with the same or a smaller schema. Do not reuse storeURL().",
        bugTitle: "Default configuration",
        bugCode: "let configuration = ModelConfiguration(\"LearningLab\", schema: schema)",
        bugQuestion: "Which defaults are dangerous on this SDK?",
        bugDiagnosis: "groupContainer and cloudKitDatabase default to .automatic. Pass .none unless the entitlements exist.",
        mistakes: ["Building the configuration in a view.", "Reusing the app URL for tests.", "Setting allowsSave false and wondering why save throws."],
        debuggingTips: ["Print the configuration URL and cloudKitDatabase.", "If launch asks for iCloud, you left automatic on.", "Keep one function, makeShared, as the only persistent opener."],
        quiz: [
            Quiz.make("m6b1", "cloudKitDatabase .none means:", ["Delete iCloud", "Do not configure sync", "Sync in the foreground only", "Use the public database"], correct: 1, "The store stays local."),
            Quiz.make("m6b2", "allowsSave false is for:", ["Faster queries", "A container that must not commit", "Migrations only", "Unique constraints"], correct: 1, "Saves are rejected."),
            Quiz.make("m6b3", "Schema and configuration are:", ["The same object", "Types versus where those types are stored", "Both view models", "Both predicates"], correct: 1, "Schema is models. Configuration is the store.")
        ],
        playground: .persistence
    )

    static let location = Lesson.make(
        id: "m6-storage-location", moduleID: id, title: "Storage location and lifetime",
        summary: "The file lives in Application Support. Deleting the app deletes it.",
        concept: "storeURL() creates Application Support/SwiftDataLearningLab/LearningLab.store. That directory is inside the app sandbox. It is not in the git repository. A normal Xcode reinstall often keeps the sandbox, so yesterday's books remain. Deleting the app removes the sandbox. The simulator can be erased from the Device menu, which also removes it. SwiftData may create sidecar files beside the store. The migration demo deletes a whole temporary directory so those sidecars go away. Lesson progress is in the same file as the demo rows. Resetting demo data does not reset progress, and the reverse is also true. Read the confirmation copy before you tap either button.",
        whyItExists: "People look for the database in the project folder and conclude saves are broken.",
        whenToUse: "When a relaunch shows unexpected rows, or when a schema change will not open.",
        sample: Samples.make("m6-url", "Application Support URL", #"""
        import Foundation

        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let url = base
            .appendingPathComponent("SwiftDataLearningLab", isDirectory: true)
            .appendingPathComponent("LearningLab.store")
        """#, [
            (".applicationSupportDirectory", "Sandbox location, not the repository."),
            ("LearningLab.store", "One file for progress and demo models.")
        ]),
        expectedBehavior: "The persistence playground shows a simulator path ending in LearningLab.store.",
        experiment: "Copy the path from the playground. Relaunch and confirm the path is stable.",
        experimentHint: "It will not be under Desktop/Project.",
        experimentSolution: "The same sandbox path returns. The file survived the relaunch.",
        challenge: "Which reset button keeps your lesson checkboxes?",
        challengeHint: "Progress overview has two destructive buttons.",
        challengeSolution: "Reset demo data. Reset lesson progress is the one that clears checkboxes.",
        bugTitle: "Looking in the repo",
        bugCode: "// searching the Xcode project for LearningLab.store",
        bugQuestion: "Why is the file not there?",
        bugDiagnosis: "The store is in the app container. The project only contains source.",
        mistakes: ["Committing a store file.", "Deleting the app to clear one book.", "Assuming reinstall cleared the schema."],
        debuggingTips: ["Read the path from the playground.", "Use the in-app reset before deleting the app.", "If the container will not open, then delete the app or that file."],
        quiz: [
            Quiz.make("m6c1", "The store file is in:", ["The git repo", "Application Support in the sandbox", "iCloud always", "The asset catalog"], correct: 1, "storeURL() builds that path."),
            Quiz.make("m6c2", "Deleting the app:", ["Keeps the store", "Deletes the sandbox, including the store", "Only deletes progress", "Migrates to version 2"], correct: 1, "The file's lifetime is the app container's lifetime."),
            Quiz.make("m6c3", "Xcode reinstall often:", ["Wipes the sandbox", "Keeps the sandbox", "Moves the file into the repo", "Turns on CloudKit"], correct: 1, "Old rows surviving a rebuild is normal.")
        ],
        playground: .persistence
    )

    static let schemaChanges = Lesson.make(
        id: "m6-schema-changes", moduleID: id, title: "Schema changes",
        summary: "The store remembers the schema it was created with.",
        concept: "The first successful launch writes a schema into the store. The next launch compares the compiled models with that schema. Adding a non-optional property, renaming a property, changing a type, or changing uniqueness can make ModelContainer throw. The app then shows ContainerErrorView instead of the dashboard. During development you may delete the app. That is a reset, not a migration. Users cannot delete their data because you renamed a property. A change that is safe in an empty in-memory test can still break the on-disk file. Treat every stored-property edit as a migration problem once a store exists.",
        whyItExists: "The file is durable. The source code moves faster than the file.",
        whenToUse: "Before you edit a property on a model that has shipped, or even one that you have been using locally for a week.",
        sample: Samples.make("m6-change", "A new stored property is a schema change", #"""
        import SwiftData

        @Model
        final class Note {
            var title: String
            var body: String
            var isPinned: Bool
            // Adding wordCount later changes the schema of existing files.
            init(title: String, body: String, isPinned: Bool = false) {
                self.title = title
                self.body = body
                self.isPinned = isPinned
            }
        }
        """#, [
            ("var isPinned: Bool", "This column is part of the schema that was written on first launch."),
            ("Adding wordCount later", "Existing files do not grow a column just because the source changed.")
        ]),
        expectedBehavior: "If you add a property without a plan, the next launch can show the container error and the store path.",
        experiment: "Read ContainerErrorView's copy in the app entry file and say which user action it recommends during development.",
        experimentHint: "It mentions deleting the app or the store file.",
        experimentSolution: "That is the development escape hatch. It is not the user-facing migration.",
        challenge: "Name a change that looks small and still breaks an existing store.",
        challengeHint: "Renames and new non-optionals.",
        challengeSolution: "Renaming body to contents, or adding a non-optional wordCount, changes the schema the file was created with.",
        bugTitle: "Editing a model and rerunning",
        bugCode: "var title: String\nvar contents: String // was body",
        bugQuestion: "Why did the app stop launching?",
        bugDiagnosis: "The store still has body. The model now wants contents. Without a migration plan or a deleted file, the container throws.",
        mistakes: ["Testing the change only in memory.", "Telling users to reinstall.", "Renaming for style on a shipped model."],
        debuggingTips: ["Read the launch error before you change SwiftUI.", "Keep a copy of the store when you practice migrations.", "Prefer adding a property with a default over a rename, then migrate the data."],
        quiz: [
            Quiz.make("m6d1", "The store remembers:", ["Only the last fetch", "The schema it was created with", "Your git branch", "The view hierarchy"], correct: 1, "Launch compares compiled models with that schema."),
            Quiz.make("m6d2", "Deleting the app during development:", ["Is a migration", "Throws away the file", "Renames columns", "Enables CloudKit"], correct: 1, "Useful locally. Not a user migration."),
            Quiz.make("m6d3", "An in-memory test of a new property:", ["Proves old files open", "Does not prove old files open", "Rewrites LearningLab.store", "Runs the migration plan always"], correct: 1, "There is no old file.")
        ],
        playground: .persistence
    )

    static let versioned = Lesson.make(
        id: "m6-versioned-schemas", moduleID: id, title: "Versioned schemas",
        summary: "VersionedSchema names one generation of the models.",
        concept: "A VersionedSchema is a type that publishes a versionIdentifier and the model types in that generation. NotesSchemaV1 is version 1.0.0 and contains LabNote with title and body. NotesSchemaV2 is version 2.0.0 and contains LabNote with title, body, and wordCount. The nested class names match so the migration can treat them as the same entity across versions. These types are not in AppModelContainer.modelTypes. Schema(versionedSchema:) builds a Schema for one generation. You open a container with that schema when you want that generation and no other.",
        whyItExists: "The live @Model classes are only the latest source. A migration needs both generations in the program at once.",
        whenToUse: "As soon as an on-disk schema must change and you cannot delete the user's file.",
        sample: Samples.make("m6-ver", "Two versions of LabNote", #"""
        import SwiftData

        enum NotesSchemaV1: VersionedSchema {
            static var versionIdentifier = Schema.Version(1, 0, 0)
            static var models: [any PersistentModel.Type] { [LabNote.self] }
            @Model final class LabNote {
                var title: String
                var body: String
                init(title: String, body: String) {
                    self.title = title
                    self.body = body
                }
            }
        }
        """#, [
            ("VersionedSchema", "A named generation, not the app's current container."),
            ("Schema.Version(1, 0, 0)", "The identifier the plan orders."),
            ("@Model final class LabNote", "Nested so version 2 can declare its own LabNote.")
        ]),
        expectedBehavior: "The migration button writes V1 notes, including a title with surrounding spaces, then opens V2.",
        experiment: "Run the migration demo and look at the written titles versus the migrated titles.",
        experimentHint: "Fetching is written with spaces. The migrated title is trimmed.",
        experimentSolution: "V1 stored the padded title. V2 shows the trimmed title because willMigrate ran.",
        challenge: "Why are these models absent from the app schema?",
        challengeHint: "Two LabNote generations.",
        challengeSolution: "The app store is a different schema. Putting both generations in it would not be the user's notes, and it would confuse the main container.",
        bugTitle: "Editing the live model and calling it a version",
        bugCode: "// Changed Note in place and did not add VersionedSchema",
        bugQuestion: "What is missing?",
        bugDiagnosis: "There is no named previous generation for a plan to migrate from. The container just sees an incompatible file.",
        mistakes: ["Reusing the app's Note type as V1 and V2.", "Forgetting versionIdentifier order.", "Shipping the migration types in the main schema."],
        debuggingTips: ["Keep V1 frozen. Do not tidy it.", "Open V1 explicitly when seeding the old file.", "Use a temporary directory so a failed plan does not touch progress."],
        quiz: [
            Quiz.make("m6e1", "VersionedSchema supplies:", ["A SwiftUI view", "A version and the models in that generation", "A CloudKit zone", "A predicate"], correct: 1, "The plan uses those generations."),
            Quiz.make("m6e2", "NotesSchemaV1 is in the app container?", ["Yes", "No", "Only in Release", "Only after the demo"], correct: 1, "It is reserved for the migration lab."),
            Quiz.make("m6e3", "Matching the nested class name LabNote helps:", ["SwiftUI", "The migration treat both generations as one entity", "Autosave", "Uniqueness"], correct: 1, "Different names are different entities.")
        ],
        playground: .migration,
        sdkNote: "VersionedSchema and SchemaMigrationPlan are iOS 17 APIs. The lab uses them. It does not use iOS 18 history or iOS 26 sectioned query types."
    )

    static let plan = Lesson.make(
        id: "m6-migration-plan", moduleID: id, title: "SchemaMigrationPlan",
        summary: "The plan lists schemas in order and the stage between each pair.",
        concept: "A SchemaMigrationPlan has schemas from oldest to newest and a stages array. NotesMigrationPlan lists V1 then V2 and one custom stage. You pass the plan to ModelContainer when opening the newer schema on a file that might be older. You do not pass it when writing a fresh V1 file, or the V1 container is not a migration. The container walks stages until the file matches the schema you asked to open. One hop needs one stage. Two hops need two stages, in order. The plan is a type, not a row in the store.",
        whyItExists: "Something must order the generations. Ad hoc if-statements in App.init are not a migration.",
        whenToUse: "Any time an existing file should survive a schema change.",
        sample: Samples.make("m6-plan", "Plan wiring", #"""
        import SwiftData

        enum NotesMigrationPlan: SchemaMigrationPlan {
            static var schemas: [any VersionedSchema.Type] {
                [NotesSchemaV1.self, NotesSchemaV2.self]
            }
            static var stages: [MigrationStage] { [migrateV1toV2] }
        }
        """#, [
            ("schemas:", "Oldest first. The order is the history."),
            ("stages:", "One stage for the single hop from V1 to V2.")
        ]),
        expectedBehavior: "Opening the V2 container with this plan migrates the temporary V1 file instead of throwing a schema mismatch.",
        experiment: "Run the demo twice. Each run uses a new temporary directory, so each is a fresh V1 file.",
        experimentHint: "The result lists two migrated notes.",
        experimentSolution: "Each run creates, migrates, and deletes its own directory. The app store is untouched.",
        challenge: "What would you add to the plan to go from V2 to a V3?",
        challengeHint: "Another schema and another stage.",
        challengeSolution: "Append NotesSchemaV3 to schemas and append a stage whose fromVersion is V2 and toVersion is V3. Do not rewrite the V1 to V2 stage.",
        bugTitle: "Stages out of order",
        bugCode: "static var schemas: [any VersionedSchema.Type] { [NotesSchemaV2.self, NotesSchemaV1.self] }",
        bugQuestion: "Why is newest-first wrong?",
        bugDiagnosis: "The plan walks forward from the file's version. V1 has to appear before V2.",
        mistakes: ["Passing the plan when creating the baseline file.", "A stage that skips a version.", "Migrating the app store from the playground."],
        debuggingTips: ["Log the URL before and after.", "If the container throws, the stage does not cover the file's version.", "Keep the plan in one type so the order is reviewable."],
        quiz: [
            Quiz.make("m6f1", "schemas should be ordered:", ["Newest first", "Oldest first", "Alphabetically", "It does not matter"], correct: 1, "Migration walks forward."),
            Quiz.make("m6f2", "The V1 writer container uses the plan?", ["Yes", "No", "Only on failure", "Only in tests"], correct: 1, "It creates that version directly."),
            Quiz.make("m6f3", "A second hop needs:", ["A replaced first stage", "An additional stage", "A new app target", "CloudKit"], correct: 1, "Do not rewrite history. Append.")
        ],
        playground: .migration
    )

    static let lightweight = Lesson.make(
        id: "m6-lightweight-custom", moduleID: id, title: "Lightweight and custom stages",
        summary: "Lightweight adds a column the store understands. Custom code fixes the values.",
        concept: "MigrationStage.lightweight is for changes the store can apply by itself, typically adding an optional property or a property with a default. The default has to be on the stored property, as in `var wordCount: Int = 0`. A default only on init does not fill rows already in the file, and the container then fails to open. Lightweight will not compute a word count. MigrationStage.custom gives you willMigrate and didMigrate. willMigrate runs against the old models. didMigrate runs against the new models. The lab's stage is custom even though adding wordCount with a property default could be lightweight, because the lesson needs both hooks: trim titles before the hop, then count words after the new property exists. Use lightweight when you truly have no data fixup. Use custom when the new column depends on old columns. Do not use custom to silently drop tables.",
        whyItExists: "Some changes are structural and some are data. One stage type cannot express both honestly.",
        whenToUse: "Lightweight for an added optional. Custom when you must transform values. A rename that lightweight cannot see needs custom or originalName.",
        sample: Samples.make("m6-stage", "willMigrate and didMigrate", #"""
        import SwiftData

        static let migrateV1toV2 = MigrationStage.custom(
            fromVersion: NotesSchemaV1.self,
            toVersion: NotesSchemaV2.self,
            willMigrate: { context in
                let notes = try context.fetch(FetchDescriptor<NotesSchemaV1.LabNote>())
                for note in notes {
                    note.title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                try context.save()
            },
            didMigrate: { context in
                let notes = try context.fetch(FetchDescriptor<NotesSchemaV2.LabNote>())
                for note in notes {
                    note.wordCount = note.body.split { $0.isWhitespace }.count
                }
                try context.save()
            }
        )
        """#, [
            ("willMigrate:", "V1 objects. Trimming happens before the new column is required."),
            ("didMigrate:", "V2 objects. wordCount exists here."),
            ("note.wordCount =", "A derived value lightweight migration would have left at the default 0.")
        ]),
        expectedBehavior: "Fetching's title loses its padding. SwiftData has 3 words. Use predicates has 2 words.",
        experiment: "Run the demo and check both word counts.",
        experimentHint: "Models and stores is three words. Use predicates is two.",
        experimentSolution: "didMigrate counted the body. The default of 0 did not remain.",
        challenge: "Which hook would you use to uppercase titles, and which to fill a new column from the body?",
        challengeHint: "Old objects versus new objects.",
        challengeSolution: "Uppercase in willMigrate if you want the V1 rows cleaned first. Fill the new column in didMigrate, because V1 has no such property.",
        bugTitle: "Counting words in willMigrate",
        bugCode: "willMigrate: { context in\n    let notes = try context.fetch(FetchDescriptor<NotesSchemaV1.LabNote>())\n    // note.wordCount = ...\n}",
        bugQuestion: "Why is wordCount unavailable here?",
        bugDiagnosis: "V1 LabNote has no wordCount. The new property exists in didMigrate.",
        mistakes: ["Using lightweight and expecting derived values.", "Forgetting to save inside the hook.", "Doing both a lightweight and a custom stage for the same hop."],
        debuggingTips: ["Print titles in willMigrate and word counts in didMigrate.", "If the count stays 0, didMigrate did not save.", "Keep the stage next to the two schema types."],
        quiz: [
            Quiz.make("m6g1", "Lightweight migration is enough when:", ["You must compute a value", "The store can add the column without help", "You are renaming every property", "You need CloudKit"], correct: 1, "Derived values need custom code."),
            Quiz.make("m6g2", "didMigrate sees:", ["Version 1 models", "Version 2 models", "SwiftUI views", "The main app schema"], correct: 1, "The new properties exist."),
            Quiz.make("m6g3", "willMigrate is the place to:", ["Read wordCount", "Clean old rows before the hop", "Open CloudKit", "Create the WindowGroup"], correct: 1, "The old shape is still what you have.")
        ],
        playground: .migration
    )

    static let testing = Lesson.make(
        id: "m6-testing-migrations", moduleID: id, title: "Testing migrations safely",
        summary: "Write V1, release the container, open V2, assert, delete the directory.",
        concept: "A migration test is a file test. Create a unique temporary directory, open a V1 container, insert known notes, save, and let that container and context deinit before opening the same URL with V2 and the plan. Two containers must not own one file at once. Assert the trimmed title and the word count. Delete the directory in defer, including sidecar files. Do not point this test at LearningLab.store. The unit test testCustomMigrationCopiesNotesAndCountsWords and the playground button share MigrationLab.runIsolatedDemo. If the demo throws, the playground shows the error and the app store is still whatever it was.",
        whyItExists: "A migration that only runs on your laptop's already-migrated store proves nothing.",
        whenToUse: "Every stage you ship. Run it on a copy of a real old store before you call it done.",
        sample: Samples.make("m6-test", "Isolated file demo", #"""
        import Foundation
        import SwiftData

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Notes.store")
        let written = try writeVersion1(at: storeURL)
        let migrated = try readVersion2(at: storeURL)
        """#, [
            ("temporaryDirectory", "Not Application Support, not the repo."),
            ("defer { try? FileManager.default.removeItem", "Sidecars live in the directory, so the directory goes."),
            ("readVersion2", "Opens the same URL with the plan after V1 has been released.")
        ]),
        expectedBehavior: "The button finishes with two summaries. The app's books and progress remain.",
        experiment: "Note a book title, run the migration demo, and confirm the book is still in the lifecycle list.",
        experimentHint: "The demo uses its own directory.",
        experimentSolution: "The book is untouched. The demo file has already been deleted.",
        challenge: "Why must the V1 container be released before V2 opens the URL?",
        challengeHint: "File ownership.",
        challengeSolution: "SQLite allows one owning container. The V1 function returns, its context and container deinit, and only then does V2 open the file.",
        bugTitle: "Migrating the live store in a test",
        bugCode: "let url = try AppModelContainer.storeURL()\ntry readVersion2(at: url)",
        bugQuestion: "What damage can this do?",
        bugDiagnosis: "It runs the note migration against the app schema's file, or fails and leaves that file locked or half-migrated. Use a temporary URL.",
        mistakes: ["Asserting only that the container opens, not the data.", "Deleting the directory before the assert.", "Reusing one directory between tests."],
        debuggingTips: ["On failure, log the URL and skip defer once so you can inspect the file.", "Assert exact titles and counts.", "Keep the demo function free of the main context."],
        quiz: [
            Quiz.make("m6h1", "A safe migration test uses:", ["LearningLab.store", "A unique temporary directory", "The preview container only", "iCloud"], correct: 1, "The file must be disposable."),
            Quiz.make("m6h2", "Two containers on one file at once are:", ["Required", "A locking bug", "How @Query works", "How autosave works"], correct: 1, "Release the first before opening the second."),
            Quiz.make("m6h3", "The assertion should check:", ["Only that init returned", "Transformed values such as the word count", "The SwiftUI font", "The git status"], correct: 1, "An open container can still have empty or wrong data.")
        ],
        playground: .migration
    )

    static let breakage = Lesson.make(
        id: "m6-why-changes-break", moduleID: id, title: "Why model changes break stored data",
        summary: "The file is a frozen schema. Source edits are not retroactive.",
        concept: "A model change breaks an existing store when the file cannot be mapped onto the new schema. Renaming a property looks like a delete plus an add, so the old values are not copied unless a migration or originalName says they are the same column. Changing a type, a uniqueness rule, or a relationship's target is the same class of problem. Adding an optional, or a value with a default the store can fill, is the change most likely to be lightweight. The lab's word count is the instructive middle: the column can be added, and the values are still wrong until custom code runs. ContainerErrorView is the development symptom. A shipping app that hits it has already lost the session. Write the plan before you ship the property.",
        whyItExists: "The compiler sees the new source. The user's phone has the old file. Nobody connects those until launch.",
        whenToUse: "As the checklist before every pull request that touches a @Model property.",
        sample: Samples.make("m6-break", "What the file still contains", #"""
        import SwiftData

        // File created by V1: title, body.
        // Source now expects V2: title, body, wordCount.
        // Without a plan, ModelContainer throws.
        // With the plan, wordCount is derived instead of left at 0.
        let container = try ModelContainer(
            for: schema,
            migrationPlan: NotesMigrationPlan.self,
            configurations: [configuration]
        )
        """#, [
            ("migrationPlan: NotesMigrationPlan.self", "This is the difference between a throw and a mapped file."),
            ("wordCount is derived", "A default of 0 would open and still be wrong.")
        ]),
        expectedBehavior: "The demo does not throw. A real app change without a plan would hit ContainerErrorView.",
        experiment: "Compare the demo result with the copy on the container error view.",
        experimentHint: "One path migrates a temp file. The other explains a failed app launch.",
        experimentSolution: "The plan is why the temp file opens. The error view is what you get when the app file has no plan.",
        challenge: "List three edits that deserve a migration test.",
        challengeHint: "Rename, new non-optional, type change.",
        challengeSolution: "Renaming body, adding a non-optional wordCount, and changing an identifier from String to UUID. Each can refuse to open an old file or can open it with the wrong values.",
        bugTitle: "It worked in the simulator yesterday",
        bugCode: "// Added a property, ran the app, container throw on second launch",
        bugQuestion: "Why did the first launch after the edit fail even though the code compiles?",
        bugDiagnosis: "Compilation does not migrate the file. Yesterday's store is still the old schema.",
        mistakes: ["Equating a green build with a launchable store.", "Resetting the simulator and calling the migration tested.", "Filling new columns with today's date."],
        debuggingTips: ["Keep an old store copy.", "Run the isolated demo in CI.", "Read the throw before deleting the only copy of the data."],
        quiz: [
            Quiz.make("m6i1", "A rename without originalName or a plan looks like:", ["The same column", "A removed column plus a new empty one", "A lightweight word count", "A transient edit"], correct: 1, "The old values are not automatically moved."),
            Quiz.make("m6i2", "A default of 0 on a new column can:", ["Compute the right word count", "Open the store and still be semantically wrong", "Delete the file", "Enable sync"], correct: 1, "Opening is not the same as correct data."),
            Quiz.make("m6i3", "The durable fix is:", ["Tell the user to reinstall", "Ship a migration stage before the schema change", "Catch the error and show an empty UI forever", "Turn off saves"], correct: 1, "The file has to be mapped.")
        ],
        playground: .migration
    )
}
