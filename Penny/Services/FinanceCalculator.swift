import Foundation

/// Pure financial calculations. Keep out of view bodies. Uses Decimal throughout.
enum FinanceCalculator {

    // MARK: - Safe to Spend

    /// Milestone-one definition:
    /// available monthly income − recurring committed − discretionary spent − planned savings
    static func safeToSpend(
        monthlyIncome: Decimal,
        recurringCommitted: Decimal,
        discretionarySpent: Decimal,
        plannedSavings: Decimal
    ) -> Decimal {
        monthlyIncome - recurringCommitted - discretionarySpent - plannedSavings
    }

    struct SafeToSpendBreakdown: Equatable {
        let income: Decimal
        let committed: Decimal
        let discretionarySpent: Decimal
        let plannedSavings: Decimal
        let safeToSpend: Decimal

        var isOverBudget: Bool { safeToSpend < 0 }
    }

    static func safeToSpendBreakdown(
        monthlyIncome: Decimal,
        recurringCommitted: Decimal,
        discretionarySpent: Decimal,
        plannedSavings: Decimal
    ) -> SafeToSpendBreakdown {
        let value = safeToSpend(
            monthlyIncome: monthlyIncome,
            recurringCommitted: recurringCommitted,
            discretionarySpent: discretionarySpent,
            plannedSavings: plannedSavings
        )
        return SafeToSpendBreakdown(
            income: monthlyIncome,
            committed: recurringCommitted,
            discretionarySpent: discretionarySpent,
            plannedSavings: plannedSavings,
            safeToSpend: value
        )
    }

    /// Convert a bill amount into an approximate monthly commitment.
    static func monthlyEquivalent(amount: Decimal, recurrence: BillRecurrence) -> Decimal {
        switch recurrence {
        case .weekly:
            return (amount * Decimal(52) / Decimal(12)).rounded(scale: 2)
        case .biweekly:
            return (amount * Decimal(26) / Decimal(12)).rounded(scale: 2)
        case .monthly:
            return amount
        case .yearly:
            return (amount / Decimal(12)).rounded(scale: 2)
        }
    }

    /// Bills (monthlyized) + planned debt payments.
    static func totalMonthlyCommitted(
        billAmountsAndRecurrence: [(Decimal, BillRecurrence)],
        debtPayments: [Decimal]
    ) -> Decimal {
        let bills = billAmountsAndRecurrence.reduce(Decimal(0)) { partial, item in
            partial + monthlyEquivalent(amount: item.0, recurrence: item.1)
        }
        let debts = debtPayments.reduce(Decimal(0), +)
        return bills + debts
    }

    // MARK: - Budget

    static func budgetRemaining(budgeted: Decimal, spent: Decimal) -> Decimal {
        budgeted - spent
    }

    static func budgetProgress(budgeted: Decimal, spent: Decimal) -> Double {
        guard budgeted > 0 else {
            return spent > 0 ? 1.0 : 0.0
        }
        let ratio = (spent / budgeted).doubleValue
        return max(0, ratio)
    }

    /// Clamped 0...1 for visual progress bars (over-budget still reads as full).
    static func budgetProgressClamped(budgeted: Decimal, spent: Decimal) -> Double {
        min(1.0, budgetProgress(budgeted: budgeted, spent: spent))
    }

    enum BudgetHealth: String, Equatable {
        case healthy
        case nearLimit
        case overBudget
        case unset

        var accessibilityLabel: String {
            switch self {
            case .healthy: return "Within budget"
            case .nearLimit: return "Near budget limit"
            case .overBudget: return "Over budget"
            case .unset: return "No budget set"
            }
        }
    }

    static func budgetHealth(budgeted: Decimal, spent: Decimal, nearLimitThreshold: Double = 0.85) -> BudgetHealth {
        guard budgeted > 0 else { return spent > 0 ? .overBudget : .unset }
        let progress = budgetProgress(budgeted: budgeted, spent: spent)
        if progress > 1.0 { return .overBudget }
        if progress >= nearLimitThreshold { return .nearLimit }
        return .healthy
    }

    static func totalBudgeted(_ amounts: [Decimal]) -> Decimal {
        amounts.reduce(0, +)
    }

    static func totalSpent(_ amounts: [Decimal]) -> Decimal {
        amounts.reduce(0, +)
    }

    // MARK: - Goals

    static func goalProgress(current: Decimal, target: Decimal) -> Double {
        guard target > 0 else { return current > 0 ? 1.0 : 0.0 }
        return max(0, (current / target).doubleValue)
    }

    static func goalProgressClamped(current: Decimal, target: Decimal) -> Double {
        min(1.0, goalProgress(current: current, target: target))
    }

