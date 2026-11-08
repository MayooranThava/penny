import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import Penny

/// Private mode acceptance checks. The suite is serialized because it reads
/// `WidgetSnapshotStore` and the shared App Group flag through the test suite.
@Suite("Private mode", .serialized, .isolatedTestResources)
struct PrivateModeTests {
    private let enUS = Locale(identifier: "en_US")

    @Test("Masked totals are five dots with no currency and no digits")
    func maskHidesMagnitude() {
        let samples: [Decimal] = [
            Decimal(string: "0.01")!,
            Decimal(string: "999.35")!,
            Decimal(string: "1234567.89")!,
            Decimal(string: "-1234567.89")!
        ]
        for amount in samples {
            let shown = PrivateAmountLogic.display(
                amount: amount,
                currencyCode: "USD",
                style: .standard,
                isPrivate: true,
                locale: enUS
            )
            #expect(shown == PrivateAmountLogic.mask)
            #expect(shown.count == 5)
            #expect(shown == "●●●●●")
            #expect(!shown.contains("$"))
            #expect(!PrivateAmountLogic.containsDigit(shown))
            let spoken = PrivateAmountLogic.accessibilityText(
                amount: amount,
                currencyCode: "USD",
                style: .standard,
                isPrivate: true,
                locale: enUS
            )
            #expect(spoken == "Hidden amount")
            #expect(!PrivateAmountLogic.containsDigit(spoken))
        }
    }

    @Test("Hero uses five calmer dots and rows use three")
    func calmerDotCounts() {
        let amount = Decimal(string: "3350.40")!
        let hero = PrivateAmountLogic.display(
            amount: amount,
            currencyCode: "CAD",
            style: .standard,
            isPrivate: true,
            site: .homeSafeToSpendHero,
            locale: enUS
        )
        #expect(hero == String(repeating: PrivateAmountLogic.dot, count: 5))
        #expect(hero.count == 5)
        let heroDots = PrivateAmountLogic.dotStyle(for: .homeSafeToSpendHero)
        #expect(heroDots.preferredOpacity == 0.40)
        #expect(heroDots.glyphScale == PrivateAmountLogic.dotCapHeightScale)
        #expect(heroDots.glyphScale < 1)

        let rows: [PrivateTotalSite] = [
            .homeBreakdownIncome,
            .homeBreakdownBills,
            .homeBreakdownDebtPayments,
            .homeBreakdownSpent,
            .homeBreakdownGoals,
            .homeBreakdownSafeToSpend,
            .budgetIncome,
            .budgetPlanned,
            .budgetSpent,
            .budgetRemaining,
            .budgetCategorySpent,
            .budgetCategoryBudgeted,
            .budgetCategoryRemaining,
            .homeIncludesDebtTarget,
            .homeIncludesGoalTarget
        ]
        for site in rows {
            let shown = PrivateAmountLogic.display(
                amount: amount,
                currencyCode: "CAD",
                style: .standard,
                isPrivate: true,
                site: site,
                locale: enUS
            )
            #expect(shown == String(repeating: PrivateAmountLogic.dot, count: 3))
            #expect(shown.count == 3)
            #expect(PrivateAmountLogic.dotStyle(for: site).preferredOpacity == 0.30)
            #expect(PrivateAmountLogic.dotStyle(for: site).glyphScale == PrivateAmountLogic.dotCapHeightScale)
            #expect(!PrivateAmountLogic.containsDigit(shown))
        }
    }

    @Test("A budget category row shows one masked value")
    func categoryRowShowsOneMask() throws {
        let hidden = PrivateAmountLogic.categoryAmountLine(
            spent: "$120.00",
            budgeted: "$400.00",
            isPrivate: true
        )
        #expect(hidden == String(repeating: PrivateAmountLogic.dot, count: 3))
        #expect(!hidden.contains("/"))
        #expect(PrivateAmountLogic.showsPairedCategoryAmounts(isPrivate: true) == false)
        let open = PrivateAmountLogic.categoryAmountLine(
            spent: "$120.00",
            budgeted: "$400.00",
            isPrivate: false
        )
        #expect(open == "$120.00 / $400.00")

        let budget = try source("Penny/Features/Budget/BudgetView.swift")
        let row = try slice(budget, from: "struct CategoryBudgetRow", until: "struct CategoryDetailView")
        #expect(row.contains("showsPairedCategoryAmounts"))
        #expect(row.contains(".budgetCategorySpent"))
        #expect(row.contains(".budgetCategoryBudgeted"))
        let slash = try #require(row.range(of: "Text(\"/\")"))
        let gate = try #require(row.range(of: "showsPairedCategoryAmounts"))
        #expect(gate.lowerBound < slash.lowerBound)
    }

