import SwiftData
import XCTest
@testable import SwiftDataLearningLab

@MainActor
final class QueryTests: IsolatedTestCase {
    func testPredicateSortAndPagination() throws {
        try QueryLab.insertSamples(in: context)
        let page = try QueryLab.fetchBooks(
            matching: "",
            minimumYear: 2020,
            limit: 2,
            offset: 0,
            sortForward: true,
            in: context
        )
        XCTAssertEqual(page.count, 2)
        XCTAssertLessThanOrEqual(page[0].title, page[1].title)

        let filtered = try QueryLab.fetchBooks(
            matching: "Pred",
            minimumYear: 2024,
            limit: 10,
            offset: 0,
            sortForward: true,
            in: context
        )
        XCTAssertEqual(filtered.map(\.title), ["Predicates"])

        let secondPage = try QueryLab.fetchBooks(
            matching: "",
            minimumYear: 2020,
            limit: 2,
            offset: 2,
            sortForward: true,
            in: context
        )
        XCTAssertEqual(secondPage.count, 2)
        XCTAssertNotEqual(page.map(\.title), secondPage.map(\.title))
    }

    func testExpenseShapes() throws {
        try ExpenseQuery.insertSampleExpenses(in: context)
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 5, day: 31, hour: 23, minute: 59))!
        let mayFood = try ExpenseQuery.fetch(
            .categoryAndDate(name: "Food", start: start, end: end),
            sortByAmount: true,
            in: context
        )
        XCTAssertEqual(mayFood.map(\.title), ["Lunch"])

        let expensive = try ExpenseQuery.fetch(.minimumAmount(40), sortByAmount: true, in: context)
        XCTAssertEqual(Set(expensive.map(\.title)), ["Train", "Dinner"])
        XCTAssertGreaterThanOrEqual(expensive[0].amount, expensive[1].amount)

        let total = mayFood.reduce(0) { $0 + $1.amount }
        XCTAssertEqual(total, 18)
    }

    func testPinnedNotesStayFirstWithoutABoolSortDescriptor() throws {
        let repository = NotesRepository(context: context)
        try repository.create(title: "Older pin", body: "A")
        try repository.create(title: "Newer plain", body: "B")
        let pinned = try XCTUnwrap(repository.fetchNotes(matching: "").first { $0.title == "Older pin" })
        try repository.update(pinned, title: pinned.title, body: pinned.body, isPinned: true)
        let titles = try repository.fetchNotes(matching: "").map(\.title)
        XCTAssertEqual(titles, ["Older pin", "Newer plain"])
    }

    func testNotesSearchMatchesBody() throws {
        let repository = NotesRepository(context: context)
        try repository.create(title: "Shopping", body: "Buy milk")
        try repository.create(title: "Empty", body: "Nothing relevant")
        let found = try repository.fetchNotes(matching: "milk")
        XCTAssertEqual(found.map(\.title), ["Shopping"])
    }
}
