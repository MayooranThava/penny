import Foundation
import SwiftData

/// Helpers for monthly planned-spending totals derived from category budgets.
enum BudgetPlanning {
    /// Categories that are not part of the discretionary spending envelope.
    static let excludedCategoryNames: Set<String> = ["Savings", "Income"]

    /// Source of truth for "Spending this month" / Budget hero planned amount.
    static func plannedSpending(from categories: [BudgetCategory]) -> Decimal {
        categories
            .filter { !excludedCategoryNames.contains($0.name) }
            .reduce(Decimal(0)) { $0 + $1.budgetedAmount }
    }

    /// Keep the monthly `Budget` envelope aligned with category budgets.
    @MainActor
    static func syncMonthEnvelope(
        in context: ModelContext,
        categories: [BudgetCategory],
        month: Date = .now
    ) {
        let planned = plannedSpending(from: categories)
        let monthStart = DateHelpers.startOfMonth(for: month)
        let descriptor = FetchDescriptor<Budget>()
        guard let budgets = try? context.fetch(descriptor) else { return }

        if let existing = budgets.first(where: { DateHelpers.isSameMonth($0.monthStart, monthStart) }) {
            existing.plannedSpending = planned
        } else {
            context.insert(Budget(monthStart: monthStart, plannedSpending: planned))
        }
        try? context.save()
    }
}