    @Test("Includes amounts are masked when Private mode is on and shown when it is off")
    func includesAmountsFollowPrivateMode() throws {
        let debt = Decimal(string: "600.00")!
        let hiddenDebt = PrivateAmountLogic.displayWithTrailing(
            amount: debt,
            currencyCode: "CAD",
            style: .standard,
            isPrivate: true,
            site: .homeIncludesDebtTarget,
            trailing: PrivateAmountLogic.monthlySuffix,
            locale: enUS
        )
        #expect(hiddenDebt == String(repeating: PrivateAmountLogic.dot, count: 3))
        #expect(!hiddenDebt.contains("/mo"))
        #expect(!PrivateAmountLogic.containsDigit(hiddenDebt))

        let goal = Decimal(string: "769.24")!
        let hiddenGoal = PrivateAmountLogic.displayWithTrailing(
            amount: goal,
            currencyCode: "CAD",
            style: .standard,
            isPrivate: true,
            site: .homeIncludesGoalTarget,
            trailing: PrivateAmountLogic.monthlySuffix,
            locale: enUS
        )
        #expect(hiddenGoal.count == 3)
        #expect(!PrivateAmountLogic.containsDigit(hiddenGoal))
        #expect(!hiddenGoal.contains("/mo"))

        let shownDebt = PrivateAmountLogic.displayWithTrailing(
            amount: debt,
            currencyCode: "CAD",
            style: .standard,
            isPrivate: false,
            site: .homeIncludesDebtTarget,
            trailing: PrivateAmountLogic.monthlySuffix,
            locale: enUS
        )
        #expect(shownDebt.contains("600.00"))
        #expect(shownDebt.hasSuffix("/mo"))

        let shownGoal = PrivateAmountLogic.displayWithTrailing(
            amount: goal,
            currencyCode: "CAD",
            style: .standard,
            isPrivate: false,
            site: .homeIncludesGoalTarget,
            trailing: PrivateAmountLogic.monthlySuffix,
            locale: enUS
        )
        #expect(shownGoal.contains("769.24"))
        #expect(shownGoal.hasSuffix("/mo"))

        let home = try source("Penny/Features/Home/HomeView.swift")
        let debtBlock = try slice(home, from: "Includes debt targets", until: "Includes Plan goal targets")
        #expect(debtBlock.contains("Text(debt.name)"))
        #expect(debtBlock.contains(".homeIncludesDebtTarget"))
        #expect(debtBlock.contains("monthlySuffix"))
        #expect(!debtBlock.contains("MoneyFormatters"))
        let goalBlock = try slice(home, from: "Includes Plan goal targets", until: ".accessibilityElement(children: .combine)")
        #expect(goalBlock.contains("Text(goal.name)"))
        #expect(goalBlock.contains(".homeIncludesGoalTarget"))
        #expect(goalBlock.contains("monthlySuffix"))
        #expect(!goalBlock.contains("MoneyFormatters"))
    }

    @Test("VoiceOver still reads Hidden amount")
    func voiceOverLabelUnchanged() throws {
        let spoken = PrivateAmountLogic.accessibilityText(
            amount: Decimal(string: "600.00")!,
            currencyCode: "CAD",
            style: .standard,
            isPrivate: true,
            locale: enUS
        )
        #expect(spoken == "Hidden amount")
        #expect(spoken == PrivateAmountLogic.hiddenAccessibilityLabel)
        let view = try source("Penny/Components/PrivateAmount.swift")
        let amount = try slice(view, from: "struct PrivateAmount", until: "struct PrivateModeEyeButton")
        #expect(amount.contains("accessibilityText"))
        #expect(amount.contains(".accessibilityLabel(spoken)"))
        #expect(!amount.contains("secure"))
        #expect(!amount.contains("encrypted"))
    }

    @Test("Widget masks stay five dots at the original opacity")
    func widgetMaskUnchanged() throws {
        let widgetSites: [PrivateTotalSite] = [
            .widgetSafeToSpend,
            .widgetLockScreenSafeToSpend,
            .widgetMonthlyBudgetSpent,
            .widgetMonthlyBudgetPlanned,
            .widgetSavingsGoal,
            .widgetReminderSafeToSpend
        ]
        for site in widgetSites {
            let dots = PrivateAmountLogic.dotStyle(for: site)
            #expect(dots.text == "●●●●●")
            #expect(dots.count == 5)
            #expect(dots.preferredOpacity == 0.60)
            #expect(dots.glyphScale == 1)
        }
        let lock = WidgetPrivateDisplay.safeToSpend(
            amount: Decimal(string: "3350.40")!,
            currencyCode: "CAD",
            isPrivate: true,
            site: .widgetLockScreenSafeToSpend,
            locale: enUS
        )
        #expect(lock == PrivateAmountLogic.mask)
        let files = [
            "PennyWidgets/SafeToSpendWidget.swift",
            "PennyWidgets/MonthlyBudgetWidget.swift",
            "PennyWidgets/SavingsGoalWidget.swift",
            "PennyWidgets/UpcomingReminderWidget.swift",
            "PennyWidgets/UpcomingBillsWidget.swift"
        ]
        for relative in files {
            let text = try source(relative)
            #expect(!text.contains("heroDotOpacity"))
            #expect(!text.contains("rowDotOpacity"))
            #expect(!text.contains("rowDotCount"))
            #expect(!text.contains("dotCapHeightScale"))
        }
    }

