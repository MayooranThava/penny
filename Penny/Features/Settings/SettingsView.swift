import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var store
    @Query private var settingsList: [UserSettings]
    @Query(filter: #Predicate<RecurringBill> { $0.isActive }) private var bills: [RecurringBill]
    @Query(sort: \FinancialAccount.sortOrder) private var accounts: [FinancialAccount]

    @State private var confirmReset = false
    @State private var confirmDelete = false
    @State private var incomeText = ""
    @State private var nameText = ""
    @State private var editingAccount: FinancialAccount?
    @State private var accountBalanceText = ""
    @State private var showPaywall = false
    @State private var showApplePaySetup = false

    private var settings: UserSettings? { settingsList.first }

    var body: some View {
        NavigationStack {
            List {
                profileSection
                currencySection
                incomeSection
                accountsSection
                applePaySection
                appearanceSection
                notificationsSection
                proSection
                dataSection
                aboutSection
                privacySection
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(PennyColors.background.ignoresSafeArea())
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showApplePaySetup) { ApplePayCaptureSetupView() }
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
                    .pennyNoAutoFill()
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
                    .pennyNoAutoFill()
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
                    .pennyNoAutoFill()
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

    private var applePaySection: some View {
        Section {
            Button {
                Haptics.light()
                showApplePaySetup = true
            } label: {
                HStack(spacing: PennySpacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(PennyColors.brandMuted)
                            .frame(width: 36, height: 36)
                        Image(systemName: "wallet.pass.fill")
                            .foregroundStyle(PennyColors.brand)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Capture Apple Pay taps")
                            .font(PennyTypography.bodyEmphasized)
                            .foregroundStyle(PennyColors.textPrimary)
                        Text(
                            settings?.applePayCaptureConfigured == true
                                ? "Automation on · reopen guide anytime"
                                : "Guided setup with copy-paste mapping"
                        )
                        .font(PennyTypography.caption)
                        .foregroundStyle(PennyColors.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Text(settings?.applePayCaptureConfigured == true ? "On" : "Set up")
                        .font(PennyTypography.caption)
                        .foregroundStyle(
                            settings?.applePayCaptureConfigured == true
                                ? PennyColors.brand
                                : PennyColors.textSecondary
                        )
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(PennyColors.textTertiary)
                }
            }
        } header: {
            Text("Apple Pay")
        } footer: {
            Text("One-time Shortcuts setup. Penny opens the builder and gives you copyable field names — Apple still requires you to approve the automation.")
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

    private var proSection: some View {
        Section("Penny Pro") {
            if store.isPro {
                Label("Penny Pro is active", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(PennyColors.brand)
                Text("Thanks for supporting Penny — every Pro feature is unlocked.")
                    .font(PennyTypography.caption)
                    .foregroundStyle(PennyColors.textSecondary)
            } else {
                Button {
                    Haptics.light()
                    showPaywall = true
                } label: {
                    Label("Unlock Penny Pro", systemImage: "sparkles")
                }
                Button("Restore purchases") {
                    Task { await store.restore() }
                }
                .font(PennyTypography.callout)
            }
        }
    }

    private var aboutSection: some View {
        Section("About Penny") {
            LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
            LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
            Text("Beautiful personal finance without an expensive subscription.")
                .font(PennyTypography.caption)
                .foregroundStyle(PennyColors.textSecondary)
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            Text("Penny keeps your financial information on this device. App updates keep your data. Only deleting the app, or using Reset/Delete below, clears it. Optional Apple Pay capture uses Shortcuts on your iPhone — amounts stay local and are never sent to Penny servers. This prototype does not sync to the cloud, connect to banks, or send analytics.")
                .font(PennyTypography.caption)
                .foregroundStyle(PennyColors.textSecondary)
            Link("Privacy Policy", destination: PennyAppInfo.privacyPolicyURL)
            Link("Support", destination: PennyAppInfo.supportURL)
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

/// Penny Pro paywall. Prices and names come from StoreKit; nothing is hard-coded.
struct PaywallView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let benefits: [(String, String)] = [
        ("target", "Unlimited savings goals"),
        ("chart.line.uptrend.xyaxis", "Advanced multi-month forecasts"),
        ("square.and.arrow.up", "CSV export of your transactions"),
        ("icloud.fill", "iCloud sync across your devices"),
        ("paintpalette.fill", "Custom themes & app icons")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PennySpacing.lg) {
                    header
                    benefitList
                    purchaseOptions
                    footer
                }
                .padding(PennySpacing.screenPadding)
            }
            .background(PennyColors.background.ignoresSafeArea())
            .navigationTitle("Penny Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                if store.products.isEmpty { await store.loadProducts() }
            }
            .onChange(of: store.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }

    private var header: some View {
        VStack(spacing: PennySpacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(PennyColors.brand)
                .symbolRenderingMode(.hierarchical)
            Text("Unlock Penny Pro")
                .font(PennyTypography.largeTitle)
                .foregroundStyle(PennyColors.textPrimary)
            Text("Everything in Penny, supercharged — pay once for life or start with a free trial.")
                .font(PennyTypography.callout)
                .foregroundStyle(PennyColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, PennySpacing.md)
    }

    private var benefitList: some View {
        VStack(alignment: .leading, spacing: PennySpacing.sm) {
            ForEach(benefits, id: \.1) { benefit in
                HStack(spacing: PennySpacing.sm) {
                    Image(systemName: benefit.0)
                        .foregroundStyle(PennyColors.brand)
                        .frame(width: 28)
                    Text(benefit.1)
                        .font(PennyTypography.body)
                        .foregroundStyle(PennyColors.textPrimary)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PennySpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PennySpacing.radiusLg, style: .continuous)
                .fill(PennyColors.surface)
        )
    }

    @ViewBuilder
    private var purchaseOptions: some View {
        if store.products.isEmpty {
            if store.isLoadingProducts {
                ProgressView().frame(maxWidth: .infinity).padding()
            } else {
                VStack(spacing: PennySpacing.sm) {
                    Text("Purchases are unavailable right now.")
                        .font(PennyTypography.callout)
                        .foregroundStyle(PennyColors.textSecondary)
                    Button("Try again") { Task { await store.loadProducts() } }
                        .buttonStyle(.pennySecondary)
                }
            }
        } else {
            VStack(spacing: PennySpacing.sm) {
                if let lifetime = store.lifetimeProduct {
                    productButton(lifetime, primary: true)
                }
                if let annual = store.annualProduct {
                    productButton(annual, primary: store.lifetimeProduct == nil)
                }
            }
        }
    }

    private func productButton(_ product: Product, primary: Bool) -> some View {
        Button {
            Task {
                let ok = await store.purchase(product)
                if ok { dismiss() }
            }
        } label: {
            VStack(spacing: 2) {
                Text(product.displayName.isEmpty ? defaultTitle(for: product) : product.displayName)
                    .font(PennyTypography.bodyEmphasized)
                Text(priceLine(for: product))
                    .font(PennyTypography.caption)
            }
        }
        .buttonStyle(primary ? AnyButtonStyle(PennyPrimaryButtonStyle()) : AnyButtonStyle(PennySecondaryButtonStyle()))
        .disabled(store.purchaseInFlight)
    }

    private func defaultTitle(for product: Product) -> String {
        product.id == PennyProductCatalog.lifetimeProductID ? "Penny Pro — Lifetime" : "Penny Pro — Annual"
    }

    private func priceLine(for product: Product) -> String {
        if product.id == PennyProductCatalog.lifetimeProductID {
            return "\(product.displayPrice) once · yours forever"
        }
        if product.subscription?.introductoryOffer?.paymentMode == .freeTrial {
            return "Free trial, then \(product.displayPrice)/year"
        }
        return "\(product.displayPrice)/year"
    }

    private var footer: some View {
        VStack(spacing: PennySpacing.xs) {
            Button("Restore purchases") { Task { await store.restore() } }
                .font(PennyTypography.callout)
                .foregroundStyle(PennyColors.brand)
            Text("Subscriptions renew automatically until cancelled in Settings. The lifetime unlock is a one-time purchase. Payment is charged to your Apple Account.")
                .font(PennyTypography.caption)
                .foregroundStyle(PennyColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, PennySpacing.sm)
    }
}

/// Type-erased button style so a single view can choose primary vs. secondary.
private struct AnyButtonStyle: ButtonStyle {
    private let makeBodyClosure: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        makeBodyClosure = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        makeBodyClosure(configuration)
    }
}

#Preview {
    SettingsView()
        .environment(StoreManager())
        .modelContainer(PennyPersistence.previewContainer())
}

#Preview("Paywall") {
    PaywallView()
        .environment(StoreManager())
}
