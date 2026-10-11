import Foundation

enum Module10Architecture {
    static let id = "architecture"
    static let module = LearningModule(
        id: id,
        title: "MVVM-C and application architecture",
        summary: "The notes project is the full MVVM-C example. The other projects stay on @Query on purpose.",
        level: .advanced,
        order: 10,
        lessons: [mvvm, coordinators, repository, injection, context, separation, tests, overengineering]
    )

    static let mvvm = Lesson.make(
        id: "m10-mvvm", moduleID: id, title: "SwiftData with MVVM",
        summary: "The view model owns screen state. The model owns stored facts.",
        concept: "In the notes feature, Note is the SwiftData model. NotesListViewModel holds the fetched array, the search string, and the error. NoteEditorViewModel holds a draft title and body. The view renders and forwards events. The view model does not import SwiftUI. That split is what makes the list testable. It is not a rule that every screen needs a view model. The task manager uses @Query in the view because the screen is the feature. Both are allowed. Pretending every property wrapper is a view model is how the acronym gets noisy.",
        whyItExists: "You want to test behavior without rendering, and you want a draft that is not the row.",
        whenToUse: "When there is a draft, a workflow, or a test you care about. Notes qualify. A one-toggle screen often does not.",
        sample: Samples.make("m10-mvvm", "Draft then save", #"""
        import SwiftData

        @MainActor
        final class NoteEditorViewModel {
            private let note: Note
            var title: String
            func save(using repository: NotesRepository) throws {
                try repository.update(note, title: title, body: body, isPinned: isPinned)
            }
            var body: String
            var isPinned: Bool
        }
        """#, [
            ("var title: String", "Draft state. Typing does not assign note.title."),
            ("repository.update", "The model changes only in save.")
        ]),
        expectedBehavior: "Dismissing the notes editor without Save leaves the stored title unchanged.",
        experiment: "Edit a note title, tap Cancel by dismissing without Save, and reopen.",
        experimentHint: "The editor's only commit button is Save.",
        experimentSolution: "The stored title is the old one. The draft died with the view model.",
        challenge: "Which project in this app is intentionally not MVVM?",
        challengeHint: "Tasks use @Query.",
        challengeSolution: "The task manager, expenses, bookmarks, and library views talk to the context directly. Notes is the MVVM-C reference.",
        bugTitle: "View model holding a second source of truth forever",
        bugCode: "viewModel.notes = []\n// @Query also showing notes",
        bugQuestion: "What diverges?",
        bugDiagnosis: "Two owners. Notes uses only the view model. Do not also add @Query.",
        mistakes: ["A view model that is a View.", "Duplicating every model property without a reason.", "Logic in the button and in the view model."],
        debuggingTips: ["If a test cannot construct the type without SwiftUI, it is not the view model you wanted.", "Trace Save from the button to the repository.", "Keep drafts obvious."],
        quiz: [
            Quiz.make("m10a1", "The notes draft lives:", ["On the Note immediately", "On the editor view model until save", "In @Query", "In the schema"], correct: 1, "Save copies it across."),
            Quiz.make("m10a2", "The task screen uses:", ["A view model for every field", "@Query in the view", "A second store", "CloudKit"], correct: 1, "That is the lighter choice, on purpose."),
            Quiz.make("m10a3", "A view model should avoid:", ["Calling a repository", "Importing SwiftUI so it can be tested plainly", "Holding a search string", "Exposing an error string"], correct: 1, "SwiftUI stays in the view.")
        ],
        playground: .architecture
    )

    static let coordinators = Lesson.make(
        id: "m10-coordinators", moduleID: id, title: "Coordinators and navigation",
        summary: "AppCoordinator switches tabs. NotesCoordinator pushes editors.",
        concept: "A coordinator owns a navigation path and the decisions about where to go. AppCoordinator owns the learn path, the project path, and the selected tab. The Projects tab has one NavigationStack. NotesCoordinator does not create another one. A nested stack crashes in NavigationColumnState.boundPathChange as soon as the notes screen appears. Instead, NotesCoordinator appends a NoteRoute, which stores a PersistentIdentifier, onto that same path. The view does not invent a second path. Passing the identifier, not Note, keeps the route small. The lesson catalog uses the same idea with String ids. Coordinators are @MainActor and @Observable so SwiftUI can observe the path.",
        whyItExists: "Navigation scattered through buttons is hard to test and hard to deep-link.",
        whenToUse: "When more than one screen needs to send the user somewhere, or when a feature has its own stack. A single list does not need a named coordinator type.",
        sample: Samples.make("m10-coord", "Open a project from anywhere", #"""
        import SwiftUI

        @MainActor
        func openProject(_ kind: ProjectKind, coordinator: AppCoordinator) {
            coordinator.selectedTab = .projects
            var path = NavigationPath()
            path.append(kind)
            coordinator.projectPath = path
        }
        """#, [
            ("selectedTab = .projects", "The coordinator changes tabs. The button does not poke TabView's private state."),
            ("path.append(kind)", "The stack is replaced with the destination, not pushed onto a stale path.")
        ]),
        expectedBehavior: "Open Notes project from the architecture playground switches to the Projects tab and shows Notes.",
        experiment: "Tap Open Notes project from a lesson playground.",
        experimentHint: "The button is on the architecture playground and on module 12 cards.",
        experimentSolution: "The tab and the path both change. That is the coordinator's job.",
        challenge: "Why does NotesCoordinator store PersistentIdentifier instead of Note?",
        challengeHint: "Routes should be small and stable.",
        challengeSolution: "The identifier survives the path. The destination resolves the note in the current context and handles deletion.",
        bugTitle: "Navigation in the model",
        bugCode: "func save() {\n    note.title = title\n    coordinator.path.append(note.persistentModelID)\n}",
        bugQuestion: "Why should the model or a low-level save not own the path?",
        bugDiagnosis: "Persistence does not know about tabs. The view model or the coordinator can navigate after a successful save. The model cannot see the coordinator.",
        mistakes: ["Two paths for one stack.", "Passing the whole Note through navigation.", "A coordinator that also fetches and saves."],
        debuggingTips: ["If the tab does not change, the button updated local state instead of the coordinator.", "Print the path.", "Keep feature coordinators off the app coordinator until a feature needs a stack."],
        quiz: [
            Quiz.make("m10b1", "AppCoordinator owns:", ["The SQLite file", "Tab and navigation paths", "The schema", "Predicates"], correct: 1, "The container owns the file."),
            Quiz.make("m10b2", "Notes routes store:", ["Note instances", "Persistent identifiers", "View models", "Predicates"], correct: 1, "Resolve on arrival."),
            Quiz.make("m10b3", "A coordinator should:", ["Save every model", "Decide where to navigate", "Replace the repository", "Be a SwiftUI View"], correct: 1, "Navigation is its job.")
        ],
        playground: .architecture
    )

    static let repository = Lesson.make(
        id: "m10-repository", moduleID: id, title: "Repository patterns",
        summary: "A repository is useful when a query is reused or tested. It is noise for a one-off view.",
        concept: "NotesRepository is the only type that fetches and saves notes. The view model calls it. Tests call it. The view does not. That is a useful repository: one query, one place for the sort, one error path. A repository that only forwards insert to the context, one method per screen that is never reused, is ceremony. The task view does not have one. If a second screen needs the same task query, extract it then. Do not start with a protocol and two implementations unless a test double is honestly simpler than an in-memory container. This lab's tests use the in-memory container against the real repository, which is the stronger test.",
        whyItExists: "The word repository is doing too much work in iOS sample code. The useful version is a focused query type.",
        whenToUse: "Shared, testable persistence for one aggregate. Notes. Not a wrapper around every model in the app.",
        sample: Samples.make("m10-repo", "One fetch for notes", #"""
        import SwiftData

        func fetchNotes(matching search: String, context: ModelContext) throws -> [Note] {
            var descriptor = FetchDescriptor<Note>(
                sortBy: [SortDescriptor(\Note.updatedAt, order: .reverse)]
            )
            if !search.isEmpty {
                let search = search
                descriptor.predicate = #Predicate<Note> { note in
                    note.title.localizedStandardContains(search) || note.body.localizedStandardContains(search)
                }
            }
            return try context.fetch(descriptor)
        }
        """#, [
            ("FetchDescriptor<Note>", "The repository owns the sort and the predicate."),
            ("context.fetch", "Still SwiftData. The repository is not a new database.")
        ]),
        expectedBehavior: "Searching notes uses this predicate. A test can call the repository and see the same rows.",
        experiment: "Create two notes and search. Then read the repository test once you run the suite.",
        experimentHint: "The test target calls the same type.",
        experimentSolution: "The UI and the test share NotesRepository, so they cannot drift into two predicates.",
        challenge: "Why is there no TaskRepository?",
        challengeHint: "One view, @Query.",
        challengeSolution: "Nothing else fetches tasks, and the view is the feature. Adding a repository would only rename context.fetch.",
        bugTitle: "A protocol with one implementation and no test",
        bugCode: "protocol NotesRepositoryProtocol { func fetch() throws -> [Note] }",
        bugQuestion: "What did the protocol buy?",
        bugDiagnosis: "Nothing yet. The in-memory container already substitutes the store. Add a protocol when a double is simpler than the real type, not before.",
        mistakes: ["A repository per button.", "The repository constructing makeShared.", "Business formatting inside the fetch."],
        debuggingTips: ["If two screens disagree, they are not sharing the repository.", "Keep the type @MainActor if it holds the view context.", "Prefer a real in-memory store over a hand-written fake."],
        quiz: [
            Quiz.make("m10c1", "NotesRepository is justified because:", ["Every app needs one", "The query is shared with tests", "SwiftData requires the name", "It replaces the context"], correct: 1, "Reuse and tests."),
            Quiz.make("m10c2", "The task screen skips a repository because:", ["Tasks cannot be fetched", "The view is the only caller", "Repositories cannot use relationships", "@Query is illegal"], correct: 1, "Extract it when a second caller appears."),
            Quiz.make("m10c3", "The preferred test double is:", ["A protocol that returns hard-coded arrays", "An in-memory ModelContainer and the real repository", "The app file", "A mock context you wrote by hand"], correct: 1, "You test the real predicate.")
        ],
        playground: .architecture
    )

    static let injection = Lesson.make(
        id: "m10-dependency-injection", moduleID: id, title: "Dependency injection",
        summary: "Pass the repository and the coordinator in. Do not look them up from a global.",
        concept: "NotesFlowView builds a NotesRepository with the environment context and passes it to the view model. The editor builds its own repository with the same context when the destination appears. Tests build a repository with an in-memory context and pass that to the view model. Nothing calls a singleton. The coordinator is created as @State on the flow and passed down. Injection here is an initializer parameter, not a framework. If a type reaches for AppModelContainer.makeShared on its own, a test cannot replace the store.",
        whyItExists: "Globals hide the dependency and pin you to the real file.",
        whenToUse: "Any type you intend to construct from a test.",
        sample: Samples.make("m10-di", "Initializer injection", #"""
        import SwiftData

        let repository = NotesRepository(context: context)
        let model = NotesListViewModel(repository: repository)
        model.load()
        """#, [
            ("NotesRepository(context: context)", "The caller chooses the context."),
            ("NotesListViewModel(repository: repository)", "The view model does not build a container.")
        ]),
        expectedBehavior: "The notes UI and the unit test use the same initializers with different contexts.",
        experiment: "Create a note in the app, then run the view-model test and confirm it does not see that note.",
        experimentHint: "The test uses makeInMemory.",
        experimentSolution: "The test's repository was injected with a private container. The app note is in a different store.",
        challenge: "What is the smell of a view model that calls AppModelContainer.makeShared inside load()?",
        challengeHint: "The test cannot aim it elsewhere.",
        challengeSolution: "The store is a hidden global. Pass the context or the repository in.",
        bugTitle: "Service locator",
        bugCode: "enum NotesAPI { static var context: ModelContext! }",
        bugQuestion: "Why is a static context worse than an initializer?",
        bugDiagnosis: "Tests and the app overwrite the same variable. Order becomes the bug. Pass the context in.",
        mistakes: ["A default initializer that opens the real store.", "Injecting the view into the repository.", "A DI container framework for four types."],
        debuggingTips: ["Look at the test's setUp. The injection is visible there.", "If the test sees app data, it used makeShared.", "Keep the graph: view builds view model builds repository."],
        quiz: [
            Quiz.make("m10d1", "The notes view model receives:", ["A global context", "A repository", "A WindowGroup", "A schema"], correct: 1, "The repository already has the context."),
            Quiz.make("m10d2", "Tests substitute:", ["The view", "The context, via a new repository", "The coordinator's tab", "CloudKit"], correct: 1, "Same type, different store."),
            Quiz.make("m10d3", "A static context is:", ["Easier to test", "Shared mutable state", "Required by SwiftData", "The coordinator"], correct: 1, "Avoid it.")
        ],
        playground: .architecture
    )

    static let context = Lesson.make(
        id: "m10-injecting-context", moduleID: id, title: "Injecting a context or a container",
        summary: "Inject a context for main-actor work. Inject a container when the receiver must build its own context.",
        concept: "NotesRepository stores a ModelContext because it runs on the main actor beside the view. LessonBackgroundImporter is initialized with a ModelContainer because it must build a context on its executor. Injecting a context into the actor would reintroduce the sharing bug. Injecting a container into the notes repository would let it open a second context and disagree with @Query if you mixed styles. Match the injection to the isolation. Views get the context from the environment. They pass it down once.",
        whyItExists: "Container and context are both dependencies, and they are not interchangeable.",
        whenToUse: "Main actor type: context. ModelActor: container. Tests: whichever the type's initializer demands, backed by memory.",
        sample: Samples.make("m10-inj", "Two different injections", #"""
        import SwiftData

        let repository = NotesRepository(context: modelContext)
        let importer = LessonBackgroundImporter(modelContainer: modelContext.container)
        """#, [
            ("NotesRepository(context:", "Main-actor work shares the view context."),
            ("modelContainer: modelContext.container", "The actor does not receive the context.")
        ]),
        expectedBehavior: "Notes saves appear in the notes list. Actor imports appear to a fresh fetch. The injections are different on purpose.",
        experiment: "Create a note and import a lab row. Each used the injection that matches its isolation.",
        experimentHint: "Notes stay on the main actor. The importer is the concurrency playground.",
        experimentSolution: "The note used the view context. The import used a container-built actor context.",
        challenge: "What bug appears if the repository stores a container and calls ModelContext(container) on every fetch?",
        challengeHint: "A new context per call.",
        challengeSolution: "You lose the view context's pending changes and can disagree with the screen. Hold the context you were given.",
        bugTitle: "Actor initialized with a context",
        bugCode: "LessonBackgroundImporter(modelContext: modelContext)",
        bugQuestion: "Why does the initializer not look like that?",
        bugDiagnosis: "The macro takes a container so the actor can build a confined context. A context parameter would be the bug.",
        mistakes: ["One style of injection for every type.", "The view fetching a container from a singleton.", "The repository creating contexts internally."],
        debuggingTips: ["Read the initializer. It documents the isolation.", "If pending edits vanish, you fetched on a new context.", "If the compiler complains about Sendable, you passed a context across a hop."],
        quiz: [
            Quiz.make("m10e1", "A main-actor repository should store:", ["A ModelContainer it reopens", "The ModelContext it was given", "Nothing, and call makeShared", "A View"], correct: 1, "Stay on that context."),
            Quiz.make("m10e2", "A ModelActor should be given:", ["The view context", "A ModelContainer", "A Binding", "A Note"], correct: 1, "It builds the context."),
            Quiz.make("m10e3", "They are not interchangeable because:", ["The names differ only", "A context is confined and a container can mint contexts", "Containers cannot be stored", "Contexts are Sendable"], correct: 1, "Confinement is the difference.")
        ],
        playground: .architecture
    )

    static let separation = Lesson.make(
        id: "m10-separation", moduleID: id, title: "Separating persistence and presentation",
        summary: "Formatting stays in the view. Fetching stays in the repository. Navigation stays in the coordinator.",
        concept: "The repository returns Note models or throws. It does not return Text or colors. The view decides how to show a pin icon and a line limit. The view model decides when to load, create, and delete. The coordinator decides to push. Mixing these feels faster and makes every change touch the file that talks to SQLite. The expense total is a presentation concern computed from rows the query already returned. It does not belong in the model as a stored column.",
        whyItExists: "Persistence bugs and layout bugs should not share a function.",
        whenToUse: "As soon as a type starts importing both SwiftUI and SwiftData and also formatting strings.",
        sample: Samples.make("m10-sep", "The view formats, the model stores", #"""
        import SwiftUI

        if note.isPinned {
            Image(systemName: "pin.fill")
                .accessibilityLabel("Pinned")
        }
        Text(note.title)
        """#, [
            ("Image(systemName: \"pin.fill\")", "Presentation. The model only stores isPinned."),
            ("Text(note.title)", "The view reads a stored property. It does not fetch.")
        ]),
        expectedBehavior: "Pinning a note shows the icon. The repository places pinned notes first in memory after the store sorts updatedAt, because a Bool SortDescriptor does not compile for @Model types. The icon is not a column.",
        experiment: "Pin a note, leave, and come back. The icon returns because isPinned was saved, and the view maps it to an image.",
        experimentHint: "The toggle is on the editor. Save.",
        experimentSolution: "The Bool survived. The image is recreated by the view.",
        challenge: "Why is the currency format in the expense view rather than on the model?",
        challengeHint: "Locale.",
        challengeSolution: "Format is presentation and depends on locale. The model stores a Double. The view uses FormatStyle.",
        bugTitle: "SwiftUI in the repository",
        bugCode: "func fetch() -> Text { Text(note.title) }",
        bugQuestion: "What became untestable without a renderer?",
        bugDiagnosis: "The repository now depends on SwiftUI. Return the note. Let the view build Text.",
        mistakes: ["Storing formatted strings.", "Fetching inside body.", "Navigation inside the model."],
        debuggingTips: ["Check imports. A repository file should not need SwiftUI.", "A view file may import SwiftData for @Query or @Bindable.", "Keep totals next to the list that shows them."],
        quiz: [
            Quiz.make("m10f1", "The pin image belongs in:", ["The schema", "The view", "The migration", "The predicate"], correct: 1, "isPinned is the stored fact."),
            Quiz.make("m10f2", "Currency formatting belongs:", ["In the view", "In the SQLite file as text", "In the actor", "In the inverse"], correct: 0, "Locale-specific presentation."),
            Quiz.make("m10f3", "The repository returns:", ["Views", "Models or errors", "Navigation paths", "Colors"], correct: 1, "Persistence results.")
        ],
        playground: .notes
    )

    static let tests = Lesson.make(
        id: "m10-testing-view-models", moduleID: id, title: "Unit testing view models",
        summary: "An in-memory container, the real repository, and assertions on the view model.",
        concept: "NotesViewModelTests builds makeInMemory, a repository, and a NotesListViewModel. It creates a note, asserts the count, deletes it, and asserts empty. It does not launch the app and does not read LearningLab.store. The view model is @MainActor, so the test type is @MainActor. Errors are asserted by feeding the unique-constraint path where that exists, and by checking errorMessage on failures you can force. Do not snapshot SwiftUI to test a predicate. That is a different, slower test.",
        whyItExists: "The view model is the layer you extracted so this test could exist.",
        whenToUse: "For every workflow you would otherwise click through: create, search, delete, and the draft save.",
        sample: Samples.make("m10-test", "The shape of the notes test", #"""
        import XCTest

        @MainActor
        func testCreateAndDelete() throws {
            let context = try TestStack.makeContext()
            let model = NotesListViewModel(repository: NotesRepository(context: context))
            model.create(title: "A", body: "B")
            XCTAssertEqual(model.notes.count, 1)
            model.delete(model.notes[0])
            XCTAssertTrue(model.notes.isEmpty)
        }
        """#, [
            ("TestStack.makeContext()", "In-memory and autosave off. Not the app file."),
            ("model.create", "The real view model and the real repository."),
            ("XCTAssertEqual(model.notes.count, 1)", "Assert the state the view would show.")
        ]),
        expectedBehavior: "Command-U runs this against an isolated store. The simulator's notes are untouched.",
        experiment: "Add a note in the app, run the tests, and confirm the app note is still there.",
        experimentHint: "The testing guide has the xcodebuild command.",
        experimentSolution: "The test store was memory. The app store was not opened by the test.",
        challenge: "What would a test of the editor draft assert before save?",
        challengeHint: "The Note's title versus the view model's title.",
        challengeSolution: "Change viewModel.title, do not call save, fetch the note, and assert the stored title is unchanged.",
        bugTitle: "Testing makeShared",
        bugCode: "let context = ModelContext(try AppModelContainer.makeShared())",
        bugQuestion: "Why can this fail on a second machine or delete your notes?",
        bugDiagnosis: "It opens the real file. Use makeInMemory.",
        mistakes: ["Asserting only that no error was thrown.", "Sharing a container across tests.", "Launching the UI to check a count."],
        debuggingTips: ["If a test sees leftover rows, it reused a container.", "Mark the class @MainActor.", "Keep one behavior per test method."],
        quiz: [
            Quiz.make("m10g1", "The notes test uses:", ["The app store", "An in-memory container", "CloudKit", "A screenshot"], correct: 1, "Isolation."),
            Quiz.make("m10g2", "The test constructs:", ["Only a View", "The view model and the real repository", "A fake array with no SwiftData", "The migration plan"], correct: 1, "You want the real predicate."),
            Quiz.make("m10g3", "@MainActor on the test matches:", ["The view model", "The ModelActor", "The schema", "The file coordinator"], correct: 0, "The repository is main-actor isolated.")
        ],
        playground: .architecture
    )

    static let overengineering = Lesson.make(
        id: "m10-overengineering", moduleID: id, title: "Avoiding overengineering",
        summary: "Notes are the full pattern. The other four projects are the argument against copying it everywhere.",
        concept: "A simple SwiftData screen is a view, @Query or a small fetch, and save. The task manager is that screen. Adding a coordinator, a repository protocol, a use case, and a mapper would not make delete-cascade clearer. Add a layer when you feel a pain the layer removes: a draft, a test, a second caller, or navigation that more than one view triggers. The architecture playground sends you to Notes because that pain is real there. It does not send you to wrap DesignedItem in a use case. If you cannot name the test the layer enables, do not add the layer.",
        whyItExists: "Sample architecture often outgrows the feature it was meant to teach.",
        whenToUse: "At the start of a feature, pick the notes shape or the task shape and say why.",
        sample: Samples.make("m10-simple", "A direct task insert", #"""
        import SwiftData

        let task = StudyTask(title: title, priority: priority, category: category)
        modelContext.insert(task)
        try modelContext.save()
        """#, [
            ("StudyTask(title:", "The view builds the model. There is no use-case type."),
            ("try modelContext.save()", "The view context is the whole persistence stack for this screen.")
        ]),
        expectedBehavior: "Adding a task in the task project persists it without a view model type.",
        experiment: "Add a task, relaunch, and find it. Then open Notes and compare how many types are involved.",
        experimentHint: "Tasks are one view. Notes are a coordinator, two view models, and a repository.",
        experimentSolution: "Both persist. Notes has the extra types because of the draft, the search, and the tests.",
        challenge: "Name the pain that would justify a TaskRepository later.",
        challengeHint: "A second caller or a test you cannot write against the view.",
        challengeSolution: "A second screen that must run the same category lookup, or a test of a multi-step rule that you do not want to drive through SwiftUI.",
        bugTitle: "Layers by default",
        bugCode: "protocol TaskUseCase { func add() }\nfinal class TaskUseCaseImpl: TaskUseCase { }",
        bugQuestion: "What test does this enable that the view's insert does not?",
        bugDiagnosis: "None, until the use case contains a rule. The protocol is empty structure. Wait for the rule.",
        mistakes: ["Copying the notes stack onto a toggle.", "Refusing a repository when a second screen duplicates a buggy predicate.", "A global architecture for a lab."],
        debuggingTips: ["Count the types you must open to understand a save.", "If the answer is one view, stop.", "If the answer is a draft plus a test, the notes stack is earned."],
        quiz: [
            Quiz.make("m10h1", "The task screen is simpler because:", ["Tasks are not stored", "The view is the whole feature", "Relationships are illegal in view models", "Save is automatic only there"], correct: 1, "No draft and no second caller."),
            Quiz.make("m10h2", "Add a repository when:", ["You always do", "A query gains a second caller or a test", "You add a button", "You add a color"], correct: 1, "Pain first."),
            Quiz.make("m10h3", "The notes stack is justified by:", ["The acronym", "A draft, shared query, and tests", "CloudKit", "Inheritance"], correct: 1, "Those are the concrete pains.")
        ],
        playground: .tasks
    )
}
