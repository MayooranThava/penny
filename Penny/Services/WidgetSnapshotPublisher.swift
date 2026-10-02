import Foundation
import WidgetKit

/// Builds and saves the App Group snapshot used by Penny widgets.
/// Call after money/bill changes and when the app becomes active — not only from Home.
@MainActor
enum WidgetSnapshotPublisher {
    struct UpcomingItem {
        var name: String
        var date: Date
        var amount: Decimal
        var kind: String
    }

    static func publish(
        transactions: [Transaction],
        categories: [BudgetCategory],
        bills: [RecurringBill],
        debts: [Debt],
        goals: [SavingsGoal],
        allocations: [GoalFundingAllocation] = [],
        settings: UserSettings?,
        month: Date = DateHelpers.startOfMonth()
    ) {
        let currency = settings?.currencyCode ?? "CAD"
        let monthTransactions = transactions.filter { DateHelpers.isSameMonth($0.date, month) }

        let billMonthly = bills.reduce(Decimal(0)) {
            $0 + FinanceCalculator.monthlyEquivalent(amount: $1.amount, recurrence: $1.recurrence)
        }
        let debtMonthly = debts.reduce(Decimal(0)) { $0 + $1.plannedMonthlyPayment }
        let reserved = Set(bills.map { $0.name.lowercased() } + debts.map { $0.name.lowercased() })
        let discretionary = monthTransactions
            .filter { $0.transactionType == .expense && !reserved.contains($0.title.lowercased()) }
            .reduce(Decimal(0)) { $0 + $1.amount }
        let fundingLinks = allocations.map {
            FinanceCalculator.GoalFundingLink(accountID: $0.accountID, goalID: $0.goalID, amount: $0.amount)
        }
        let plannedSavings = FinanceCalculator.effectiveMonthlySavings(
            goals: goals.map { goal in
                let funded = FinanceCalculator.fundedAmount(forGoal: goal.id, links: fundingLinks)
                let current = FinanceCalculator.effectiveGoalCurrent(
                    manualCurrent: goal.currentAmount,
                    fundedFromAccounts: funded
                )
                return .init(current: current, target: goal.targetAmount, targetDate: goal.targetDate)
            },
            fallbackPlannedSavings: settings?.plannedMonthlySavings ?? 0
        )
        let breakdown = FinanceCalculator.safeToSpendBreakdown(
            monthlyIncome: settings?.monthlyIncome ?? 0,
            recurringCommitted: billMonthly + debtMonthly,
            discretionarySpent: discretionary,
            plannedSavings: plannedSavings
        )

        let monthExpenses = monthTransactions
            .filter { $0.transactionType == .expense }
            .reduce(Decimal(0)) { $0 + $1.amount }
        let plannedSpending = BudgetPlanning.plannedSpending(from: categories)

        let upcoming = upcomingItems(bills: bills, debts: debts)
        let next = upcoming.first
        let upcomingLines: [WidgetSnapshotStore.UpcomingLine] = upcoming.prefix(5).map { item in
            .init(
                title: item.name,
                detail: "\(MoneyFormatters.compact(from: item.amount, currencyCode: currency)) · \(DateHelpers.shortMonthDay(for: item.date))",
                kind: item.kind
            )
        }

        let health: String = {
            switch FinanceCalculator.budgetHealth(budgeted: plannedSpending, spent: monthExpenses) {
            case .overBudget: return "over"
            case .nearLimit: return "near"
            case .healthy, .unset: return "healthy"
            }
        }()

        let topGoal = goals.first
        let topCurrent = topGoal.map { goal -> Decimal in
            let funded = FinanceCalculator.fundedAmount(forGoal: goal.id, links: fundingLinks)
            return FinanceCalculator.effectiveGoalCurrent(
                manualCurrent: goal.currentAmount,
                fundedFromAccounts: funded
            )
        }
        let topProgress = topGoal.flatMap { goal in
            topCurrent.map {
                FinanceCalculator.goalProgressClamped(current: $0, target: goal.targetAmount)
            }
        }
        let topDetail = topGoal.flatMap { goal in
            topCurrent.map {
                "\(MoneyFormatters.compact(from: $0, currencyCode: currency)) of \(MoneyFormatters.compact(from: goal.targetAmount, currencyCode: currency))"
            }
        }

        let snapshot = WidgetSnapshotStore.Snapshot(
            safeToSpend: NSDecimalNumber(decimal: breakdown.safeToSpend).doubleValue,
            currencyCode: currency,
            monthLabel: DateHelpers.monthName(for: month),
            nextReminderTitle: next.map { "\($0.name) due" },
            nextReminderDetail: next.map {
                "\(MoneyFormatters.compact(from: $0.amount, currencyCode: currency)) · \(DateHelpers.shortMonthDay(for: $0.date))"
            },
            displayName: settings?.displayName ?? "",
            updatedAt: .now,
            upcomingItems: Array(upcomingLines),
            spentThisMonth: NSDecimalNumber(decimal: monthExpenses).doubleValue,
            plannedSpending: NSDecimalNumber(decimal: plannedSpending).doubleValue,
            budgetHealth: health,
            topGoalName: topGoal?.name,
            topGoalProgress: topProgress,
            topGoalDetail: topDetail
        )
        WidgetSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func upcomingItems(bills: [RecurringBill], debts: [Debt]) -> [UpcomingItem] {
        let billItems = bills.map {
            UpcomingItem(
                name: $0.name,
                date: $0.nextDueDate,
                amount: $0.amount,
                kind: "bill"
            )
        }
        let debtItems = debts.map {
            UpcomingItem(
                name: $0.name,
                date: DateHelpers.nextDueDate(dueDay: $0.dueDay),
                amount: $0.plannedMonthlyPayment,
                kind: "debt"
            )
        }
        return (billItems + debtItems).sorted { $0.date < $1.date }
    }
}
