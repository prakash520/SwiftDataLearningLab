import XCTest
@testable import SwiftDataLearningLab

final class MigrationTests: XCTestCase {
    func testCustomMigrationTrimsTitlesAndCountsWords() throws {
        let result = try MigrationLab.runIsolatedDemo()
        XCTAssertEqual(result.migrated.count, 2)
        let fetching = try XCTUnwrap(result.migrated.first { $0.title == "Fetching" })
        XCTAssertEqual(fetching.wordCount, 2)
        XCTAssertEqual(fetching.body, "Use predicates")
        let swiftData = try XCTUnwrap(result.migrated.first { $0.title == "SwiftData" })
        XCTAssertEqual(swiftData.wordCount, 3)
        XCTAssertFalse(result.migrated.contains { $0.title.hasPrefix(" ") })
    }
}

@MainActor
final class NotesViewModelTests: IsolatedTestCase {
    func testCreateAndDelete() throws {
        let model = NotesListViewModel(repository: NotesRepository(context: context))
        model.create(title: "A", body: "B")
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.notes.count, 1)
        model.delete(model.notes[0])
        XCTAssertTrue(model.notes.isEmpty)
    }

    func testEditorDraftDoesNotWriteUntilSave() throws {
        let repository = NotesRepository(context: context)
        try repository.create(title: "Original", body: "Body")
        let note = try XCTUnwrap(repository.fetchNotes(matching: "").first)
        let editor = NoteEditorViewModel(repository: repository, note: note)
        editor.title = "Changed"
        let stored = try repository.fetchNotes(matching: "")
        XCTAssertEqual(stored.first?.title, "Original")
        editor.save()
        let after = try repository.fetchNotes(matching: "")
        XCTAssertEqual(after.first?.title, "Changed")
    }
}

final class CurriculumAndProgressTests: XCTestCase {
    func testCatalogCoversTheCurriculum() {
        XCTAssertEqual(LessonCatalog.modules.count, 12)
        XCTAssertGreaterThanOrEqual(LessonCatalog.allLessons.count, 90)
        let ids = LessonCatalog.allLessons.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)

        for lesson in LessonCatalog.allLessons {
            XCTAssertEqual(lesson.quiz.count, 3, lesson.id)
            XCTAssertFalse(lesson.concept.isEmpty, lesson.id)
            XCTAssertFalse(lesson.whyItExists.isEmpty, lesson.id)
            XCTAssertFalse(lesson.whenToUse.isEmpty, lesson.id)
            XCTAssertFalse(lesson.sample.source.isEmpty, lesson.id)
            XCTAssertFalse(lesson.expectedBehavior.isEmpty, lesson.id)
            XCTAssertFalse(lesson.experiment.prompt.isEmpty, lesson.id)
            XCTAssertFalse(lesson.challenge.prompt.isEmpty, lesson.id)
            XCTAssertFalse(lesson.bug.diagnosis.isEmpty, lesson.id)
            XCTAssertFalse(lesson.mistakes.isEmpty, lesson.id)
            XCTAssertFalse(lesson.debuggingTips.isEmpty, lesson.id)
            XCTAssertFalse(lesson.concept.localizedCaseInsensitiveContains("lorem ipsum"), lesson.id)
            for question in lesson.quiz {
                XCTAssertEqual(question.choices.count, 4, question.id)
                XCTAssertTrue(question.choices.indices.contains(question.correctIndex), question.id)
            }
            for annotation in lesson.sample.annotations {
                XCTAssertTrue(
                    lesson.sample.source.contains(annotation.anchor),
                    "\(lesson.id) missing anchor \(annotation.anchor)"
                )
            }
        }

        let used = Set(LessonCatalog.allLessons.map(\.playground))
        for kind in PlaygroundKind.allCases {
            XCTAssertTrue(used.contains(kind), kind.rawValue)
        }
    }

    func testPreviousAndNextWalkTheCatalog() {
        let lessons = LessonCatalog.allLessons
        XCTAssertNil(LessonCatalog.previous(before: lessons[0]))
        XCTAssertEqual(LessonCatalog.next(after: lessons[0])?.id, lessons[1].id)
        XCTAssertNil(LessonCatalog.next(after: lessons[lessons.count - 1]))
    }

    func testProgressMath() {
        XCTAssertEqual(ProgressMath.percentage(completed: 1, total: 4), 0.25)
        XCTAssertEqual(ProgressMath.percentage(completed: 0, total: 0), 0)
        let lessons = LessonCatalog.allLessons
        let done: Set<String> = [lessons[0].id]
        XCTAssertEqual(ProgressMath.recommendedLesson(in: lessons, completedIDs: done)?.id, lessons[1].id)

        let record = LessonProgressRecord(lessonID: lessons[2].id, moduleID: lessons[2].moduleID)
        let recent = ProgressMath.recentLessons(records: [record], lessons: lessons, limit: 1)
        XCTAssertEqual(recent.map(\.id), [lessons[2].id])
    }

    @MainActor
    func testDashboardSearchFindsALesson() {
        let query = DashboardQuery(searchText: "ModelActor")
        let matches = query.matchingLessons(in: LessonCatalog.modules)
        XCTAssertTrue(matches.contains { $0.id == "m9-model-actor" })
    }
}
