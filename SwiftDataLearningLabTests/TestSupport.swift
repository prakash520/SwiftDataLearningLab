import SwiftData
import XCTest
@testable import SwiftDataLearningLab

@MainActor
enum TestStack {
    static func makeContext() throws -> (ModelContainer, ModelContext) {
        let container = try AppModelContainer.makeInMemory()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return (container, context)
    }
}

@MainActor
class IsolatedTestCase: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        let stack = try TestStack.makeContext()
        container = stack.0
        context = stack.1
    }

    override func tearDown() async throws {
        context = nil
        container = nil
        try await super.tearDown()
    }
}