    @Test("Dots meet 3:1 graphic contrast on card surfaces in Dark and Light")
    func dotContrastOnCardSurfaces() {
        #expect(PrivateAmountLogic.minimumContrast == 3)
        let white = PrivateAmountLogic.SRGB(r: 1, g: 1, b: 1)
        let ink = PennyColors.textPrimary.privateSRGB(.light)
        let lightInk = PennyColors.textPrimary.privateSRGB(.dark)
        let secondaryLight = PennyColors.textSecondary.privateSRGB(.light)
        let secondaryDark = PennyColors.textSecondary.privateSRGB(.dark)
        let incomeLight = PennyColors.income.privateSRGB(.light)
        let incomeDark = PennyColors.income.privateSRGB(.dark)
        let expenseLight = PennyColors.expense.privateSRGB(.light)
        let expenseDark = PennyColors.expense.privateSRGB(.dark)
        let paper = PennyColors.surface.privateSRGB(.light)
        let night = PennyColors.surface.privateSRGB(.dark)
        let theme = AccentTheme.mint
        let heroLight = [theme.heroStartLight.privateSRGB(.light), theme.heroEndLight.privateSRGB(.light)]
        let heroDark = [theme.heroStartDark.privateSRGB(.dark), theme.heroEndDark.privateSRGB(.dark)]

        #expect(abs(paper.r - 1) < 0.02 && abs(paper.g - 1) < 0.02 && abs(paper.b - 1) < 0.02)
        #expect(abs(night.r - 0.12) < 0.02 && abs(night.g - 0.13) < 0.02 && abs(night.b - 0.15) < 0.02)

        let heroDots = PrivateAmountLogic.dotStyle(for: .homeSafeToSpendHero)
        let rowDots = PrivateAmountLogic.dotStyle(for: .budgetCategorySpent)
        let surfaces: [(PrivateAmountLogic.DotStyle, PrivateAmountLogic.SRGB, [PrivateAmountLogic.SRGB])] = [
            (heroDots, white, heroLight),
            (heroDots, white, heroDark),
            (rowDots, white, heroLight),
            (rowDots, white, heroDark),
            (rowDots, ink, [paper]),
            (rowDots, lightInk, [night]),
            (rowDots, secondaryLight, [paper]),
            (rowDots, secondaryDark, [night]),
            (rowDots, incomeLight, [paper]),
            (rowDots, incomeDark, [night]),
            (rowDots, expenseLight, [paper]),
            (rowDots, expenseDark, [night])
        ]
        for (dots, amount, backgrounds) in surfaces {
            let style = PrivateAmountLogic.maskStyle(
                matching: amount,
                over: backgrounds,
                preferredOpacity: dots.preferredOpacity,
                minimum: PrivateAmountLogic.minimumContrast
            )
            let score = PrivateAmountLogic.minimumContrast(
                of: style.foreground,
                over: backgrounds,
                opacity: style.opacity
            )
            #expect(score >= 3)
            #expect(style.opacity + 0.000_001 >= dots.preferredOpacity)
            if style.opacity > dots.preferredOpacity + 0.011 {
                let lower = style.opacity - 0.01
                let lowerInk = PrivateAmountLogic.foreground(
                    matching: amount,
                    over: backgrounds,
                    opacity: lower,
                    minimum: PrivateAmountLogic.minimumContrast
                )
                let lowerScore = PrivateAmountLogic.minimumContrast(
                    of: lowerInk,
                    over: backgrounds,
                    opacity: lower
                )
                #expect(lowerScore < PrivateAmountLogic.minimumContrast)
            }
        }

        for accent in AccentTheme.allCases {
            for scheme in [ColorScheme.light, ColorScheme.dark] {
                let stops = scheme == .dark
                    ? [accent.heroStartDark, accent.heroEndDark]
                    : [accent.heroStartLight, accent.heroEndLight]
                let backgrounds = stops.map { $0.privateSRGB(scheme) }
                for site in [PrivateTotalSite.homeSafeToSpendHero, .homeBreakdownIncome] {
                    let dots = PrivateAmountLogic.dotStyle(for: site)
                    let style = PrivateAmountLogic.maskStyle(
                        matching: white,
                        over: backgrounds,
                        preferredOpacity: dots.preferredOpacity,
                        minimum: PrivateAmountLogic.minimumContrast
                    )
                    let score = PrivateAmountLogic.minimumContrast(
                        of: style.foreground,
                        over: backgrounds,
                        opacity: style.opacity
                    )
                    #expect(score >= PrivateAmountLogic.minimumContrast)
                }
            }
        }
    }

    @Test("Private mode off shows the formatted amount to the cent")
    func showsExactAmountWhenOff() {
        let amount = Decimal(string: "999.35")!
        let shown = PrivateAmountLogic.display(
            amount: amount,
            currencyCode: "USD",
            style: .standard,
            isPrivate: false,
            locale: enUS
        )
        #expect(shown == MoneyFormatters.string(from: amount, currencyCode: "USD", locale: enUS))
        #expect(shown.contains("999.35"))
    }

    @Test("Individual transaction and bill rows are not masked")
    func individualsStayVisible() throws {
        let amount = Decimal(string: "19.99")!
        let shown = PrivateAmountLogic.display(
            amount: amount,
            currencyCode: "CAD",
            style: .signed(showPlus: false),
            isPrivate: true,
            isTotal: false,
            locale: enUS
        )
        #expect(shown.contains("19.99"))
        #expect(shown != PrivateAmountLogic.mask)

        let components = try source("Penny/Components/PennyComponents.swift")
        let transaction = try slice(components, from: "struct TransactionRow", until: "struct RingProgressView")
        let bill = try slice(components, from: "struct BillRow", until: "struct TransactionRow")
        #expect(!transaction.contains("PrivateAmount"))
        #expect(transaction.contains("MoneyFormatters.signed"))
        #expect(!bill.contains("PrivateAmount"))
        #expect(bill.contains("MoneyText"))
    }