    static func goalRemaining(current: Decimal, target: Decimal) -> Decimal {
        max(0, target - current)
    }

    /// Required monthly savings to hit target by date. Returns nil if date is not in the future.
    static func requiredMonthlySavings(
        current: Decimal,
        target: Decimal,
        targetDate: Date,
        from date: Date = .now,
        calendar: Calendar = .current
    ) -> Decimal? {
        let remaining = goalRemaining(current: current, target: target)
        guard remaining > 0 else { return 0 }

        let start = calendar.startOfDay(for: date)
        let end = calendar.startOfDay(for: targetDate)
        guard end > start else { return nil }

        let comps = calendar.dateComponents([.month, .day], from: start, to: end)
        var months = comps.month ?? 0
        if (comps.day ?? 0) > 0 { months += 1 }
        months = max(months, 1)

        let monthly = remaining / Decimal(months)
        return monthly.rounded(scale: 2, mode: .up)
    }

    struct GoalSavingsInput: Equatable {
        let current: Decimal
        let target: Decimal
        let targetDate: Date?
    }

    /// Monthly savings deducted from Safe to Spend.
    /// Sums required amounts for incomplete goals that have a target date.
    /// Falls back to Settings → Planned monthly savings when no dated goals apply.
    /// When both exist, uses the larger amount so the Settings slider can still raise the floor.
    static func effectiveMonthlySavings(
        goals: [GoalSavingsInput],
        fallbackPlannedSavings: Decimal,
        from date: Date = .now,
        calendar: Calendar = .current
    ) -> Decimal {
        var fromGoals = Decimal(0)
        var hasDatedRequirement = false
        for goal in goals {
            guard let targetDate = goal.targetDate else { continue }
            guard let required = requiredMonthlySavings(
                current: goal.current,
                target: goal.target,
                targetDate: targetDate,
                from: date,
                calendar: calendar
            ) else { continue }
            if required > 0 {
                fromGoals += required
                hasDatedRequirement = true
            }
        }
        if hasDatedRequirement {
            return max(fromGoals, fallbackPlannedSavings)
        }
        return fallbackPlannedSavings
    }

    static func estimatedCompletionDate(
        current: Decimal,
        target: Decimal,
        monthlyContribution: Decimal,
        from date: Date = .now,
        calendar: Calendar = .current
    ) -> Date? {
        let remaining = goalRemaining(current: current, target: target)
        guard remaining > 0 else { return date }
        guard monthlyContribution > 0 else { return nil }

        let monthsExact = (remaining / monthlyContribution).doubleValue
        let months = Int(ceil(monthsExact))
        return calendar.date(byAdding: .month, value: months, to: date)
    }

    // MARK: - Goal funding from accounts

    struct GoalFundingLink: Equatable {
        let accountID: UUID
        let goalID: UUID
        let amount: Decimal
    }

    /// Sum of positive allocation amounts.
    static func totalAllocated(amounts: [Decimal]) -> Decimal {
        amounts.reduce(Decimal(0)) { $0 + max(0, $1) }
    }

    /// Balance left after earmarking allocations toward goals.
    static func unallocatedBalance(accountBalance: Decimal, allocatedAmounts: [Decimal]) -> Decimal {
        max(0, accountBalance - totalAllocated(amounts: allocatedAmounts))
    }

    /// Clamp a requested earmark so it never exceeds remaining room on the account.
    static func clampedAllocation(
        requested: Decimal,
        accountBalance: Decimal,
        otherAllocatedOnAccount: Decimal
    ) -> Decimal {
        let room = max(0, accountBalance - max(0, otherAllocatedOnAccount))
        return min(max(0, requested), room).rounded(scale: 2)
    }

    /// Total earmarked toward one goal across all accounts.
    static func fundedAmount(
        forGoal goalID: UUID,
        links: [GoalFundingLink]
    ) -> Decimal {
        totalAllocated(amounts: links.filter { $0.goalID == goalID }.map(\.amount))
    }

    /// Effective goal progress current: manual entry wins unless accounts fund more.
    static func effectiveGoalCurrent(
        manualCurrent: Decimal,
        fundedFromAccounts: Decimal
    ) -> Decimal {
        max(max(0, manualCurrent), max(0, fundedFromAccounts))
    }

    /// Soft validation: true when every account’s allocations fit within its balance.
    static func allocationsFitBalances(
        accountBalances: [UUID: Decimal],
        links: [GoalFundingLink]
    ) -> Bool {
        var byAccount: [UUID: Decimal] = [:]
        for link in links {
            byAccount[link.accountID, default: 0] += max(0, link.amount)
        }
        for (accountID, allocated) in byAccount {
            let balance = accountBalances[accountID] ?? 0
            if allocated > balance { return false }
        }
        return true
    }

