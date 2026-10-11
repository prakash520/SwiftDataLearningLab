import Foundation

enum Module11CloudKit {
    static let id = "cloudkit"
    static let module = LearningModule(
        id: id,
        title: "CloudKit and synchronization",
        summary: "What sync would require, and why this lab stays on a local store.",
        level: .advanced,
        order: 11,
        lessons: [overview, constraints, local, conflicts, configuration, testing]
    )

    static let overview = Lesson.make(
        id: "m11-overview", moduleID: id, title: "SwiftData and CloudKit",
        summary: "Sync is a configuration and a schema constraint, not a different model macro.",
        concept: "SwiftData can mirror a store to CloudKit when the configuration asks for a CloudKit database and the app has the capability. The models are still @Model. The container is still a ModelContainer. What changes is who else can write the file, and which schema features are legal. This lab passes cloudKitDatabase: .none and does not add the iCloud capability. The playground tells you that plainly. Turning the flag on without the capability does not produce a useful demo. It produces a failed sync you cannot distinguish from a schema bug.",
        whyItExists: "People hear that SwiftData syncs and assume the default configuration already does.",
        whenToUse: "When the product must show the same user data on two devices signed into the same iCloud account. Not for a single-device lab.",
        sample: Samples.make("m11-over", "The line this app refuses to ship", #"""
        import SwiftData

        // This lab does not execute a CloudKit configuration.
        // A syncing app would pass cloudKitDatabase: .automatic
        // only together with the capability, container, and a legal schema.
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        """#, [
            ("cloudKitDatabase: .none", "The executed choice. The store is local."),
            (".automatic", "Named so you can recognize it. This initializer does not pass it.")
        ]),
        expectedBehavior: "The CloudKit playground says sync is off and prints the local path.",
        experiment: "Open the CloudKit playground and read the path. Airplane mode does not matter. The lab never contacts iCloud.",
        experimentHint: "The copy names .none.",
        experimentSolution: "The file is in the sandbox. No network is required to read it.",
        challenge: "What user problem is sync for, in one sentence?",
        challengeHint: "Two devices.",
        challengeSolution: "The same iCloud user should see their records on another device. A single simulator does not demonstrate that.",
        bugTitle: "Assuming the SDK default",
        bugCode: "ModelConfiguration(\"Lab\", schema: schema)",
        bugQuestion: "What CloudKit setting did you just accept?",
        bugDiagnosis: "This SDK defaults cloudKitDatabase to .automatic. The lab always passes .none.",
        mistakes: ["Equating SwiftData with iCloud.", "Testing sync by quitting the app.", "A schema that uses unique constraints and then enabling sync."],
        debuggingTips: ["Print the configuration's cloudKit database.", "If you did not add a capability, you are not syncing.", "Keep the local lab launching with no account."],
        quiz: [
            Quiz.make("m11a1", "This app's CloudKit setting is:", [".automatic", ".none", "public", "shared"], correct: 1, "Explicitly local."),
            Quiz.make("m11a2", "Sync requires:", ["Only the @Model macro", "Capability, container, and a compatible schema", "An in-memory store", "Core Data"], correct: 1, "The flag is not sufficient."),
            Quiz.make("m11a3", "The playground contacts iCloud?", ["Yes", "No", "Only the first launch", "Only in Release"], correct: 1, "There is no sync configuration.")
        ],
        playground: .cloudKit,
        sdkNote: "CloudKit sync is not enabled. Running the lab does not require an Apple Developer account. Configuring sync would."
    )

    static let constraints = Lesson.make(
        id: "m11-constraints", moduleID: id, title: "Schema constraints for CloudKit",
        summary: "Unique attributes, required relationships, and deny rules are local-store features.",
        concept: "A CloudKit-backed SwiftData store requires optional relationships and optional attributes or attributes with defaults. It does not support @Attribute(.unique). The deny delete rule is not a sync-friendly rule. This lab uses unique category names, unique SKUs, and a deny rule on Department on purpose, because the store is local. Those choices are documented so you do not copy the schema into a syncing app unchanged. If you need both a local-only teaching schema and a syncing schema, they are two schemas, not one model with a comment. The bookmarks' unique tag name would have to become a different deduping strategy in a syncing design.",
        whyItExists: "Sync cannot enforce a unique constraint the way a single SQLite file can, and it cannot represent a missing relationship the way a required one demands.",
        whenToUse: "Before you flip cloudKitDatabase away from .none. Audit every attribute and relationship.",
        sample: Samples.make("m11-cons", "Legal locally, illegal for sync", #"""
        import SwiftData

        @Model
        final class Tag {
            // Unique keeps one local row. A second save replaces values.
            // A CloudKit-backed schema cannot use this constraint.
            @Attribute(.unique) var name: String
            init(name: String) { self.name = name }
        }
        """#, [
            ("@Attribute(.unique)", "Correct for the local tag list. Remove it before a syncing schema."),
            ("var name: String", "A syncing schema would also need defaults or optionality on every attribute.")
        ]),
        expectedBehavior: "Saving two bookmarks with the same tag name keeps one Tag. The constraint does not throw. A syncing schema cannot use it, so that dedupe would have to move into your own lookup.",
        experiment: "Create a tag by saving a bookmark, then try to rely on the unique name by saving another bookmark with the same tag. You should get one tag, not two.",
        experimentHint: "The bookmark form reuses the tag by name.",
        experimentSolution: "The unique lookup returns the existing tag. A syncing schema could not lean on the same constraint.",
        challenge: "Name two relationship rules in this app that a syncing schema would have to drop or relax.",
        challengeHint: "Department and required links.",
        challengeSolution: "Department's deny rule, and any non-optional relationship. Sync wants optional links and will not deny in the same way.",
        bugTitle: "One schema for both modes",
        bugCode: "@Attribute(.unique) var sku: String\n// and later cloudKitDatabase: .automatic",
        bugQuestion: "What fails?",
        bugDiagnosis: "The syncing store rejects the unique attribute. Split the schema or drop the constraint and dedupe in a way sync allows.",
        mistakes: ["Copying the lab schema into a sync target.", "Making every property optional without a product reason, just in case.", "Leaving deny in place and hoping."],
        debuggingTips: ["List unique attributes before enabling sync.", "List delete rules.", "Treat the audit as a compile-time checklist, not a runtime surprise."],
        quiz: [
            Quiz.make("m11b1", "CloudKit-backed SwiftData and @Attribute(.unique):", ["Required together", "The unique attribute is not supported", "Unique replaces the capability", "Unique is only a warning"], correct: 1, "Dedupe another way."),
            Quiz.make("m11b2", "Relationships in a syncing schema should be:", ["Non-optional", "Optional", "Cascade only", "noAction"], correct: 1, "Required links are a local luxury."),
            Quiz.make("m11b3", "Department.deny is:", ["A good sync rule", "A local teaching rule", "Required by @Model", "The default"], correct: 1, "The lab uses it because sync is off.")
        ],
        playground: .cloudKit
    )

    static let local = Lesson.make(
        id: "m11-local-vs-cloud", moduleID: id, title: "Local persistence versus cloud sync",
        summary: "Local data is durable on this device. Sync is a second writer.",
        concept: "LearningLab.store survives relaunch and disappears when the app is deleted. That is local persistence. Sync would copy changes to iCloud and down to other devices. It does not replace the local file. The device still has a store. It also does not make the app work offline in a new way: this app already works offline because it never needed the network. Adding sync adds failure modes: no account, no network, a schema the server rejects, and conflicts. The progress and demo rows are local on purpose so the curriculum is available on an airplane and in a simulator signed out of iCloud.",
        whyItExists: "Offline and synced are different promises. This lab keeps the first.",
        whenToUse: "Choose local when the data is a cache or a single-device notebook. Choose sync when the user expects another device to know.",
        sample: Samples.make("m11-local", "Offline by construction", #"""
        import SwiftData

        let configuration = ModelConfiguration(
            "LearningLab",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        """#, [
            ("url: storeURL", "The durable copy is this file."),
            ("cloudKitDatabase: .none", "No second writer.")
        ]),
        expectedBehavior: "Create a note in airplane mode. It remains after relaunch. No account is involved.",
        experiment: "Enable airplane mode, add a note, relaunch.",
        experimentHint: "The notes project never checks reachability.",
        experimentSolution: "The note is in the local file. Sync was not required.",
        challenge: "What would deleting the app do to synced data versus this lab's data?",
        challengeHint: "The lab has no remote copy.",
        challengeSolution: "This lab's notes are gone, because the only copy was the sandbox. A synced store might still exist in iCloud for another device. Do not promise that here.",
        bugTitle: "A reachability check before save",
        bugCode: "guard networkAvailable else { return }\ntry context.save()",
        bugQuestion: "Why is the guard wrong for this architecture?",
        bugDiagnosis: "The store is local. The guard blocks offline use. Sync, if you added it later, would still save locally and sync when it could.",
        mistakes: ["Telling users the lab needs an account.", "Using sync as a backup plan you have not configured.", "Confusing sandbox deletion with iCloud deletion."],
        debuggingTips: ["Airplane mode is a valid test for this app.", "If a save needs the network, you have left the lab's design.", "Read the store path when someone says the data vanished."],
        quiz: [
            Quiz.make("m11c1", "This lab works offline because:", ["CloudKit caches automatically", "It only writes a local file", "The simulator is always online", "Notes are in the git repo"], correct: 1, "No network API is called."),
            Quiz.make("m11c2", "Sync would:", ["Remove the local file", "Add a remote copy and new failure modes", "Replace ModelContext", "Disable save"], correct: 1, "The local store remains."),
            Quiz.make("m11c3", "Deleting the app deletes:", ["iCloud for every app", "This sandbox, which is the only copy", "The source models", "The tests"], correct: 1, "There is no remote replica.")
        ],
        playground: .cloudKit
    )

    static let conflicts = Lesson.make(
        id: "m11-conflicts", moduleID: id, title: "Conflicts and synchronization",
        summary: "Two devices can edit one row. This lab never does.",
        concept: "A conflict happens when two stores commit different values for one record and sync has to reconcile them. SwiftData's CloudKit integration has a strategy for that, and you still have to understand which value survives. This app cannot demonstrate a conflict because it has one store and no sync. Do not invent a conflict UI for a local file. Do not simulate one by opening two containers on the same URL. That is file locking, not a merge. If you later enable sync, test with two devices or two simulators on one account, and decide what a duplicate tag name means once uniqueness is gone.",
        whyItExists: "Sync samples skip the conflict until it hits a user.",
        whenToUse: "Only after sync is actually configured. Until then, teach the idea and do not fake the mechanics.",
        sample: Samples.make("m11-conflict", "What this process does instead", #"""
        import SwiftData

        // One container, one file, no remote writer.
        // A conflict UI would be fiction here.
        try modelContext.save()
        """#, [
            ("One container, one file", "There is no second replica to disagree."),
            ("try modelContext.save()", "The local transaction either commits or throws. It does not merge.")
        ]),
        expectedBehavior: "Two saves on one device are ordered transactions, not conflicts. The later save wins because it ran later, not because a policy merged fields.",
        experiment: "Edit a note, save, edit it again, save. There is one row.",
        experimentHint: "The editor overwrites the draft onto the same note.",
        experimentSolution: "The second save replaced fields in the same local row. No conflict record was created.",
        challenge: "Why would unique tag names become a product problem under sync?",
        challengeHint: "Two devices create the same name offline.",
        challengeSolution: "Both commits can be legal locally and illegal together once uniqueness is not available. You need a merge or a non-unique schema.",
        bugTitle: "Two containers, one file, called a conflict",
        bugCode: "let a = try AppModelContainer.makeShared()\nlet b = try AppModelContainer.makeShared()",
        bugQuestion: "What did you actually create?",
        bugDiagnosis: "Two owners of one SQLite file. Expect locking errors, not a CloudKit merge.",
        mistakes: ["A conflict screen that never runs.", "Testing merge logic against one context.", "Assuming the last save always wins across devices without reading the current docs."],
        debuggingTips: ["If you cannot sign into two devices, you cannot finish a sync test. Say so.", "Keep the lab's save errors as local errors.", "Do not open the store twice."],
        quiz: [
            Quiz.make("m11d1", "This app produces CloudKit conflicts?", ["Yes", "No, there is no second writer", "Only for notes", "Only in tests"], correct: 1, "One local store."),
            Quiz.make("m11d2", "Two makeShared() containers are:", ["A merge", "A locking hazard", "The ModelActor pattern", "Required for previews"], correct: 1, "One owner per file."),
            Quiz.make("m11d3", "A later local save:", ["Is a conflict", "Is a new transaction on the same row", "Deletes the file", "Opens iCloud"], correct: 1, "Order is just order.")
        ],
        playground: .cloudKit
    )

    static let configuration = Lesson.make(
        id: "m11-configuration", moduleID: id, title: "Configuration and capabilities",
        summary: "The entitlements are not in this project. The code path that would need them is named and not taken.",
        concept: "A syncing app needs an iCloud capability, a CloudKit container identifier, the remote-notification background mode, a provisioning profile that includes them, and a signed build. The configuration then uses cloudKitDatabase .automatic or .private with that container. This target's entitlements do not include iCloud. Adding the API call without those entitlements fails at runtime. The lab will not add a partial entitlement to look configured. The persistence configuration you can read in AppModelContainer is the source of truth: URL, allowsSave, cloudKitDatabase .none.",
        whyItExists: "Capabilities live in the signing setup, which is easy to forget when the snippet compiled.",
        whenToUse: "When you are ready to provision a syncing target. Not as a step in this curriculum's build.",
        sample: Samples.make("m11-cap", "What would have to be true", #"""
        import SwiftData

        // Not executed. Shown so the requirement list stays next to the API.
        // 1. iCloud capability
        // 2. CloudKit container id
        // 3. Remote notifications background mode
        // 4. A schema without unique constraints, deny rules, or required relationships
        // let syncing = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        let local = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        """#, [
            ("Not executed", "The syncing initializer is a comment."),
            ("let local = ModelConfiguration", "The only configuration the lesson's real counterpart uses.")
        ]),
        expectedBehavior: "The app launches signed with the existing team settings and never asks for iCloud.",
        experiment: "Launch the app signed out of iCloud, or stay signed in. The dashboard appears either way.",
        experimentHint: "No permission prompt should mention iCloud.",
        experimentSolution: "The lab does not use the capability, so the account does not matter.",
        challenge: "Why is a comment safer than an #if DEBUG sync configuration?",
        challengeHint: "Debug still needs entitlements.",
        challengeSolution: "A debug-only .automatic still needs the capability and a legal schema, and it would sync a developer's real iCloud data by mistake.",
        bugTitle: "Calling automatic in a debug button",
        bugCode: "let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)",
        bugQuestion: "Why is this button a bad idea in the lab?",
        bugDiagnosis: "It needs entitlements the target does not have, and the schema is illegal for sync. The button would fail opaquely.",
        mistakes: ["Adding the capability and keeping unique attributes.", "Pointing a test at a private CloudKit database.", "Assuming the simulator is signed into the right account."],
        debuggingTips: ["Read the entitlements file. If iCloud is absent, sync is absent.", "Keep the working configuration in one function.", "Do not toggle sync from a playground button."],
        quiz: [
            Quiz.make("m11e1", "This target includes the iCloud capability?", ["Yes", "No", "Only for tests", "Only for migration"], correct: 1, "Sync is not configured."),
            Quiz.make("m11e2", "cloudKitDatabase .automatic also needs:", ["Nothing else", "Entitlements and a legal schema", "An in-memory flag", "Core Data"], correct: 1, "The argument is not the whole setup."),
            Quiz.make("m11e3", "A debug-only sync flag is risky because:", ["Debug cannot save", "It can sync a real account with an illegal schema", "The compiler strips ModelConfiguration", "Previews require it"], correct: 1, "Leave it commented until the project is ready.")
        ],
        playground: .cloudKit,
        sdkNote: "No Apple Developer entitlement is required to run the lab. Adding CloudKit later requires a paid account, a container, and a schema audit."
    )

