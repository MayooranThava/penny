import SwiftUI
import SwiftData
import Charts

struct PlanView: View {
    @State private var segment: PlanSegment = .goals

    var body: some View {
        NavigationStack {
            VStack(spacing: PennySpacing.md) {
                Picker("Plan", selection: $segment) {
                    ForEach(PlanSegment.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, PennySpacing.screenPadding)
                .onChange(of: segment) { _, _ in Haptics.selection() }

                Group {
                    switch segment {
                    case .goals: GoalsPlanView()
                    case .bills: BillsPlanView()
                    case .debt: DebtPlanView()
                    case .forecast: ForecastPlanView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .background(PennyColors.background.ignoresSafeArea())
            .navigationTitle("Plan")
        }
    }
}

enum PlanSegment: String, CaseIterable, Identifiable {
    case goals, bills, debt, forecast
    var id: String { rawValue }
    var title: String {
        switch self {
        case .goals: return "Goals"
        case .bills: return "Bills"
        case .debt: return "Debt"
        case .forecast: return "Forecast"
        }
    }
}

// MARK: - Goals

struct GoalsPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavingsGoal.createdAt) private var goals: [SavingsGoal]
    @Query private var settingsList: [UserSettings]
    @State private var showAdd = false

    private var currency: String { settingsList.first?.currencyCode ?? "CAD" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PennySpacing.md) {
                if goals.isEmpty {
                    EmptyStateView(
                        symbol: "target",
                        title: "No savings goals",
                        message: "Create a goal to track progress toward something that matters.",
                        actionTitle: "Add goal"
                    ) { showAdd = true }
                } else {
                    ForEach(goals, id: \.id) { goal in
                        PennyCard {
                            VStack(alignment: .leading, spacing: PennySpacing.sm) {
                                GoalProgressView(
                                    name: goal.name,
                                    current: goal.currentAmount,
                                    target: goal.targetAmount,
                                    currencyCode: currency,
                                    icon: goal.icon,
                                    colourIdentifier: goal.colourIdentifier,
                                    estimatedCompletion: goal.targetDate ?? FinanceCalculator.estimatedCompletionDate(
                                        current: goal.currentAmount,
                                        target: goal.targetAmount,
                                        monthlyContribution: (settingsList.first?.plannedMonthlySavings ?? 500) / Decimal(max(goals.count, 1))
                                    )
                                )
                                if let target = goal.targetDate,
                                   let required = FinanceCalculator.requiredMonthlySavings(
                                    current: goal.currentAmount,
                                    target: goal.targetAmount,
                                    targetDate: target
                                   ), required > 0 {
                                    Text("To reach \(MoneyFormatters.compact(from: goal.targetAmount, currencyCode: currency)) by \(DateHelpers.monthYear(for: target)), save about \(MoneyFormatters.compact(from: required, currencyCode: currency))/month.")
                                        .font(PennyTypography.caption)
                                        .foregroundStyle(PennyColors.textSecondary)
                                }
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                modelContext.delete(goal)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }

                Button {
                    showAdd = true
                } label: {
                    Label("Add savings goal", systemImage: "plus")
                }
                .buttonStyle(.pennySecondary)
            }
            .padding(.horizontal, PennySpacing.screenPadding)
            .padding(.bottom, PennySpacing.xxxl)
        }
        .sheet(isPresented: $showAdd) {
            AddGoalView()
        }
    }
}

struct AddGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var targetText = ""
    @State private var currentText = "0"
    @State private var hasTargetDate = true
    @State private var targetDate = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
    @State private var icon = "target"
    @State private var selectedPreset: String?

    private let presets: [(String, String)] = [
        ("Emergency Fund", "shield.fill"),
        ("House", "house.fill"),
        ("Vacation", "airplane"),
        ("Car", "car.fill"),
        ("Wedding", "heart.fill"),
        ("Education", "graduationcap.fill")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(presets, id: \.0) { preset in
                                Button {
                                    name = preset.0
                                    icon = preset.1
                                    selectedPreset = preset.0
                                } label: {
                                    VStack {
                                        Image(systemName: preset.1)
                                        Text(preset.0).font(.caption2)
                                    }
                                    .frame(width: 72, height: 64)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedPreset == preset.0 ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    TextField("Name", text: $name)
                        .pennyNoAutoFill()
                    TextField("Target amount", text: $targetText)
                        .keyboardType(.decimalPad)
                        .pennyNoAutoFill()
                    TextField("Current amount", text: $currentText)
                        .keyboardType(.decimalPad)
                        .pennyNoAutoFill()
                }
                Section("Target date") {
                    Toggle("Set target date", isOn: $hasTargetDate)
                    if hasTargetDate {
                        DatePicker("Reach by", selection: $targetDate, in: Date.now..., displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("New Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty || Decimal.from(targetText) == nil)
                }
            }
        }
    }

    private func save() {
        guard let target = Decimal.from(targetText), target > 0 else { return }
        let current = Decimal.from(currentText) ?? 0
        let goal = SavingsGoal(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            targetAmount: target,
            currentAmount: max(0, current),
            targetDate: hasTargetDate ? targetDate : nil,
            icon: icon
        )
        modelContext.insert(goal)
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }
}

// MARK: - Bills

struct BillsPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<RecurringBill> { $0.isActive }, sort: \RecurringBill.nextDueDate)
    private var bills: [RecurringBill]
    @Query private var settingsList: [UserSettings]
    @State private var showAdd = false

    private var currency: String { settingsList.first?.currencyCode ?? "CAD" }
    private var total: Decimal { bills.reduce(0) { $0 + $1.amount } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PennySpacing.md) {
                PennyCard(fill: PennyColors.brandMuted) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recurring bills")
                            .font(PennyTypography.caption)
                            .foregroundStyle(PennyColors.textSecondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            MoneyText(amount: total, currencyCode: currency, font: PennyTypography.largeAmount, color: PennyColors.brand, compact: true)
                            Text("/ month")
                                .font(PennyTypography.callout)
                                .foregroundStyle(PennyColors.textSecondary)
                        }
                    }
                }

                if bills.isEmpty {
                    EmptyStateView(
                        symbol: "calendar",
                        title: "No recurring bills",
                        message: "Add rent, utilities, and subscriptions to plan upcoming payments.",
                        actionTitle: "Add bill"
                    ) { showAdd = true }
                } else {
                    PennyCard {
                        VStack(spacing: PennySpacing.md) {
                            ForEach(bills, id: \.id) { bill in
                                BillRow(
                                    name: bill.name,
                                    dueDate: bill.nextDueDate,
                                    amount: bill.amount,
                                    currencyCode: currency,
                                    icon: bill.icon,
                                    categoryName: bill.categoryName
                                )
                                .contextMenu {
                                    Button(role: .destructive) {
                                        bill.isActive = false
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                                if bill.id != bills.last?.id { Divider() }
                            }
                        }
                    }
                }

                Button {
                    showAdd = true
                } label: {
                    Label("Add bill", systemImage: "plus")
                }
                .buttonStyle(.pennySecondary)
            }
            .padding(.horizontal, PennySpacing.screenPadding)
            .padding(.bottom, PennySpacing.xxxl)
        }
        .sheet(isPresented: $showAdd) {
            AddBillView()
        }
    }
}

