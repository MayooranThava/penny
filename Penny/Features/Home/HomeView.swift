import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query(filter: #Predicate<RecurringBill> { $0.isActive }, sort: \RecurringBill.nextDueDate)
    private var bills: [RecurringBill]
    @Query(sort: \SavingsGoal.createdAt) private var goals: [SavingsGoal]
    @Query private var settingsList: [UserSettings]
    @Query private var budgets: [Budget]

    @Environment(AppSession.self) private var session

    private var settings: UserSettings? { settingsList.first }
    private var currency: String { settings?.currencyCode ?? "CAD" }

    private var monthTransactions: [Transaction] {
        transactions.filter { DateHelpers.isSameMonth($0.date, session.selectedMonth) }
    }

    private var priorMonthTransactions: [Transaction] {
        let prior = DateHelpers.addingMonths(-1, to: session.selectedMonth)
        return transactions.filter { DateHelpers.isSameMonth($0.date, prior) }
    }

    private var monthlyIncome: Decimal {
        settings?.monthlyIncome ?? 0
    }

    private var recurringCommitted: Decimal {
        bills.reduce(0) { $0 + $1.amount }
    }

    private var discretionarySpent: Decimal {
        // Expenses that aren't already counted as recurring bill names this month
        let billNames = Set(bills.map { $0.name.lowercased() })
        return monthTransactions
            .filter { $0.transactionType == .expense && !billNames.contains($0.title.lowercased()) }
            .reduce(0) { $0 + $1.amount }
    }

    /// Include housing rent etc. that appear as both bill and transaction carefully:
    /// Safe-to-spend uses recurring commitments + discretionary spending (non-bill expenses).
    private var plannedSavings: Decimal {
        settings?.plannedMonthlySavings ?? 0
    }

    private var breakdown: FinanceCalculator.SafeToSpendBreakdown {
        FinanceCalculator.safeToSpendBreakdown(
            monthlyIncome: monthlyIncome,
            recurringCommitted: recurringCommitted,
            discretionarySpent: discretionarySpent,
            plannedSavings: plannedSavings
        )
    }

    private var monthExpenses: Decimal {
        monthTransactions.filter { $0.transactionType == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var plannedSpending: Decimal {
        if let budget = budgets.first(where: { DateHelpers.isSameMonth($0.monthStart, session.selectedMonth) }) {
            return budget.plannedSpending
        }
        return categories.filter { $0.name != "Savings" }.reduce(0) { $0 + $1.budgetedAmount }
    }

    private var upcomingBills: [RecurringBill] {
        Array(bills.sorted { $0.nextDueDate < $1.nextDueDate }.prefix(4))
    }

    private var insights: [PennyInsight] {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: Date.now)
        let daysInMonth = calendar.range(of: .day, in: .month, for: session.selectedMonth)?.count ?? 30

        let categorySpends: [InsightEngine.CategorySpend] = categories.map { cat in
            let current = monthTransactions
                .filter { $0.transactionType == .expense && $0.categoryName == cat.name }
                .reduce(Decimal(0)) { $0 + $1.amount }
            let previous = priorMonthTransactions
                .filter { $0.transactionType == .expense && $0.categoryName == cat.name }
                .reduce(Decimal(0)) { $0 + $1.amount }
            return .init(name: cat.name, current: current, previous: previous, budgeted: cat.budgetedAmount)
        }

        let billTuples = upcomingBills.map { bill -> (name: String, daysUntil: Int, amount: Decimal) in
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date.now), to: calendar.startOfDay(for: bill.nextDueDate)).day ?? 0
            return (bill.name, max(0, days), bill.amount)
        }

        let goalSnaps: [InsightEngine.GoalSnapshot] = goals.map { goal in
            let monthly = settings?.plannedMonthlySavings ?? 0
            return .init(
                name: goal.name,
                current: goal.currentAmount,
                target: goal.targetAmount,
                targetDate: goal.targetDate,
                monthlyContributionEstimate: monthly / Decimal(max(goals.count, 1))
            )
        }

        return InsightEngine.generate(
            from: .init(
                categorySpends: categorySpends,
                upcomingBillsWithinDays: billTuples,
                goals: goalSnaps,
                monthlyBudget: plannedSpending,
                spentSoFar: monthExpenses,
                dayOfMonth: day,
                daysInMonth: daysInMonth,
                currencyCode: currency,
                now: Date.now
            ),
            limit: 2
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PennySpacing.sectionGap) {
                    header
                    safeToSpendCard
                    spendingSection
                    billsSection
                    goalsSection
                    insightSection
                }
                .padding(.horizontal, PennySpacing.screenPadding)
                .padding(.bottom, PennySpacing.xxxl)
            }
            .background(PennyColors.softBackgroundGradient.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        session.showAddTransaction = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(PennyColors.brand)
                            .font(.title2)
                    }
                    .accessibilityLabel("Add transaction")
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(DateHelpers.greeting())
                    .font(PennyTypography.largeTitle)
                    .foregroundStyle(PennyColors.textPrimary)
                Text(DateHelpers.monthYear(for: session.selectedMonth))
                    .font(PennyTypography.callout)
                    .foregroundStyle(PennyColors.textSecondary)
            }
            Spacer()
            Circle()
                .fill(PennyColors.brandMuted)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(PennyColors.brand)
                )
                .accessibilityHidden(true)
        }
        .padding(.top, PennySpacing.sm)
    }

    private var safeToSpendCard: some View {
        VStack(alignment: .leading, spacing: PennySpacing.md) {
            Text("Safe to Spend")
                .font(PennyTypography.overline)
                .foregroundStyle(PennyColors.textOnBrand.opacity(0.85))
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(MoneyFormatters.compact(from: breakdown.safeToSpend, currencyCode: currency))
                    .font(PennyTypography.heroAmount)
                    .monospacedDigit()
                    .foregroundStyle(PennyColors.textOnBrand)
                    .contentTransition(reduceMotion ? .identity : .numericText())

                if breakdown.isOverBudget {
                    Text("Over")
                        .font(PennyTypography.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.2)))
                        .foregroundStyle(PennyColors.textOnBrand)
                }
            }

            Text(
                breakdown.isOverBudget
                ? "You're projected over budget for the rest of \(DateHelpers.monthName(for: session.selectedMonth))"
                : "Available for the rest of \(DateHelpers.monthName(for: session.selectedMonth))"
            )
            .font(PennyTypography.callout)
            .foregroundStyle(PennyColors.textOnBrand.opacity(0.9))

            Divider().overlay(Color.white.opacity(0.25))

            VStack(spacing: 8) {
                breakdownRow("Income", breakdown.income, positive: true)
                breakdownRow("Committed", -breakdown.committed, positive: false)
                breakdownRow("Spent", -breakdown.discretionarySpent, positive: false)
                breakdownRow("Saved", -breakdown.plannedSavings, positive: false)
                breakdownRow("Safe to Spend", breakdown.safeToSpend, positive: breakdown.safeToSpend >= 0, emphasized: true)
            }
        }
        .padding(PennySpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: PennySpacing.radiusXl, style: .continuous)
                .fill(PennyColors.heroGradient)
                .shadow(color: PennyColors.brand.opacity(0.25), radius: 16, y: 8)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Safe to spend \(MoneyFormatters.string(from: breakdown.safeToSpend, currencyCode: currency))")
    }

    private func breakdownRow(_ label: String, _ amount: Decimal, positive: Bool, emphasized: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(emphasized ? PennyTypography.bodyEmphasized : PennyTypography.callout)
                .foregroundStyle(PennyColors.textOnBrand.opacity(emphasized ? 1 : 0.85))
            Spacer()
            Text(MoneyFormatters.signed(from: amount, currencyCode: currency, showPlus: positive && amount > 0))
                .font(emphasized ? PennyTypography.smallAmount : PennyTypography.callout)
                .monospacedDigit()
                .foregroundStyle(PennyColors.textOnBrand)
        }
    }

    private var spendingSection: some View {
        VStack(alignment: .leading, spacing: PennySpacing.sm) {
            SectionHeader(title: "Spending this month")
            PennyCard {
                ProgressCard(
                    title: DateHelpers.monthName(for: session.selectedMonth),
                    spent: monthExpenses,
                    budget: max(plannedSpending, 1),
                    currencyCode: currency,
                    health: FinanceCalculator.budgetHealth(budgeted: plannedSpending, spent: monthExpenses)
                )
            }
        }
    }

    private var billsSection: some View {
        VStack(alignment: .leading, spacing: PennySpacing.sm) {
            SectionHeader(title: "Upcoming bills")
            if upcomingBills.isEmpty {
                PennyCard {
                    EmptyStateView(
                        symbol: "calendar",
                        title: "No bills yet",
                        message: "Add recurring bills in Plan to see what's coming up."
                    )
                }
            } else {
                PennyCard {
                    VStack(spacing: PennySpacing.md) {
                        ForEach(upcomingBills, id: \.id) { bill in
                            BillRow(
                                name: bill.name,
                                dueDate: bill.nextDueDate,
                                amount: bill.amount,
                                currencyCode: currency,
                                icon: bill.icon,
                                categoryName: bill.categoryName
                            )
                            if bill.id != upcomingBills.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: PennySpacing.sm) {
            SectionHeader(title: "Savings goals")
            if goals.isEmpty {
                PennyCard {
                    EmptyStateView(
                        symbol: "target",
                        title: "No goals yet",
                        message: "Set a savings goal to track progress toward what matters."
                    )
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PennySpacing.sm) {
                        ForEach(goals, id: \.id) { goal in
                            PennyCard {
                                GoalProgressView(
                                    name: goal.name,
                                    current: goal.currentAmount,
                                    target: goal.targetAmount,
                                    currencyCode: currency,
                                    icon: goal.icon,
                                    colourIdentifier: goal.colourIdentifier,
                                    estimatedCompletion: estimatedCompletion(for: goal),
                                    compact: true
                                )
                            }
                            .frame(width: 220)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var insightSection: some View {
        VStack(alignment: .leading, spacing: PennySpacing.sm) {
            SectionHeader(title: "Insights")
            if let insight = insights.first {
                PennyCard(fill: PennyColors.secondarySurface) {
                    HStack(alignment: .top, spacing: PennySpacing.sm) {
                        Image(systemName: insight.symbolName)
                            .font(.title2)
                            .foregroundStyle(insightColor(insight.kind))
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(insight.title)
                                .font(PennyTypography.bodyEmphasized)
                                .foregroundStyle(PennyColors.textPrimary)
                            Text(insight.detail)
                                .font(PennyTypography.caption)
                                .foregroundStyle(PennyColors.textSecondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            } else {
                PennyCard {
                    Text("Keep logging spending to unlock personalized insights.")
                        .font(PennyTypography.callout)
                        .foregroundStyle(PennyColors.textSecondary)
                }
            }
        }
    }

    private func insightColor(_ kind: PennyInsight.Kind) -> Color {
        switch kind {
        case .positive: return PennyColors.income
        case .caution: return PennyColors.warning
        case .neutral: return PennyColors.savings
        case .tip: return PennyColors.brand
        }
    }

    private func estimatedCompletion(for goal: SavingsGoal) -> Date? {
        let monthly = (settings?.plannedMonthlySavings ?? 0) / Decimal(max(goals.count, 1))
        if let target = goal.targetDate { return target }
        return FinanceCalculator.estimatedCompletionDate(
            current: goal.currentAmount,
            target: goal.targetAmount,
            monthlyContribution: monthly
        )
    }
}

#Preview("Home Light") {
    HomeView()
        .environment(AppSession())
        .modelContainer(PennyPersistence.previewContainer())
}

#Preview("Home Dark") {
    HomeView()
        .environment(AppSession())
        .modelContainer(PennyPersistence.previewContainer())
        .preferredColorScheme(.dark)
}
