import SwiftUI
import SwiftData
import Charts

struct PlanView: View {
    @Environment(AppSession.self) private var session
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
            .onAppear {
                if let hint = session.walkthroughPlanSegment {
                    segment = hint
                }
            }
            .onChange(of: session.walkthroughPlanSegment) { _, newValue in
                if let newValue {
                    segment = newValue
                }
            }
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
    @Environment(StoreManager.self) private var store
    @Query(sort: \SavingsGoal.createdAt) private var goals: [SavingsGoal]
    @Query private var settingsList: [UserSettings]
    @State private var showAdd = false
    @State private var editingGoal: SavingsGoal?
    @State private var pendingDelete: SavingsGoal?
    @State private var showPaywall = false

    /// Free users can keep up to the free-tier limit of goals; beyond that needs Pro.
    private var canAddGoal: Bool {
        store.isPro || goals.count < PennyProductCatalog.freeTierGoalLimit
    }

    private func startAddGoal() {
        if canAddGoal {
            showAdd = true
        } else {
            Haptics.light()
            showPaywall = true
        }
    }

    private var currency: String { settingsList.first?.currencyCode ?? "CAD" }

    var body: some View {
        List {
            if goals.isEmpty {
                Section {
                    EmptyStateView(
                        symbol: "target",
                        title: "No savings goals",
                        message: "Create a goal to track progress toward something that matters.",
                        actionTitle: "Add goal"
                    ) { startAddGoal() }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            } else {
                Section {
                    ForEach(goals, id: \.id) { goal in
                        Button {
                            editingGoal = goal
                        } label: {
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
                                    Text("About \(MoneyFormatters.compact(from: required, currencyCode: currency))/month to reach \(MoneyFormatters.compact(from: goal.targetAmount, currencyCode: currency)) by \(DateHelpers.monthYear(for: target))\(LegalCopy.asterisk)")
                                        .font(PennyTypography.caption)
                                        .foregroundStyle(PennyColors.textSecondary)
                                }
                            }
                            .padding(.vertical, PennySpacing.xs)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(PennyColors.surface)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDelete = goal
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                editingGoal = goal
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(PennyColors.brand)
                        }
                        .contextMenu {
                            Button {
                                editingGoal = goal
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                pendingDelete = goal
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    startAddGoal()
                } label: {
                    Label(canAddGoal ? "Add savings goal" : "Add savings goal (Pro)", systemImage: canAddGoal ? "plus" : "sparkles")
                }
                .buttonStyle(.pennySecondary)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: PennySpacing.sm, leading: PennySpacing.screenPadding, bottom: PennySpacing.sm, trailing: PennySpacing.screenPadding))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(PennyColors.background.ignoresSafeArea())
        .sheet(isPresented: $showAdd) {
            AddGoalView()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: Binding(
            get: { editingGoal != nil },
            set: { if !$0 { editingGoal = nil } }
        )) {
            if let editingGoal {
                AddGoalView(goal: editingGoal)
            }
        }
        .confirmationDialog(
            "Delete goal?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let pendingDelete {
                    modelContext.delete(pendingDelete)
                    try? modelContext.save()
                    Haptics.warning()
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            if let pendingDelete {
                Text("Remove “\(pendingDelete.name)”? This can’t be undone.")
            }
        }
    }
}

struct AddGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var goal: SavingsGoal? = nil

    @State private var name = ""
    @State private var targetText = ""
    @State private var currentText = "0"
    @State private var hasTargetDate = true
    @State private var targetDate = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
    @State private var icon = "target"
    @State private var selectedPreset: String?
    @State private var didLoadExisting = false
    @State private var showDeleteConfirm = false

    private let presets: [(String, String)] = [
        ("Emergency Fund", "shield.fill"),
        ("House", "house.fill"),
        ("Vacation", "airplane"),
        ("Car", "car.fill"),
        ("Wedding", "heart.fill"),
        ("Education", "graduationcap.fill")
    ]

    private var isEditing: Bool { goal != nil }

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
                if isEditing {
                    Section {
                        Button("Delete Goal", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "Edit Goal" : "New Goal")
            .pennyKeyboardDone()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Keyboard.dismiss()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty || Decimal.from(targetText) == nil)
                }
            }
            .onAppear { loadExistingIfNeeded() }
            .confirmationDialog(
                "Delete goal?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteGoal() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Remove “\(name)”? This can’t be undone.")
            }
        }
    }

    private func loadExistingIfNeeded() {
        guard !didLoadExisting, let goal else { return }
        didLoadExisting = true
        name = goal.name
        targetText = NSDecimalNumber(decimal: goal.targetAmount).stringValue
        currentText = NSDecimalNumber(decimal: goal.currentAmount).stringValue
        hasTargetDate = goal.targetDate != nil
        targetDate = goal.targetDate ?? targetDate
        icon = goal.icon
        selectedPreset = presets.first { $0.1 == goal.icon }?.0
    }

    private func save() {
        Keyboard.dismiss()
        guard let target = Decimal.from(targetText), target > 0 else { return }
        let current = Decimal.from(currentText) ?? 0
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let goal {
            goal.name = trimmed
            goal.targetAmount = target
            goal.currentAmount = max(0, current)
            goal.targetDate = hasTargetDate ? targetDate : nil
            goal.icon = icon
        } else {
            let goal = SavingsGoal(
                name: trimmed,
                targetAmount: target,
                currentAmount: max(0, current),
                targetDate: hasTargetDate ? targetDate : nil,
                icon: icon
            )
            modelContext.insert(goal)
        }
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }

    private func deleteGoal() {
        guard let goal else { return }
        Keyboard.dismiss()
        modelContext.delete(goal)
        try? modelContext.save()
        Haptics.warning()
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
    @State private var editingBill: RecurringBill?
    @State private var pendingDelete: RecurringBill?

    private var currency: String { settingsList.first?.currencyCode ?? "CAD" }
    private var monthlyTotal: Decimal {
        bills.reduce(Decimal(0)) {
            $0 + FinanceCalculator.monthlyEquivalent(amount: $1.amount, recurrence: $1.recurrence)
        }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recurring bills")
                        .font(PennyTypography.caption)
                        .foregroundStyle(PennyColors.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        MoneyText(amount: monthlyTotal, currencyCode: currency, font: PennyTypography.largeAmount, color: PennyColors.brand, compact: true)
                        Text("/ month equiv.")
                            .font(PennyTypography.callout)
                            .foregroundStyle(PennyColors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, PennySpacing.xs)
                .listRowBackground(PennyColors.brandMuted)
            }

            Section {
                if bills.isEmpty {
                    EmptyStateView(
                        symbol: "calendar",
                        title: "No recurring bills",
                        message: "Add rent, utilities, and subscriptions to plan upcoming payments.",
                        actionTitle: "Add bill"
                    ) { showAdd = true }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } else {
                    ForEach(bills, id: \.id) { bill in
                        BillRow(
                            name: bill.name,
                            dueDate: bill.nextDueDate,
                            amount: bill.amount,
                            currencyCode: currency,
                            icon: bill.icon,
                            categoryName: bill.categoryName,
                            recurrenceLabel: bill.recurrence.displayName
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { editingBill = bill }
                        .listRowBackground(PennyColors.surface)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDelete = bill
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                editingBill = bill
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(PennyColors.brand)
                        }
                        .contextMenu {
                            Button {
                                editingBill = bill
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                pendingDelete = bill
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    showAdd = true
                } label: {
                    Label("Add bill", systemImage: "plus")
                }
                .buttonStyle(.pennySecondary)
                .walkthroughAnchor(.addBill)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: PennySpacing.sm, leading: PennySpacing.screenPadding, bottom: PennySpacing.sm, trailing: PennySpacing.screenPadding))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(PennyColors.background.ignoresSafeArea())
        .sheet(isPresented: $showAdd) {
            AddBillView()
        }
        .sheet(isPresented: Binding(
            get: { editingBill != nil },
            set: { if !$0 { editingBill = nil } }
        )) {
            if let editingBill {
                AddBillView(bill: editingBill)
            }
        }
        .confirmationDialog(
            "Delete bill?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let pendingDelete {
                    pendingDelete.isActive = false
                    try? modelContext.save()
                    Haptics.warning()
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            if let pendingDelete {
                Text("Remove “\(pendingDelete.name)” from your recurring bills?")
            }
        }
    }
}

struct AddBillView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var bill: RecurringBill? = nil

    @State private var name = ""
    @State private var amountText = ""
    @State private var recurrence: BillRecurrence = .monthly
    @State private var startDate = Date.now
    @State private var dueDay = Calendar.current.component(.day, from: .now)
    @State private var category = "Subscriptions"
    @State private var didLoadExisting = false
    @State private var showDeleteConfirm = false

    private var isEditing: Bool { bill != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bill") {
                    TextField("Name", text: $name)
                        .pennyNoAutoFill()
                    TextField("Amount per payment", text: $amountText)
                        .keyboardType(.decimalPad)
                        .pennyNoAutoFill()
                    Picker("Category", selection: $category) {
                        ForEach(CategoryCatalog.defaults.map(\.name), id: \.self) { Text($0) }
                    }
                }
                Section("Schedule") {
                    Picker("Frequency", selection: $recurrence) {
                        ForEach(BillRecurrence.allCases) { item in
                            Text(item.displayName).tag(item)
                        }
                    }
                    DatePicker("Starts on", selection: $startDate, displayedComponents: .date)
                        .onChange(of: startDate) { _, newValue in
                            dueDay = Calendar.current.component(.day, from: newValue)
                        }
                    if recurrence == .monthly || recurrence == .yearly {
                        Stepper("Due day: \(clampedDueDay)", value: $dueDay, in: 1...28)
                    } else {
                        Text(weekdayHint)
                            .font(PennyTypography.caption)
                            .foregroundStyle(PennyColors.textSecondary)
                    }
                }
                if isEditing {
                    Section {
                        Button("Delete Bill", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "Edit Bill" : "New Bill")
            .pennyKeyboardDone()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Keyboard.dismiss()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty || Decimal.from(amountText) == nil)
                }
            }
            .onAppear { loadExistingIfNeeded() }
            .confirmationDialog(
                "Delete bill?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteBill() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Remove “\(name)” from your recurring bills?")
            }
        }
    }

    private var clampedDueDay: Int { max(1, min(28, dueDay)) }

    private var weekdayHint: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return "Repeats every \(recurrence == .weekly ? "week" : "two weeks") on \(formatter.string(from: startDate))"
    }

    private func loadExistingIfNeeded() {
        guard !didLoadExisting, let bill else { return }
        didLoadExisting = true
        name = bill.name
        amountText = NSDecimalNumber(decimal: bill.amount).stringValue
        recurrence = bill.recurrence
        startDate = bill.startDate
        dueDay = bill.dueDay
        category = bill.categoryName
    }

    private func save() {
        Keyboard.dismiss()
        guard let amount = Decimal.from(amountText), amount > 0 else { return }
        let day = clampedDueDay
        let next = DateHelpers.nextDueDate(
            startDate: startDate,
            recurrence: recurrence,
            dueDay: day
        )
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let icon = CategoryCatalog.icon(for: category)

        if let bill {
            bill.name = trimmed
            bill.amount = amount
            bill.dueDay = day
            bill.categoryName = category
            bill.recurrence = recurrence
            bill.nextDueDate = next
            bill.startDate = startDate
            bill.icon = icon
        } else {
            let bill = RecurringBill(
                name: trimmed,
                amount: amount,
                dueDay: day,
                categoryName: category,
                recurrence: recurrence,
                nextDueDate: next,
                startDate: startDate,
                icon: icon
            )
            modelContext.insert(bill)
        }
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }

    private func deleteBill() {
        guard let bill else { return }
        Keyboard.dismiss()
        bill.isActive = false
        try? modelContext.save()
        Haptics.warning()
        dismiss()
    }
}