    @Test("Insight sentences keep the words and mask only the amount")
    func insightSentencesMaskTotals() throws {
        let over = MoneyFormatters.string(from: Decimal(string: "42.50")!, currencyCode: "CAD", locale: enUS)
        let presented = PrivateInsightText.present(
            title: "You're \(over) over your Food budget.",
            detail: "Based on the budget and spending you entered for this category.",
            includesTotal: true,
            isPrivate: true
        )
        #expect(presented.title.contains("You're"))
        #expect(presented.title.contains("over your Food budget."))
        #expect(presented.title.contains(PrivateAmountLogic.mask))
        #expect(!PrivateAmountLogic.containsDigit(presented.title))
        #expect(presented.accessibilityTitle.contains("Hidden amount"))
        #expect(presented.accessibilityTitle.contains("Food"))

        let insights = InsightEngine.generate(
            from: InsightEngine.Input(
                categorySpends: [
                    .init(name: "Food", current: 140, previous: 80, budgeted: 100)
                ],
                upcomingBillsWithinDays: [("Internet", 2, Decimal(string: "79.99")!)],
                goals: [],
                monthlyBudget: 0,
                spentSoFar: 0,
                dayOfMonth: 1,
                daysInMonth: 30,
                currencyCode: "CAD",
                now: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            limit: 8
        )
        let overBudget = try #require(insights.first { $0.title.contains("over your Food budget") })
        #expect(overBudget.includesTotal)
        let bill = try #require(insights.first { $0.title.contains("Internet") })
        #expect(bill.includesTotal == false)
        let masked = PrivateInsightText.present(
            title: overBudget.title,
            detail: overBudget.detail,
            includesTotal: overBudget.includesTotal,
            isPrivate: true
        )
        #expect(masked.title.contains("Food"))
        #expect(!PrivateAmountLogic.containsDigit(masked.title))
        let open = PrivateInsightText.present(
            title: bill.title,
            detail: bill.detail,
            includesTotal: bill.includesTotal,
            isPrivate: true
        )
        #expect(open.detail.contains("79.99"))
    }

    @Test("PDF and CSV exports keep real numbers when private mode is on")
    func exportsIgnorePrivateMode() throws {
        let defaults = try #require(UserDefaults(suiteName: WidgetSnapshotStore.activeDefaultsSuite))
        PrivateModeDefaults.setEnabled(true, in: defaults)
        #expect(PrivateModeStore.isEnabled)

        let lines = MonthlySummaryPDFService.summaryLines(
            for: MonthlySummaryPDFService.Input(
                monthLabel: "October",
                currencyCode: "USD",
                displayName: "Alex",
                income: Decimal(string: "5000")!,
                spent: Decimal(string: "999.35")!,
                billsMonthly: Decimal(string: "1750")!,
                safeToSpend: Decimal(string: "1234.56")!,
                categoryLines: [],
                billLines: []
            ),
            locale: enUS
        )
        let pdf = lines.joined(separator: "\n")
        #expect(pdf.contains("999.35"))
        #expect(pdf.contains("1,234.56"))
        #expect(!pdf.contains(PrivateAmountLogic.mask))

        let csv = CSVExportLogic.makeCSV(rows: [
            .init(
                date: Date(timeIntervalSince1970: 1_700_000_000),
                title: "Rent",
                amount: Decimal(string: "1234.56")!,
                type: "expense",
                category: "Housing",
                note: "",
                merchant: "",
                source: ""
            )
        ])
        #expect(csv.contains("1234.56"))
        #expect(!csv.contains(PrivateAmountLogic.mask))
    }

    @Test("The flag lives in the App Group suite, defaults off, and survives a new reader")
    @MainActor
    func persistenceSurvivesRelaunch() throws {
        let suite = WidgetSnapshotStore.activeDefaultsSuite
        #expect(suite.hasPrefix("PennyTests."))
        let defaults = try #require(UserDefaults(suiteName: suite))
        #expect(PrivateModeDefaults.isEnabled(in: defaults) == false)
        #expect(defaults.object(forKey: PrivateModeDefaults.key) == nil)
        #expect(PrivateModeDefaults.key == "penny.privateMode.enabled")

        let settings = try source("Penny/Models/Models.swift")
        let userSettings = try slice(settings, from: "final class UserSettings", until: "enum AppAppearance")
        #expect(!userSettings.contains("privateMode"))

        let controllerSource = try source("Penny/Services/PrivateModeController.swift")
        #expect(controllerSource.contains("WidgetSnapshotStore.activeDefaultsSuite"))
        #expect(!controllerSource.contains("import SwiftData"))
        #expect(!controllerSource.contains("modelContext"))
        #expect(!controllerSource.contains("WidgetSnapshotPublisher"))
        #expect(!controllerSource.contains(".save("))

        let eye = PrivateModeController(reloader: RecordingPrivateReloader())
        eye.toggle()
        let relaunch = UserDefaults(suiteName: suite)
        #expect(relaunch?.bool(forKey: PrivateModeDefaults.key) == true)
        let next = PrivateModeController(reloader: RecordingPrivateReloader())
        #expect(next.isEnabled)
    }

    @Test("The eye, Settings, and the shortcut share one flag")
    @MainActor
    func controlsShareOneFlag() async throws {
        let suite = WidgetSnapshotStore.activeDefaultsSuite
        let defaults = try #require(UserDefaults(suiteName: suite))
        let eye = PrivateModeController(reloader: RecordingPrivateReloader())
        eye.toggle()
        #expect(PrivateModeDefaults.isEnabled(in: defaults))

        let settings = PrivateModeController(reloader: RecordingPrivateReloader())
        settings.setEnabled(false)
        #expect(PrivateModeDefaults.isEnabled(in: defaults) == false)

        _ = try await TogglePrivateModeIntent().perform()
        #expect(PrivateModeDefaults.isEnabled(in: defaults))
        let afterShortcut = PrivateModeController(reloader: RecordingPrivateReloader())
        #expect(afterShortcut.isEnabled)
        #expect(PrivateAmountLogic.shortcutTitle == "Toggle Penny private mode")
        #expect(PrivateAmountLogic.eyeAccessibilityLabel(isPrivate: false) == "Hide totals")
        #expect(PrivateAmountLogic.eyeAccessibilityLabel(isPrivate: true) == "Show totals")
    }

    @Test("Widgets mask totals and keep each upcoming bill amount")
    func widgetDisplay() {
        let safe = WidgetPrivateDisplay.safeToSpend(
            amount: Decimal(string: "3350.40")!,
            currencyCode: "CAD",
            isPrivate: true,
            site: .widgetSafeToSpend,
            locale: enUS
        )
        let lock = WidgetPrivateDisplay.safeToSpend(
            amount: Decimal(string: "3350.40")!,
            currencyCode: "CAD",
            isPrivate: true,
            site: .widgetLockScreenSafeToSpend,
            locale: enUS
        )
        let spent = WidgetPrivateDisplay.budget(
            amount: 1240,
            currencyCode: "CAD",
            isPrivate: true,
            site: .widgetMonthlyBudgetSpent,
            locale: enUS
        )
        let goal = WidgetPrivateDisplay.goalDetail(
            "$6,200 of $10,000",
            isPrivate: true,
            site: .widgetSavingsGoal
        )
        let bill = WidgetPrivateDisplay.upcomingBillDetail("$1,750 · Oct 1", isPrivate: true)
        #expect(safe == PrivateAmountLogic.mask)
        #expect(lock == PrivateAmountLogic.mask)
        #expect(spent == PrivateAmountLogic.mask)
        #expect(!PrivateAmountLogic.containsDigit(goal))
        #expect(bill.contains("1,750"))
        #expect(bill.contains("Oct 1"))
    }

    @Test("Leaving the foreground suppresses the crossfade and re-reads the flag")
    @MainActor
    func appSwitcherMasksBeforeSnapshot() {
        let controller = PrivateModeController(reloader: RecordingPrivateReloader())
        controller.setEnabled(true)
        controller.noteScenePhase(.inactive)
        #expect(controller.isEnabled)
        #expect(controller.animationsSuppressed)
        #expect(PrivateAmountLogic.crossfadeSeconds(reduceMotion: false, animationsSuppressed: true) == 0)
        controller.noteScenePhase(.active)
        #expect(!controller.animationsSuppressed)
        #expect(PrivateAmountLogic.crossfadeSeconds(reduceMotion: false, animationsSuppressed: false) == 0.2)
    }

    @Test("Bill reminders keep the original wording when private mode is off")
    func billReminderMatchesPreviousCopy() throws {
        let open = PennyNotificationContent.billReminder(
            name: "Internet",
            individualAmount: nil,
            billsTotal: nil,
            currencyCode: "EUR",
            isPrivate: false,
            locale: enUS
        )
        #expect(open.title == "Upcoming bill")
        #expect(open.body == "Internet is due soon.")

        let service = try source("Penny/Services/NotificationService.swift")
        #expect(!service.contains("currencyCode: \"CAD\""))
        #expect(service.contains("currencyCode: currencyCode"))
        #expect(!service.contains("notifyWalletConnectedIfAuthorized"))
        #expect(!service.contains("Connected ✓"))
        let setup = try source("Penny/Features/Settings/ApplePayCaptureSetupView.swift")
        #expect(!setup.contains("notifyWalletConnectedIfAuthorized"))
    }

    @Test("Every hidden total is built through a PrivateAmount site")
    func everyTotalSiteIsWired() throws {
        var combined = ""
        for folder in ["Penny", "PennyWidgets"] {
            let root = repoRoot().appendingPathComponent(folder, isDirectory: true)
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
                Issue.record("Could not read \(folder)")
                continue
            }
            for case let url as URL in enumerator where url.pathExtension == "swift" {
                combined += (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                combined += "\n"
            }
        }
        var missing: [String] = []
        for site in PrivateTotalSite.allCases where !combined.contains(".\(site.rawValue)") {
            missing.append(site.rawValue)
        }
        #expect(missing.isEmpty, "Totals with no PrivateAmount site: \(missing.joined(separator: ", "))")
    }

    @Test("The eye button is its own VoiceOver control on the Safe to Spend card")
    func eyeButtonIsItsOwnAccessibilityElement() throws {
        let home = try source("Penny/Features/Home/HomeView.swift")
        let card = try slice(home, from: "private var safeToSpendCardBody", until: "private func breakdownRow")
        let combine = try #require(card.range(of: ".accessibilityElement(children: .combine)"))
        let beforeCombine = String(card[..<combine.lowerBound])
        let afterCombine = String(card[combine.upperBound...])
        #expect(!beforeCombine.contains("PrivateModeEyeButton"))
        #expect(afterCombine.contains("PrivateModeEyeButton"))
        #expect(afterCombine.contains(".accessibilityElement(children: .contain)"))

        let button = try slice(
            try source("Penny/Components/PrivateAmount.swift"),
            from: "struct PrivateModeEyeButton",
            until: "struct PrivateInsightBlock"
        )
        #expect(button.contains("Button"))
        #expect(button.contains(".accessibilityAddTraits(.isButton)"))
        #expect(button.contains("eyeAccessibilityLabel"))
        #expect(PrivateAmountLogic.eyeAccessibilityLabel(isPrivate: false) == "Hide totals")
        #expect(PrivateAmountLogic.eyeAccessibilityLabel(isPrivate: true) == "Show totals")
    }

    @Test("Widget timelines keep real snapshot numbers and mask them at render")
    func widgetsMaskFromTheFlagAtRender() throws {
        let defaults = try #require(UserDefaults(suiteName: WidgetSnapshotStore.activeDefaultsSuite))
        PrivateModeDefaults.setEnabled(true, in: defaults)
        let snapshot = WidgetSnapshotStore.Snapshot.placeholder
        WidgetSnapshotStore.save(snapshot)
        #expect(snapshot.safeToSpend > 0)
        let shown = WidgetPrivateDisplay.safeToSpend(
            amount: snapshot.safeToSpend,
            currencyCode: snapshot.currencyCode,
            isPrivate: PrivateModeStore.isEnabled,
            site: .widgetSafeToSpend,
            locale: enUS
        )
        #expect(shown == PrivateAmountLogic.mask)
        #expect(PrivateModeStore.isEnabled)
        let stored = try #require(defaults.data(forKey: WidgetSnapshotStore.snapshotKey))
        #expect(String(decoding: stored, as: UTF8.self).contains("3350"))

        let totalWidgets = [
            "PennyWidgets/SafeToSpendWidget.swift",
            "PennyWidgets/MonthlyBudgetWidget.swift",
            "PennyWidgets/SavingsGoalWidget.swift",
            "PennyWidgets/UpcomingReminderWidget.swift"
        ]
        for relative in totalWidgets {
            let source = try source(relative)
            #expect(source.contains("PrivateModeStore.record.masksWidgetTotals()"))
            if let view = source.range(of: "WidgetView") {
                let provider = String(source[..<view.lowerBound])
                #expect(!provider.contains("MoneyFormatters"))
                #expect(!provider.contains("PrivateAmountLogic.display"))
            }
        }
        let bills = try source("PennyWidgets/UpcomingBillsWidget.swift")
        #expect(bills.contains("upcomingBillDetail"))
        #expect(bills.contains("PrivateModeStore.record.masksWidgetBills()"))
    }

    @Test("Fifty quick toggles reload once and do not save SwiftData")
    @MainActor
    func fiftyTogglesDoNotTouchData() async throws {
        let snapshot = WidgetSnapshotStore.Snapshot.placeholder
        WidgetSnapshotStore.save(snapshot)
        let defaults = try #require(UserDefaults(suiteName: WidgetSnapshotStore.activeDefaultsSuite))
        let before = try #require(defaults.data(forKey: WidgetSnapshotStore.snapshotKey))
        #expect(String(decoding: before, as: UTF8.self).contains("3350"))

        let container = try PennyPersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let containerSaves = PennyDataAccessCounter()
        let token = try observeContainerSaves(of: context, counter: containerSaves)
        defer { NotificationCenter.default.removeObserver(token) }

        context.insert(Transaction(
            title: "Coffee",
            amount: Decimal(string: "4.75")!,
            transactionType: .expense,
            categoryName: "Food"
        ))
        let probe = PennyDataAccessCounter()
        let reloader = RecordingPrivateReloader()
        let controller = PrivateModeController(reloader: reloader)
        controller.reloadCoalescer.debounce = 0.05

        PennyDataAccessProbe.$counter.withValue(probe) {
            #expect(context.saveOrSurfaceError())
        }
        let proofDeadline = Date().addingTimeInterval(1)
        while containerSaves.saves < 1 && Date() < proofDeadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(containerSaves.saves >= 1)
        #expect(probe.saves >= 1)
        containerSaves.saves = 0
        probe.saves = 0
        probe.fetches = 0

        PennyDataAccessProbe.$counter.withValue(probe) {
            for _ in 0..<50 {
                controller.toggle()
            }
        }
        #expect(reloader.calls.isEmpty)
        // An even number of toggles from the default off ends off.
        #expect(controller.isEnabled == false)
        #expect(PrivateModeDefaults.isEnabled(in: defaults) == false)
        try await Task.sleep(nanoseconds: 400_000_000)

        #expect(probe.saves == 0)
        #expect(probe.fetches == 0)
        #expect(containerSaves.saves == 0)
        let after = try #require(defaults.data(forKey: WidgetSnapshotStore.snapshotKey))
        #expect(after == before)
        #expect(reloader.calls.count == 1)
        #expect(reloader.calls.count <= 3)
        #expect(reloader.calls.allSatisfy { $0 == PrivateWidgetKinds.totalAndUpcomingBills })
        #expect(reloader.calls.allSatisfy { $0.contains(PrivateWidgetKinds.upcomingBills) })
        #expect(!PrivateWidgetKinds.totalShowing.contains(PrivateWidgetKinds.upcomingBills))
    }

    @MainActor
    private func observeContainerSaves(
        of context: ModelContext,
        counter: PennyDataAccessCounter
    ) throws -> NSObjectProtocol {
        guard #available(iOS 18, *) else {
            throw PrivateModeTestError.missingMarker("ModelContext.didSave")
        }
        return NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: context,
            queue: .main
        ) { _ in
            counter.saves += 1
        }
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ relative: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(relative), encoding: .utf8)
    }

    private func slice(_ text: String, from start: String, until end: String) throws -> String {
        guard let startRange = text.range(of: start) else {
            throw PrivateModeTestError.missingMarker(start)
        }
        let tail = text[startRange.lowerBound...]
        guard let endRange = tail.range(of: end) else {
            throw PrivateModeTestError.missingMarker(end)
        }
        return String(tail[..<endRange.lowerBound])
    }
}

