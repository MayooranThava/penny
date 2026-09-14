import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var page = 0
    @State private var currency = SupportedCurrency.cad
    @State private var displayName = "Mayooran"
    @State private var incomeText = "6200"
    @State private var isWorking = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                onboardingPage(
                    symbol: "leaf.circle.fill",
                    title: "Meet Penny",
                    message: "Your money, made simple.",
                    detail: "A calm, clear view of what you can spend, save, and plan for — without spreadsheet stress."
                ).tag(0)

                onboardingPage(
                    symbol: "calendar.badge.clock",
                    title: "Plan your month",
                    message: "See your bills, budget, and spending in one place.",
                    detail: "Track where money goes and stay within a budget that actually feels usable."
                ).tag(1)

                onboardingPage(
                    symbol: "chart.line.uptrend.xyaxis.circle.fill",
                    title: "Build your future",
                    message: "Track savings goals and understand where you're headed.",
                    detail: "Lightweight forecasts help you peek a few months ahead — always labeled as estimates."
                ).tag(2)

                setupPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(PennyAnimation.prefer(PennyAnimation.standard, reduceMotion: reduceMotion), value: page)

            bottomControls
                .padding(PennySpacing.screenPadding)
        }
        .background(PennyColors.softBackgroundGradient.ignoresSafeArea())
    }

    private func onboardingPage(symbol: String, title: String, message: String, detail: String) -> some View {
        VStack(spacing: PennySpacing.lg) {
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 72, weight: .medium))
                .foregroundStyle(PennyColors.brand)
                .symbolRenderingMode(.hierarchical)
                .padding(.bottom, PennySpacing.sm)

            Text("Penny")
                .font(PennyTypography.largeTitle)
                .foregroundStyle(PennyColors.brand)

            Text(title)
                .font(PennyTypography.title)
                .foregroundStyle(PennyColors.textPrimary)

            Text(message)
                .font(PennyTypography.sectionHeading)
                .foregroundStyle(PennyColors.textPrimary)
                .multilineTextAlignment(.center)

            Text(detail)
                .font(PennyTypography.callout)
                .foregroundStyle(PennyColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PennySpacing.xl)

            Spacer()
            Spacer()
        }
        .padding()
    }

    private var setupPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PennySpacing.lg) {
                Text("Quick setup")
                    .font(PennyTypography.largeTitle)
                    .foregroundStyle(PennyColors.textPrimary)

                Text("No account needed. Everything stays on this device.")
                    .font(PennyTypography.callout)
                    .foregroundStyle(PennyColors.textSecondary)

                VStack(alignment: .leading, spacing: PennySpacing.sm) {
                    Text("Your name")
                        .font(PennyTypography.caption)
                        .foregroundStyle(PennyColors.textSecondary)
                    TextField("Mayooran", text: $displayName)
                        .textContentType(.name)
                        .font(PennyTypography.sectionHeading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: PennySpacing.radiusMd, style: .continuous)
                                .fill(PennyColors.surface)
                        )
                }

                VStack(alignment: .leading, spacing: PennySpacing.sm) {
                    Text("Currency")
                        .font(PennyTypography.caption)
                        .foregroundStyle(PennyColors.textSecondary)
                    Picker("Currency", selection: $currency) {
                        ForEach(SupportedCurrency.allCases) { item in
                            Text("\(item.flag) \(item.rawValue)").tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: PennySpacing.sm) {
                    Text("Monthly take-home income")
                        .font(PennyTypography.caption)
                        .foregroundStyle(PennyColors.textSecondary)
                    TextField("6200", text: $incomeText)
                        .keyboardType(.decimalPad)
                        .font(PennyTypography.largeAmount)
                        .monospacedDigit()
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: PennySpacing.radiusMd, style: .continuous)
                                .fill(PennyColors.surface)
                        )
                }

                Spacer(minLength: 40)
            }
            .padding(PennySpacing.screenPadding)
        }
    }

    private var bottomControls: some View {
        VStack(spacing: PennySpacing.sm) {
            if page < 3 {
                Button("Continue") {
                    withAnimation(PennyAnimation.prefer(PennyAnimation.standard, reduceMotion: reduceMotion)) {
                        page += 1
                    }
                    Haptics.light()
                }
                .buttonStyle(.pennyPrimary)
            } else {
                Button {
                    finish(useDemo: true)
                } label: {
                    if isWorking {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: PennySpacing.minTapTarget)
                    } else {
                        Text("Explore with sample data")
                    }
                }
                .buttonStyle(.pennyPrimary)
                .disabled(isWorking)

                Button {
                    finish(useDemo: false)
                } label: {
                    Text("Start fresh")
                }
                .buttonStyle(.pennySecondary)
                .disabled(isWorking)
            }
        }
    }

    private func finish(useDemo: Bool) {
        isWorking = true
        let income = Decimal.from(incomeText) ?? (useDemo ? DemoDataService.demoMonthlyIncome : 0)
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if useDemo {
                try DemoDataService.seedDemo(
                    in: modelContext,
                    currencyCode: currency.rawValue,
                    markOnboardingComplete: true
                )
                if let settings = try modelContext.fetch(FetchDescriptor<UserSettings>()).first {
                    settings.monthlyIncome = income > 0 ? income : DemoDataService.demoMonthlyIncome
                    settings.currencyCode = currency.rawValue
                    settings.displayName = name.isEmpty ? "Mayooran" : name
                    settings.hasCompletedOnboarding = true
                    settings.usingDemoData = true
                }
            } else {
                try DemoDataService.seedFresh(
                    in: modelContext,
                    currencyCode: currency.rawValue,
                    monthlyIncome: income,
                    displayName: name
                )
            }
            try modelContext.save()
            Haptics.success()
        } catch {
            Haptics.warning()
            isWorking = false
        }
    }
}

#Preview {
    OnboardingView()
        .modelContainer(PennyPersistence.previewContainer())
}
