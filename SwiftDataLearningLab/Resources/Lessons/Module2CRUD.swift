import Foundation

enum Module2CRUD {
    static let id = "crud"
    static let module = LearningModule(
        id: id,
        title: "CRUD operations",
        summary: "Insert, fetch, update, delete, save, change tracking, autosave, and the failures that leave a context dirty.",
        level: .beginner,
        order: 2,
        lessons: [insert, fetch, update, delete, save, tracking, autosave, errors]
    )

    static let insert = Lesson.make(
        id: "m2-insert", moduleID: id, title: "Insert records",
        summary: "Register a new instance with the context that should own it.",
        concept: "insert tells one ModelContext to track a new instance. You can insert a graph: a student, a profile, and a course in the same context before one save. Insert does not check unique constraints. On this SDK a later save with the same unique value keeps one row and replaces its values instead of throwing. Inserting the same instance twice is a mistake. If a repeated SKU must be an error, look it up before insert.",
        whyItExists: "The context must know which objects are new so save can write inserts rather than updates.",
        whenToUse: "Call insert for objects you created with init. Objects returned by fetch are already registered. Relating a new object to an inserted parent often inserts it as well, but explicit insert is clearer and easier to test.",
        sample: Samples.make("m2-insert", "Insert and save a lab record", #"""
        import SwiftData

        let record = LabRecord(title: "Milk", notes: "Buy oat milk")
        modelContext.insert(record)
        try modelContext.save()
        """#, [
            ("LabRecord(title:", "The instance is untracked until the next line."),
            ("modelContext.insert(record)", "This context now includes the record in its inserted set."),
            ("try modelContext.save()", "The unique place this lesson publishes the row.")
        ]),
        expectedBehavior: "Add and save puts a row in the CRUD list. Relaunch keeps it.",
        experiment: "Add a record titled Relaunch check, stop the app, run it, and find that title.",
        experimentHint: "Use Add and save, not only the text field.",
        experimentSolution: "The title is still there because insert plus save wrote the store.",
        challenge: "Insert two LabRecord values and save once. How many transactions did you need?",
        challengeHint: "The context can hold many inserts.",
        challengeSolution: "One save. Both inserts are part of the same pending change set.",
        bugTitle: "Insert after the object was fetched",
        bugCode: "let existing = try context.fetch(FetchDescriptor<LabRecord>()).first!\ncontext.insert(existing)",
        bugQuestion: "What is wrong with inserting a fetched object?",
        bugDiagnosis: "It is already registered. Insert is for new instances. Mutate the properties and save.",
        mistakes: ["Forgetting insert and only calling save.", "Inserting into a temporary context that is released without save.", "Expecting insert to throw on a duplicate unique value."],
        debuggingTips: ["Watch insertedModelsArray.count.", "Save, then fetch from a new context.", "If the list stays empty, confirm you inserted into the environment context."],
        quiz: [
            Quiz.make("m2a1", "When are unique constraints checked?", ["Inside init", "Inside insert", "When the context saves", "When the view appears"], correct: 2, "The store enforces uniqueness at save."),
            Quiz.make("m2a2", "Which objects need insert?", ["Every object you fetched", "New instances the context does not track yet", "Only relationships", "Only @Transient properties"], correct: 1, "Fetched objects are already in a context."),
            Quiz.make("m2a3", "Can one save cover two inserts?", ["No, save writes one object", "Yes", "Only if autosave is off", "Only for relationships"], correct: 1, "The context commits its whole pending set.")
        ],
        playground: .crud
    )

    static let fetch = Lesson.make(
        id: "m2-fetch", moduleID: id, title: "Fetch records",
        summary: "Read instances back with FetchDescriptor or @Query.",
        concept: "modelContext.fetch returns instances tracked by that context. The fetch includes the context's unsaved inserts and hides its unsaved deletes. @Query is the SwiftUI wrapper around the same idea and is only valid in a view. fetchCount is the cheap version when you need a number. Always set fetchLimit when you only need one row.",
        whyItExists: "The store holds rows. The context is how you turn them back into model instances.",
        whenToUse: "Use @Query for a screen that should redraw. Use fetch in a repository, a test, or a ModelActor.",
        sample: Samples.make("m2-fetch", "Fetch with a limit", #"""
        import SwiftData

        var descriptor = FetchDescriptor<LabRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        let records = try modelContext.fetch(descriptor)
        """#, [
            ("FetchDescriptor<LabRecord>", "The model type selects the entity. This is not an NSFetchRequest."),
            ("SortDescriptor(\\.updatedAt", "Sort in the store when you can, instead of sorting a giant array in the view."),
            ("descriptor.fetchLimit = 20", "A missing limit is how a demo accidentally loads the entire table.")
        ]),
        expectedBehavior: "The CRUD list is a @Query sorted by updatedAt. The newest edit floats to the top.",
        experiment: "Add two records. Confirm the later one is listed first.",
        experimentHint: "The query sort is reverse updatedAt.",
        experimentSolution: "The second save has the later updatedAt, so it is first.",
        challenge: "Write a fetch that returns at most one LabRecord for a known title.",
        challengeHint: "Predicate plus fetchLimit.",
        challengeSolution: "Copy the title into a local let, build #Predicate { $0.title == title }, set fetchLimit to 1, and fetch.",
        bugTitle: "Fetching in a view body with no limit",
        bugCode: "var body: some View {\n    let all = try! modelContext.fetch(FetchDescriptor<LabRecord>())\n    Text(\"\\(all.count)\")\n}",
        bugQuestion: "Why is this a poor pattern even when it works?",
        bugDiagnosis: "body can run often, try! hides errors, and there is no limit. Use @Query or fetch from a view model method.",
        mistakes: ["Using try! on fetch.", "Assuming a fetch sees another context's unsaved inserts.", "Sorting only in the view after fetching everything."],
        debuggingTips: ["Compare fetchCount on the view context and on a new context.", "Print the descriptor's predicate when the result is empty.", "Check the sort key path. Optional dates sort nil in a way that looks like a bug."],
        quiz: [
            Quiz.make("m2b1", "Where may @Query appear?", ["In a ModelActor", "In a SwiftUI view", "In an XCTest assertion only", "Inside init of a model"], correct: 1, "@Query is a DynamicProperty."),
            Quiz.make("m2b2", "Does fetch include unsaved inserts of the same context?", ["No", "Yes", "Only after rollback", "Only if the property is unique"], correct: 1, "The context overlays its pending changes on the store."),
            Quiz.make("m2b3", "What does fetchLimit do?", ["Deletes extra rows", "Caps how many instances the fetch returns", "Sets the page size on CloudKit", "Disables autosave"], correct: 1, "It does not delete anything.")
        ],
        playground: .crud
    )

    static let update = Lesson.make(
        id: "m2-update", moduleID: id, title: "Update properties",
        summary: "Mutating a tracked property is the update. Save publishes it.",
        concept: "There is no separate update() API. You change a property on a tracked instance. The context records the object in changedModelsArray. SwiftUI observation redraws views that read the property. The store learns about the new value at save, or at autosave. Reassign value-type properties such as arrays and structs. Editing an element in place and never writing the property back can be missed by change tracking.",
        whyItExists: "The context is already observing the instance. A second update API would be a second source of truth.",
        whenToUse: "Update when the user edits a field or when a command changes state, such as toggling a task complete. In the notes project the view model holds a draft and copies it onto the model at Save, so cancel does not mutate the row.",
        sample: Samples.make("m2-update", "Mutate then save", #"""
        import SwiftData

        record.title = title
        record.notes = notes
        record.updatedAt = .now
        try modelContext.save()
        """#, [
            ("record.title = title", "Assignment is the update. The object must already be tracked."),
            ("record.updatedAt = .now", "A stored timestamp makes sort order match the edit."),
            ("try modelContext.save()", "Until this returns, other contexts can still see the old title.")
        ]),
        expectedBehavior: "Select a row, change the title, tap Update selected. The list shows the new title after relaunch.",
        experiment: "Change a saved title, relaunch, and verify the new title.",
        experimentHint: "Select the row so Update selected has a target.",
        experimentSolution: "The updated title is in the store. The list is not a cache that relaunch discards.",
        challenge: "Why does the notes editor copy title into the view model instead of binding the TextField to the model?",
        challengeHint: "Compare it with the SwiftUI lab form.",
        challengeSolution: "A direct binding mutates the tracked object immediately, and autosave may persist it. A draft makes Save the transaction boundary.",
        bugTitle: "Mutating an untracked copy",
        bugCode: "var copy = record\ncopy.title = \"New\"\ntry context.save()",
        bugQuestion: "Why does the stored title stay old?",
        bugDiagnosis: "Models are classes, but if you constructed a different instance, you mutated the wrong object. Change the fetched instance, or assign back and insert. There is no value-type copy of a class, so this bug more often looks like editing a snapshot struct you made yourself and never writing it back.",
        mistakes: ["Editing a struct snapshot and forgetting to assign it.", "Updating on a background queue with the view's context.", "Forgetting updatedAt and then wondering why sort order is stale."],
        debuggingTips: ["Read changedModelsArray after the edit and before save.", "Fetch from a new context to see the stored value.", "If the UI updates but relaunch does not, save never ran and autosave had not flushed."],
        quiz: [
            Quiz.make("m2c1", "How do you update a tracked model?", ["context.update(model)", "Assign its properties", "Call insert again", "Replace the ModelContainer"], correct: 1, "There is no update method."),
            Quiz.make("m2c2", "When does another context see the new title?", ["On the assignment", "After this context saves", "When the property is @Transient", "Immediately, always"], correct: 1, "The assignment is local until save."),
            Quiz.make("m2c3", "Why reassign an array property?", ["Arrays cannot be stored", "In-place edits of a value type can be missed", "Reassignment deletes the row", "The macro requires a new allocation every frame"], correct: 1, "Write the whole value back so observation and persistence see the change.")
        ],
        playground: .crud
    )

    static let delete = Lesson.make(
        id: "m2-delete", moduleID: id, title: "Delete records",
        summary: "context.delete marks an instance deleted. Save commits that, and relationship rules run.",
        concept: "delete(_:) removes one instance. The object stays in deletedModelsArray until save. Relationship delete rules decide what happens to related rows: cascade deletes them, nullify clears the link, deny can fail the save, noAction leaves the inverse alone. Deleting a model and continuing to use it is unsafe. Check isDeleted. There is also delete(model:where:), which deletes by predicate. Prefer an explicit object delete while you are learning, so you can see the rule fire.",
        whyItExists: "Users delete data, and related data needs a defined outcome. The rule belongs on the relationship, not in an ad hoc loop you might forget.",
        whenToUse: "Delete from a swipe action or a button that confirms destructive rules. Cascade in particular deserves a confirmation.",
        sample: Samples.make("m2-delete", "Delete one tracked record", #"""
        import SwiftData

        modelContext.delete(record)
        try modelContext.save()
        """#, [
            ("modelContext.delete(record)", "Marks the instance deleted in this context."),
            ("try modelContext.save()", "The row leaves the store. Cascade or deny runs as part of the save.")
        ]),
        expectedBehavior: "Delete selected removes the row from the list and from the store.",
        experiment: "Delete a record, relaunch, and confirm it is gone.",
        experimentHint: "Select it before tapping Delete selected.",
        experimentSolution: "The row is gone after relaunch. Delete plus save is durable.",
        challenge: "In the relationship playground, delete a category that has tasks. What happens to the tasks, and which rule says so?",
        challengeHint: "TaskCategory.tasks uses cascade.",
        challengeSolution: "The tasks are deleted with the category because the relationship's delete rule is cascade.",
        bugTitle: "Using a model after delete",
        bugCode: "context.delete(record)\ntry context.save()\nprint(record.title)",
        bugQuestion: "What should you do instead of reading the deleted instance?",
        bugDiagnosis: "The instance is deleted. Keep the title in a local String before delete if you still need to display it. Do not fault a deleted object.",
        mistakes: ["Deleting and then saving a different context.", "Ignoring a deny error and leaving the context dirty.", "Cascading without telling the user."],
        debuggingTips: ["Read isDeleted.", "On a thrown save after delete, call rollback().", "Count related objects before and after the save."],
        quiz: [
            Quiz.make("m2d1", "What does delete(_:) do before save?", ["Erases the file", "Marks the instance deleted in the context", "Nullifies every model in the store", "Turns autosave off"], correct: 1, "The store changes at save."),
            Quiz.make("m2d2", "Which rule deletes related tasks when a category is deleted?", ["nullify", "cascade", "deny", "noAction"], correct: 1, "TaskCategory.tasks is cascade."),
            Quiz.make("m2d3", "What should follow a failed delete save?", ["Insert the object again immediately", "rollback()", "Delete the container", "Ignore hasChanges"], correct: 1, "Rollback clears the failed pending delete.")
        ],
        playground: .crud
    )

    static let save = Lesson.make(
        id: "m2-save", moduleID: id, title: "modelContext.save()",
        summary: "save is the transaction boundary you can catch.",
        concept: "save() throws. Unique violations, deny rules, and store failures surface here. After a successful save, hasChanges is false and other contexts can read the committed data. After a thrown save, the context may still hold the bad changes. Roll them back or fix the values before the next save. Autosave also calls the same machinery, but you do not get a natural place to catch the error. Call save when a command finishes, when a ModelActor finishes, and when a test needs a deterministic store.",
        whyItExists: "Pending changes are not a transaction. save is.",
        whenToUse: "User-facing commands, background import, and any time the next line must observe failure or success.",
        sample: Samples.make("m2-save", "Save and roll back on failure", #"""
        import SwiftData

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
        """#, [
            ("try modelContext.save()", "Commits inserts, updates, and deletes, or throws."),
            ("modelContext.rollback()", "Drops the pending set after a failure so the context can be used again.")
        ]),
        expectedBehavior: "Save now reports hasChanges false when the context was dirty. The duplicate SKU button in the model-design playground throws and rolls back.",
        experiment: "In the model-design playground, force a duplicate SKU and read the status. Confirm the context can still save a later valid item.",
        experimentHint: "The button is Force a duplicate SKU error.",
        experimentSolution: "The error is reported and rollback ran. A later valid save still works.",
        challenge: "Name a flow in this app that uses an explicit save as its product boundary.",
        challengeHint: "Look at the notes editor.",
        challengeSolution: "NoteEditorViewModel.save copies the draft onto the Note and calls repository.update, which saves. Cancel does not.",
        bugTitle: "Empty catch",
        bugCode: "do { try context.save() } catch { }",
        bugQuestion: "What did the user lose?",
        bugDiagnosis: "The failure is swallowed, the context may still be dirty, and the UI says nothing. Surface error.localizedDescription and rollback or repair.",
        mistakes: ["Assuming save is a no-op when hasChanges is false. It is cheap, but the interesting case is when it throws.", "Saving in a loop per property change without need.", "Catching the error and continuing to use the bad graph."],
        debuggingTips: ["Branch the UI on the thrown error.", "Check hasChanges after the catch.", "Reproduce the failure in an in-memory test."],
        quiz: [
            Quiz.make("m2e1", "What does a successful save guarantee?", ["CloudKit delivery", "The pending changes are committed", "Views stop observing", "The schema migrates"], correct: 1, "It is the local transaction boundary."),
            Quiz.make("m2e2", "Why rollback after a thrown save?", ["To delete the store", "To clear the failed pending changes", "To disable autosave", "To create a new container"], correct: 1, "Otherwise the next save retries the same failure."),
            Quiz.make("m2e3", "Where should a unique-constraint failure appear?", ["In init", "As a thrown error from save", "As an empty fetch", "As a SwiftUI warning only"], correct: 1, "The store reports it when the transaction is attempted.")
        ],
        playground: .crud
    )

    static let tracking = Lesson.make(
        id: "m2-tracking", moduleID: id, title: "Automatic change tracking",
        summary: "The context notices property writes on registered models.",
        concept: "Because @Model makes the class Observable and backed by SwiftData, a property write on a registered instance marks that instance changed. You do not call a willChange method. insertedModelsArray, changedModelsArray, and deletedModelsArray are the pending sets. hasChanges is true when any of them is non-empty. Tracking applies only to registered instances. A Book() you have not inserted is invisible to the context. @Transient and computed properties are not columns, so writing them does not create a store update.",
        whyItExists: "Call sites stay ordinary Swift assignments, which is what makes SwiftUI bindings possible.",
        whenToUse: "Rely on tracking for registered models. Do not build a parallel dirty flag unless you have a draft layer outside the model, as the notes editor does.",
        sample: Samples.make("m2-track", "Read the pending sets", #"""
        import SwiftData

        let inserted = modelContext.insertedModelsArray.count
        let updated = modelContext.changedModelsArray.count
        let deleted = modelContext.deletedModelsArray.count
        let dirty = modelContext.hasChanges
        """#, [
            ("insertedModelsArray", "Instances inserted and not yet saved."),
            ("changedModelsArray", "Tracked instances whose stored properties changed."),
            ("hasChanges", "The single flag that save and tests should consult.")
        ]),
        expectedBehavior: "The CRUD playground prints the three counts. They return to zero after a successful save.",
        experiment: "Type a new title and add it. Before you dismiss the thought, look at the counts, then tap Save now if anything is still dirty.",
        experimentHint: "Add and save already saves, so the counts may already be zero. Edit a field through Update selected and watch the status line.",
        experimentSolution: "An unsaved mutation increases the changed count. Save clears it.",
        challenge: "Why does typing into DesignedItem.draftNote not belong in changedModelsArray as a column update?",
        challengeHint: "Look at the @Transient attribute.",
        challengeSolution: "draftNote is transient. It is not a stored property, so the store has nothing to update.",
        bugTitle: "Tracking an unregistered object",
        bugCode: "let book = Book(title: \"X\", authorName: \"A\", publicationYear: 1)\nbook.title = \"Y\"\nprint(context.hasChanges)",
        bugQuestion: "Why is hasChanges false?",
        bugDiagnosis: "The book was never inserted. The context is not observing it.",
        mistakes: ["Expecting @Transient writes to survive save.", "Polling hasChanges on a different context.", "Building a custom dirty system that drifts from the context."],
        debuggingTips: ["Print the three arrays' counts.", "Confirm model.modelContext === the context you are inspecting.", "Call processPendingChanges() if you mutated outside the normal run loop and need the sets updated before you read them."],
        quiz: [
            Quiz.make("m2f1", "What marks a tracked object changed?", ["A special update() call", "Writing a stored property", "Reading a stored property", "Creating a FetchDescriptor"], correct: 1, "The write is the change."),
            Quiz.make("m2f2", "Which write is not a column change?", ["title =", "A @Transient draft note", "notes =", "updatedAt ="], correct: 1, "Transient properties are excluded from the schema."),
            Quiz.make("m2f3", "hasChanges is true when:", ["The view is on screen", "Any pending insert, update, or delete exists", "The container is in memory", "A predicate fails"], correct: 1, "It summarizes the three pending sets.")
        ],
        playground: .crud
    )

    static let autosave = Lesson.make(
        id: "m2-autosave", moduleID: id, title: "Autosave versus explicit save",
        summary: "Autosave is convenient and not a transaction you control.",
        concept: "autosaveEnabled defaults to true. The view context may save on its own schedule, including around UI updates and when the system thinks the context is idle. That is why a bound TextField often survives relaunch even if you never called save. It is also why a discard experiment is meaningless unless you turn autosave off: the row may hit the store before you can roll it back. Explicit save is required for ModelActor work, for tests, for multi-context publication, and whenever you must handle an error. Turning autosave off for the whole app is reasonable in a tightly controlled editor and annoying in a simple SwiftUI screen. This lab leaves the view context on and uses secondary contexts with autosave off for the proof.",
        whyItExists: "SwiftUI apps would otherwise forget save() on every keystroke. The cost is a blurry transaction boundary.",
        whenToUse: "Leave autosave on for simple bound forms. Turn it off for importers, tests, and any context whose unsaved state you need to reason about.",
        sample: Samples.make("m2-auto", "Disable autosave for a proof", #"""
        import SwiftData

        let secondary = ModelContext(container)
        secondary.autosaveEnabled = false
        secondary.insert(LabRecord(title: title, notes: "Discard me"))
        secondary.rollback()
        """#, [
            ("autosaveEnabled = false", "Stops this context from flushing before rollback."),
            ("secondary.insert", "Visible to secondary only."),
            ("secondary.rollback()", "Drops the insert. The main context never observed it.")
        ]),
        expectedBehavior: "Run discard experiment reports 1, then 0, then 0. Save from a second context reports a count of 1 from a new reader.",
        experiment: "Run both CRUD buttons: discard, then save from a second context.",
        experimentHint: "Read the status banner after each.",
        experimentSolution: "Discard never reaches the main list. The second-context save does, because that path calls save().",
        challenge: "A form is bound with @Bindable and the developer deletes every save() call. Why might relaunch still show the edit, and why is that not a proof that save is unnecessary?",
        challengeHint: "Autosave may have flushed.",
        challengeSolution: "The view context likely autosaved. That is not a guarantee about timing, errors, or other contexts. Keep an explicit save on commands that must succeed or fail now.",
        bugTitle: "Proving data loss with autosave still on",
        bugCode: "context.insert(record)\n// autosaveEnabled is still true\ncontext.rollback()",
        bugQuestion: "Why might the row still be in the store?",
        bugDiagnosis: "Autosave may have committed between insert and rollback. Turn autosave off before the experiment.",
        mistakes: ["Treating autosave as immediate.", "Treating autosave as durable before the next line.", "Disabling autosave globally and then forgetting every save()."],
        debuggingTips: ["Log autosaveEnabled on the context you are testing.", "Use a secondary context so the view's autosave does not confuse the result.", "Fetch from a new context after the operation."],
        quiz: [
            Quiz.make("m2g1", "What is the default of autosaveEnabled?", ["false", "true", "true only for in-memory stores", "true only after the first error"], correct: 1, "New contexts autosave unless you disable it."),
            Quiz.make("m2g2", "Why disable autosave in the discard demo?", ["To speed up SQLite", "So the insert cannot be flushed before rollback", "To enable CloudKit", "To turn off observation"], correct: 1, "The experiment needs a known unsaved state."),
            Quiz.make("m2g3", "Which work should still call save() when autosave is on?", ["A ModelActor import that must publish now", "Reading a Text view", "Building a FetchDescriptor", "Creating a Schema"], correct: 0, "Background work and error handling need an explicit boundary.")
        ],
        playground: .crud
    )

    static let errors = Lesson.make(
        id: "m2-errors-and-discard", moduleID: id, title: "Errors and discarded contexts",
        summary: "A thrown save, a rollback, and a released context are three different endings.",
        concept: "If a context with autosave disabled is released without save, its pending inserts die with it. If save throws, the pending changes are still there until rollback. Two constraints people expect to throw do not, on this SDK. A second DesignedItem with the same SKU replaces the stored row. Deleting a Department that still has employees succeeds even though the relationship is marked deny. DesignLab.insertIfSKUAvailable and RelationshipLab.deleteDepartmentIfEmpty throw before the store can do those things. processPendingChanges is available when you need the context to notice edits before you read hasChanges, but it does not replace save.",
        whyItExists: "People treat SwiftData errors as UI copy problems. They are transaction problems.",
        whenToUse: "Catch save around user commands. Use rollback when you cannot repair the pending set. Use a short-lived context when the work should vanish if it is not explicitly saved.",
        sample: Samples.make("m2-error", "Duplicate SKU, then rollback", #"""
        import SwiftData

        let sku = "SKU-DEMO"
        let key = sku
        let existing = try context.fetchCount(
            FetchDescriptor<DesignedItem>(predicate: #Predicate { $0.sku == key })
        )
        if existing > 0 {
            throw LabError.message("SKU is already stored")
        }
        context.insert(DesignedItem(sku: sku, name: "Duplicate"))
        try context.save()
        """#, [
            ("name: \"Duplicate\"", "This insert is reached only when the lookup found no row."),
            ("fetchCount", "The app asks the store before insert. save() will not throw for a repeated SKU."),
            ("try context.save()", "Commits the row the lookup allowed.")
        ]),
        expectedBehavior: "Reject a SKU the app already stored shows the lookup error and leaves the first name. The discard button shows that an unsaved secondary context publishes nothing.",
        experiment: "Save GUARDED-SKU once, then tap the reject button again. Then run the discard experiment on the CRUD playground.",
        experimentHint: "Model design playground for the SKU. CRUD playground for discard.",
        experimentSolution: "The lookup throws, so the stored name stays First. Discard shows that an unsaved secondary context publishes nothing.",
        challenge: "What is the difference between rollback and releasing a secondary context?",
        challengeHint: "Both can drop unsaved work.",
        challengeSolution: "rollback clears one context's pending changes and leaves the context usable. Releasing the context drops those changes because nothing owns them, provided autosave did not flush. Neither deletes committed rows.",
        bugTitle: "Retrying without rollback",
        bugCode: "do { try context.save() } catch {\n    context.insert(LabRecord(title: \"another\", notes: \"\"))\n    try? context.save()\n}",
        bugQuestion: "Why can the second save fail with the same error?",
        bugDiagnosis: "The first failed objects are still pending. Rollback, or fix those objects, before inserting more work into the same save.",
        mistakes: ["Using try? and losing the message.", "Assuming a thrown save deleted the whole file.", "Leaving a deny-rule delete pending."],
        debuggingTips: ["Show localizedDescription in the playground status.", "Assert XCTAssertThrowsError in a test with an in-memory container.", "After the catch, assert hasChanges is false if you rolled back."],
        quiz: [
            Quiz.make("m2h1", "What happens to unsaved inserts in a released context if autosave is off?", ["They move to the main context", "They are discarded", "They become unique", "They migrate the schema"], correct: 1, "Nothing committed them."),
            Quiz.make("m2h2", "A duplicate unique value fails when?", ["The second init runs", "save runs", "The view redraws", "fetch runs"], correct: 1, "Enforcement is at save."),
            Quiz.make("m2h3", "After a failed save, the pending changes are:", ["Always gone", "Still in the context until rollback or a successful repair", "Written to a sidecar file", "Sent to CloudKit"], correct: 1, "Throwing does not imply rollback.")
        ],
        playground: .crud
    )
}
