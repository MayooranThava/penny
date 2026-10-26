import Foundation
import Testing
@testable import PennyCoreLogic

@Suite("Private mode")
struct PrivateModeLogicTests {
    private let enUS = Locale(identifier: "en_US")
    private let germany = Locale(identifier: "de_DE")

    @Test("Masked totals are five dots and never a currency amount")
    func maskHidesMagnitude() {
        let samples: [Decimal] = [
            Decimal(string: "0.01")!,
            Decimal(string: "999.35")!,
            Decimal(string: "1234567.89")!,
            Decimal(string: "-1234567.89")!,
            Decimal(string: "-0.01")!
        ]
        for amount in samples {
            for style in [PrivateAmountLogic.Style.standard, .compact, .signed(showPlus: true)] {
                let shown = PrivateAmountLogic.display(
                    amount: amount,
                    currencyCode: "USD",
                    style: style,
                    isPrivate: true,
                    locale: enUS
                )
                #expect(shown == PrivateAmountLogic.mask)
                #expect(shown.count == PrivateAmountLogic.maskCount)
                #expect(!shown.contains("$"))
                #expect(!PrivateAmountLogic.containsDigit(shown))
                let spoken = PrivateAmountLogic.accessibilityText(
                    amount: amount,
                    currencyCode: "USD",
                    style: style,
                    isPrivate: true,
                    locale: enUS
                )
                #expect(spoken == "Hidden amount")
                #expect(!PrivateAmountLogic.containsDigit(spoken))
                #expect(!spoken.contains("\(amount)"))
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
        let expected = MoneyFormatters.string(from: amount, currencyCode: "USD", locale: enUS)
        #expect(shown == expected)
        #expect(shown.contains("999.35"))

        let compactWhole = PrivateAmountLogic.display(
            amount: Decimal(string: "1200")!,
            currencyCode: "CAD",
            style: .compact,
            isPrivate: false,
            locale: enUS
        )
        #expect(compactWhole == MoneyFormatters.compact(from: 1200, currencyCode: "CAD", locale: enUS))
        #expect(compactWhole.contains("1,200"))
    }

    @Test("Individual amounts stay visible while private mode is on")
    func individualAmountsStayVisible() {
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
    }

    @Test("Insight sentences keep the words and mask only the amount")
    func insightSentencesMaskTotals() {
        let over = MoneyFormatters.string(from: Decimal(string: "42.50")!, currencyCode: "CAD", locale: enUS)
        let title = "You're \(over) over your Food budget."
        let presented = PrivateInsightText.present(
            title: title,
            detail: "Based on the budget and spending you entered for this category.",
            includesTotal: true,
            isPrivate: true
        )
        #expect(presented.title.contains("You're"))
        #expect(presented.title.contains("over your Food budget."))
        #expect(presented.title.contains(PrivateAmountLogic.mask))
        #expect(!PrivateAmountLogic.containsDigit(presented.title))
        #expect(presented.detail == "Based on the budget and spending you entered for this category.")
        #expect(presented.accessibilityTitle.contains("Hidden amount"))
        #expect(presented.accessibilityTitle.contains("Food"))
        #expect(!presented.accessibilityTitle.contains("42"))

        let bill = PrivateInsightText.present(
            title: "Internet is due in 2 days.",
            detail: MoneyFormatters.string(from: Decimal(string: "79.99")!, currencyCode: "CAD", locale: enUS),
            includesTotal: false,
            isPrivate: true
        )
        #expect(bill.detail.contains("79.99"))
        #expect(!bill.detail.contains(PrivateAmountLogic.mask))
    }

    @Test("CSV export keeps real numbers when private mode is on")
    func csvExportIgnoresPrivateMode() {
        let suite = "PennyCoreLogic.PrivateMode.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        PrivateModeDefaults.setEnabled(true, in: defaults)
        #expect(PrivateModeDefaults.isEnabled(in: defaults))

        let amount = Decimal(string: "1234.56")!
        let csv = CSVExportLogic.makeCSV(rows: [
            .init(
                date: Date(timeIntervalSince1970: 1_700_000_000),
                title: "Rent",
                amount: amount,
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

    @Test("The flag lives in UserDefaults, defaults off, and survives a new reader")
    func persistence() {
        let suite = "PennyCoreLogic.PrivateMode.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(PrivateModeDefaults.isEnabled(in: defaults) == false)
        #expect(defaults.object(forKey: PrivateModeDefaults.key) == nil)

        var session = PrivateModeSession(defaults: defaults)
        #expect(session.isEnabled == false)
        _ = session.toggle()
        #expect(session.isEnabled)

        let relaunch = UserDefaults(suiteName: suite)!
        #expect(PrivateModeDefaults.isEnabled(in: relaunch))
        let next = PrivateModeSession(defaults: relaunch)
        #expect(next.isEnabled)
        #expect(PrivateModeDefaults.key == "penny.privateMode.enabled")
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
        #expect(safe == PrivateAmountLogic.mask)
        let lock = WidgetPrivateDisplay.safeToSpend(
            amount: Decimal(string: "3350.40")!,
            currencyCode: "CAD",
            isPrivate: true,
            site: .widgetLockScreenSafeToSpend,
            locale: enUS
        )
        #expect(lock == PrivateAmountLogic.mask)
        let spent = WidgetPrivateDisplay.budget(
            amount: 1240,
            currencyCode: "CAD",
            isPrivate: true,
            site: .widgetMonthlyBudgetSpent,
            locale: enUS
        )
        let planned = WidgetPrivateDisplay.budget(
            amount: 2000,
            currencyCode: "CAD",
            isPrivate: true,
            site: .widgetMonthlyBudgetPlanned,
            locale: enUS
        )
        #expect(spent == PrivateAmountLogic.mask)
        #expect(planned == PrivateAmountLogic.mask)
        let detail = WidgetPrivateDisplay.goalDetail(
            "$6,200 of $10,000",
            isPrivate: true,
            site: .widgetSavingsGoal
        )
        #expect(detail.contains("of"))
        #expect(!PrivateAmountLogic.containsDigit(detail))
        #expect(detail.contains(PrivateAmountLogic.mask))

        let bill = "$1,750 · Oct 1"
        #expect(WidgetPrivateDisplay.upcomingBillDetail(bill, isPrivate: true) == bill)
        let reminder = WidgetPrivateDisplay.reminderLine(
            amount: Decimal(string: "3350.40")!,
            currencyCode: "CAD",
            isPrivate: true,
            locale: enUS
        )
        #expect(reminder.contains("Safe to spend"))
        #expect(!PrivateAmountLogic.containsDigit(reminder))
    }

    @Test("Fifty quick toggles coalesce into one reload and keep the final flag")
    func fiftyToggles() {
        let suite = "PennyCoreLogic.PrivateMode.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var session = PrivateModeSession(defaults: defaults)
        var coalescer = PrivateWidgetReloadCoalescer()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var changes = 0
        for index in 0..<50 {
            if session.toggle() != nil {
                changes += 1
                coalescer.noteChange(at: start.addingTimeInterval(Double(index) * 0.01))
            }
        }
        #expect(changes == 50)
        // An even number of toggles from the default off ends off.
        #expect(session.isEnabled == false)
        #expect(PrivateModeDefaults.isEnabled(in: defaults) == false)
        let midway = start.addingTimeInterval(0.49)
        #expect(coalescer.takeDueReload(at: midway) == nil)
        let due = start.addingTimeInterval(0.49 + PrivateWidgetReloadCoalescer.defaultDebounce)
        let kinds = coalescer.takeDueReload(at: due)
        #expect(kinds == PrivateWidgetKinds.totalShowing)
        #expect(kinds?.count == PrivateWidgetKinds.totalShowing.count)
        #expect(coalescer.takeDueReload(at: due.addingTimeInterval(5)) == nil)
        #expect(!PrivateWidgetKinds.totalShowing.contains(PrivateWidgetKinds.upcomingBills))
        #expect(kinds?.contains(PrivateWidgetKinds.safeToSpend) == true)
        #expect(kinds?.contains(PrivateWidgetKinds.monthlyBudget) == true)
        #expect(kinds?.contains(PrivateWidgetKinds.savingsGoal) == true)
        #expect(kinds?.contains(PrivateWidgetKinds.upcomingReminder) == true)
    }

    @Test("Bill reminders keep the original wording when private mode is off")
    func billReminderMatchesPreviousCopy() {
        let open = PennyNotificationContent.billReminder(
            name: "Rent",
            individualAmount: nil,
            billsTotal: nil,
            currencyCode: "EUR",
            isPrivate: false,
            locale: enUS
        )
        #expect(open.title == "Upcoming bill")
        #expect(open.body == "Rent is due soon.")

        let hidden = PennyNotificationContent.billReminder(
            name: "Rent",
            individualAmount: Decimal(string: "1750")!,
            billsTotal: Decimal(string: "2400")!,
            currencyCode: "EUR",
            isPrivate: true,
            locale: enUS
        )
        #expect(hidden.title == "Upcoming bill")
        #expect(hidden.body.contains("Rent is due soon."))
        #expect(hidden.body.contains("1,750"))
        #expect(!hidden.body.contains("2,400"))
        #expect(!hidden.body.contains("All bills"))
        let euros = MoneyFormatters.string(from: Decimal(string: "1750")!, currencyCode: "EUR", locale: enUS)
        #expect(hidden.body.contains(euros))
    }

    @Test("Dots at 60% opacity keep 4.5:1 contrast on card surfaces")
    func contrast() {
        let white = PrivateAmountLogic.SRGB(r: 1, g: 1, b: 1)
        let ink = PrivateAmountLogic.SRGB(r: 0.12, g: 0.14, b: 0.16)
        let paper = PrivateAmountLogic.SRGB(r: 0.97, g: 0.96, b: 0.94)
        let night = PrivateAmountLogic.SRGB(r: 0.12, g: 0.13, b: 0.15)
        let lightInk = PrivateAmountLogic.SRGB(r: 0.96, g: 0.96, b: 0.95)
        let samples: [(PrivateAmountLogic.SRGB, [PrivateAmountLogic.SRGB])] = [
            (ink, [paper]),
            (white, [paper]),
            (lightInk, [night]),
            (ink, [night])
        ]
        for (amount, backgrounds) in samples {
            let style = PrivateAmountLogic.maskStyle(matching: amount, over: backgrounds)
            #expect(style.opacity == PrivateAmountLogic.maskOpacity)
            let score = PrivateAmountLogic.minimumContrast(
                of: style.foreground,
                over: backgrounds,
                opacity: style.opacity
            )
            #expect(score >= PrivateAmountLogic.minimumContrast)
        }

        // Mint hero stops cannot both clear 4.5:1, even for solid white. The mask
        // then uses the stronger colour instead of pretending 60% black is enough.
        let hero = [
            PrivateAmountLogic.SRGB(r: 0.10, g: 0.55, b: 0.45),
            PrivateAmountLogic.SRGB(r: 0.08, g: 0.42, b: 0.48)
        ]
        let heroStyle = PrivateAmountLogic.maskStyle(matching: white, over: hero)
        let heroScore = PrivateAmountLogic.minimumContrast(
            of: heroStyle.foreground,
            over: hero,
            opacity: heroStyle.opacity
        )
        let solidWhite = PrivateAmountLogic.minimumContrast(of: white, over: hero, opacity: 1)
        #expect(heroScore + 0.02 >= solidWhite)
    }

    @Test("Dot scale grows with Dynamic Type and is unchanged at the default size")
    func dynamicType() {
        #expect(PrivateAmountLogic.dynamicTypeScale(step: 3) == 1)
        #expect(PrivateAmountLogic.dynamicTypeScale(step: 11) > PrivateAmountLogic.dynamicTypeScale(step: 6))
        #expect(PrivateAmountLogic.dynamicTypeScale(step: 0) < 1)
    }

    @Test("Leaving the foreground suppresses the crossfade while private mode stays on")
    func appSwitcher() {
        let suite = "PennyCoreLogic.PrivateMode.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var session = PrivateModeSession(defaults: defaults)
        _ = session.setEnabled(true)
        session.noteScenePhase(.inactive)
        #expect(session.isEnabled)
        #expect(session.animationsSuppressed)
        #expect(PrivateAmountLogic.crossfadeSeconds(reduceMotion: false, animationsSuppressed: true) == 0)
        #expect(PrivateAmountLogic.crossfadeSeconds(reduceMotion: true, animationsSuppressed: false) == 0)
        #expect(PrivateAmountLogic.crossfadeSeconds(reduceMotion: false, animationsSuppressed: false) == 0.2)
        session.noteScenePhase(.active)
        #expect(!session.animationsSuppressed)
    }

    @Test("Goal pace keeps the monthly contribution and masks the target")
    func goalPace() {
        let sentence = PrivateAmountLogic.goalPaceSentence(
            monthlyRequired: "$200",
            target: "$10,000",
            dateLabel: "June 2027",
            isPrivate: true
        )
        #expect(sentence.contains("About $200/month"))
        #expect(sentence.contains("June 2027"))
        #expect(sentence.contains(PrivateAmountLogic.mask))
        #expect(!sentence.contains("10,000"))
    }

    @Test("German currency sentences mask the amount and keep the words")
    func germanCurrency() {
        let money = MoneyFormatters.string(from: Decimal(string: "42.50")!, currencyCode: "EUR", locale: germany)
        let sentence = "Rest \(money) diesen Monat."
        let masked = PrivateAmountLogic.maskCurrencyAmounts(in: sentence)
        #expect(masked.contains("Rest"))
        #expect(masked.contains("diesen Monat."))
        #expect(masked.contains(PrivateAmountLogic.mask))
        #expect(!PrivateAmountLogic.containsDigit(masked))
    }

    @Test("The eye button names Hide totals or Show totals")
    func eyeButtonLabels() {
        #expect(PrivateAmountLogic.eyeSymbol(isPrivate: false) == "eye")
        #expect(PrivateAmountLogic.eyeSymbol(isPrivate: true) == "eye.slash")
        #expect(PrivateAmountLogic.eyeAccessibilityLabel(isPrivate: false) == "Hide totals")
        #expect(PrivateAmountLogic.eyeAccessibilityLabel(isPrivate: true) == "Show totals")
        #expect(PrivateAmountLogic.shortcutTitle == "Toggle Penny private mode")
    }
}
