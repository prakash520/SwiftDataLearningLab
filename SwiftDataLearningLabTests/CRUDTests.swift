import SwiftData
import XCTest
@testable import SwiftDataLearningLab

@MainActor
final class CRUDTests: IsolatedTestCase {
    func testInsertFetchUpdateDelete() throws {
        let record = try CRUDLab.insert(title: "Milk", notes: "Oat", in: context)
        var fetched = try context.fetch(FetchDescriptor<LabRecord>())
        XCTAssertEqual(fetched.map(\.title), ["Milk"])

        try CRUDLab.update(record, title: "Oat milk", notes: "Two cartons", in: context)
        fetched = try context.fetch(FetchDescriptor<LabRecord>())
        XCTAssertEqual(fetched.map(\.title), ["Oat milk"])
        XCTAssertEqual(fetched.first?.notes, "Two cartons")

        try CRUDLab.delete(record, in: context)
        fetched = try context.fetch(FetchDescriptor<LabRecord>())
        XCTAssertTrue(fetched.isEmpty)
    }

    func testDiscardDoesNotPublish() throws {
        let report = try CRUDLab.demonstrateDiscard(mainContext: context)
        XCTAssertEqual(report.visibleBeforeRollback, 1)
        XCTAssertEqual(report.visibleAfterRollback, 0)
        XCTAssertEqual(report.visibleFromMainContext, 0)
    }

    func testSecondaryContextSaveIsVisibleToANewReader() throws {
        let count = try CRUDLab.saveFromSecondaryContext(title: "From writer", notes: "saved", mainContext: context)
        XCTAssertEqual(count, 1)
    }

    func testUniqueSKUReplacesTheStoredRow() throws {
        let stack = try AppModelContainer.makeTemporaryDisk()
        defer { try? FileManager.default.removeItem(at: stack.directory) }
        let diskContext = ModelContext(stack.container)
        diskContext.autosaveEnabled = false

        let report = try DesignLab.saveDuplicateSKU(in: diskContext)
        XCTAssertEqual(report.count, 1)
        XCTAssertEqual(report.savedName, "Duplicate")
    }

    func testAppRejectsASKUBeforeTheStoreCanReplaceIt() throws {
        let stack = try AppModelContainer.makeTemporaryDisk()
        defer { try? FileManager.default.removeItem(at: stack.directory) }
        let diskContext = ModelContext(stack.container)
        diskContext.autosaveEnabled = false

        try DesignLab.insertIfSKUAvailable(sku: "SKU-KEEP", name: "First", in: diskContext)
        XCTAssertThrowsError(try DesignLab.insertIfSKUAvailable(sku: "SKU-KEEP", name: "Second", in: diskContext))
        let names = try diskContext.fetch(FetchDescriptor<DesignedItem>()).map(\.name)
        XCTAssertEqual(names, ["First"])
    }

    func testMemoryStoreDoesNotTouchTheCaller() throws {
        let report = try PersistenceLab.proveMemoryStoreIsIsolated(mainContext: context)
        XCTAssertGreaterThanOrEqual(report.memoryCount, 1)
        XCTAssertEqual(report.mainCountBefore, report.mainCountAfter)
    }
}