// MARK: - Debt

struct DebtPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Debt.name) private var debts: [Debt]
    @Query private var settingsList: [UserSettings]
    @State private var showAdd = false
    @State private var editingDebt: Debt?
    @State private var pendingDelete: Debt?

    private var currency: String { settingsList.first?.currencyCode ?? "CAD" }

    var body: some View {
        List {
            if debts.isEmpty {
                Section {
                    EmptyStateView(
                        symbol: "creditcard.fill",
                        title: "No debt tracked",
                        message: "Add a loan or card balance to see payoff estimates.",
                        actionTitle: "Add debt"
                    ) { showAdd = true }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            } else {
                Section {
                    ForEach(debts, id: \.id) { debt in
                        Button {
                            editingDebt = debt
                        } label: {
                            DebtCard(debt: debt, currencyCode: currency)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: PennySpacing.sm, leading: PennySpacing.screenPadding, bottom: PennySpacing.sm, trailing: PennySpacing.screenPadding))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDelete = debt
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                editingDebt = debt
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(PennyColors.brand)
                        }
                        .contextMenu {
                            Button {
                                editingDebt = debt
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                pendingDelete = debt
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            Section {
                Button {
                    showAdd = true
                } label: {
                    Label("Add debt", systemImage: "plus")
                }
                .buttonStyle(.pennySecondary)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: PennySpacing.sm, leading: PennySpacing.screenPadding, bottom: PennySpacing.sm, trailing: PennySpacing.screenPadding))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(PennyColors.background.ignoresSafeArea())
        .sheet(isPresented: $showAdd) {
            AddDebtView()
        }
        .sheet(isPresented: Binding(
            get: { editingDebt != nil },
            set: { if !$0 { editingDebt = nil } }
        )) {
            if let editingDebt {
                AddDebtView(debt: editingDebt)
            }
        }
        .confirmationDialog(
            "Delete debt?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let pendingDelete {
                    modelContext.delete(pendingDelete)
                    try? modelContext.save()
                    Haptics.warning()
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            if let pendingDelete {
                Text("Remove “\(pendingDelete.name)”? This can’t be undone.")
            }
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
                    Label("Estimated payoff\(LegalCopy.asterisk): \(DateHelpers.monthYear(for: date))", systemImage: "calendar")
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

    var debt: Debt? = nil

    @State private var name = ""
    @State private var balanceText = ""
    @State private var rateText = "19.99"
    @State private var paymentText = ""
    @State private var minimumText = ""
    @State private var didLoadExisting = false
    @State private var showDeleteConfirm = false

    private var isEditing: Bool { debt != nil }

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
                if isEditing {
                    Section {
                        Button("Delete Debt", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "Edit Debt" : "New Debt")
            .pennyKeyboardDone()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Keyboard.dismiss()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty || Decimal.from(balanceText) == nil)
                }
            }
            .onAppear { loadExistingIfNeeded() }
            .confirmationDialog(
                "Delete debt?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteDebt() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Remove “\(name)”? This can’t be undone.")
            }
        }
    }

    private func loadExistingIfNeeded() {
        guard !didLoadExisting, let debt else { return }
        didLoadExisting = true
        name = debt.name
        balanceText = NSDecimalNumber(decimal: debt.currentBalance).stringValue
        rateText = NSDecimalNumber(decimal: debt.interestRate).stringValue
        minimumText = NSDecimalNumber(decimal: debt.minimumPayment).stringValue
        paymentText = NSDecimalNumber(decimal: debt.plannedMonthlyPayment).stringValue
    }

    private func save() {
        Keyboard.dismiss()
        guard let balance = Decimal.from(balanceText), balance >= 0 else { return }
        let rate = Decimal.from(rateText) ?? 0
        let minimum = Decimal.from(minimumText) ?? 0
        let payment = Decimal.from(paymentText) ?? minimum
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let debt {
            debt.name = trimmed
            debt.currentBalance = balance
            debt.interestRate = rate
            debt.minimumPayment = minimum
            debt.plannedMonthlyPayment = payment
        } else {
            let debt = Debt(
                name: trimmed,
                originalBalance: balance,
                currentBalance: balance,
                interestRate: rate,
                minimumPayment: minimum,
                plannedMonthlyPayment: payment
            )
            modelContext.insert(debt)
        }
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }

    private func deleteDebt() {
        guard let debt else { return }
        Keyboard.dismiss()
        modelContext.delete(debt)
        try? modelContext.save()
        Haptics.warning()
        dismiss()
    }
}

// MARK: - Forecast

struct ForecastPlanView: View {
    @Query private var accounts: [FinancialAccount]
    @Query(filter: #Predicate<RecurringBill> { $0.isActive }) private var bills: [RecurringBill]
    @Query private var debts: [Debt]
    @Query(sort: \SavingsGoal.createdAt) private var goals: [SavingsGoal]
    @Query private var settingsList: [UserSettings]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Environment(AppSession.self) private var session
    @Environment(StoreManager.self) private var store
    @State private var showPaywall = false

    private var currency: String { settingsList.first?.currencyCode ?? "CAD" }
    private var horizons: [Int] { PennyProductCatalog.forecastHorizons(isPro: store.isPro) }

    private var currentBalance: Decimal {
        accounts.filter { $0.accountType == .chequing || $0.accountType == .savings || $0.accountType == .cash }
            .reduce(0) { $0 + $1.balance }
    }

    private var recurring: Decimal {
        bills.reduce(0) {
            $0 + FinanceCalculator.monthlyEquivalent(amount: $1.amount, recurrence: $1.recurrence)
        }
    }

    private var averageDiscretionary: Decimal {
        let monthStart = DateHelpers.startOfMonth(for: session.selectedMonth)
        let reserved = Set(bills.map { $0.name.lowercased() } + debts.map { $0.name.lowercased() })
        let recentMonths: [Date] = (0..<3).map { DateHelpers.addingMonths(-$0, to: monthStart) }
        let totals: [Decimal] = recentMonths.map { month in
            transactions
                .filter {
                    DateHelpers.isSameMonth($0.date, month)
                        && $0.transactionType == .expense
                        && !reserved.contains($0.title.lowercased())
                }
                .reduce(0) { $0 + $1.amount }
        }
        return FinanceCalculator.average(totals)
    }

    private var plannedSavings: Decimal {
        FinanceCalculator.effectiveMonthlySavings(
            goals: goals.map {
                .init(current: $0.currentAmount, target: $0.targetAmount, targetDate: $0.targetDate)
            },
            fallbackPlannedSavings: settingsList.first?.plannedMonthlySavings ?? 0
        )
    }

    private var projections: [FinanceCalculator.BalanceProjection] {
        FinanceCalculator.projectBalance(
            currentBalance: currentBalance,
            monthlyIncome: settingsList.first?.monthlyIncome ?? 0,
            recurringBills: recurring,
            averageDiscretionary: averageDiscretionary,
            plannedSavings: plannedSavings,
            debtPayments: debts.reduce(0) { $0 + $1.plannedMonthlyPayment },
            horizons: horizons
        )
    }

    private var summaryHorizons: Set<Int> {
        store.isPro ? [0, 3, 6, 12] : [0, 1, 3]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PennySpacing.md) {
                PennyCard {
                    VStack(alignment: .leading, spacing: PennySpacing.md) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("Projected liquid balance")
                                .font(PennyTypography.cardTitle)
                            EstimateAsterisk()
                        }
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
                            AxisMarks(values: horizons) { value in
                                AxisValueLabel {
                                    if let m = value.as(Int.self) {
                                        Text(m == 0 ? "Now" : "\(m)mo")
                                    }
                                }
                            }
                        }
                        .accessibilityLabel(chartAccessibility)

                        ForEach(projections.filter { summaryHorizons.contains($0.monthsAhead) }) { point in
                            HStack {
                                Text(point.monthsAhead == 0 ? "Today" : "\(point.monthsAhead) months")
                                    .foregroundStyle(PennyColors.textSecondary)
                                Spacer()
                                MoneyText(amount: point.projectedBalance, currencyCode: currency, font: PennyTypography.smallAmount, compact: true)
                            }
                            .font(PennyTypography.callout)
                        }

                        if !store.isPro {
                            Button {
                                Haptics.light()
                                showPaywall = true
                            } label: {
                                Label("Unlock 6- and 12-month forecasts with Pro", systemImage: "sparkles")
                            }
                            .buttonStyle(.pennySecondary)
                        }
                    }
                }
            }
            .padding(.horizontal, PennySpacing.screenPadding)
            .padding(.bottom, PennySpacing.xxxl)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
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
        .environment(StoreManager())
        .modelContainer(PennyPersistence.previewContainer())
}
