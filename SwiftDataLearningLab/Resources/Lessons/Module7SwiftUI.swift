import Foundation

enum Module7SwiftUI {
    static let id = "swiftui"
    static let module = LearningModule(
        id: id,
        title: "SwiftUI integration",
        summary: "@Query, bindings, lists, search, empty states, the shared container, and previews.",
        level: .intermediate,
        order: 7,
        lessons: [query, reactivity, forms, lists, search, states, sharing, previews]
    )

    static let query = Lesson.make(
        id: "m7-query-in-views", moduleID: id, title: "Using @Query in views",
        summary: "The property wrapper belongs on the view that draws the rows.",
        concept: "@Query fetches when the view is installed in a hierarchy that has a model container. The SwiftUI lab declares it on the playground view, which sits under RootView's .modelContainer. The sort is part of the query, so the list does not re-sort by hand. Keep the query private. Pass a single model into a child if the child edits one row. Do not pass the whole query array through an @Observable object and also keep the wrapper. One owner.",
        whyItExists: "A view that fetches in body repeats work and loses observation.",
        whenToUse: "Screen-sized lists of one model. The task, bookmark, and library projects use it. Notes deliberately do not, so the view model stays testable.",
        sample: Samples.make("m7-query", "Query on the lab view", #"""
        import SwiftData
        import SwiftUI

        struct SwiftUILabPlayground: View {
            @Query(sort: \LabRecord.updatedAt, order: .reverse) private var records: [LabRecord]
            var body: some View {
                List(records) { record in
                    Text(record.title)
                }
            }
        }
        """#, [
            ("@Query(sort: \\LabRecord.updatedAt", "The view context supplies the rows."),
            ("List(records)", "Identity comes from persistentModelID, which List uses via Identifiable.")
        ]),
        expectedBehavior: "Inserting in the SwiftUI lab adds a row without calling a reload method.",
        experiment: "Insert a record in the SwiftUI playground.",
        experimentHint: "The list is the query result.",
        experimentSolution: "The new title appears because insert and save hit the same context the query observes.",
        challenge: "Why is the notes list not an @Query?",
        challengeHint: "Module 10 and the repository.",
        challengeSolution: "NotesListViewModel loads through a repository so a unit test can run without a View. The tradeoff is an explicit load() after writes.",
        bugTitle: "Query above the container",
        bugCode: "WindowGroup { LabList() }\n// modelContainer is missing",
        bugQuestion: "Why is the list empty or the preview crashing?",
        bugDiagnosis: "@Query has no container. Attach .modelContainer on an ancestor.",
        mistakes: ["A query per row.", "Sorting again in the view with a different key.", "Using the query from a sheet that lost the environment."],
        debuggingTips: ["If preview crashes, the preview is missing a container.", "Compare with the FetchDescriptor playground.", "Check the modifier is on the WindowGroup content, not a sibling."],
        quiz: [
            Quiz.make("m7a1", "@Query needs an ancestor:", [".modelContainer", ".padding", ".searchable", ".task"], correct: 0, "The wrapper reads that environment."),
            Quiz.make("m7a2", "Notes avoid @Query because:", ["Notes cannot be stored", "The view model must be testable without SwiftUI", "Queries cannot sort", "Titles are unique"], correct: 1, "The repository is the test seam."),
            Quiz.make("m7a3", "List identity for a model uses:", ["The title", "persistentModelID", "The row index only", "The file URL"], correct: 1, "PersistentModel is Identifiable by that id.")
        ],
        playground: .swiftUI
    )

    static let reactivity = Lesson.make(
        id: "m7-reactivity", moduleID: id, title: "Reactivity after writes",
        summary: "Insert, update, and delete in the view context refresh @Query.",
        concept: "The view context tracks models and SwiftUI observation invalidates views that read them. An insert into that context, once processed, shows up in @Query. A property write on a listed object updates the text that reads it. A delete removes the row. Writes in a different context appear after they are saved and the view context learns about the store change. The concurrency lab deliberately reads through a new context because a background save is the case most likely to look stale. Do not call objectWillChange yourself on a model. You will fight the macro.",
        whyItExists: "The point of @Query is that the screen follows the store without a reload button.",
        whenToUse: "Trust it for the view context. After background work, fetch again or use a new context if the list looks stale, and do not pretend the timing is magic.",
        sample: Samples.make("m7-react", "Insert into the view context", #"""
        import SwiftData

        modelContext.insert(LabRecord(title: trimmed, notes: "Created from the SwiftUI lab"))
        try modelContext.save()
        """#, [
            ("modelContext.insert", "The environment context is the one @Query is using."),
            ("try modelContext.save()", "Makes the row durable. Autosave might also flush, but the button does not rely on that.")
        ]),
        expectedBehavior: "The row appears in the list after Insert. Delete in the editor removes it.",
        experiment: "Insert a row, open it, delete it, and return.",
        experimentHint: "The editor is a navigation push from the lab list.",
        experimentSolution: "The list gains and then loses the row. Both operations used the view context.",
        challenge: "Why might a ModelActor save not redraw the list on the same frame?",
        challengeHint: "It is a different context.",
        challengeSolution: "The actor saved its own context. The view context has to observe the store change. The concurrency playground reads with a fresh context so the result does not depend on that timing.",
        bugTitle: "A manual cache next to @Query",
        bugCode: "@State var cache: [LabRecord] = []\n.onAppear { cache = records }",
        bugQuestion: "Why does the cache go stale?",
        bugDiagnosis: "You copied the array once. Later inserts update the query and not the copy. Render the query.",
        mistakes: ["Dispatching the insert to a background queue with the view context.", "Refreshing by recreating the whole container.", "Ignoring save errors and blaming observation."],
        debuggingTips: ["Breakpoint the insert and the body.", "Confirm both use the same container.", "If only background writes are wrong, the view path is fine."],
        quiz: [
            Quiz.make("m7b1", "A view-context insert is reflected by @Query:", ["After the context processes the change", "Never", "Only after reinstall", "Only for unique properties"], correct: 0, "That is the observation path."),
            Quiz.make("m7b2", "A background context's save is:", ["The same object graph", "A different context that must commit before others can read it", "Ignored by SQLite", "A preview"], correct: 1, "Contexts do not share unsaved work."),
            Quiz.make("m7b3", "objectWillChange on a model is:", ["Required", "Something to avoid. The macro observes", "The migration plan", "The delete rule"], correct: 1, "Let the generated observation work.")
        ],
        playground: .swiftUI
    )

    static let forms = Lesson.make(
        id: "m7-forms-bindings", moduleID: id, title: "Forms and bindings",
        summary: "@Bindable writes straight through to a tracked model.",
        concept: "@Bindable on a model lets TextField bind to $record.title. Each keystroke assigns the stored property, so the context tracks the change and autosave may persist it before the user thinks they committed. That is acceptable for the lab editor and wrong for a screen with Cancel. The notes editor keeps String state on the view model and calls save explicitly. Use the binding when the model is the draft. Use a copy when cancel must discard. onDisappear in the lab editor saves so a pop still commits. A production editor should make that button obvious rather than only saving on disappear.",
        whyItExists: "Bindings are the shortest correct path and the easiest way to persist a half-edited form by accident.",
        whenToUse: "Inline edits and simple inspectors. Not for a modal create flow with Cancel.",
        sample: Samples.make("m7-form", "Bindable model form", #"""
        import SwiftData
        import SwiftUI

        struct LabRecordForm: View {
            @Bindable var record: LabRecord
            var body: some View {
                Form {
                    TextField("Title", text: $record.title)
                    TextField("Notes", text: $record.notes)
                }
            }
        }
        """#, [
            ("@Bindable var record", "The model is observable, so the binding can write through."),
            ("$record.title", "This assigns the stored property. It is an update, not a copy.")
        ]),
        expectedBehavior: "Editing the title in the pushed form changes the stored title. Relaunch shows it.",
        experiment: "Open a lab record, change the title, go back, and relaunch.",
        experimentHint: "onDisappear also saves.",
        experimentSolution: "The new title is in the store. There was no separate draft.",
        challenge: "What would you add so this form can cancel?",
        challengeHint: "Look at NoteEditorViewModel.",
        challengeSolution: "Copy title and notes into the view model. Write them onto the model only in Save. Dismiss without save leaves the row alone.",
        bugTitle: "Binding and autosave as an implicit commit",
        bugCode: "TextField(\"Title\", text: $record.title)",
        bugQuestion: "Why can a relaunch show text the user meant to cancel?",
        bugDiagnosis: "The binding mutated the tracked object and autosave flushed it. Cancel cannot undo a commit that already happened unless you rollback or use a draft.",
        mistakes: ["Binding to a transient property and expecting durability.", "Binding to a model from another context.", "Dismissing without a clear save while teaching explicit transactions."],
        debuggingTips: ["Watch hasChanges while typing.", "Compare with the notes Save button.", "If relaunch lost the edit, neither save nor autosave ran."],
        quiz: [
            Quiz.make("m7c1", "@Bindable on a model:", ["Copies the row", "Writes property assignments into the tracked object", "Creates a container", "Disables autosave"], correct: 1, "The binding is an assignment."),
            Quiz.make("m7c2", "A cancelable form should:", ["Bind directly", "Edit a draft and save on purpose", "Delete the row on appear", "Use noAction"], correct: 1, "The notes editor is the example."),
            Quiz.make("m7c3", "onDisappear save in the lab is:", ["A hidden commit", "The only legal SwiftData API", "A migration", "A predicate"], correct: 0, "Prefer a visible Save when the boundary matters.")
        ],
        playground: .swiftUI
    )

    static let lists = Lesson.make(
        id: "m7-lists-navigation", moduleID: id, title: "Lists and navigation",
        summary: "Navigate by persistent identifier, not by hoping the class is a route.",
        concept: "List and ForEach use the model's persistent identity. Navigation in the SwiftUI lab appends a PersistentIdentifier. The editor resolves it with model(for:) and bails out if the object is deleted. Passing the live model through the path also type-checks, because models are Hashable, and it is still the worse choice: the value in the path can outlive a delete. The app coordinator navigates lessons by String id for the same reason. Swipe to delete should delete the model and save, not only remove a local array.",
        whyItExists: "Navigation state lives longer than a single body invocation. Identity has to be stable.",
        whenToUse: "Any push to an editor. Resolve the id on the destination side.",
        sample: Samples.make("m7-nav", "Push an identifier", #"""
        import SwiftData
        import SwiftUI

        NavigationLink(value: record.persistentModelID) {
            Text(record.title)
        }
        .navigationDestination(for: PersistentIdentifier.self) { id in
            LabRecordEditor(identifier: id)
        }
        """#, [
            ("record.persistentModelID", "A stable value. It is not the title."),
            ("navigationDestination(for: PersistentIdentifier.self)", "The editor resolves the id in the destination context.")
        ]),
        expectedBehavior: "Tapping a row pushes an editor. Deleting the row pops the data out from under a stale binding because the loader checks isDeleted.",
        experiment: "Open a row, change notes, go back, and confirm the list subtitle or a second open shows the notes.",
        experimentHint: "The form binds notes.",
        experimentSolution: "The identifier led back to the same row. The notes were stored on it.",
        challenge: "Why does the lesson catalog navigate with a String id instead of the Lesson value?",
        challengeHint: "Lesson contains the whole curriculum text.",
        challengeSolution: "The path stays small and stable. The screen looks the lesson up. The same idea as a persistent identifier: pass the key, resolve the object.",
        bugTitle: "Index-based navigation",
        bugCode: "NavigationLink(value: index) { Text(records[index].title) }",
        bugQuestion: "What breaks after a delete?",
        bugDiagnosis: "Indexes shift. The link opens the wrong row or crashes. Use the persistent identifier.",
        mistakes: ["Routing by title.", "Holding the model in @State across a container reset.", "Forgetting navigationDestination so the tap does nothing."],
        debuggingTips: ["Print the identifier, not only the title.", "If the editor says unavailable, the row was deleted or the id came from another store.", "Keep one destination per type on that stack."],
        quiz: [
            Quiz.make("m7d1", "The lab pushes:", ["The row index", "persistentModelID", "The store URL", "The schema version"], correct: 1, "The editor resolves it."),
            Quiz.make("m7d2", "model(for:) on a deleted id should be:", ["Displayed as normal", "Rejected with isDeleted or a missing object", "Reinserted", "Migrated"], correct: 1, "The editor shows an unavailable state."),
            Quiz.make("m7d3", "Swipe delete should:", ["Only edit @State", "Delete the model and save", "Nullify the container", "Run a migration"], correct: 1, "The list is a view of the store.")
        ],
        playground: .swiftUI
    )

    static let search = Lesson.make(
        id: "m7-search", moduleID: id, title: "Search interfaces",
        summary: ".searchable is the field. The predicate is still your job.",
        concept: "The dashboard uses .searchable and filters lessons in memory because lessons are catalog values, not SwiftData rows. The notes project uses .searchable and refetches with a predicate, because notes are rows. The expense project uses explicit filter fields because a date range does not fit one search string. Pick the control the filter needs. Do not run an unbounded fetch on every keystroke without a limit once the table is large. Empty search must widen the results, not search for the word empty.",
        whyItExists: "A search box that only filters a forgotten array will disagree with the store.",
        whenToUse: "Text containment uses searchable plus a predicate. Structured filters use toggles and dates, as expenses do.",
        sample: Samples.make("m7-search", "Notes search refetches", #"""
        import SwiftUI

        .searchable(text: $viewModel.searchText, prompt: "Search notes")
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.load()
        }
        """#, [
            (".searchable", "System search field, including the clear button."),
            ("viewModel.load()", "Rebuilds the predicate. The field does not know about SwiftData.")
        ]),
        expectedBehavior: "Typing in the notes search narrows the list to title or body matches. Clearing it restores the list.",
        experiment: "Create two notes, search for a word that is only in one body.",
        experimentHint: "The predicate uses OR across title and body.",
        experimentSolution: "The note with the word in the body remains. The other drops out until you clear search.",
        challenge: "Why is the lesson search not a #Predicate?",
        challengeHint: "Lesson is not a @Model.",
        challengeSolution: "The curriculum is a Swift value in memory. localizedStandardContains on the struct is the right tool. Predicates are for the store.",
        bugTitle: "Filtering a stale array",
        bugCode: ".searchable(text: $text)\nvar shown: [Note] { allNotes.filter { $0.title.contains(text) } }",
        bugQuestion: "When is this wrong even if it looks right on a small list?",
        bugDiagnosis: "allNotes was a one-time fetch, contains is case-sensitive, and you never asked the store. Use the repository predicate.",
        mistakes: ["Case-sensitive contains for user search.", "A search that does not include the fields the user expects.", "Forgetting the empty-string shape."],
        debuggingTips: ["Log the trimmed query and the count.", "Test a lowercase query against an uppercase title.", "Add fetchLimit before the table grows."],
        quiz: [
            Quiz.make("m7e1", ".searchable provides:", ["A predicate", "The system search field", "A migration", "A container"], correct: 1, "You still build the fetch."),
            Quiz.make("m7e2", "Notes search is:", ["In-memory on a Swift array only", "A FetchDescriptor predicate", "A CloudKit query", "A transient property"], correct: 1, "The repository owns it."),
            Quiz.make("m7e3", "Lesson search is in memory because:", ["Lessons are not model rows", "Predicates cannot use strings", "The store is read-only", "@Query is deprecated"], correct: 0, "The catalog is compiled Swift.")
        ],
        playground: .notes
    )

    static let states = Lesson.make(
        id: "m7-empty-loading-error", moduleID: id, title: "Empty, loading, and error states",
        summary: "Local SwiftData is usually empty or ready. Errors are save and container failures.",
        concept: "There is no network loading state for this store. A ProgressView that waits for @Query to become non-nil will spin forever, because the array is empty rather than absent. Use ContentUnavailableView for no notes, no tasks, no bookmarks. Use ProgressView for work you started, such as the migration button or the notes screen before the first load() returns. Use an alert or a banner for a thrown save. Use ContainerErrorView when the container itself cannot open. Do not hide a unique-constraint error behind an empty list.",
        whyItExists: "Empty and broken look the same if you only check count == 0.",
        whenToUse: "Every list in the projects. The notes empty state includes the create button so the next step is obvious.",
        sample: Samples.make("m7-empty", "Empty is not loading", #"""
        import SwiftUI

        if records.isEmpty {
            ContentUnavailableView(
                "Nothing here",
                systemImage: "tray",
                description: Text("Insert a row. There is no network loading state because the store is local.")
            )
        }
        """#, [
            ("records.isEmpty", "A successful fetch of zero rows."),
            ("no network loading state", "Do not show a spinner for a local query that has already answered.")
        ]),
        expectedBehavior: "The SwiftUI lab shows the empty view before the first insert, then the list.",
        experiment: "Reset lab records from the CRUD screen, open the SwiftUI lab, and read the empty copy. Then insert.",
        experimentHint: "Reset is on the CRUD playground.",
        experimentSolution: "Empty is a real state. Insert replaces it. Neither step waited on the network.",
        challenge: "Where should a duplicate SKU error appear?",
        challengeHint: "Not as an empty list.",
        challengeSolution: "In the status banner or an alert that includes localizedDescription, after rollback.",
        bugTitle: "Spinner until count > 0",
        bugCode: "if notes.isEmpty { ProgressView() }",
        bugQuestion: "What does a new user see?",
        bugDiagnosis: "An infinite spinner. Zero notes is the empty state, not a load.",
        mistakes: ["try? save with no UI.", "A full-screen error for a validation miss.", "Clearing the error before the user can read it."],
        debuggingTips: ["Separate isLoaded from isEmpty, as the notes list does.", "Surface localizedDescription.", "The container error is the only full-screen store failure."],
        quiz: [
            Quiz.make("m7f1", "An empty local @Query should show:", ["A spinner forever", "An empty state", "A migration", "CloudKit login"], correct: 1, "The fetch already finished."),
            Quiz.make("m7f2", "A thrown save should:", ["Be ignored", "Be shown", "Delete the store", "Switch schemas"], correct: 1, "The user cannot fix a hidden error."),
            Quiz.make("m7f3", "ContainerErrorView is for:", ["Zero notes", "The container failing to open", "An empty search", "A deny rule you handled"], correct: 1, "That is a launch failure, not an empty table.")
        ],
        playground: .swiftUI
    )

    static let sharing = Lesson.make(
        id: "m7-sharing-container", moduleID: id, title: "Sharing the model container",
        summary: "One container on the window. Every tab reads the same environment.",
        concept: "RootView sits inside .modelContainer. Learn, Projects, and Progress are tabs under that modifier, so they share the store. A book saved in the lab is visible to a fetch in another tab. They do not share unsaved changes across contexts you create yourself. Passing the container into a ModelActor is sharing the store, not sharing the view context. The actor builds its own context. Do not create a second makeShared() container for a tab. Two containers on one file fight. Previews and tests are the exception: they build private containers on purpose.",
        whyItExists: "The alternative is a global context singleton that cannot be replaced in tests.",
        whenToUse: "One user store per process, injected from the app entry. Extra containers only for isolation.",
        sample: Samples.make("m7-share", "One modifier for the tree", #"""
        import SwiftData
        import SwiftUI

        WindowGroup {
            RootView()
        }
        .modelContainer(container)
        """#, [
            ("RootView()", "Tabs are descendants, so they inherit the container."),
            (".modelContainer(container)", "One shared store. Not one store per tab.")
        ]),
        expectedBehavior: "A lab record created in Learn shows up in the SwiftUI lab and the CRUD list. Both are the same store.",
        experiment: "Insert a lab record in CRUD. Open the SwiftUI lesson playground and find it.",
        experimentHint: "Both query LabRecord on the app container.",
        experimentSolution: "The row is there. The tabs did not open separate files.",
        challenge: "How does a test avoid this shared container?",
        challengeHint: "makeInMemory.",
        challengeSolution: "The test builds a private in-memory container and passes that context to the repository. It never calls makeShared.",
        bugTitle: "A second shared container",
        bugCode: "let other = try AppModelContainer.makeShared()\n// used from a background screen while the app container is open",
        bugQuestion: "What conflict is this?",
        bugDiagnosis: "Two containers open the same URL. Use the existing container, or a truly different URL.",
        mistakes: ["A singleton ModelContext.", "Per-view containers.", "Passing the view context into an actor."],
        debuggingTips: ["Print the store URL once at launch.", "If a tab cannot see a save, check that the save used this container.", "Actors receive modelContainer, then use their modelContext."],
        quiz: [
            Quiz.make("m7g1", "Tabs share data because:", ["They each call makeShared", "They inherit one .modelContainer", "They use UserDefaults", "They import the same file"], correct: 1, "The environment is inherited."),
            Quiz.make("m7g2", "A ModelActor should receive:", ["The view's ModelContext", "The ModelContainer, and make its own context", "The SwiftUI view", "The store URL string only"], correct: 1, "The context is not Sendable across domains."),
            Quiz.make("m7g3", "Tests should:", ["Call makeShared", "Use a private in-memory container", "Reuse the preview's saved rows", "Open the sandbox file"], correct: 1, "Isolation is the point.")
        ],
        playground: .swiftUI
    )

    static let previews = Lesson.make(
        id: "m7-previews", moduleID: id, title: "Previews with in-memory storage",
        summary: "A preview container is a separate store that cannot touch the simulator file.",
        concept: "AppModelContainer.preview calls makeInMemory and traps only if that fails, which is a programmer error. Attach it with .modelContainer in a #Preview. Seed models inside the preview if you need rows. Do not point a preview at storeURL(). Preview crashes that mention a schema are often the preview opening a stale file you did not mean to use. The canvas and the simulator do not share an in-memory container. Each process has its own. The main app still uses makeShared.",
        whyItExists: "Previews render views that need a container. They must not be a back door into the user's data.",
        whenToUse: "Any #Preview of a SwiftData view. Skip the preview rather than using the live store.",
        sample: Samples.make("m7-prev", "Preview container", #"""
        import SwiftData
        import SwiftUI

        #Preview {
            DashboardView()
                .modelContainer(AppModelContainer.preview)
                .environment(AppCoordinator())
        }
        """#, [
            ("AppModelContainer.preview", "In-memory. Built once for the preview process."),
            (".modelContainer", "The dashboard's @Query of progress has a container."),
            (".environment(AppCoordinator())", "The dashboard also expects the coordinator. The container does not provide it.")
        ]),
        expectedBehavior: "A preview can show the dashboard without writing LearningLab.store. The simulator app still uses the file.",
        experiment: "Read makeInMemory and preview in AppModelContainer and confirm preview does not call makeShared.",
        experimentHint: "preview's closure calls makeInMemory.",
        experimentSolution: "The preview store is memory-only. The app store is the file.",
        challenge: "What else must a preview of LessonDetailView install besides the container?",
        challengeHint: "The view uses AppCoordinator from the environment.",
        challengeSolution: ".environment(AppCoordinator()), or the view will not find the coordinator when it navigates.",
        bugTitle: "Preview on the real URL",
        bugCode: ".modelContainer(try! AppModelContainer.makeShared())",
        bugQuestion: "What can the canvas change?",
        bugDiagnosis: "The same file the simulator uses. Seed data and migrations in the canvas now hit your lesson progress.",
        mistakes: ["try! in the preview with no idea which store opened.", "Seeding makeShared from a preview.", "Forgetting the coordinator environment."],
        debuggingTips: ["Assert isStoredInMemoryOnly in a test of makeInMemory.", "If the canvas shows old rows, it is not using the memory helper.", "Keep preview setup in one modifier stack."],
        quiz: [
            Quiz.make("m7h1", "preview uses:", ["makeShared", "makeInMemory", "The migration plan on the app file", "CloudKit"], correct: 1, "Memory isolation."),
            Quiz.make("m7h2", "The canvas and the simulator:", ["Share one in-memory container", "Are separate processes", "Share LearningLab.store if the preview is correct", "Cannot show SwiftData"], correct: 1, "Each has its own container."),
            Quiz.make("m7h3", "A lesson preview also needs:", ["A second schema", "The coordinator in the environment", "Core Data", "An iCloud account"], correct: 1, "Navigation reads AppCoordinator.")
        ],
        playground: .swiftUI
    )
}
