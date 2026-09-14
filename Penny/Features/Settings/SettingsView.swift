import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [UserSettings]
    @Query(filter: #Predicate<RecurringBill> { $0.isActive }) private var bills: [RecurringBill]
    @Query(sort: \FinancialAccount.sortOrder) private var accounts: [FinancialAccount]

    @State private var confirmReset = false
    @State private var confirmDelete = false
    @State private var incomeText = ""
    @State private var nameText = ""
    @State private var editingAccount: FinancialAccount?
    @State private var accountBalanceText = ""

    private var settings: UserSettings? { settingsList.first }

    var body: some View {
        NavigationStack {
            List {
                profileSection
                currencySection
                incomeSection
                accountsSection
                appearanceSection
                notificationsSection
                dataSection
                aboutSection
                privacySection
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(PennyColors.background.ignoresSafeArea())
            .pennyKeyboardDone()
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                if let income = settings?.monthlyIncome {
                    incomeText = NSDecimalNumber(decimal: income).stringValue
                }
                nameText = settings?.displayName ?? ""
            }
            .alert("Reset demo data?", isPresented: $confirmReset) {
                Button("Reset", role: .destructive) { resetDemo() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This replaces all local data with the sample household.")
            }
            .alert("Delete all data?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) { deleteAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes transactions, budgets, goals, bills, and settings on this device.")
            }
            .alert(
                "Update balance",
                isPresented: Binding(
                    get: { editingAccount != nil },
                    set: { if !$0 { editingAccount = nil } }
                )
            ) {
                TextField("Balance", text: $accountBalanceText)
                    .keyboardType(.decimalPad)
                Button("Save") {
                    Keyboard.dismiss()
                    if let editingAccount, let value = Decimal.from(accountBalanceText) {
                        editingAccount.balance = value
                        try? modelContext.save()
                        Haptics.success()
                    }
                    editingAccount = nil
                }
                Button("Cancel", role: .cancel) {
                    editingAccount = nil
                }
            } message: {
                if let editingAccount {
                    Text("Set the current balance for \(editingAccount.name).")
                }
            }
        }
    }

    private var profileSection: some View {
        Section("Profile") {
            HStack {
                TextField("Your name", text: $nameText)
                    .textContentType(.name)
                    .autocorrectionDisabled()
                Button("Save") {
                    Keyboard.dismiss()
                    let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    settings?.displayName = trimmed
                    nameText = trimmed
                    try? modelContext.save()
                    Haptics.success()
                }
                .disabled(settings == nil)
            }
            Text("Home greets you with “Welcome back” when a name is set.")
                .font(PennyTypography.caption)
                .foregroundStyle(PennyColors.textSecondary)
        }
    }

    private var currencySection: some View {
        Section("Currency") {
            Picker("Currency", selection: currencyBinding) {
                ForEach(SupportedCurrency.allCases) { currency in
                    Text("\(currency.flag) \(currency.rawValue) — \(currency.displayName)")
                        .tag(currency.rawValue)
                }
            }
        }
    }

    private var incomeSection: some View {
        Section("Monthly take-home") {
            HStack {
                TextField("Income", text: $incomeText)
                    .keyboardType(.decimalPad)
                Button("Save") {
                    Keyboard.dismiss()
                    if let value = Decimal.from(incomeText), let settings {
                        settings.monthlyIncome = value
                        try? modelContext.save()
                        Haptics.success()
                    }
                }
            }
            if let settings {
                HStack {
                    Text("Planned monthly savings")
                    Spacer()
                    Text(MoneyFormatters.compact(from: settings.plannedMonthlySavings, currencyCode: settings.currencyCode))
                        .foregroundStyle(PennyColors.textSecondary)
                        .monospacedDigit()
                }
                Slider(
                    value: Binding(
                        get: { NSDecimalNumber(decimal: settings.plannedMonthlySavings).doubleValue },
                        set: {
                            settings.plannedMonthlySavings = Decimal($0).rounded(scale: 0)
                            try? modelContext.save()
                        }
                    ),
                    in: 0...5_000,
                    step: 50
                )
                .tint(PennyColors.brand)
            }
        }
    }

    private var accountsSection: some View {
        Section {
            if accounts.isEmpty {
                Text("No accounts yet. Reset demo data or start fresh to create defaults.")
                    .font(PennyTypography.caption)
                    .foregroundStyle(PennyColors.textSecondary)
            } else {
                ForEach(accounts, id: \.id) { account in
                    Button {
                        editingAccount = account
                        accountBalanceText = NSDecimalNumber(decimal: account.balance).stringValue
                    } label: {
                        HStack {
                            Label(account.name, systemImage: account.accountType.icon)
                                .foregroundStyle(PennyColors.textPrimary)
                            Spacer()
                            Text(
                                MoneyFormatters.compact(
                                    from: account.balance,
                                    currencyCode: settings?.currencyCode ?? "CAD"
                                )
                            )
                            .foregroundStyle(PennyColors.textSecondary)
                            .monospacedDigit()
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundStyle(PennyColors.textTertiary)
                        }
                    }
                }
            }
        } header: {
            Text("Accounts")
        } footer: {
            Text("Balances stay on this device and power Forecast. Updating an app build does not erase them.")
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Appearance", selection: appearanceBinding) {
                ForEach(AppAppearance.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Bill reminders", isOn: remindersBinding)
        }
    }

    private var dataSection: some View {
        Section("Data") {
            Button("Reset demo data") { confirmReset = true }
            Button("Delete all data", role: .destructive) { confirmDelete = true }
        }
    }

    private var aboutSection: some View {
        Section("About Penny") {
            LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
            LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
            Text("Beautiful personal finance without an expensive subscription.")
                .font(PennyTypography.caption)
                .foregroundStyle(PennyColors.textSecondary)
            NavigationLink("Penny Pro (coming soon)") {
                PennyProInfoView()
            }
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            Text("Penny keeps your financial information on this device. This prototype does not sync to the cloud, connect to banks, or send analytics. App updates keep your local data unless you choose Reset or Delete.")
                .font(PennyTypography.caption)
                .foregroundStyle(PennyColors.textSecondary)
        }
    }

    private var currencyBinding: Binding<String> {
        Binding(
            get: { settings?.currencyCode ?? "CAD" },
            set: { newValue in
                settings?.currencyCode = newValue
                try? modelContext.save()
            }
        )
    }

    private var appearanceBinding: Binding<AppAppearance> {
        Binding(
            get: { settings?.appearance ?? .system },
            set: { newValue in
                settings?.appearance = newValue
                try? modelContext.save()
            }
        )
    }

    private var remindersBinding: Binding<Bool> {
        Binding(
            get: { settings?.billRemindersEnabled ?? true },
            set: { newValue in
                settings?.billRemindersEnabled = newValue
                try? modelContext.save()
                Task {
                    await NotificationService.shared.refreshBillReminders(bills: bills, enabled: newValue)
                }
            }
        )
    }

    private func resetDemo() {
        do {
            try DemoDataService.resetAll(in: modelContext)
            Haptics.success()
        } catch {
            Haptics.warning()
        }
    }

    private func deleteAll() {
        do {
            try DemoDataService.deleteAll(in: modelContext)
            try DemoDataService.seedFresh(
                in: modelContext,
                currencyCode: "CAD",
                monthlyIncome: 0,
                replaceExisting: true
            )
            let descriptor = FetchDescriptor<UserSettings>()
            if let settings = try modelContext.fetch(descriptor).first {
                settings.hasCompletedOnboarding = false
                try modelContext.save()
            }
            Haptics.warning()
        } catch {
            Haptics.warning()
        }
    }
}

struct PennyProInfoView: View {
    var body: some View {
        List {
            Section {
                Text("Penny Free covers everyday budgeting. A future Penny Pro lifetime unlock may include advanced forecasts, unlimited goals, debt planner depth, CSV export, widgets, and iCloud sync — without a recurring subscription.")
                    .font(PennyTypography.callout)
            }
            Section("Potential Pro features") {
                Label("Advanced forecasts", systemImage: "chart.line.uptrend.xyaxis")
                Label("Unlimited savings goals", systemImage: "target")
                Label("Debt planner", systemImage: "creditcard")
                Label("Advanced insights", systemImage: "lightbulb")
                Label("CSV export", systemImage: "square.and.arrow.up")
                Label("Widgets", systemImage: "rectangle.on.rectangle")
                Label("iCloud sync", systemImage: "icloud")
                Label("Custom themes", systemImage: "paintpalette")
            }
            Section {
                Text("No paywall in this prototype. StoreKit product IDs will be configured later — pricing is never hard-coded.")
                    .font(PennyTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Penny Pro")
    }
}

/// Placeholder StoreKit product catalog for future monetization (no paywall yet).
enum PennyProductCatalog {
    static let lifetimeProductID = "com.penny.app.pro.lifetime"
    static let freeTierGoalLimit = 3
}

#Preview {
    SettingsView()
        .modelContainer(PennyPersistence.previewContainer())
}