    // MARK: - Debt payoff (amortization)

    enum DebtPayoffResult: Equatable {
        case paidOff(date: Date, months: Int, totalInterest: Decimal)
        case alreadyPaid
        case paymentTooLow(minimumNeeded: Decimal)
        case invalid

        var isPossible: Bool {
            if case .paidOff = self { return true }
            if case .alreadyPaid = self { return true }
            return false
        }
    }

    /// Monthly interest rate from APR percentage (e.g. 19.99 → 0.1999/12).
    static func monthlyInterestRate(aprPercent: Decimal) -> Decimal {
        (aprPercent / 100) / 12
    }

    /// Mathematically correct amortization payoff with monthly compounding.
    static func debtPayoff(
        balance: Decimal,
        aprPercent: Decimal,
        monthlyPayment: Decimal,
        from date: Date = .now,
        calendar: Calendar = .current,
        maxMonths: Int = 600
    ) -> DebtPayoffResult {
        guard balance >= 0, monthlyPayment >= 0, aprPercent >= 0 else { return .invalid }
        if balance == 0 { return .alreadyPaid }

        let r = monthlyInterestRate(aprPercent: aprPercent)

        // First month interest — payment must exceed it to ever pay off.
        let firstInterest = (balance * r).rounded(scale: 2)
        if r > 0 && monthlyPayment <= firstInterest {
            let minimum = (firstInterest + Decimal(0.01)).rounded(scale: 2)
            return .paymentTooLow(minimumNeeded: minimum)
        }

        if r == 0 {
            guard monthlyPayment > 0 else {
                return .paymentTooLow(minimumNeeded: balance)
            }
            let months = Int(ceil((balance / monthlyPayment).doubleValue))
            let payoffDate = calendar.date(byAdding: .month, value: months, to: date) ?? date
            return .paidOff(date: payoffDate, months: months, totalInterest: 0)
        }

        var remaining = balance
        var totalInterest: Decimal = 0
        var months = 0

        while remaining > 0 && months < maxMonths {
            months += 1
            let interest = (remaining * r).rounded(scale: 2)
            totalInterest += interest
            let principal = monthlyPayment - interest
            if principal <= 0 {
                return .paymentTooLow(minimumNeeded: (interest + Decimal(0.01)).rounded(scale: 2))
            }
            remaining = (remaining - principal).rounded(scale: 2)
            if remaining < 0 { remaining = 0 }
        }

        if remaining > 0 {
            return .paymentTooLow(minimumNeeded: monthlyPayment)
        }

        let payoffDate = calendar.date(byAdding: .month, value: months, to: date) ?? date
        return .paidOff(date: payoffDate, months: months, totalInterest: totalInterest.rounded(scale: 2))
    }

    // MARK: - Projections

    struct BalanceProjection: Equatable, Identifiable {
        let monthsAhead: Int
        let projectedBalance: Decimal
        var id: Int { monthsAhead }
    }

    /// Deterministic balance projection.
    /// monthlyNet = income − recurringBills − averageDiscretionary − plannedSavings − debtPayments
    static func projectBalance(
        currentBalance: Decimal,
        monthlyIncome: Decimal,
        recurringBills: Decimal,
        averageDiscretionary: Decimal,
        plannedSavings: Decimal,
        debtPayments: Decimal = 0,
        horizons: [Int] = [0, 1, 3, 6, 12]
    ) -> [BalanceProjection] {
        let monthlyNet = monthlyIncome - recurringBills - averageDiscretionary - plannedSavings - debtPayments
        return horizons.sorted().map { months in
            let projected = (currentBalance + monthlyNet * Decimal(months)).rounded(scale: 2)
            return BalanceProjection(monthsAhead: months, projectedBalance: projected)
        }
    }

    static func monthlyNetCashFlow(
        monthlyIncome: Decimal,
        recurringBills: Decimal,
        averageDiscretionary: Decimal,
        plannedSavings: Decimal,
        debtPayments: Decimal = 0
    ) -> Decimal {
        monthlyIncome - recurringBills - averageDiscretionary - plannedSavings - debtPayments
    }

    // MARK: - Spending helpers

    static func sumExpenses(amounts: [Decimal]) -> Decimal {
        amounts.reduce(0, +)
    }

    static func percentChange(current: Decimal, previous: Decimal) -> Double? {
        guard previous != 0 else {
            if current == 0 { return 0 }
            return nil
        }
        return ((current - previous) / abs(previous)).doubleValue
    }

    static func average(_ values: [Decimal]) -> Decimal {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Decimal(values.count)
    }
}
