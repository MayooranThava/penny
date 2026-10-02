import SwiftUI
import SwiftData

/// Add or edit a financial account. Goal funding (earmarks) is a Penny Pro feature.
struct AccountEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreManager.self) private var store

    @Query(sort: \SavingsGoal.createdAt) private var goals: [SavingsGoal]
    @Query private var allocations: [GoalFundingAllocation]
    @Query(sort: \FinancialAccount.sortOrder) private var accounts: [FinancialAccount]
    @Query private var settingsList: [UserSettings]

    var account: FinancialAccount? = nil

    @State private var name = ""
    @State private var accountType: AccountType = .tfsa
    @State private var balanceText = "0"
    @State private var fundingTexts: [UUID: String] = [:]
    @State private var didLoadExisting = false
    @State private var showDeleteConfirm = false
    @State private var showPaywall = false
    @State private var didSuggestNameForType = false

    private var isEditing: Bool { account != nil }
    private var currency: String { settingsList.first?.currencyCode ?? "CAD" }

    private var fundingEligibleGoals: [SavingsGoal] { goals }

    private var parsedBalance: Decimal {
        Decimal.from(balanceText) ?? 0
    }

    /// Allocations on this account toward other goals while editing draft amounts.
    private func otherAllocated(excludingGoal goalID: UUID?) -> Decimal {
        fundingEligibleGoals.reduce(Decimal(0)) { partial, goal in
            if let goalID, goal.id == goalID { return partial }
            let text = fundingTexts[goal.id] ?? "0"
            return partial + max(0, Decimal.from(text) ?? 0)
        }
    }

    private var totalDraftAllocated: Decimal {
        otherAllocated(excludingGoal: nil)
    }

    private var unallocated: Decimal {
        FinanceCalculator.unallocatedBalance(
            accountBalance: max(0, parsedBalance),
            allocatedAmounts: [totalDraftAllocated]
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                accountDetailsSection
                if store.isPro {
                    goalFundingSection
                } else if isEditing, accountType.isGoalFundingEligible {
                    lockedFundingSection
                }
                if isEditing {
                    Section {
                        Button("Delete Account", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "Edit Account" : "New Account")
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
                        .disabled(!canSave)
                }
            }
            .onAppear { loadExistingIfNeeded() }
            .onChange(of: accountType) { _, newType in
                if !isEditing || !didSuggestNameForType {
                    if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || AccountType.allCases.contains(where: { $0.suggestedName == name }) {
                        name = newType.suggestedName
                        didSuggestNameForType = true
                    }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .confirmationDialog(
                "Delete account?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteAccount() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Remove “\(name)” and any goal funding linked to it? This can’t be undone.")
            }
        }
    }

    private var canSave: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, Decimal.from(balanceText) != nil else { return false }
        if store.isPro, accountType.isGoalFundingEligible {
            return totalDraftAllocated <= max(0, parsedBalance) + Decimal(0.001)
        }
        return true
    }

    private var accountDetailsSection: some View {
        Section {
            Picker("Type", selection: $accountType) {
                ForEach(AccountType.allCases) { type in
                    Label(type.displayName, systemImage: type.icon)
                        .tag(type)
                }
            }
            TextField("Name", text: $name)
                .pennyNoAutoFill()
            TextField("Balance", text: $balanceText)
                .keyboardType(.numbersAndPunctuation)
                .pennyNoAutoFill()
        } header: {
            Text("Account")
        } footer: {
            Text("Balances stay on this device. Use TFSA, FHSA, RRSP, or non-registered for tax wrappers.")
        }
    }

    private var goalFundingSection: some View {
        Section {
            if !accountType.isGoalFundingEligible {
                Text("Debt and chequing accounts aren’t typically earmarked for savings goals.")
                    .font(PennyTypography.caption)
                    .foregroundStyle(PennyColors.textSecondary)
            } else if fundingEligibleGoals.isEmpty {
                Text("Add a savings goal in Plan to earmark part of this balance.")
                    .font(PennyTypography.caption)
                    .foregroundStyle(PennyColors.textSecondary)
            } else {
                ForEach(fundingEligibleGoals, id: \.id) { goal in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label(goal.name, systemImage: goal.icon)
                                .font(PennyTypography.bodyEmphasized)
                                .foregroundStyle(PennyColors.textPrimary)
                                .lineLimit(1)
                            Text("Target \(MoneyFormatters.compact(from: goal.targetAmount, currencyCode: currency))")
                                .font(PennyTypography.caption)
                                .foregroundStyle(PennyColors.textTertiary)
                        }
                        Spacer(minLength: PennySpacing.sm)
                        TextField("0", text: fundingBinding(for: goal.id))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 96)
                            .pennyNoAutoFill()
                            .monospacedDigit()
                    }
                }
                HStack {
                    Text("Unallocated")
                        .foregroundStyle(PennyColors.textSecondary)
                    Spacer()
                    Text(MoneyFormatters.compact(from: unallocated, currencyCode: currency))
                        .foregroundStyle(unallocated >= 0 ? PennyColors.textSecondary : PennyColors.overBudget)
                        .monospacedDigit()
                }
                .font(PennyTypography.caption)
            }
        } header: {
            Text("Contribute to goals")
        } footer: {
            Text("Split this balance across long-term goals — for example FHSA toward a down payment, or part of a TFSA toward vacation. Totals can’t exceed the balance.")
        }
    }

    private var lockedFundingSection: some View {
        Section {
            Button {
                Haptics.light()
                showPaywall = true
            } label: {
                Label("Earmark this balance toward goals (Pro)", systemImage: "sparkles")
            }
        } footer: {
            Text("Penny Pro lets you allocate TFSA, FHSA, and other savings toward specific goals.")
        }
    }

    private func fundingBinding(for goalID: UUID) -> Binding<String> {
        Binding(
            get: { fundingTexts[goalID] ?? "0" },
            set: { fundingTexts[goalID] = $0 }
        )
    }

    private func loadExistingIfNeeded() {
        guard !didLoadExisting else { return }
        didLoadExisting = true
        if let account {
            name = account.name
            accountType = account.accountType
            balanceText = NSDecimalNumber(decimal: account.balance).stringValue
            let existing = allocations.filter { $0.accountID == account.id }
            for goal in goals {
                if let row = existing.first(where: { $0.goalID == goal.id }) {
                    fundingTexts[goal.id] = NSDecimalNumber(decimal: row.amount).stringValue
                } else {
                    fundingTexts[goal.id] = ""
                }
            }
        } else {
            name = accountType.suggestedName
            balanceText = "0"
            for goal in goals {
                fundingTexts[goal.id] = ""
            }
        }
    }

    private func save() {
        Keyboard.dismiss()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let balance = Decimal.from(balanceText) else { return }

        let targetAccount: FinancialAccount
        if let account {
            account.name = trimmed
            account.accountType = accountType
            account.balance = balance
            targetAccount = account
        } else {
            let nextOrder = (accounts.map(\.sortOrder).max() ?? -1) + 1
            let created = FinancialAccount(
                name: trimmed,
                accountType: accountType,
                balance: balance,
                sortOrder: nextOrder
            )
            modelContext.insert(created)
            targetAccount = created
        }

        if store.isPro {
            persistFunding(for: targetAccount, balance: balance)
        }

        try? modelContext.save()
        Haptics.success()
        dismiss()
    }

    private func persistFunding(for account: FinancialAccount, balance: Decimal) {
        let existing = allocations.filter { $0.accountID == account.id }
        var used = Decimal(0)

        for goal in fundingEligibleGoals {
            let requested = max(0, Decimal.from(fundingTexts[goal.id] ?? "") ?? 0)
            let applied = FinanceCalculator.clampedAllocation(
                requested: requested,
                accountBalance: max(0, balance),
                otherAllocatedOnAccount: used
            )
            used += applied

            if applied > 0 {
                if let row = existing.first(where: { $0.goalID == goal.id }) {
                    row.amount = applied
                } else {
                    modelContext.insert(
                        GoalFundingAllocation(
                            accountID: account.id,
                            goalID: goal.id,
                            amount: applied
                        )
                    )
                }
            } else if let row = existing.first(where: { $0.goalID == goal.id }) {
                modelContext.delete(row)
            }
        }

        for row in existing where !fundingEligibleGoals.contains(where: { $0.id == row.goalID }) {
            modelContext.delete(row)
        }
    }

    private func deleteAccount() {
        guard let account else { return }
        Keyboard.dismiss()
        for row in allocations where row.accountID == account.id {
            modelContext.delete(row)
        }
        modelContext.delete(account)
        try? modelContext.save()
        Haptics.warning()
        dismiss()
    }
}

#Preview {
    AccountEditorView()
        .environment(StoreManager())
        .modelContainer(PennyPersistence.previewContainer())
}
