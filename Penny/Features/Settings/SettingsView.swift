import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var store
    @Query private var settingsList: [UserSettings]
    @Query(filter: #Predicate<RecurringBill> { $0.isActive }) private var bills: [RecurringBill]
    @Query(sort: \FinancialAccount.sortOrder) private var accounts: [FinancialAccount]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var confirmReset = false
    @State private var confirmDelete = false
    @State private var incomeText = ""
    @State private var nameText = ""
    @State private var editingAccount: FinancialAccount?
    @State private var accountBalanceText = ""
    @State private var showPaywall = false
    @State private var showApplePaySetup = false
    @State private var exportShareURL: URL?
    @State private var exportErrorMessage: String?
    @State private var themeRefreshToken = 0

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
                applePaySection
                proSection
                dataSection
                aboutSection
                legalSection
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(PennyColors.background.ignoresSafeArea())
            .id(themeRefreshToken)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showApplePaySetup) { ApplePayCaptureSetupView() }
            .sheet(isPresented: Binding(
                get: { exportShareURL != nil },
                set: { if !$0 { exportShareURL = nil } }
            )) {
                if let exportShareURL {
                    ActivityShareSheet(items: [exportShareURL])
                }
            }
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
                Text("This permanently removes transactions, budgets, goals, bills, and settings on this device. Export a CSV first if you want a copy — the developer cannot recover deleted data.")
            }
            .alert(
                "Export unavailable",
                isPresented: Binding(
                    get: { exportErrorMessage != nil },
                    set: { if !$0 { exportErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { exportErrorMessage = nil }
            } message: {
                Text(exportErrorMessage ?? "")
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
                        Text("Wallet tap capture")
                            .font(PennyTypography.bodyEmphasized)
                            .foregroundStyle(PennyColors.textPrimary)
                        Text(
                            settings?.applePayCaptureConfigured == true
                                ? "Instructions saved · reopen anytime"
                                : "Optional · view Shortcuts instructions"
                        )
                        .font(PennyTypography.caption)
                        .foregroundStyle(PennyColors.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Text(settings?.applePayCaptureConfigured == true ? "On" : "Optional")
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
            Text("Optional")
        } footer: {
            Text("Penny works fully without this. Friends can use the AI prompt in Settings (or mayooranthava.github.io/penny/wallet-capture.html). Apple still requires each person to approve a Wallet automation once.")
        }
    }

    private var appearanceSection: some View {
        Section {
            Picker("Appearance", selection: appearanceBinding) {
                ForEach(AppAppearance.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: PennySpacing.sm) {
                Text("Accent theme")
                    .font(PennyTypography.caption)
                    .foregroundStyle(PennyColors.textSecondary)
                HStack(spacing: PennySpacing.sm) {
                    ForEach(AccentTheme.allCases) { theme in
                        accentThemeButton(theme)
                    }
                }
                if !store.isPro {
                    Text("Mint is free. Other accents unlock with Penny Pro.")
                        .font(PennyTypography.caption)
                        .foregroundStyle(PennyColors.textTertiary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Appearance")
        }
    }

    private func accentThemeButton(_ theme: AccentTheme) -> some View {
        let selected = AccentTheme.effective(
            storedRaw: settings?.accentThemeRaw,
            isPro: store.isPro
        ) == theme
        let locked = theme.requiresPro && !store.isPro

        return Button {
            if locked {
                Haptics.light()
                showPaywall = true
                return
            }
            settings?.accentTheme = theme
            try? modelContext.save()
            AccentTheme.active = theme
            themeRefreshToken += 1
            Haptics.selection()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color(light: theme.brandLight, dark: theme.brandDark))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Circle()
                                .strokeBorder(selected ? PennyColors.textPrimary : Color.clear, lineWidth: 2)
                        }
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.white)
                    }
                }
                Text(theme.displayName)
                    .font(.caption2)
                    .foregroundStyle(selected ? PennyColors.textPrimary : PennyColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.displayName) theme\(locked ? ", requires Penny Pro" : "")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Bill reminders", isOn: remindersBinding)
        }
    }

    private var dataSection: some View {
        Section {
            Button {
                exportTransactions()
            } label: {
                Label(
                    store.isPro ? "Export transactions (CSV)" : "Export transactions (Pro)",
                    systemImage: store.isPro ? "square.and.arrow.up" : "sparkles"
                )
            }
            Button("Reset demo data") { confirmReset = true }
            Button("Delete all data", role: .destructive) { confirmDelete = true }
        } header: {
            Text("Data")
        } footer: {
            Text("CSV export is a Penny Pro feature. Export before deleting if you want a copy. Device backups (if enabled) may still retain app data under Apple’s terms.")
        }
    }

    private var proSection: some View {
        Section("Penny Pro") {
            if store.isPro {
                Label("Penny Pro is active", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(PennyColors.brand)
                Text("Thanks for supporting Penny — Pro features are unlocked.")
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
            Text("Personal finance planning that stays on your device. Free to use; Penny Pro Lifetime is an optional one-time unlock.")
                .font(PennyTypography.caption)
                .foregroundStyle(PennyColors.textSecondary)
        }
    }

    private var legalSection: some View {
        Section {
            Text("Penny keeps your financial information on this device. App updates keep your data. Deleting the app, or using Reset/Delete in Data, clears local data. Optional Wallet tap capture uses Shortcuts on your iPhone — amounts stay local. Penny does not connect to banks or send analytics to the developer. Widgets may show a local summary snapshot via an App Group.")
                .font(PennyTypography.caption)
                .foregroundStyle(PennyColors.textSecondary)
            Text("Figures marked with \(LegalCopy.asterisk) are estimates from your entries — not bank balances or financial advice. Full details are in the Terms of Use.")
                .font(PennyTypography.caption)
                .foregroundStyle(PennyColors.textSecondary)
            Link("Privacy Policy", destination: PennyAppInfo.privacyPolicyURL)
            Link("Terms of Use", destination: PennyAppInfo.termsOfUseURL)
            Link("Support", destination: PennyAppInfo.supportURL)
        } header: {
            Text("Legal & privacy")
        }
    }

    private func exportTransactions() {
        guard store.isPro else {
            Haptics.light()
            showPaywall = true
            return
        }
        do {
            exportShareURL = try CSVExportService.exportFile(transactions: Array(transactions))
            Haptics.success()
        } catch {
            exportErrorMessage = error.localizedDescription
            Haptics.warning()
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
        ("chart.line.uptrend.xyaxis", "Longer-range forecasts (6 & 12 months)"),
        ("square.and.arrow.up", "CSV export of your transactions"),
        ("paintpalette.fill", "Custom accent themes")
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
            Text("One-time unlock for unlimited goals, longer forecasts, CSV export, and accent themes.")
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
                    if let detail = store.lastErrorMessage, !detail.isEmpty {
                        Text(detail)
                            .font(PennyTypography.caption)
                            .foregroundStyle(PennyColors.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    Text("If this continues, check your connection and try again later. Restore purchases if you already bought Penny Pro.")
                        .font(PennyTypography.caption)
                        .foregroundStyle(PennyColors.textTertiary)
                        .multilineTextAlignment(.center)
                    Button("Try again") { Task { await store.loadProducts() } }
                        .buttonStyle(.pennySecondary)
                }
            }
        } else if let lifetime = store.lifetimeProduct {
            productButton(lifetime)
        } else {
            VStack(spacing: PennySpacing.sm) {
                Text("Penny Pro Lifetime isn’t available on the App Store yet.")
                    .font(PennyTypography.callout)
                    .foregroundStyle(PennyColors.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Try again") { Task { await store.loadProducts() } }
                    .buttonStyle(.pennySecondary)
            }
        }
    }

    private func productButton(_ product: Product) -> some View {
        Button {
            Task {
                let ok = await store.purchase(product)
                if ok { dismiss() }
            }
        } label: {
            VStack(spacing: 2) {
                Text(product.displayName.isEmpty ? "Penny Pro — Lifetime" : product.displayName)
                    .font(PennyTypography.bodyEmphasized)
                Text("\(product.displayPrice) once · yours forever")
                    .font(PennyTypography.caption)
            }
        }
        .buttonStyle(.pennyPrimary)
        .disabled(store.purchaseInFlight)
    }

    private var footer: some View {
        VStack(spacing: PennySpacing.sm) {
            Button("Restore purchases") { Task { await store.restore() } }
                .font(PennyTypography.callout)
                .foregroundStyle(PennyColors.brand)
            Text("One-time purchase. Payment is charged to your Apple Account at confirmation. Restore purchases anytime if you reinstall.")
                .font(PennyTypography.caption)
                .foregroundStyle(PennyColors.textTertiary)
                .multilineTextAlignment(.center)
            HStack(spacing: PennySpacing.md) {
                Link("Privacy Policy", destination: PennyAppInfo.privacyPolicyURL)
                Link("Terms of Use", destination: PennyAppInfo.termsOfUseURL)
            }
            .font(PennyTypography.caption)
        }
        .padding(.top, PennySpacing.sm)
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
