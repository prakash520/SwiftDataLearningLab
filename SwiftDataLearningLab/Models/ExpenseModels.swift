import Foundation
import SwiftData

@Model
final class ExpenseCategory {
    @Attribute(.unique) var name: String

    /// Deleting a category keeps the expenses and clears their category.
    @Relationship(deleteRule: .nullify, inverse: \Expense.category)
    var expenses: [Expense] = []

    init(name: String) {
        self.name = name
    }
}

@Model
final class Expense {
    var title: String

    /// `Double` is used because `#Predicate` comparisons are straightforward.
    /// `Decimal` is a legal stored type, but decimal predicates are limited.
    var amount: Double

    var spentOn: Date
    var category: ExpenseCategory?

    init(title: String, amount: Double, spentOn: Date, category: ExpenseCategory? = nil) {
        self.title = title
        self.amount = amount
        self.spentOn = spentOn
        self.category = category
    }
}