struct AddBillView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var amountText = ""
    @State private var dueDay = 15
    @State private var category = "Subscriptions"
    @State private var icon = "doc.text.fill"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                    .pennyNoAutoFill()
                TextField("Amount", text: $amountText)
                    .keyboardType(.decimalPad)
                    .pennyNoAutoFill()
                Stepper("Due day: \(dueDay)", value: $dueDay, in: 1...28)
                Picker("Category", selection: $category) {
                    ForEach(CategoryCatalog.defaults.map(\.name), id: \.self) { Text($0) }
                }
            }
            .navigationTitle("New Bill")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty || Decimal.from(amountText) == nil)
                }
            }
        }
    }

    private func save() {
        guard let amount = Decimal.from(amountText), amount > 0 else { return }
        let bill = RecurringBill(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            dueDay: dueDay,
            categoryName: category,
            nextDueDate: DateHelpers.nextDueDate(dueDay: dueDay),
            icon: CategoryCatalog.icon(for: category)
        )
        modelContext.insert(bill)
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }
}

// MARK: - Debt

struct DebtPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Debt.name) private var debts: [Debt]
    @Query private var settingsList: [UserSettings]
    @State private var showAdd = false

    private var currency: String { settingsList.first?.currencyCode ?? "CAD" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PennySpacing.md) {
                if debts.isEmpty {
                    EmptyStateView(
                        symbol: "creditcard.fill",
                        title: "No debt tracked",
                        message: "Add a loan or card balance to see payoff estimates.",
                        actionTitle: "Add debt"
                    ) { showAdd = true }
                } else {
                    ForEach(debts, id: \.id) { debt in
                        DebtCard(debt: debt, currencyCode: currency)
                            .contextMenu {
                                Button(role: .destructive) {
                                    modelContext.delete(debt)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                Button {
                    showAdd = true
                } label: {
                    Label("Add debt", systemImage: "plus")
                }
                .buttonStyle(.pennySecondary)
            }
            .padding(.horizontal, PennySpacing.screenPadding)
            .padding(.bottom, PennySpacing.xxxl)
        }
        .sheet(isPresented: $showAdd) {
            AddDebtView()
        }
    }
}

struct DebtCard: View {
    let debt: Debt
    let currencyCode: String

    private var result: FinanceCalculator.DebtPayoffResult {
        FinanceCalculator.debtPayoff(
            balance: debt.currentBalance,
            aprPercent: debt.interestRate,
            monthlyPayment: debt.plannedMonthlyPayment
        )
    }

    var body: some View {
        PennyCard {
            VStack(alignment: .leading, spacing: PennySpacing.sm) {
                HStack {
                    CategoryIcon(icon: debt.icon, colourIdentifier: "debt", size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(debt.name)
                            .font(PennyTypography.cardTitle)
                        Text("Interest \(NSDecimalNumber(decimal: debt.interestRate).stringValue)%")
                            .font(PennyTypography.caption)
                            .foregroundStyle(PennyColors.textSecondary)
                    }
                    Spacer()
                    MoneyText(amount: debt.currentBalance, currencyCode: currencyCode, font: PennyTypography.mediumAmount, color: PennyColors.debt, compact: true)
                }

                Text("Payment \(MoneyFormatters.compact(from: debt.plannedMonthlyPayment, currencyCode: currencyCode))/month")
                    .font(PennyTypography.callout)
                    .foregroundStyle(PennyColors.textSecondary)

                switch result {
                case .paidOff(let date, let months, let interest):
                    Label("Estimated payoff: \(DateHelpers.monthYear(for: date))", systemImage: "calendar")
                        .font(PennyTypography.caption)
                        .foregroundStyle(PennyColors.textPrimary)
                    Text("\(months) months · \(MoneyFormatters.compact(from: interest, currencyCode: currencyCode)) total interest")
                        .font(PennyTypography.footnote)
                        .foregroundStyle(PennyColors.textTertiary)
                case .alreadyPaid:
                    Text("This balance is paid off.")
                        .font(PennyTypography.caption)
                        .foregroundStyle(PennyColors.income)
                case .paymentTooLow(let minimum):
                    Label("Payment too low to pay off at this rate.", systemImage: "exclamationmark.triangle.fill")
                        .font(PennyTypography.caption)
                        .foregroundStyle(PennyColors.warning)
                    Text("Need about \(MoneyFormatters.compact(from: minimum, currencyCode: currencyCode))/month to make progress.")
                        .font(PennyTypography.footnote)
                        .foregroundStyle(PennyColors.textSecondary)
                case .invalid:
                    Text("Check the balance, rate, and payment values.")
                        .font(PennyTypography.caption)
                        .foregroundStyle(PennyColors.expense)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct AddDebtView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var balanceText = ""
    @State private var rateText = "19.99"
    @State private var paymentText = ""
    @State private var minimumText = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                    .pennyNoAutoFill()
                TextField("Current balance", text: $balanceText)
                    .keyboardType(.decimalPad)
                    .pennyNoAutoFill()
                TextField("Interest rate (%)", text: $rateText)
                    .keyboardType(.decimalPad)
                    .pennyNoAutoFill()
                TextField("Minimum payment", text: $minimumText)
                    .keyboardType(.decimalPad)
                    .pennyNoAutoFill()
                TextField("Planned monthly payment", text: $paymentText)
                    .keyboardType(.decimalPad)
                    .pennyNoAutoFill()
            }
            .navigationTitle("New Debt")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty || Decimal.from(balanceText) == nil)
                }
            }
        }
    }

    private func save() {
        guard let balance = Decimal.from(balanceText), balance >= 0 else { return }
        let rate = Decimal.from(rateText) ?? 0
        let minimum = Decimal.from(minimumText) ?? 0
        let payment = Decimal.from(paymentText) ?? minimum
        let debt = Debt(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            originalBalance: balance,
            currentBalance: balance,
            interestRate: rate,
            minimumPayment: minimum,
            plannedMonthlyPayment: payment
        )
        modelContext.insert(debt)
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }
}