    static let testing = Lesson.make(
        id: "m11-testing-limits", moduleID: id, title: "Testing limitations",
        summary: "You can test the local store completely. You cannot honestly test sync here.",
        concept: "The unit tests cover the local container: CRUD, predicates, relationships, migration on a temp file, and the notes view model. They do not sign in to iCloud, and they should not. A green test suite is not evidence that sync works. The simulator's iCloud account is a poor stand-in for two devices. The CloudKit playground's job is to show the local path and the checklist, not to flip a switch. If a future target enables sync, add a separate test plan that can fail when no account is present, and do not mix those assertions into the in-memory suite.",
        whyItExists: "The absence of a failing test is not coverage.",
        whenToUse: "When someone asks if the lab proved CloudKit. The answer is no, and the local tests are still real.",
        sample: Samples.make("m11-test", "What the tests actually open", #"""
        import SwiftData

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        """#, [
            ("isStoredInMemoryOnly: true", "No file and no network."),
            ("cloudKitDatabase: .none", "The test does not become a sync test by accident.")
        ]),
        expectedBehavior: "The test suite passes without an iCloud account. The CloudKit screen still says sync is unconfigured.",
        experiment: "Run the tests signed out, or run them and then read the CloudKit playground. Both should succeed for different reasons.",
        experimentHint: "The testing guide is on the Progress tab.",
        experimentSolution: "Tests exercise the local schema. The playground refuses to pretend they exercised sync.",
        challenge: "What would a dishonest sync test assert?",
        challengeHint: "A local save.",
        challengeSolution: "That a local save succeeded after setting .automatic in a process with no account and no second device. That assertion does not prove replication.",
        bugTitle: "Marking a local test as sync coverage",
        bugCode: "func testCloudKitSync() throws {\n    try context.save()\n    XCTAssertTrue(context.hasChanges == false)\n}",
        bugQuestion: "What did this test omit?",
        bugDiagnosis: "A second device, an account, a legal schema, and an assertion that the other side received the row. It tests save().",
        mistakes: ["Skipping local tests because sync is the real store. Local still matters.", "Requiring an account for the lab tests.", "Using production iCloud from a unit test."],
        debuggingTips: ["Read the test name. If it says CloudKit and uses makeInMemory, the name is wrong.", "Keep the checklist in the playground.", "Say unfinished when something is unfinished. Sync is unfinished on purpose."],
        quiz: [
            Quiz.make("m11f1", "The unit tests require an iCloud account?", ["Yes", "No", "Only migration", "Only notes"], correct: 1, "Memory containers and .none."),
            Quiz.make("m11f2", "A green suite means:", ["Sync works", "The local behaviors under test passed", "The schema is legal for CloudKit", "The capability is present"], correct: 1, "Coverage is the tests you wrote."),
            Quiz.make("m11f3", "An honest sync test needs:", ["One local save", "Two participants and a configured container", "An in-memory store", "A predicate"], correct: 1, "Replication is the thing under test.")
        ],
        playground: .cloudKit,
        sdkNote: "Sync is intentionally unfinished. The local curriculum, including tests, runs without a developer account or iCloud."
    )
}
