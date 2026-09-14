import SwiftUI
import SwiftData
import WidgetKit

struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query(filter: #Predicate<RecurringBill> { $0.isActive }, sort: \RecurringBill.nextDueDate)
    private var bills: [RecurringBill]
    @Query(sort: \Debt.name) private var debts: [Debt]
    @Query(sort: \SavingsGoal.createdAt) private var goals: [SavingsGoal]
    @Query private var settingsList: [UserSettings]

    @Environment(AppSession.self) private var session
    @State private var editingBill: RecurringBill?
    @State private var editingDebt: Debt?
    @State private var editingGoal: SavingsGoal?

    private var settings: UserSettings? { settingsList.first }
    private var currency: String { settings?.currencyCode ?? "CAD" }

    private var monthTransactions: [Transaction] {
        transactions.filter { DateHelpers.isSameMonth($0.date, session.selectedMonth) }
    }

    private var priorMonthTransactions: [Transaction] {
        let prior = DateHelpers.addingMonths(-1, to: session.selectedMonth)
        return transactions.filter { DateHelpers.isSameMonth($0.date, prior) }
    }

    private var monthlyIncome: Decimal { settings?.monthlyIncome ?? 0 }

    private var billMonthlyCommitted: Decimal {
        bills.reduce(Decimal(0)) {
            $0 + FinanceCalculator.monthlyEquivalent(amount: $1.amount, recurrence: $1.recurrence)
        }
    }

    private var debtMonthlyCommitted: Decimal {
        debts.reduce(Decimal(0)) { $0 + $1.plannedMonthlyPayment }
    }

    private var recurringCommitted: Decimal { billMonthlyCommitted + debtMonthlyCommitted }

    private var discretionarySpent: Decimal {
        let reserved = Set(bills.map { $0.name.lowercased() } + debts.map { $0.name.lowercased() })
        return monthTransactions
            .filter { $0.transactionType == .expense && !reserved.contains($0.title.lowercased()) }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var plannedSavings: Decimal { settings?.plannedMonthlySavings ?? 0 }

    private var breakdown: FinanceCalculator.SafeToSpendBreakdown {
        FinanceCalculator.safeToSpendBreakdown(
            monthlyIncome: monthlyIncome,
            recurringCommitted: recurringCommitted,
            discretionarySpent: discretionarySpent,
            plannedSavings: plannedSavings
        )
    }

    private var monthExpenses: Decimal {
        monthTransactions
            .filter { $0.transactionType == .expense }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    /// Always derived from category budgets — the monthly `Budget` row can lag
    /// after a user edits a single category (which caused "$10 of $1" on Home).
    private var plannedSpending: Decimal {
        BudgetPlanning.plannedSpending(from: categories)
    }

    private struct UpcomingItem: Identifiable {
        enum Kind { case bill, debt }
        let id: String
        let kind: Kind
        let name: String
        let date: Date
        let amount: Decimal
        let icon: String
        let subtitle: String
    }

    private var upcomingItems: [UpcomingItem] {
        let billItems = bills.map {
            UpcomingItem(
                id: "bill-\($0.id.uuidString)",
                kind: .bill,
                name: $0.name,
                date: $0.nextDueDate,
                amount: $0.amount,
                icon: $0.icon,
                subtitle: $0.recurrence.displayName
            )
        }
        let debtItems = debts.map {
            UpcomingItem(
                id: "debt-\($0.id.uuidString)",
                kind: .debt,
                name: $0.name,
                date: DateHelpers.nextDueDate(dueDay: $0.dueDay),
                amount: $0.plannedMonthlyPayment,
                icon: $0.icon,
                subtitle: "Debt payment"
            )
        }
        return (billItems + debtItems).sorted { $0.date < $1.date }.prefix(5).map { $0 }
    }

    private var insights: [PennyInsight] {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: .now)
        let daysInMonth = calendar.range(of: .day, in: .month, for: session.selectedMonth)?.count ?? 30

        let categorySpends: [InsightEngine.CategorySpend] = categories.map { category in
            let current = monthTransactions
                .filter { $0.transactionType == .expense && $0.categoryName == category.name }
                .reduce(Decimal(0)) { $0 + $1.amount }
            let previous = priorMonthTransactions
                .filter { $0.transactionType == .expense && $0.categoryName == category.name }
                .reduce(Decimal(0)) { $0 + $1.amount }
            return .init(name: category.name, current: current, previous: previous, budgeted: category.budgetedAmount)
        }

        let upcomingBills = upcomingItems.prefix(4).map { item -> (name: String, daysUntil: Int, amount: Decimal) in
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: .now),
                to: calendar.startOfDay(for: item.date)
            ).day ?? 0
            return (item.name, max(0, days), item.amount)
        }

        let goalSnapshots: [InsightEngine.GoalSnapshot] = goals.map { goal in
            .init(
                name: goal.name,
                current: goal.currentAmount,
                target: goal.targetAmount,
                targetDate: goal.targetDate,
                monthlyContributionEstimate: plannedSavings / Decimal(max(goals.count, 1))
            )
        }

        return InsightEngine.generate(
            from: .init(
                categorySpends: categorySpends,
                upcomingBillsWithinDays: upcomingBills,
                goals: goalSnapshots,
                monthlyBudget: plannedSpending,
                spentSoFar: monthExpenses,
                dayOfMonth: day,
                daysInMonth: daysInMonth,
                currencyCode: currency,
                now: .now
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
                    upcomingSection
                    goalsSection
                    insightsSection
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
            .onAppear { publishWidgetSnapshot() }
            .onChange(of: breakdown.safeToSpend) { _, _ in publishWidgetSnapshot() }
            .onChange(of: upcomingItems.first?.id) { _, _ in publishWidgetSnapshot() }
            .sheet(isPresented: Binding(
                get: { editingBill != nil },
                set: { if !$0 { editingBill = nil } }
            )) {
                if let editingBill {
                    AddBillView(bill: editingBill)
                }
            }
            .sheet(isPresented: Binding(
                get: { editingDebt != nil },
                set: { if !$0 { editingDebt = nil } }
            )) {
                if let editingDebt {
                    AddDebtView(debt: editingDebt)
                }
            }
            .sheet(isPresented: Binding(
                get: { editingGoal != nil },
                set: { if !$0 { editingGoal = nil } }
            )) {
                if let editingGoal {
                    AddGoalView(goal: editingGoal)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(DateHelpers.welcomeMessage(displayName: settings?.displayName))
                    .font(PennyTypography.largeTitle)
                    .foregroundStyle(PennyColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(DateHelpers.monthYear(for: session.selectedMonth))
                    .font(PennyTypography.callout)
                    .foregroundStyle(PennyColors.textSecondary)
            }
            Spacer()
            Circle()
                .fill(PennyColors.brandMuted)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(PennyColors.brand)
                }
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
                breakdownRow("Bills", -billMonthlyCommitted, positive: false)
                if debtMonthlyCommitted > 0 {
                    breakdownRow("Debt payments", -debtMonthlyCommitted, positive: false)
                }
                breakdownRow("Spent", -breakdown.discretionarySpent, positive: false)
                breakdownRow("Saved", -breakdown.plannedSavings, positive: false)
                breakdownRow(
                    "Safe to Spend",
                    breakdown.safeToSpend,
                    positive: breakdown.safeToSpend >= 0,
                    emphasized: true
                )
            }

            if !debts.isEmpty {
                Divider().overlay(Color.white.opacity(0.2))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Includes debt targets")
                        .font(PennyTypography.caption)
                        .foregroundStyle(PennyColors.textOnBrand.opacity(0.75))
                    ForEach(debts, id: \.id) { debt in
                        HStack {
                            Text(debt.name)
                                .font(PennyTypography.caption)
                                .foregroundStyle(PennyColors.textOnBrand.opacity(0.9))
                            Spacer()
                            Text(
                                MoneyFormatters.compact(
                                    from: debt.plannedMonthlyPayment,
                                    currencyCode: currency
                                ) + "/mo"
                            )
                            .font(PennyTypography.caption)
                            .monospacedDigit()
                            .foregroundStyle(PennyColors.textOnBrand)
                        }
                    }
                }
            }
        }
        .padding(PennySpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: PennySpacing.radiusXl, style: .continuous)
                .fill(PennyColors.heroGradient)
                .shadow(color: PennyColors.brand.opacity(0.25), radius: 16, y: 8)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Safe to spend \(MoneyFormatters.string(from: breakdown.safeToSpend, currencyCode: currency))"
        )
    }

    private func breakdownRow(
        _ label: String,
        _ amount: Decimal,
        positive: Bool,
        emphasized: Bool = false
    ) -> some View {
        HStack {
            Text(label)
                .font(emphasized ? PennyTypography.bodyEmphasized : PennyTypography.callout)
                .foregroundStyle(PennyColors.textOnBrand.opacity(emphasized ? 1 : 0.85))
            Spacer()
            Text(
                MoneyFormatters.signed(
                    from: amount,
                    currencyCode: currency,
                    showPlus: positive && amount > 0
                )
            )
            .font(emphasized ? PennyTypography.smallAmount : PennyTypography.callout)
            .monospacedDigit()
            .foregroundStyle(PennyColors.textOnBrand)
        }
    }

    private var spendingSection: some View {
        VStack(alignment: .leading, spacing: PennySpacing.sm) {
            SectionHeader(title: "Spending this month")
            PennyCard {
                if plannedSpending <= 0 {
                    EmptyStateView(
                        symbol: "chart.pie",
                        title: "No spending budget yet",
                        message: "Set category budgets in Budget to track how this month is going."
                    )
                } else {
                    ProgressCard(
                        title: DateHelpers.monthName(for: session.selectedMonth),
                        spent: monthExpenses,
                        budget: plannedSpending,
                        currencyCode: currency,
                        health: FinanceCalculator.budgetHealth(
                            budgeted: plannedSpending,
                            spent: monthExpenses
                        )
                    )
                }
            }
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: PennySpacing.sm) {
            SectionHeader(title: "Upcoming")
            if upcomingItems.isEmpty {
                PennyCard {
                    EmptyStateView(
                        symbol: "calendar",
                        title: "Nothing due soon",
                        message: "Add bills or debt payments in Plan to see what's coming up."
                    )
                }
            } else {
                PennyCard {
                    VStack(spacing: PennySpacing.md) {
                        ForEach(upcomingItems) { item in
                            Button {
                                switch item.kind {
                                case .bill:
                                    editingBill = bills.first { "bill-\($0.id.uuidString)" == item.id }
                                case .debt:
                                    editingDebt = debts.first { "debt-\($0.id.uuidString)" == item.id }
                                }
                            } label: {
                                HStack(spacing: PennySpacing.sm) {
                                    CategoryIcon(
                                        icon: item.icon,
                                        colourIdentifier: item.kind == .debt ? "debt" : "subscriptions"
                                    )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(PennyTypography.bodyEmphasized)
                                            .foregroundStyle(PennyColors.textPrimary)
                                        Text("\(item.subtitle) · \(DateHelpers.shortMonthDay(for: item.date))")
                                            .font(PennyTypography.caption)
                                            .foregroundStyle(PennyColors.textSecondary)
                                    }
                                    Spacer()
                                    MoneyText(
                                        amount: item.amount,
                                        currencyCode: currency,
                                        font: PennyTypography.smallAmount
                                    )
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(PennyColors.textTertiary)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
                            .accessibilityHint("Double tap to edit")
                            if item.id != upcomingItems.last?.id {
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
                            Button {
                                editingGoal = goal
                            } label: {
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
                            }
                            .buttonStyle(.plain)
                            .frame(width: 220)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var insightsSection: some View {
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
        if let target = goal.targetDate { return target }
        let monthly = plannedSavings / Decimal(max(goals.count, 1))
        return FinanceCalculator.estimatedCompletionDate(
            current: goal.currentAmount,
            target: goal.targetAmount,
            monthlyContribution: monthly
        )
    }

    private func publishWidgetSnapshot() {
        let next = upcomingItems.first
        let snapshot = WidgetSnapshotStore.Snapshot(
            safeToSpend: NSDecimalNumber(decimal: breakdown.safeToSpend).doubleValue,
            currencyCode: currency,
            monthLabel: DateHelpers.monthName(for: session.selectedMonth),
            nextReminderTitle: next.map { "\($0.name) due" },
            nextReminderDetail: next.map {
                "\(MoneyFormatters.compact(from: $0.amount, currencyCode: currency)) · \(DateHelpers.shortMonthDay(for: $0.date))"
            },
            displayName: settings?.displayName ?? "",
            updatedAt: .now
        )
        WidgetSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
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
