import SwiftData
import SwiftUI

struct ExpenseTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseCategory.name) private var categories: [ExpenseCategory]
    @State private var title = ""
    @State private var amount = ""
    @State private var spentOn = Date.now
    @State private var categoryName = "Food"
    @State private var filterCategory = ""
    @State private var useDates = false
    @State private var start = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var end = Date.now
    @State private var sortByAmount = true
    @State private var rows: [Expense] = []
    @State private var status = "Add expenses, then filter. Totals use the filtered rows, not every row in the store."

    private var total: Double { rows.reduce(0) { $0 + $1.amount } }

    var body: some View {
        List {
            Section("New expense") {
                TextField("Title", text: $title)
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
                DatePicker("Spent on", selection: $spentOn, displayedComponents: .date)
                TextField("Category", text: $categoryName)
                Button("Save expense") { save() }
            }
            Section("Filter") {
                TextField("Category, or leave empty", text: $filterCategory)
                Toggle("Date range", isOn: $useDates)
                if useDates {
                    DatePicker("Start", selection: $start, displayedComponents: .date)
                    DatePicker("End", selection: $end, displayedComponents: .date)
                }
                Toggle("Sort by amount", isOn: $sortByAmount)
                Button("Apply") { apply() }
                Button("Load sample expenses") {
                    do {
                        try ExpenseQuery.insertSampleExpenses(in: modelContext)
                        apply()
                    } catch {
                        status = error.localizedDescription
                    }
                }
            }
            Section("Results") {
                Text("Total \(total, format: .currency(code: "USD"))")
                    .font(.headline)
                    .accessibilityLabel("Filtered total \(total, format: .currency(code: "USD"))")
                if rows.isEmpty {
                    Text("No expenses match.")
                        .foregroundStyle(.secondary)
                }
                ForEach(rows) { expense in
                    VStack(alignment: .leading) {
                        Text(expense.title)
                        Text("\(expense.category?.name ?? "Uncategorized") · \(expense.amount, format: .currency(code: "USD")) · \(expense.spentOn.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    for index in offsets { modelContext.delete(rows[index]) }
                    try? modelContext.save()
                    apply()
                }
            }
            Section {
                Text(status).font(.footnote)
                if !categories.isEmpty {
                    Text("Categories: \(categories.map(\.name).joined(separator: ", "))")
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Expenses")
        .onAppear { apply() }
    }

    private func save() {
        guard let value = Double(amount), value >= 0 else {
            status = "Enter a non-negative amount."
            return
        }
        do {
            let name = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            let category = try expenseCategory(named: name.isEmpty ? "General" : name)
            modelContext.insert(Expense(title: title.isEmpty ? "Expense" : title, amount: value, spentOn: spentOn, category: category))
            try modelContext.save()
            title = ""
            amount = ""
            apply()
            status = "Saved into the on-disk store."
        } catch {
            status = error.localizedDescription
        }
    }

    private func expenseCategory(named name: String) throws -> ExpenseCategory {
        let name = name
        var descriptor = FetchDescriptor<ExpenseCategory>(predicate: #Predicate { $0.name == name })
        descriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }
        let created = ExpenseCategory(name: name)
        modelContext.insert(created)
        return created
    }

    private func apply() {
        do {
            let shape: ExpenseQuery.Shape
            let name = filterCategory.trimmingCharacters(in: .whitespacesAndNewlines)
            if useDates && !name.isEmpty {
                shape = .categoryAndDate(name: name, start: start, end: end)
            } else if useDates {
                shape = .dateRange(start: start, end: end)
            } else if !name.isEmpty {
                shape = .category(name)
            } else {
                shape = .all
            }
            rows = try ExpenseQuery.fetch(shape, sortByAmount: sortByAmount, in: modelContext)
            status = "Showing \(rows.count) expense(s)."
        } catch {
            status = error.localizedDescription
        }
    }
}