@Suite("Private mode amount types", .serialized, .isolatedTestResources)
struct PrivateModeAmountTypeTests {
    @Test("v1.2 and v1.3 fixtures keep Private mode and every amount")
    @MainActor
    func upgradeFixturesKeepPrivateModeAndAmounts() throws {
        let names = [
            "Penny-v1.2-private-on",
            "Penny-v1.2-private-off",
            "Penny-v1.3-private-on",
            "Penny-v1.3-private-off"
        ]
        for name in names {
            let fixture = try PrivateModeUpgradeFixture.load(named: name)
            #expect(name.contains(fixture.marketingVersion))
            let defaults = try #require(UserDefaults(suiteName: WidgetSnapshotStore.activeDefaultsSuite))
            defaults.removeObject(forKey: PrivateModeStorage.settingsKey)
            defaults.set(fixture.privateModeEnabled, forKey: PrivateModeDefaults.key)

            let url = try upgradeStoreURL("\(name).store")
            try fixture.writeStore(at: url)
            let expectedTotal = fixture.homeSafeToSpend
            let expectedTransactionTotal = fixture.transactionAmounts.reduce(Decimal(0), +)
            let expectedBillTotal = fixture.billAmounts.reduce(Decimal(0), +)

            let container = try PennyPersistence.makeContainer(at: url)
            let context = ModelContext(container)
            let transactions = try context.fetch(FetchDescriptor<Transaction>())
            let bills = try context.fetch(FetchDescriptor<RecurringBill>())
            let debts = try context.fetch(FetchDescriptor<Debt>())
            let settings = try #require(context.fetch(FetchDescriptor<UserSettings>()).first)

            let storedTransactions = transactions.sorted { $0.title < $1.title }
            let storedBills = bills.sorted { $0.name < $1.name }
            let expectedBills = fixture.bills.sorted { ($0.name ?? "") < ($1.name ?? "") }
            #expect(storedTransactions.map(\.amount) == fixture.transactionAmounts.sorted())
            #expect(storedTransactions.reduce(Decimal(0)) { $0 + $1.amount } == expectedTransactionTotal)
            #expect(storedBills.map(\.amount) == expectedBills.map { Decimal(string: $0.amount)! })
            #expect(storedBills.map(\.isActive) == expectedBills.map { $0.active ?? true })
            #expect(bills.reduce(Decimal(0)) { $0 + $1.amount } == expectedBillTotal)
            #expect(debts.first?.plannedMonthlyPayment == fixture.debtPayment)
            #expect(settings.monthlyIncome == fixture.income)
            #expect(settings.plannedMonthlySavings == fixture.plannedSavings)

            WidgetSnapshotPublisher.publish(
                transactions: transactions,
                categories: [],
                bills: bills,
                debts: debts,
                goals: [],
                settings: settings,
                month: PrivateModeUpgradeFixture.sampleDate
            )
            let snapshot = try #require(WidgetSnapshotStore.load())
            #expect(snapshot.safeToSpend == expectedTotal)
            let inactive = fixture.bills.filter { !$0.active }.reduce(Decimal(0)) { $0 + $1.amount }
            #expect(snapshot.safeToSpend != expectedTotal - inactive)

            let migrated = PrivateModeStorage.load(from: defaults)
            #expect(migrated.isEnabled == fixture.privateModeEnabled)
            #expect(migrated.visibility == .hidden)
            #expect(migrated.upgradeNotePending == fixture.privateModeEnabled)
            let shown = PrivateModeStorage.acknowledgeUpgradeNote(in: defaults)
            #expect(shown.upgradeNotePending == false)
            #expect(PrivateModeStorage.load(from: defaults).isEnabled == fixture.privateModeEnabled)
            #expect(snapshot.safeToSpend == expectedTotal)
        }
    }

