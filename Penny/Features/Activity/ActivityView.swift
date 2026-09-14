import SwiftUI
import SwiftData

struct ActivityView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSession.self) private var session
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var settingsList: [UserSettings]

    @State private var searchText = ""
    @State private var filter: ActivityFilter = .all
    @State private var categoryFilter: String? = nil
    @State private var editingTransaction: Transaction?
    @State private var pendingDelete: Transaction?

    private var currency: String { settingsList.first?.currencyCode ?? "CAD" }

    private var monthTransactions: [Transaction] {
        transactions.filter { DateHelpers.isSameMonth($0.date, session.selectedMonth) }
    }

    private var filtered: [Transaction] {
        monthTransactions.filter { tx in
            let matchesFilter: Bool = {
                switch filter {
                case .all: return true
                case .income: return tx.transactionType == .income
                case .expense: return tx.transactionType == .expense
                }
            }()
            let matchesCategory = categoryFilter == nil || tx.categoryName == categoryFilter
            let matchesSearch = searchText.isEmpty
                || tx.title.localizedCaseInsensitiveContains(searchText)
                || tx.categoryName.localizedCaseInsensitiveContains(searchText)
                || tx.note.localizedCaseInsensitiveContains(searchText)
            return matchesFilter && matchesCategory && matchesSearch
        }
    }

    private var grouped: [(key: String, date: Date, items: [Transaction])] {
        let calendar = Calendar.current
        let dict = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.date) }
        return dict.keys.sorted(by: >).map { day in
            let label = DateHelpers.relativeDayLabel(for: day).uppercased()
            let items = (dict[day] ?? []).sorted { $0.date > $1.date }
            return (label, day, items)
        }
    }

    private var categoriesInMonth: [String] {
        Array(Set(monthTransactions.map(\.categoryName))).sorted()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthSelector
                    .padding(.horizontal, PennySpacing.screenPadding)
                    .padding(.top, PennySpacing.xs)

                filterBar
                    .padding(.horizontal, PennySpacing.screenPadding)
                    .padding(.vertical, PennySpacing.sm)

                if filtered.isEmpty {
                    Spacer()
                    EmptyStateView(
                        symbol: "arrow.left.arrow.right",
                        title: "Your month is looking quiet.",
                        message: "Add your first transaction to start tracking your spending.",
                        actionTitle: "Add transaction"
                    ) {
                        session.showAddTransaction = true
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(grouped, id: \.date) { group in
                            Section {
                                ForEach(group.items, id: \.id) { tx in
                                    Button {
                                        editingTransaction = tx
                                    } label: {
                                        TransactionRow(
                                            title: tx.title,
                                            categoryName: tx.categoryName,
                                            amount: tx.amount,
                                            type: tx.transactionType,
                                            currencyCode: currency
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .listRowBackground(PennyColors.surface)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            pendingDelete = tx
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        Button {
                                            editingTransaction = tx
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .tint(PennyColors.brand)
                                    }
                                    .contextMenu {
                                        Button {
                                            editingTransaction = tx
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        Button(role: .destructive) {
                                            pendingDelete = tx
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            } header: {
                                Text(group.key)
                                    .font(PennyTypography.overline)
                                    .foregroundStyle(PennyColors.textSecondary)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(PennyColors.background.ignoresSafeArea())
            .navigationTitle("Activity")
            .searchable(text: $searchText, prompt: "Search transactions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        session.showAddTransaction = true
                        Haptics.light()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add transaction")
                }
            }
            .sheet(isPresented: Binding(
                get: { editingTransaction != nil },
                set: { if !$0 { editingTransaction = nil } }
            )) {
                if let editingTransaction {
                    AddTransactionView(transaction: editingTransaction)
                }
            }
            .confirmationDialog(
                "Delete transaction?",
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
                Button("Cancel", role: .cancel) {
                    pendingDelete = nil
                }
            } message: {
                if let pendingDelete {
                    Text("Remove “\(pendingDelete.title)” from Activity? This can’t be undone.")
                }
            }
        }
    }

    private var monthSelector: some View {
        HStack {
            Button {
                withAnimation(PennyAnimation.standard) {
                    session.selectedMonth = DateHelpers.addingMonths(-1, to: session.selectedMonth)
                }
                Haptics.selection()
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            Spacer()
            Text(DateHelpers.monthYear(for: session.selectedMonth))
                .font(PennyTypography.cardTitle)
                .foregroundStyle(PennyColors.textPrimary)
            Spacer()
            Button {
                withAnimation(PennyAnimation.standard) {
                    session.selectedMonth = DateHelpers.addingMonths(1, to: session.selectedMonth)
                }
                Haptics.selection()
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
        }
        .foregroundStyle(PennyColors.brand)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PennySpacing.xs) {
                ForEach(ActivityFilter.allCases) { item in
                    FilterChip(title: item.displayName, selected: filter == item) {
                        filter = item
                        Haptics.selection()
                    }
                }
                ForEach(categoriesInMonth, id: \.self) { name in
                    FilterChip(title: name, selected: categoryFilter == name) {
                        categoryFilter = categoryFilter == name ? nil : name
                        Haptics.selection()
                    }
                }
            }
        }
    }
}

enum ActivityFilter: String, CaseIterable, Identifiable {
    case all, income, expense
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .all: return "All"
        case .income: return "Income"
        case .expense: return "Expense"
        }
    }
}

struct FilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PennyTypography.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(selected ? PennyColors.brand : PennyColors.secondarySurface)
                )
                .foregroundStyle(selected ? PennyColors.textOnBrand : PennyColors.textPrimary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Add / Edit Transaction

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query private var settingsList: [UserSettings]

    var transaction: Transaction? = nil

    @State private var amountText = ""
    @State private var type: TransactionType = .expense
    @State private var categoryName = "Food"
    @State private var title = ""
    @State private var note = ""
    @State private var date = Date.now
    @State private var showValidation = false
    @State private var didLoadExisting = false
    @FocusState private var amountFocused: Bool

    private var currency: String { settingsList.first?.currencyCode ?? "CAD" }
    private var isEditing: Bool { transaction != nil }

    private var parsedAmount: Decimal? {
        Decimal.from(amountText)
    }

    private var canSave: Bool {
        guard let amount = parsedAmount, amount > 0 else { return false }
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PennySpacing.lg) {
                    amountField
                    typePicker
                    categoryGrid
                    descriptionField
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: PennySpacing.radiusMd).fill(PennyColors.surface))
                    noteField
                }
                .padding(PennySpacing.screenPadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PennyColors.background.ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit Transaction" : "Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
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
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                loadExistingIfNeeded()
                if !isEditing {
                    if categories.contains(where: { $0.name == "Food" }) {
                        categoryName = "Food"
                    } else if let first = categories.first {
                        categoryName = first.name
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        amountFocused = true
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func loadExistingIfNeeded() {
        guard !didLoadExisting, let transaction else { return }
        didLoadExisting = true
        amountText = NSDecimalNumber(decimal: transaction.amount).stringValue
        type = transaction.transactionType
        categoryName = transaction.categoryName
        title = transaction.title
        note = transaction.note
        date = transaction.date
    }

    private var amountField: some View {
        VStack(spacing: PennySpacing.xs) {
            Text(type == .expense ? "Expense" : "Income")
                .font(PennyTypography.caption)
                .foregroundStyle(PennyColors.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(currencySymbol)
                    .font(PennyTypography.largeAmount)
                    .foregroundStyle(PennyColors.textSecondary)
                TextField("0.00", text: $amountText)
                    .font(PennyTypography.heroAmount)
                    .monospacedDigit()
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(type == .income ? PennyColors.income : PennyColors.textPrimary)
            }
            if showValidation, parsedAmount == nil || (parsedAmount ?? 0) <= 0 {
                Text("Enter a valid amount.")
                    .font(PennyTypography.caption)
                    .foregroundStyle(PennyColors.expense)
            }
        }
        .padding(PennySpacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: PennySpacing.radiusXl, style: .continuous)
                .fill(PennyColors.surface)
        )
    }

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.currencySymbol ?? "$"
    }

    private var typePicker: some View {
        HStack(spacing: PennySpacing.xs) {
            ForEach(TransactionType.allCases) { item in
                Button {
                    withAnimation(PennyAnimation.prefer(PennyAnimation.quick, reduceMotion: reduceMotion)) {
                        type = item
                        if item == .income { categoryName = "Income" }
                        else if categoryName == "Income" { categoryName = categories.first?.name ?? "Other" }
                    }
                    Haptics.selection()
                } label: {
                    Text(item.displayName)
                        .font(PennyTypography.bodyEmphasized)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: PennySpacing.radiusMd, style: .continuous)
                                .fill(type == item ? PennyColors.brand : PennyColors.secondarySurface)
                        )
                        .foregroundStyle(type == item ? PennyColors.textOnBrand : PennyColors.textPrimary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: PennySpacing.sm) {
            Text("Category")
                .font(PennyTypography.caption)
                .foregroundStyle(PennyColors.textSecondary)
            let items: [(name: String, icon: String, colour: String)] = {
                if type == .income {
                    return [("Income", "banknote.fill", "income")]
                }
                return categories.map { ($0.name, $0.icon, $0.colourIdentifier) }
            }()
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                ForEach(items, id: \.name) { item in
                    Button {
                        categoryName = item.name
                        Haptics.selection()
                    } label: {
                        VStack(spacing: 8) {
                            CategoryIcon(icon: item.icon, colourIdentifier: item.colour, size: 36)
                            Text(item.name)
                                .font(PennyTypography.footnote)
                                .foregroundStyle(PennyColors.textPrimary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: PennySpacing.radiusMd, style: .continuous)
                                .strokeBorder(categoryName == item.name ? PennyColors.brand : Color.clear, lineWidth: 2)
                                .background(
                                    RoundedRectangle(cornerRadius: PennySpacing.radiusMd, style: .continuous)
                                        .fill(PennyColors.surface)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(categoryName == item.name ? .isSelected : [])
                }
            }
        }
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: PennySpacing.xs) {
            Text("Description")
                .font(PennyTypography.caption)
                .foregroundStyle(PennyColors.textSecondary)
            TextField("What was this for?", text: $title)
                .padding()
                .background(RoundedRectangle(cornerRadius: PennySpacing.radiusMd).fill(PennyColors.surface))
            if showValidation, title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Add a short description.")
                    .font(PennyTypography.caption)
                    .foregroundStyle(PennyColors.expense)
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: PennySpacing.xs) {
            Text("Note (optional)")
                .font(PennyTypography.caption)
                .foregroundStyle(PennyColors.textSecondary)
            TextField("Add a note", text: $note, axis: .vertical)
                .lineLimit(3...5)
                .padding()
                .background(RoundedRectangle(cornerRadius: PennySpacing.radiusMd).fill(PennyColors.surface))
        }
    }

    private func save() {
        Keyboard.dismiss()
        amountFocused = false
        guard let amount = parsedAmount, amount > 0 else {
            showValidation = true
            return
        }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showValidation = true
            return
        }

        if let transaction {
            transaction.title = trimmed
            transaction.amount = amount
            transaction.date = date
            transaction.transactionType = type
            transaction.categoryName = categoryName
            transaction.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            let tx = Transaction(
                title: trimmed,
                amount: amount,
                date: date,
                transactionType: type,
                categoryName: categoryName,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            modelContext.insert(tx)
        }

        do {
            try modelContext.save()
            Haptics.success()
            dismiss()
        } catch {
            showValidation = true
        }
    }
}

#Preview("Activity") {
    ActivityView()
        .environment(AppSession())
        .modelContainer(PennyPersistence.previewContainer())
}

#Preview("Add Transaction") {
    AddTransactionView()
        .modelContainer(PennyPersistence.previewContainer())
}
