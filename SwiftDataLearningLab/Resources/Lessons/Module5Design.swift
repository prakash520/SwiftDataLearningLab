import Foundation

enum Module5Design {
    static let id = "design"
    static let module = LearningModule(
        id: id,
        title: "Model design",
        summary: "Optionals, defaults, uniqueness, transient state, enums, collections, initialization, and the inheritance limit.",
        level: .intermediate,
        order: 5,
        lessons: [optional, defaults, unique, transient, enums, collections, initialization, inheritance, supported]
    )

    static let optional = Lesson.make(
        id: "m5-optional-required", moduleID: id, title: "Optional and non-optional properties",
        summary: "Required properties must have a value. Optional properties model absence.",
        concept: "A non-optional String cannot be nil, so the row always has a title. An optional String? stores nil distinctly from \"\". Use optional for data the user may not have yet: subtitle, due date, URL, category. Do not use empty string, 0, or a fake UUID as a substitute for nil unless 0 is a real measurement. Predicates treat nil as a value you must test on purpose. Migration from non-optional to optional is easier than the reverse, because the reverse has to invent values for old nulls.",
        whyItExists: "The schema should match the domain. A required column that the UI cannot fill becomes a crash or a sentinel.",
        whenToUse: "Required for identity you always have, such as a note title you default to Untitled at the boundary. Optional for everything incomplete.",
        sample: Samples.make("m5-opt", "nil subtitle versus a required title", #"""
        import SwiftData

        let book = Book(title: "States", subtitle: nil, authorName: "Ada", publicationYear: 2024)
        modelContext.insert(book)
        try modelContext.save()
        """#, [
            ("subtitle: nil", "The column is null. It is not an empty string."),
            ("title: \"States\"", "title is non-optional, so the call site must supply one.")
        ]),
        expectedBehavior: "Books save with a nil subtitle. The list still shows the title.",
        experiment: "Save a book from the lifecycle playground. The form has no subtitle field, so the stored subtitle is nil.",
        experimentHint: "The Book initializer defaults subtitle to nil.",
        experimentSolution: "The row exists. Absence of a subtitle did not block the save.",
        challenge: "Why does the notes composer substitute Untitled instead of making title optional?",
        challengeHint: "The model requires a title. The UI picks a default.",
        challengeSolution: "The product wants every note to have a display title. The default is applied at the boundary, so the schema stays non-optional.",
        bugTitle: "Empty string as nil",
        bugCode: "book.subtitle = \"\"",
        bugQuestion: "How is this different from nil?",
        bugDiagnosis: "Empty string is a present value. Predicates and UI that check nil will treat it as a real subtitle. Use nil for missing.",
        mistakes: ["Making everything optional to avoid thinking.", "Making everything required and filling junk.", "Comparing optional strings with == \"\" and missing the nil rows."],
        debuggingTips: ["Print String(describing: subtitle).", "Add a predicate for nil and one for empty if both exist in old data.", "Prefer optional in new models when the UI has a clear empty state."],
        quiz: [
            Quiz.make("m5a1", "nil means:", ["Empty string", "The value is absent", "The default zero", "The property is transient"], correct: 1, "Optional absence is its own state."),
            Quiz.make("m5a2", "A non-optional title requires:", ["A value before the instance can be initialized", "A unique constraint", "CloudKit", "An inverse"], correct: 0, "The compiler enforces it at init."),
            Quiz.make("m5a3", "Changing a column from optional to required is:", ["Always lightweight with no data work", "A migration problem for existing nulls", "Impossible to express", "Only a SwiftUI change"], correct: 1, "Old nulls need real values.")
        ],
        playground: .modelDesign
    )

    static let defaults = Lesson.make(
        id: "m5-defaults", moduleID: id, title: "Default property values",
        summary: "Defaults on init apply to new objects. They do not rewrite old rows.",
        concept: "A default parameter such as quantity: Int = 1 applies when code calls that initializer. SwiftData does not re-run your initializer when it fetches a row. Old rows keep the values they were saved with. If you add a new non-optional property, existing stores need a default in the schema or a migration, or the container fails to open. That failure is what ContainerErrorView explains. A default of .now on createdAt is correct for new objects and wrong as a migration default if you wanted the original creation time. For a new column, pick a default that means unknown, not today's date pretending to be history.",
        whyItExists: "New code and old files disagree unless you say what the new column should contain.",
        whenToUse: "Defaults for new instances in init. Schema defaults or migration stages for files that already exist.",
        sample: Samples.make("m5-def", "Init default is not a fetch", #"""
        import SwiftData

        let item = DesignedItem(sku: "FIELD-1", name: "Field notes")
        // quantity defaults to 1 only because this init ran.
        modelContext.insert(item)
        try modelContext.save()
        """#, [
            ("DesignedItem(sku:", "Omitted arguments use the init defaults."),
            ("quantity defaults to 1", "A fetched item from last week does not get a new default applied on read.")
        ]),
        expectedBehavior: "Saving a designed item without setting quantity stores 1, because init assigned it.",
        experiment: "Save a designed item and read the row. Relaunch. The quantity you did not edit is still 1, not reset by a later code change unless you migrate.",
        experimentHint: "The model design form sets sku and name. Other fields use init defaults.",
        experimentSolution: "The stored quantity remains the value written at insert. Relaunch does not call the default again.",
        challenge: "You add isArchived: Bool with default false. What happens to a store created before that property existed?",
        challengeHint: "The file's schema does not match.",
        challengeSolution: "Opening can fail until you add a migration or delete the store. A default on init does not rewrite the existing file by itself.",
        bugTitle: "Default .now on a migrated createdAt",
        bugCode: "var createdAt: Date = .now",
        bugQuestion: "Why can every old row look like it was created today?",
        bugDiagnosis: "If a migration fills the new column with the current date, you have erased history. Use a sentinel or preserve the old value.",
        mistakes: ["Expecting init defaults to heal old data.", "Using a meaningful business value as the migration filler.", "Changing a default and expecting saved rows to change."],
        debuggingTips: ["Read ContainerErrorView after a model edit.", "Check the store URL before deleting random files.", "Write a migration test when the default is not obvious."],
        quiz: [
            Quiz.make("m5b1", "Init defaults run when:", ["The initializer is called", "Every fetch", "Every autosave", "Every query"], correct: 0, "Fetch restores stored values."),
            Quiz.make("m5b2", "A new non-optional property on a shipping store needs:", ["Nothing", "A migration or a schema default the store can apply", "A new @Query", "CloudKit"], correct: 1, "The existing file has no column value yet."),
            Quiz.make("m5b3", "createdAt = .now is appropriate for:", ["New objects", "Backfilling old rows during a casual migration", "Transient drafts", "Predicates"], correct: 0, "New objects really are created now.")
        ],
        playground: .modelDesign
    )

    static let unique = Lesson.make(
        id: "m5-unique", moduleID: id, title: "Unique attributes",
        summary: "@Attribute(.unique) keeps one row. On this SDK a second save replaces that row instead of throwing.",
        concept: "@Attribute(.unique) puts a uniqueness constraint on a stored property. DesignedItem.sku, Tag.name, ExpenseCategory.name, and TaskCategory.name use it. Two inits with the same SKU succeed. On this SDK the second save does not throw. The store keeps one row, and the later object's values replace the earlier row. If the product must refuse a duplicate, look the SKU up and throw before insert. DesignLab.insertIfSKUAvailable does that. iOS 18 adds #Unique for compound constraints. This deployment target is iOS 17, so the lab uses the attribute form and does not call #Unique. CloudKit-backed SwiftData does not support unique constraints. That is one reason the syncing module tells you to keep a separate schema if you ever turn sync on. Uniqueness is not a substitute for persistentModelID. IDs identify the row. The SKU identifies the business key.",
        whyItExists: "Duplicate tags and duplicate categories split your data into buckets the UI did not mean to create.",
        whenToUse: "Natural keys the user understands: tag names, category names, SKUs. Not for titles people may legitimately repeat, such as two notes called Untitled.",
        sample: Samples.make("m5-uniq", "Two inserts, one SKU", #"""
        import SwiftData

        let sku = "SKU-DEMO"
        context.insert(DesignedItem(sku: sku, name: "First"))
        try context.save()
        context.insert(DesignedItem(sku: sku, name: "Duplicate"))
        try context.save()
        """#, [
            ("DesignedItem(sku: sku, name: \"First\")", "The first save commits a legal row."),
            ("name: \"Duplicate\"", "The second object uses the same SKU. The store keeps one row and this name replaces First."),
            ("try context.save()", "This save succeeds. Unique does not throw on this SDK.")
        ]),
        expectedBehavior: "Saving a second item with the same SKU leaves one row, named Duplicate. Rejecting a known SKU throws before insert and leaves the first name in place.",
        experiment: "Tap Save a second item with the same SKU, then tap Reject a SKU the app already stored.",
        experimentHint: "The model design playground has both buttons.",
        experimentSolution: "The unconstrained second save replaces the row. The lookup throws and the original GUARDED-SKU row stays First.",
        challenge: "Why is Note.title not unique?",
        challengeHint: "Users repeat titles.",
        challengeSolution: "Two notes can share a title. Identity is persistentModelID. Uniqueness would make a second Untitled impossible.",
        bugTitle: "Checking uniqueness only in the view",
        bugCode: "if items.contains(where: { $0.sku == sku }) { return }\ncontext.insert(DesignedItem(sku: sku, name: name))",
        bugQuestion: "What race remains?",
        bugDiagnosis: "Another context can insert the same SKU after the check and before save. The store will then keep one row and let the later values win. The lookup makes the error explicit. It does not make two contexts atomic.",
        mistakes: ["Expecting init to throw.", "Expecting save() to throw on a duplicate SKU.", "Putting unique on a property CloudKit will sync."],
        debuggingTips: ["Fetch after the second save and count the rows. One row means the unique value collapsed them.", "Throw from a lookup when the user must hear that the SKU is taken.", "Do not use #Unique unless you raise the deployment target and wrap it in an availability check. This target stays on @Attribute(.unique)."],
        quiz: [
            Quiz.make("m5c1", "A second save with the same SKU:", ["Throws from init", "Keeps one row and replaces its values", "Is ignored by the store", "Creates two rows"], correct: 1, "save() succeeded in the file-backed test and the stored name became Duplicate."),
            Quiz.make("m5c2", "#Unique is:", ["Required on iOS 17", "An iOS 18 compound-constraint macro this lab does not call", "The same as @Transient", "A delete rule"], correct: 1, "The deployment target stays on the iOS 17 attribute."),
            Quiz.make("m5c3", "To refuse a duplicate SKU you should:", ["Wait for save() to throw", "Look the SKU up and throw before insert", "Mark the property @Transient", "Turn on CloudKit"], correct: 1, "The store replaces the row. The app has to reject it.")
        ],
        playground: .modelDesign,
        sdkNote: "#Unique and #Index are iOS 18 macros. This app deploys to iOS 17 and uses @Attribute(.unique) instead. The newer macros are named here so you can recognize them, and they are not compiled into the target."
    )

    static let transient = Lesson.make(
        id: "m5-transient", moduleID: id, title: "Transient properties",
        summary: "@Transient keeps a value on the instance and out of the store.",
        concept: "@Transient var draftNote is stored in the object and lost when the object is fetched again in a new process. It is useful for UI scratch that must sit beside the model for a moment and must not become a column. A computed property is different: it has no storage at all. Neither can appear in a predicate. Do not use transient for data the user expects after relaunch. The notes editor uses a separate view-model draft instead of a transient property, which is the better place for a cancelable form because the draft does not pretend to be part of the model.",
        whyItExists: "Not every field on the class is a fact about the row.",
        whenToUse: "Short-lived scratch tied to an instance you already hold. Prefer view state when the scratch belongs to the screen.",
        sample: Samples.make("m5-trans", "A draft that is not a column", #"""
        import SwiftData

        let item = DesignedItem(sku: sku, name: name)
        item.draftNote = draft
        modelContext.insert(item)
        try modelContext.save()
        // After the next launch, draftNote is empty. name is still stored.
        """#, [
            ("item.draftNote = draft", "@Transient stores this only on the current instance."),
            ("try modelContext.save()", "The save writes name and sku. It does not write draftNote.")
        ]),
        expectedBehavior: "The status tells you the draft is instance-only. After relaunch the draft line reads empty while the name remains.",
        experiment: "Save an item with a draft note, stop the app, and run it again. Compare name and draft.",
        experimentHint: "The model design list prints the draft or the word empty.",
        experimentSolution: "The name survived. The draft did not, because it is not in the schema.",
        challenge: "Give one reason the notes editor does not use @Transient for its text fields.",
        challengeHint: "Cancel and observation.",
        challengeSolution: "A transient property on the model still lives on the persistent object and is easy to confuse with stored state. A view-model draft is obviously not the row until save.",
        bugTitle: "Predicating on a transient property",
        bugCode: "#Predicate<DesignedItem> { $0.draftNote == \"ready\" }",
        bugQuestion: "Why is this the wrong tool?",
        bugDiagnosis: "draftNote is not a column. The predicate cannot translate it. Filter stored properties, or keep the draft in the view.",
        mistakes: ["Using transient for a value that must survive relaunch.", "Expecting @Query to sort by a transient property.", "Hiding real model fields as transient to avoid a migration."],
        debuggingTips: ["Relaunch is the test.", "Look at the property macro. @Transient and a plain var are different.", "If a new column was the real goal, add it and migrate."],
        quiz: [
            Quiz.make("m5d1", "@Transient data after relaunch is:", ["Restored", "Empty or default, because it was not stored", "Migrated", "Unique"], correct: 1, "It never entered the file."),
            Quiz.make("m5d2", "A computed property differs because:", ["It is a column", "It has no storage", "It is unique", "It cascades"], correct: 1, "Transient has instance storage. Computed does not."),
            Quiz.make("m5d3", "A cancelable editor draft belongs:", ["In the store", "In view-model state or truly temporary UI state", "In the schema version", "In the inverse"], correct: 1, "It is not a fact until the user saves.")
        ],
        playground: .modelDesign
    )

    static let enums = Lesson.make(
        id: "m5-enums", moduleID: id, title: "Enums and value types",
        summary: "Raw-value Codable enums can be columns. Associated values cannot.",
        concept: "TaskPriority and ReadingStatus are String raw-value enums that conform to Codable. SwiftData stores the raw value. A picker can bind to the property. Associated-value enums are not a supported attribute. If you need a payload, store a raw status plus separate columns, or store a Codable struct. Enums you want in predicates should stay simple. If a predicate over the enum will not compile, store the raw string in a column and predicate on that, and keep a computed enum for the UI. This target stores the enum directly because these cases have no payloads. Do not store a SwiftUI enum such as a Color. Store a name you control.",
        whyItExists: "Strings drift into typos. An enum keeps the legal set in the type.",
        whenToUse: "Closed sets: priority, reading status, a sync state you own. Not for user-generated category names. Those are models.",
        sample: Samples.make("m5-enum", "A Codable raw enum", #"""
        import SwiftData

        enum TaskPriority: String, Codable, CaseIterable {
            case low, medium, high
        }

        @Model
        final class StudyTask {
            var priority: TaskPriority
            init(priority: TaskPriority) { self.priority = priority }
        }
        """#, [
            ("String, Codable", "The raw value is what the store knows how to encode."),
            ("var priority: TaskPriority", "A column, not a transient mapping."),
            ("case low, medium, high", "No associated values. Those would not be a legal attribute.")
        ]),
        expectedBehavior: "The task manager picker writes a TaskPriority and the row shows Low, Medium, or High after relaunch.",
        experiment: "Add a high-priority task, relaunch the task project, and confirm the priority label.",
        experimentHint: "The picker is on the new-task form.",
        experimentSolution: "The raw value was stored and decoded back into the enum.",
        challenge: "Why is a category a model while a priority is an enum?",
        challengeHint: "Who invents the values?",
        challengeSolution: "The app owns the priority set. The user invents categories, and categories have relationships. An enum cannot grow a new case because someone typed one.",
        bugTitle: "Associated value as a column",
        bugCode: "enum Status: Codable { case reading(page: Int) }",
        bugQuestion: "Why is this a poor SwiftData attribute?",
        bugDiagnosis: "The store does not treat associated-value enums as columns. Store page as an Int and status as a simple raw enum.",
        mistakes: ["A new enum case without a migration plan for old raw values.", "Using the enum name as a user-facing English string with no mapping.", "Predicating on a computed enum you forgot to store."],
        debuggingTips: ["If decoding fails after a rename, the raw value in the file no longer matches.", "Keep CaseIterable for pickers.", "Test a round trip: save high, fetch, compare."],
        quiz: [
            Quiz.make("m5e1", "Which enum can be a property?", ["String raw value, Codable, no payloads", "An enum with associated values", "A SwiftUI Color", "A ViewBuilder result"], correct: 0, "Simple Codable raw enums are supported."),
            Quiz.make("m5e2", "User-created categories should be:", ["New enum cases", "A model", "Transient", "A sort order"], correct: 1, "Users can create values the compiler cannot list."),
            Quiz.make("m5e3", "The stored form of TaskPriority is:", ["The whole Swift type metadata", "Its raw value", "Its localized title only", "Nothing, it is computed"], correct: 1, "Codable raw values are the column contents.")
        ],
        playground: .modelDesign
    )

    static let collections = Lesson.make(
        id: "m5-collections-codable", moduleID: id, title: "Collections and Codable values",
        summary: "[String] is a column. A Codable struct is one transformable value, not several columns.",
        concept: "DesignedItem.tags is [String]. That array is a supported collection. ItemMetadata is a Codable struct stored as one transformable value. You can read metadata.rating in Swift after the object is loaded. You should not expect a predicate to filter metadata.rating as if it were a column. If you must query the rating, promote it to a stored property. Mutating a struct or an array in place can be missed. Reassign the whole value: item.tags = item.tags + [\"new\"], and item.metadata = ItemMetadata(...). Relationships are not this kind of collection. [Author] on a book is a relationship, with an inverse and a delete rule.",
        whyItExists: "Small embedded values do not deserve a table. Queryable facts do.",
        whenToUse: "Tags as strings when they are not shared entities. A metadata blob for data you only display. A real Tag model when tags are shared, which is what the bookmarks project does.",
        sample: Samples.make("m5-cod", "Reassign the collection", #"""
        import SwiftData

        var tags = item.tags
        tags.append("new")
        item.tags = tags

        var metadata = item.metadata
        metadata.rating = 5
        item.metadata = metadata
        """#, [
            ("item.tags = tags", "Reassignment is the reliable way to publish an array edit."),
            ("item.metadata = metadata", "The struct is one value. Assign it back so the context notices.")
        ]),
        expectedBehavior: "A designed item saved with tags lab and design shows those strings after fetch.",
        experiment: "Save an item and confirm the tag line in the list.",
        experimentHint: "insert uses tags lab and design.",
        experimentSolution: "The array was stored and fetched as [String], not as Tag models.",
        challenge: "Why do bookmarks use a Tag model instead of [String]?",
        challengeHint: "Sharing and uniqueness.",
        challengeSolution: "The same tag is attached to many bookmarks, has a unique name, and can be deleted as its own object. A string array would duplicate the label and could not nullify one shared row.",
        bugTitle: "In-place array edit",
        bugCode: "item.tags.append(\"new\")\ntry context.save()",
        bugQuestion: "Why might the new tag be missing after fetch?",
        bugDiagnosis: "The array is a value type. Mutating it through a property that was not written back can skip change tracking. Reassign item.tags.",
        mistakes: ["Predicating into a Codable struct.", "Using [String] for shared tags.", "Nesting models inside the Codable struct."],
        debuggingTips: ["After save, fetch in a new context and print tags.", "If you need a query, add a real column.", "Keep Codable structs small and Hashable so previews and tests can compare them."],
        quiz: [
            Quiz.make("m5f1", "ItemMetadata.rating is:", ["Its own column", "Part of one encoded value", "A relationship", "Transient"], correct: 1, "The struct is transformable storage."),
            Quiz.make("m5f2", "To edit tags reliably:", ["Append and hope", "Reassign the array property", "Make the array transient", "Use noAction"], correct: 1, "Write the whole value back."),
            Quiz.make("m5f3", "[Author] on LibraryBook is:", ["A Codable collection", "A relationship", "A transient cache", "Illegal"], correct: 1, "Other models are relationships, not transformable arrays.")
        ],
        playground: .modelDesign
    )

    static let initialization = Lesson.make(
        id: "m5-initialization", moduleID: id, title: "Model initialization",
        summary: "Your init builds new objects. Fetch does not replay it.",
        concept: "When you call DesignedItem(...), your initializer runs and must assign stored properties. When SwiftData fetches a row, it materializes the instance from the store. Do not put side effects in init that must run on every load: no network, no analytics, no insert of related objects. Do not call context.insert inside the model initializer. The caller decides which context, if any, should track the object. Uniqueness is not checked in init. Relationship defaults such as = [] let you omit those arguments. A convenience initializer is fine. A required custom schema initializer that the macro cannot see is not something you should invent.",
        whyItExists: "Init looks like the place to be clever. It is the wrong place, because fetch bypasses those clever arguments.",
        whenToUse: "Assign stored state. Keep derived work in methods the caller runs on purpose.",
        sample: Samples.make("m5-init", "Init assigns, the caller inserts", #"""
        import SwiftData

        let item = DesignedItem(sku: "FIELD-1", name: "Field notes")
        // The initializer did not insert and did not save.
        modelContext.insert(item)
        try modelContext.save()
        """#, [
            ("DesignedItem(sku:", "Your init ran because you called it."),
            ("modelContext.insert(item)", "Registration is outside the model. The model does not know about a global context.")
        ]),
        expectedBehavior: "Creating a DesignedItem does not change the list until Save item, which inserts and saves.",
        experiment: "Open the model design playground and do nothing. The list does not gain a row from the view appearing.",
        experimentHint: "There is no hidden insert in DesignedItem.init.",
        experimentSolution: "The list changes only after the button inserts and saves.",
        challenge: "Where should sample expenses be inserted: in Expense.init, or in a function the button calls?",
        challengeHint: "Look at ExpenseQuery.insertSampleExpenses.",
        challengeSolution: "In the function the button calls. Otherwise every new Expense would try to seed the database, including ones fetched later if you had put the side effect in a place fetch could hit. Init must stay pure.",
        bugTitle: "Insert inside init",
        bugCode: "init(name: String, context: ModelContext) {\n    self.name = name\n    context.insert(self)\n}",
        bugQuestion: "Why is that harmful?",
        bugDiagnosis: "Every new instance immediately joins that context, including ones you meant to throw away. Fetch paths must not depend on this initializer. Keep insert at the call site.",
        mistakes: ["Network calls in init.", "Assuming fetch runs init(title:author:).", "Checking unique constraints in init and thinking the store agrees."],
        debuggingTips: ["Put a breakpoint in init. Fetch should not hit the custom argument list.", "Keep init small enough to read.", "Seed data from a named function."],
        quiz: [
            Quiz.make("m5g1", "Fetch of an existing row:", ["Calls your init with the original arguments", "Materializes stored properties", "Always inserts a duplicate", "Runs migration"], correct: 1, "Do not rely on init side effects for loaded rows."),
            Quiz.make("m5g2", "insert belongs:", ["Inside the model init", "At the call site that owns a context", "Inside #Predicate", "Inside the inverse"], correct: 1, "The caller chooses the context."),
            Quiz.make("m5g3", "A default of [] on a relationship:", ["Deletes children", "Lets init omit that argument", "Marks the link unique", "Disables cascade"], correct: 1, "The property is already initialized.")
        ],
        playground: .modelDesign
    )

    static let inheritance = Lesson.make(
        id: "m5-inheritance", moduleID: id, title: "Inheritance limitations",
        summary: "Model classes are final. Use composition or an enum instead of a subclass.",
        concept: "SwiftData does not support a hierarchy of @Model classes. Book cannot have a SpecialBook subclass that adds columns. The macro requires final. If you need variation, use a raw enum that selects behavior, or compose a Codable struct, or make a separate model with a relationship. Entity inheritance from Core Data does not carry over. The broken snippet in the bug section is documentation of a compile failure. It is not a type in this target, because shipping it would not compile. Protocols can still exist for non-persistent behavior, but the persistent type itself is one final class.",
        whyItExists: "The schema is a flat list of entities. Subclass columns do not fit that story in SwiftData today.",
        whenToUse: "Whenever a design review proposes class inheritance for models. Stop and pick an enum or a relationship.",
        sample: Samples.make("m5-final", "One final class and a discriminator", #"""
        import SwiftData

        enum ReadingStatus: String, Codable { case unread, reading, finished }

        @Model
        final class DesignedItem {
            var name: String
            var status: ReadingStatus
            init(name: String, status: ReadingStatus) {
                self.name = name
                self.status = status
            }
        }
        """#, [
            ("final class DesignedItem", "final is required. A subclass is not a second entity."),
            ("var status: ReadingStatus", "Variation is data, not a subclass.")
        ]),
        expectedBehavior: "The target compiles because there is no model subclass. The bug card shows the pattern that does not compile.",
        experiment: "Read the bug snippet and confirm there is no SpecialBook type in the project.",
        experimentHint: "The models folder has Book, not a subclass.",
        experimentSolution: "Variation is an enum or another model. The compiler would reject @Model class SpecialBook: Book.",
        challenge: "You need a video note and a text note with different fields. Name two legal designs.",
        challengeHint: "Enum plus optional fields, or two models.",
        challengeSolution: "One Note model with a kind enum and optional video URL, or two models related to a common parent that is not a SwiftData superclass, such as a protocol the views use. Do not subclass @Model.",
        bugTitle: "Subclassing a model",
        bugCode: "@Model\nfinal class SpecialBook: Book {\n    var edition: Int = 1\n}",
        bugQuestion: "What is the outcome if this is added to the target?",
        bugDiagnosis: "The macro rejects model inheritance. SpecialBook is not in the target. Use a property on Book or a new model.",
        mistakes: ["Hiding fields in a subclass to avoid migration.", "A protocol that you then try to list in the schema.", "Copying a Core Data parent-entity design straight across."],
        debuggingTips: ["If the diagnostic mentions inheritance, flatten the type.", "Search for @Model class declarations that are not final.", "Keep the illegal snippet in the lesson, not in the module."],
        quiz: [
            Quiz.make("m5h1", "SwiftData model inheritance is:", ["Encouraged", "Unsupported", "Required for relationships", "How migrations work"], correct: 1, "Models are final classes."),
            Quiz.make("m5h2", "A legal way to vary a model is:", ["A subclass", "A stored enum or a composed value", "An NSManagedObject parent", "A SwiftUI View subclass"], correct: 1, "Put the variation in data."),
            Quiz.make("m5h3", "The SpecialBook snippet is:", ["A compiled model", "An example of code this target deliberately does not compile", "The migration plan", "A transient helper"], correct: 1, "It is shown as a bug, not as a type.")
        ],
        playground: .modelDesign
    )

    static let supported = Lesson.make(
        id: "m5-supported-types", moduleID: id, title: "Supported property types",
        summary: "The column types this lab uses, and the ones it refuses.",
        concept: "Supported stored types include Bool, numeric types, Double, String, Date, Data, UUID, URL, raw Codable enums, arrays of those values, and Codable structs as transformable values. Optional versions are supported. Relationships are other models. This lab uses Double for money in predicates and says plainly that Decimal can be stored but is a poor predicate citizen. It stores bookmark addresses as String so the form can hold invalid text. URL is used on DesignedItem.externalLink where the value is already a URL. Unsupported as columns: SwiftUI views, UIColor, closures, associated-value enums, and class instances that are not models. iOS 18 #Index can index properties. It is not used here because the deployment target is iOS 17.",
        whyItExists: "A model that compiles is not the same as a model the store can round-trip. The macro and the store both have opinions.",
        whenToUse: "Check this list before adding a property. If you need a query, the value must be a real column, not a blob field you hope to peek into.",
        sample: Samples.make("m5-types", "Several legal columns", #"""
        import SwiftData

        @Model
        final class DesignedItem {
            var name: String
            var quantity: Int
            var price: Double
            var isArchived: Bool
            var addedOn: Date
            var identifier: UUID
            var externalLink: URL?
            var thumbnail: Data?
            var tags: [String]
            init(name: String, quantity: Int, price: Double, isArchived: Bool, addedOn: Date, identifier: UUID) {
                self.name = name
                self.quantity = quantity
                self.price = price
                self.isArchived = isArchived
                self.addedOn = addedOn
                self.identifier = identifier
                self.tags = []
            }
        }
        """#, [
            ("var price: Double", "Double is the predicate-friendly number in this lab."),
            ("var externalLink: URL?", "URL is legal when you already have a URL. Invalid drafts belong in a String."),
            ("var tags: [String]", "A supported collection, not a relationship.")
        ]),
        expectedBehavior: "DesignedItem saves with the types above. The playground does not ask you to store a View.",
        experiment: "Save an item and relaunch. UUID, date, and tags come back. You never set a thumbnail, so that optional Data stays nil.",
        experimentHint: "thumbnail defaults to nil.",
        experimentSolution: "The stored fields round-trip. The nil Data stays nil.",
        challenge: "Why is the bookmark URL a String while DesignedItem.externalLink is URL??",
        challengeHint: "Validation versus storage.",
        challengeSolution: "The bookmark form must keep a half-typed address that is not yet a URL. The designed item only stores a real URL or nil.",
        bugTitle: "Storing a Color",
        bugCode: "var tint: Color",
        bugQuestion: "Why is Color the wrong column?",
        bugDiagnosis: "SwiftUI.Color is not a persistent value type in the schema. Store a name or hex string and map it in the view.",
        mistakes: ["Decimal in a predicate because it is a legal attribute.", "Data for something you need to query.", "A dictionary of models."],
        debuggingTips: ["If the macro rejects a property, replace it with a stored primitive.", "Promote blob fields to columns when you start filtering on them.", "Keep #Index off this target unless you raise the deployment target."],
        quiz: [
            Quiz.make("m5i1", "Which is a legal column?", ["String", "SwiftUI.View", "A closure", "UIColor"], correct: 0, "String is a basic attribute."),
            Quiz.make("m5i2", "This lab uses Double for amounts because:", ["Decimal cannot be stored at all", "Predicates over Double are straightforward", "Double is unique", "Double is transient"], correct: 1, "Decimal as an attribute is a different question from Decimal in a predicate."),
            Quiz.make("m5i3", "#Index is:", ["Used on every model here", "An iOS 18 feature this iOS 17 target does not call", "A delete rule", "Required for @Query"], correct: 1, "The lab stays on the iOS 17 schema surface.")
        ],
        playground: .modelDesign,
        sdkNote: "iOS 18 adds #Index and #Unique. They are not referenced in compiled code. Raising the deployment target is a product decision, not something a lesson should sneak into the schema."
    )
}