    @Test("A fresh install never shows the upgrade note")
    func freshInstallHidesNote() {
        let suite = "PennyTests.PrivateFresh.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let fresh = PrivateModeStorage.load(from: defaults)
        #expect(fresh == .fresh)
        #expect(fresh.isEnabled == false)
        #expect(fresh.upgradeNotePending == false)
        #expect(fresh.visibility == .hidden)
        #expect(PrivateModeStorage.upgradeNote == "Private mode now also hides transaction and bill amounts on screen. You can change this in Settings.")
    }

    @Test("Each toggle hides only its amount type")
    func togglesAreIndependent() {
        var record = PrivateModeRecord.fresh
        record.isEnabled = true
        record.visibility = .hidden
        #expect(record.masks(.totals))
        #expect(record.masks(.transactions))
        #expect(record.masks(.bills))
        #expect(record.masks(.widgets))

        record.visibility.hideTransactions = false
        #expect(!record.masks(.transactions))
        #expect(record.masks(.bills))
        #expect(record.masks(.totals))

        record.isEnabled = false
        #expect(!record.masks(.transactions))
        #expect(!record.masks(.bills))
        #expect(!record.masks(.totals))
        #expect(!record.masks(.widgets))
    }

    @Test("Exports show the same totals Home uses while Private mode is on")
    func exportsMatchHomeTotals() {
        var record = PrivateModeRecord.fresh
        record.isEnabled = true
        record.visibility = .hidden
        #expect(record.masks(.transactions))
        #expect(record.masks(.totals))
        let income = Decimal(string: "4500.50")!
        let coffee = Decimal(string: "7.15")!
        let phone = Decimal(string: "64.20")!
        let hydro = Decimal(string: "48.75")!
        let debt = Decimal(string: "40.00")!
        let savings = Decimal(string: "200.25")!
        let committed = FinanceCalculator.totalMonthlyCommitted(
            billAmountsAndRecurrence: [(phone, .monthly, true), (hydro, .monthly, false)],
            debtPayments: [debt]
        )
        let home = FinanceCalculator.safeToSpend(
            monthlyIncome: income,
            recurringCommitted: committed,
            discretionarySpent: coffee,
            plannedSavings: savings
        )
        #expect(home == income - phone - debt - coffee - savings)
        let locale = Locale(identifier: "en_CA")
        let lines = MonthlySummaryPDFService.summaryLines(for: .init(
            monthLabel: "October",
            currencyCode: "CAD",
            displayName: "Avery",
            income: income,
            spent: coffee,
            billsMonthly: phone,
            debtMonthly: debt,
            safeToSpend: home,
            categoryLines: [],
            billLines: [("Phone", phone), ("Hydro", hydro)]
        ), locale: locale)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains(MoneyFormatters.string(from: home, currencyCode: "CAD", locale: locale)))
        #expect(joined.contains(MoneyFormatters.string(from: income, currencyCode: "CAD", locale: locale)))
        #expect(joined.contains(MoneyFormatters.string(from: coffee, currencyCode: "CAD", locale: locale)))
        let csv = CSVExportLogic.makeCSV(rows: [
            .init(
                date: PrivateModeUpgradeFixture.sampleDate,
                title: "Coffee",
                amount: coffee,
                type: "expense",
                category: "Food",
                note: "",
                merchant: "",
                source: "manual"
            )
        ])
        #expect(csv.contains(CSVExportLogic.formatAmount(coffee)))
        #expect(!joined.contains(PrivateAmountLogic.mask))
    }

    @Test("Turning Private mode on reloads Upcoming Bills and the total widgets")
    func enablingReloadsUpcomingBills() async throws {
        let reloader = RecordingPrivateReloader()
        let controller = PrivateModeController(reloader: reloader)
        controller.reloadCoalescer.debounce = 0.05
        controller.setEnabled(true)
        try await Task.sleep(nanoseconds: 400_000_000)
        let kinds = try #require(reloader.calls.first)
        #expect(kinds == PrivateWidgetKinds.totalAndUpcomingBills)
        #expect(kinds.contains(PrivateWidgetKinds.upcomingBills))
        for kind in PrivateWidgetKinds.totalShowing {
            #expect(kinds.contains(kind))
        }
    }

    @Test("A bill toggle reloads totals and Upcoming Bills, and nothing else does extra work")
    func widgetReloadTargetsAffectedKinds() async throws {
        let reloader = RecordingPrivateReloader()
        let controller = PrivateModeController(reloader: reloader)
        controller.reloadCoalescer.debounce = 0.05
        controller.setEnabled(true)
        try await Task.sleep(nanoseconds: 400_000_000)
        controller.setHidden(.bills, false)
        try await Task.sleep(nanoseconds: 400_000_000)
        let last = try #require(reloader.calls.last)
        #expect(last == PrivateWidgetReloadCoalescer.widgetKinds(affectedBy: .bills))
        #expect(last.contains(PrivateWidgetKinds.upcomingBills))
        #expect(last.contains(PrivateWidgetKinds.safeToSpend))
        #expect(PrivateWidgetReloadCoalescer.widgetKinds(affectedBy: .transactions).isEmpty)
    }

    @Test("Private mode copy hides amounts on screen and avoids banned words")
    func wordingHidesAmountsOnScreen() {
        let approvedNote = "Private mode now also hides transaction and bill amounts on screen. You can change this in Settings."
        #expect(PrivateModeStorage.upgradeNote == approvedNote)
        let copy = [
            PrivateModeStorage.upgradeNote,
            PrivateModeStorage.settingsFooter,
            PrivateModeStorage.nothingHiddenFooter,
            PrivateModeStorage.amountsStillShowFootnote
        ]
        let phraseExceptions: Set<String> = [
            PrivateModeStorage.nothingHiddenFooter,
            PrivateModeStorage.amountsStillShowFootnote
        ]
        let banned = ["secure", "protected", "safe", "encrypted", "forever", "lifetime"]
        for line in copy {
            if !phraseExceptions.contains(line) {
                #expect(line.localizedCaseInsensitiveContains("amounts on screen"))
            }
            let lowered = line.lowercased()
            for word in banned {
                #expect(!lowered.contains(word))
            }
        }
    }

    @Test("Legal's asterisk line shows under the Private mode switches")
    func footnoteShowsUnderTheSwitches() throws {
        #expect(PrivateModeStorage.amountsStillShowFootnote == "*Amounts still show when you add or edit an entry, and in exports.")
        let source = try String(
            contentsOf: repoFile("Penny/Features/Settings/SettingsView.swift"),
            encoding: .utf8
        )
        guard let viewStart = source.range(of: "struct PrivateModeSettingsView") else {
            Issue.record("Private mode settings view is missing")
            return
        }
        let view = source[viewStart.lowerBound...]
        let switches = try #require(view.range(of: "toggle(\"Widgets\""))
        let footnote = try #require(view.range(of: "PrivateModeStorage.amountsStillShowFootnote"))
        #expect(switches.upperBound < footnote.lowerBound)
    }
}

