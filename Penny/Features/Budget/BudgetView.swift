import SwiftUI
import SwiftData
import Charts

struct BudgetView: View {
    @Environment(AppSession.self) private var session
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var settingsList: [UserSettings]

    @State private var selectedCategoryID: UUID?

    private var currency: String { settingsList.first?.currencyCode ?? "CAD" }
    private var selectedCategory: BudgetCategory? {
        categories.first { $0.id == selectedCategoryID }
    }

    private var monthTransactions: [Transaction] {
        transactions.filter {
            DateHelpers.isSameMonth($0.date, session.selectedMonth) && $0.transactionType == .expense
        }
    }

    private var planned: Decimal {
        BudgetPlanning.plannedSpending(from: categories)
    }

    private var spent: Decimal {
        monthTransactions.reduce(0) { $0 + $1.amount }
    }

    private var remaining: Decimal {
        FinanceCalculator.budgetRemaining(budgeted: planned, spent: spent)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PennySpacing.sectionGap) {
                    header
                    hero
                    categoriesSection
                }
                .padding(.horizontal, PennySpacing.screenPadding)
                .padding(.bottom, PennySpacing.xxxl)
            }
            .background(PennyColors.background.ignoresSafeArea())
            .navigationTitle("Budget")
            .sheet(isPresented: Binding(
                get: { selectedCategoryID != nil },
                set: { if !$0 { selectedCategoryID = nil } }
            )) {
                if let category = selectedCategory {
                    CategoryDetailView(category: category, month: session.selectedMonth, currencyCode: currency)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                session.selectedMonth = DateHelpers.addingMonths(-1, to: session.selectedMonth)
                Haptics.selection()
            } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }
            Spacer()
            Text("\(DateHelpers.monthName(for: session.selectedMonth)) Budget")
                .font(PennyTypography.sectionHeading)
            Spacer()
            Button {
                session.selectedMonth = DateHelpers.addingMonths(1, to: session.selectedMonth)
                Haptics.selection()
            } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }
        }
        .foregroundStyle(PennyColors.brand)
        .padding(.top, PennySpacing.xs)
    }

    private var hero: some View {
        PennyCard {
            HStack(spacing: PennySpacing.lg) {
                RingProgressView(
                    progress: FinanceCalculator.budgetProgressClamped(budgeted: planned, spent: spent),
                    lineWidth: 14,
                    progressColor: ringColor
                )
                .frame(width: 96, height: 96)
                .overlay {
                    VStack(spacing: 0) {
                        Text("\(Int((FinanceCalculator.budgetProgressClamped(budgeted: planned, spent: spent) * 100).rounded()))%")
                            .font(PennyTypography.cardTitle)
                            .monospacedDigit()
                        Text("used")
                            .font(PennyTypography.footnote)
                            .foregroundStyle(PennyColors.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: PennySpacing.sm) {
                    metric("Planned spending", planned)
                    metric("Spent", spent)
                    metric("Remaining", remaining, color: remaining < 0 ? PennyColors.expense : PennyColors.income)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Budget \(Int(FinanceCalculator.budgetProgressClamped(budgeted: planned, spent: spent) * 100)) percent used. Remaining \(MoneyFormatters.string(from: remaining, currencyCode: currency))")
        }
    }

    private func metric(_ title: String, _ value: Decimal, color: Color = PennyColors.textPrimary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(PennyTypography.footnote)
                .foregroundStyle(PennyColors.textSecondary)
            MoneyText(amount: value, currencyCode: currency, font: PennyTypography.smallAmount, color: color, compact: true)
        }
    }

    private var ringColor: Color {
        switch FinanceCalculator.budgetHealth(budgeted: planned, spent: spent) {
        case .healthy: return PennyColors.healthy
        case .nearLimit: return PennyColors.nearLimit
        case .overBudget: return PennyColors.overBudget
        case .unset: return PennyColors.textTertiary
        }
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: PennySpacing.sm) {
            SectionHeader(title: "Categories")
            if categories.isEmpty {
                EmptyStateView(
                    symbol: "chart.pie.fill",
                    title: "No budget categories",
                    message: "Reset demo data or add categories to start budgeting."
                )
            } else {
                LazyVStack(spacing: PennySpacing.sm) {
                    ForEach(categories.filter { $0.name != "Income" }, id: \.id) { category in
                        let catSpent = monthTransactions
                            .filter { $0.categoryName == category.name }
                            .reduce(Decimal(0)) { $0 + $1.amount }
                        Button {
                            selectedCategoryID = category.id
                        } label: {
                            CategoryBudgetRow(
                                category: category,
                                spent: catSpent,
                                currencyCode: currency
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct CategoryBudgetRow: View {
    let category: BudgetCategory
    let spent: Decimal
    let currencyCode: String

    private var health: FinanceCalculator.BudgetHealth {
        FinanceCalculator.budgetHealth(budgeted: category.budgetedAmount, spent: spent)
    }

    private var progress: Double {
        FinanceCalculator.budgetProgressClamped(budgeted: category.budgetedAmount, spent: spent)
    }

    var body: some View {
        PennyCard {
            HStack(spacing: PennySpacing.sm) {
                CategoryIcon(icon: category.icon, colourIdentifier: category.colourIdentifier)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(category.name)
                            .font(PennyTypography.bodyEmphasized)
                            .foregroundStyle(PennyColors.textPrimary)
                        Spacer()
                        Text("\(MoneyFormatters.compact(from: spent, currencyCode: currencyCode)) / \(MoneyFormatters.compact(from: category.budgetedAmount, currencyCode: currencyCode))")
                            .font(PennyTypography.caption)
                            .monospacedDigit()
                            .foregroundStyle(PennyColors.textSecondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(PennyColors.secondarySurface)
                            Capsule()
                                .fill(barColor)
                                .frame(width: max(4, geo.size.width * progress))
                        }
                    }
                    .frame(height: 6)
                    HStack {
                        Label(health.accessibilityLabel, systemImage: healthSymbol)
                            .font(PennyTypography.footnote)
                            .foregroundStyle(barColor)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(PennyColors.textTertiary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var barColor: Color {
        switch health {
        case .healthy: return PennyColors.healthy
        case .nearLimit: return PennyColors.nearLimit
        case .overBudget: return PennyColors.overBudget
        case .unset: return PennyColors.textTertiary
        }
    }

    private var healthSymbol: String {
        switch health {
        case .healthy: return "checkmark.circle"
        case .nearLimit: return "exclamationmark.circle"
        case .overBudget: return "xmark.circle"
        case .unset: return "minus.circle"
        }
    }
}

struct CategoryDetailView: View {
    @Bindable var category: BudgetCategory
    let month: Date
    let currencyCode: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]

    @State private var budgetText: String = ""
    @State private var isEditing = false
    @Query(sort: \BudgetCategory.sortOrder) private var allCategories: [BudgetCategory]

    private var monthTx: [Transaction] {
        transactions.filter {
            DateHelpers.isSameMonth($0.date, month)
                && $0.transactionType == .expense
                && $0.categoryName == category.name
        }
        .sorted { $0.date > $1.date }
    }

    private var spent: Decimal {
        monthTx.reduce(0) { $0 + $1.amount }
    }

    private var remaining: Decimal {
        FinanceCalculator.budgetRemaining(budgeted: category.budgetedAmount, spent: spent)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PennySpacing.lg) {
                    PennyCard {
                        VStack(alignment: .leading, spacing: PennySpacing.md) {
                            HStack {
                                CategoryIcon(icon: category.icon, colourIdentifier: category.colourIdentifier, size: 48)
                                VStack(alignment: .leading) {
                                    Text(category.name)
                                        .font(PennyTypography.title)
                                    Text(FinanceCalculator.budgetHealth(budgeted: category.budgetedAmount, spent: spent).accessibilityLabel)
                                        .font(PennyTypography.caption)
                                        .foregroundStyle(PennyColors.textSecondary)
                                }
                            }
                            HStack {
                                stat("Budget", category.budgetedAmount)
                                stat("Spent", spent)
                                stat("Left", remaining, color: remaining < 0 ? PennyColors.expense : PennyColors.income)
                            }

                            if isEditing {
                                HStack {
                                    TextField("Budget amount", text: $budgetText)
                                        .keyboardType(.decimalPad)
                                        .padding()
                                        .background(RoundedRectangle(cornerRadius: 12).fill(PennyColors.secondarySurface))
                                    Button("Save") {
                                        Keyboard.dismiss()
                                        if let value = Decimal.from(budgetText), value >= 0 {
                                            category.budgetedAmount = value
                                            try? modelContext.save()
                                            BudgetPlanning.syncMonthEnvelope(
                                                in: modelContext,
                                                categories: allCategories,
                                                month: month
                                            )
                                            isEditing = false
                                            Haptics.success()
                                        }
                                    }
                                    .buttonStyle(.pennyPrimary)
                                    .frame(width: 100)
                                }
                            }
                        }
                    }

                    trendChart

                    VStack(alignment: .leading, spacing: PennySpacing.sm) {
                        SectionHeader(title: "Transactions")
                        if monthTx.isEmpty {
                            Text("No transactions in this category yet.")
                                .font(PennyTypography.callout)
                                .foregroundStyle(PennyColors.textSecondary)
                        } else {
                            ForEach(monthTx, id: \.id) { tx in
                                TransactionRow(
                                    title: tx.title,
                                    categoryName: tx.categoryName,
                                    amount: tx.amount,
                                    type: tx.transactionType,
                                    currencyCode: currencyCode
                                )
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .padding(PennySpacing.screenPadding)
            }
            .background(PennyColors.background.ignoresSafeArea())
            .navigationTitle(category.name)
            .navigationBarTitleDisplayMode(.inline)
            .pennyKeyboardDone()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        Keyboard.dismiss()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(isEditing ? "Cancel" : "Edit") {
                        if isEditing {
                            Keyboard.dismiss()
                            isEditing = false
                        } else {
                            budgetText = NSDecimalNumber(decimal: category.budgetedAmount).stringValue
                            isEditing = true
                        }
                    }
                }
            }
        }
    }

    private func stat(_ title: String, _ value: Decimal, color: Color = PennyColors.textPrimary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(PennyTypography.footnote)
                .foregroundStyle(PennyColors.textSecondary)
            MoneyText(amount: value, currencyCode: currencyCode, font: PennyTypography.smallAmount, color: color, compact: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var trendChart: some View {
        let calendar = Calendar.current
        let points: [(label: String, amount: Decimal)] = (-2...0).compactMap { offset in
            let m = DateHelpers.addingMonths(offset, to: month)
            let total = transactions.filter {
                DateHelpers.isSameMonth($0.date, m)
                    && $0.transactionType == .expense
                    && $0.categoryName == category.name
            }.reduce(Decimal(0)) { $0 + $1.amount }
            let label = calendar.shortMonthSymbols[calendar.component(.month, from: m) - 1]
            return (label, total)
        }

        return PennyCard {
            VStack(alignment: .leading, spacing: PennySpacing.sm) {
                Text("3-month trend")
                    .font(PennyTypography.caption)
                    .foregroundStyle(PennyColors.textSecondary)
                Chart(points, id: \.label) { point in
                    BarMark(
                        x: .value("Month", point.label),
                        y: .value("Spent", point.amount.doubleValue)
                    )
                    .foregroundStyle(PennyColors.category(category.colourIdentifier))
                    .cornerRadius(6)
                }
                .frame(height: 140)
                .accessibilityLabel("Spending trend for \(category.name) over three months")
            }
        }
    }
}

#Preview("Budget") {
    BudgetView()
        .environment(AppSession())
        .modelContainer(PennyPersistence.previewContainer())
}