// MARK: - Forecast

struct ForecastPlanView: View {
    @Query private var accounts: [FinancialAccount]
    @Query(filter: #Predicate<RecurringBill> { $0.isActive }) private var bills: [RecurringBill]
    @Query private var debts: [Debt]
    @Query private var settingsList: [UserSettings]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Environment(AppSession.self) private var session

    private var currency: String { settingsList.first?.currencyCode ?? "CAD" }

    private var currentBalance: Decimal {
        accounts.filter { $0.accountType == .chequing || $0.accountType == .savings || $0.accountType == .cash }
            .reduce(0) { $0 + $1.balance }
    }

    private var recurring: Decimal { bills.reduce(0) { $0 + $1.amount } }

    private var averageDiscretionary: Decimal {
        let monthStart = DateHelpers.startOfMonth(for: session.selectedMonth)
        let billNames = Set(bills.map { $0.name.lowercased() })
        let recentMonths: [Date] = (0..<3).map { DateHelpers.addingMonths(-$0, to: monthStart) }
        let totals: [Decimal] = recentMonths.map { month in
            transactions
                .filter {
                    DateHelpers.isSameMonth($0.date, month)
                        && $0.transactionType == .expense
                        && !billNames.contains($0.title.lowercased())
                }
                .reduce(0) { $0 + $1.amount }
        }
        return FinanceCalculator.average(totals)
    }

    private var projections: [FinanceCalculator.BalanceProjection] {
        FinanceCalculator.projectBalance(
            currentBalance: currentBalance,
            monthlyIncome: settingsList.first?.monthlyIncome ?? 0,
            recurringBills: recurring,
            averageDiscretionary: averageDiscretionary,
            plannedSavings: settingsList.first?.plannedMonthlySavings ?? 0,
            debtPayments: debts.reduce(0) { $0 + $1.plannedMonthlyPayment },
            horizons: [0, 1, 3, 6, 12]
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PennySpacing.md) {
                PennyCard(fill: PennyColors.secondarySurface) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Estimates only", systemImage: "info.circle")
                            .font(PennyTypography.caption)
                            .foregroundStyle(PennyColors.warning)
                        Text("Projections use your income, bills, recent spending, savings plan, and debt payments. They are not guaranteed outcomes.")
                            .font(PennyTypography.footnote)
                            .foregroundStyle(PennyColors.textSecondary)
                    }
                }

                PennyCard {
                    VStack(alignment: .leading, spacing: PennySpacing.md) {
                        Text("Projected liquid balance")
                            .font(PennyTypography.cardTitle)
                        Chart(projections) { point in
                            LineMark(
                                x: .value("Months", point.monthsAhead),
                                y: .value("Balance", point.projectedBalance.doubleValue)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(PennyColors.brand)
                            AreaMark(
                                x: .value("Months", point.monthsAhead),
                                y: .value("Balance", point.projectedBalance.doubleValue)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(PennyColors.brand.opacity(0.12))
                            PointMark(
                                x: .value("Months", point.monthsAhead),
                                y: .value("Balance", point.projectedBalance.doubleValue)
                            )
                            .foregroundStyle(PennyColors.brand)
                        }
                        .frame(height: 200)
                        .chartXAxis {
                            AxisMarks(values: [0, 1, 3, 6, 12]) { value in
                                AxisValueLabel {
                                    if let m = value.as(Int.self) {
                                        Text(m == 0 ? "Now" : "\(m)mo")
                                    }
                                }
                            }
                        }
                        .accessibilityLabel(chartAccessibility)

                        ForEach(projections.filter { [0, 3, 6, 12].contains($0.monthsAhead) }) { point in
                            HStack {
                                Text(point.monthsAhead == 0 ? "Today" : "\(point.monthsAhead) months")
                                    .foregroundStyle(PennyColors.textSecondary)
                                Spacer()
                                MoneyText(amount: point.projectedBalance, currencyCode: currency, font: PennyTypography.smallAmount, compact: true)
                            }
                            .font(PennyTypography.callout)
                        }
                    }
                }
            }
            .padding(.horizontal, PennySpacing.screenPadding)
            .padding(.bottom, PennySpacing.xxxl)
        }
    }

    private var chartAccessibility: String {
        projections.map {
            let label = $0.monthsAhead == 0 ? "today" : "\($0.monthsAhead) months"
            return "\(label): \(MoneyFormatters.string(from: $0.projectedBalance, currencyCode: currency))"
        }.joined(separator: ". ")
    }
}

#Preview("Plan") {
    PlanView()
        .environment(AppSession())
        .modelContainer(PennyPersistence.previewContainer())
}