private struct PrivateModeUpgradeFixture: Decodable {
    struct Row: Decodable {
        var id: String
        var title: String?
        var name: String?
        var amount: String
        var category: String?
        var active: Bool?
    }

    var marketingVersion: String
    var privateModeEnabled: Bool
    var income: String
    var plannedSavings: String
    var currencyCode: String
    var displayName: String
    var debtPayment: String
    var transactions: [Row]
    var bills: [Row]

    static let sampleDate = Date(timeIntervalSince1970: 1_759_276_800)

    static func load(named name: String) throws -> PrivateModeUpgradeFixture {
        let bundle = Bundle(for: MigrationFixtureAnchor.self)
        let url = try #require(
            bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
            "Missing bundled fixture \(name).json"
        )
        return try JSONDecoder().decode(PrivateModeUpgradeFixture.self, from: Data(contentsOf: url))
    }

    var transactionAmounts: [Decimal] { transactions.map { Decimal(string: $0.amount)! } }
    var billAmounts: [Decimal] { bills.map { Decimal(string: $0.amount)! } }
    var incomeAmount: Decimal { Decimal(string: income)! }
    var plannedSavingsAmount: Decimal { Decimal(string: plannedSavings)! }
    var debtPaymentAmount: Decimal { Decimal(string: debtPayment)! }

    var homeSafeToSpend: Decimal {
        let activeBills = bills.filter { $0.active == true }.map { (Decimal(string: $0.amount)!, BillRecurrence.monthly, true) }
        let committed = FinanceCalculator.totalMonthlyCommitted(
            billAmountsAndRecurrence: activeBills,
            debtPayments: [debtPaymentAmount]
        )
        let spent = transactions.reduce(Decimal(0)) { $0 + Decimal(string: $1.amount)! }
        return FinanceCalculator.safeToSpend(
            monthlyIncome: incomeAmount,
            recurringCommitted: committed,
            discretionarySpent: spent,
            plannedSavings: plannedSavingsAmount
        )
    }

    @MainActor
    func writeStore(at url: URL) throws {
        let schema = Schema(versionedSchema: PennySchemaV1.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(url: url)])
        let context = ModelContext(container)
        let date = Self.sampleDate
        for row in transactions {
            context.insert(Transaction(
                id: UUID(uuidString: row.id)!,
                title: row.title ?? "Transaction",
                amount: Decimal(string: row.amount)!,
                date: date,
                transactionType: .expense,
                categoryName: row.category ?? "Food",
                createdAt: date
            ))
        }
        for row in bills {
            context.insert(RecurringBill(
                id: UUID(uuidString: row.id)!,
                name: row.name ?? "Bill",
                amount: Decimal(string: row.amount)!,
                dueDay: 12,
                categoryName: "Bills",
                nextDueDate: date,
                startDate: date,
                isActive: row.active ?? true,
                paidCycleKey: row.active == false ? "2026-10" : ""
            ))
        }
        context.insert(Debt(
            name: "Visa",
            originalBalance: Decimal(string: "500.00")!,
            currentBalance: Decimal(string: "120.40")!,
            interestRate: Decimal(string: "18.50")!,
            minimumPayment: Decimal(string: "20.00")!,
            plannedMonthlyPayment: debtPaymentAmount
        ))
        context.insert(UserSettings(
            currencyCode: currencyCode,
            monthlyIncome: incomeAmount,
            plannedMonthlySavings: plannedSavingsAmount,
            hasCompletedOnboarding: true,
            displayName: displayName,
            hasCompletedWalkthrough: true
        ))
        try context.save()
    }
}

private func upgradeStoreURL(_ name: String) throws -> URL {
    let directoryName = try #require(
        PennyPersistence.activeIsolatedStoreName,
        "Upgrade tests need an isolated store directory"
    )
    let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent(directoryName, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appendingPathComponent(name)
}

private func repoFile(_ relative: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent(relative)
}

private final class RecordingPrivateReloader: PrivateWidgetReloading, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [[String]] = []

    var calls: [[String]] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func reload(kinds: [String]) {
        lock.lock()
        stored.append(kinds)
        lock.unlock()
    }
}

private enum PrivateModeTestError: Error {
    case missingMarker(String)
}
