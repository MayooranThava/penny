import Foundation
import Testing
@testable import PennyCoreLogic

/// Pre-release smoke suite for vital calculation features.
/// Run via `./scripts/pre-release-sanity.sh` or `swift test` in Tools/PennyCoreLogic.
@Suite("Release Sanity")
struct ReleaseSanityTests {

    // MARK: - Safe to Spend (Home hero)

    @Test("Safe to spend formula and over-budget flag")
    func safeToSpendVital() {
        let ok = FinanceCalculator.safeToSpendBreakdown(
            monthlyIncome: 5_000,
            recurringCommitted: 2_000,
            discretionarySpent: 1_000,
            plannedSavings: 500
        )
        #expect(ok.safeToSpend == 1_500)
        #expect(!ok.isOverBudget)

        let over = FinanceCalculator.safeToSpendBreakdown(
            monthlyIncome: 2_000,
            recurringCommitted: 1_500,
            discretionarySpent: 800,
            plannedSavings: 200
        )
        #expect(over.safeToSpend < 0)
        #expect(over.isOverBudget)
    }

    @Test("Monthly committed combines bill recurrence and debt payments")
    func totalMonthlyCommittedVital() {
        let total = FinanceCalculator.totalMonthlyCommitted(
            billAmountsAndRecurrence: [
                (100, .monthly),
                (50, .weekly),
                (1_200, .yearly)
            ],
            debtPayments: [250, 100]
        )
        // weekly 50 → 216.67; yearly 1200 → 100; monthly 100; debts 350
        let expected = Decimal(100)
            + (Decimal(50) * 52 / 12).rounded(scale: 2)
            + (Decimal(1_200) / 12).rounded(scale: 2)
            + 350
        #expect(total == expected)
    }

    @Test("Monthly equivalent covers all bill recurrences")
    func monthlyEquivalentVital() {
        #expect(FinanceCalculator.monthlyEquivalent(amount: 100, recurrence: .monthly) == 100)
        #expect(FinanceCalculator.monthlyEquivalent(amount: 1_200, recurrence: .yearly) == 100)
        #expect(FinanceCalculator.monthlyEquivalent(amount: 50, recurrence: .weekly) == Decimal(string: "216.67"))
        #expect(FinanceCalculator.monthlyEquivalent(amount: 100, recurrence: .biweekly) == Decimal(string: "216.67"))
    }

    // MARK: - Budgets

    @Test("Budget health thresholds")
    func budgetHealthVital() {
        #expect(FinanceCalculator.budgetHealth(budgeted: 100, spent: 50) == .healthy)
        #expect(FinanceCalculator.budgetHealth(budgeted: 100, spent: 85) == .nearLimit)
        #expect(FinanceCalculator.budgetHealth(budgeted: 100, spent: 101) == .overBudget)
        #expect(FinanceCalculator.budgetHealth(budgeted: 0, spent: 0) == .unset)
        #expect(FinanceCalculator.budgetProgressClamped(budgeted: 100, spent: 200) == 1.0)
    }

    // MARK: - Goals

    @Test("Goal progress and required monthly savings")
    func goalsVital() {
        #expect(FinanceCalculator.goalRemaining(current: 2_000, target: 5_000) == 3_000)
        #expect(FinanceCalculator.goalProgressClamped(current: 6_000, target: 5_000) == 1.0)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let from = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let target = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        let required = FinanceCalculator.requiredMonthlySavings(
            current: 0,
            target: 6_000,
            targetDate: target,
            from: from,
            calendar: calendar
        )
        #expect(required != nil)
        #expect(required! >= 1_000)
    }

    // MARK: - Debt

    @Test("Debt payoff outcomes")
    func debtVital() {
        switch FinanceCalculator.debtPayoff(balance: 1_000, aprPercent: 0, monthlyPayment: 250) {
        case .paidOff(_, let months, let interest):
            #expect(months == 4)
            #expect(interest == 0)
        default:
            Issue.record("Expected zero-APR payoff")
        }

        switch FinanceCalculator.debtPayoff(balance: 5_000, aprPercent: 20, monthlyPayment: 50) {
        case .paymentTooLow:
            break
        default:
            Issue.record("Expected payment-too-low for tiny payment vs interest")
        }

        switch FinanceCalculator.debtPayoff(balance: 0, aprPercent: 19.99, monthlyPayment: 100) {
        case .alreadyPaid:
            break
        default:
            Issue.record("Expected alreadyPaid for zero balance")
        }
    }

    // MARK: - Forecast

    @Test("Balance projection scales with monthly net")
    func forecastVital() {
        let points = FinanceCalculator.projectBalance(
            currentBalance: 1_000,
            monthlyIncome: 500,
            recurringBills: 200,
            averageDiscretionary: 50,
            plannedSavings: 50,
            debtPayments: 0,
            horizons: [0, 1, 3]
        )
        // monthly net = 500 - 200 - 50 - 50 = 200
        #expect(points.count == 3)
        #expect(points.last?.monthsAhead == 3)
        #expect(points.last?.projectedBalance == 1_600)
    }

    // MARK: - Money formatting (Home two-decimal contract)

    @Test("Currency string always shows two decimal places")
    func moneyStringVital() {
        let locale = Locale(identifier: "en_US")
        let whole = MoneyFormatters.string(from: 3_450, currencyCode: "USD", locale: locale)
        #expect(whole.contains("3,450.00") || whole.contains("3450.00"))
        let fractional = MoneyFormatters.string(from: Decimal(string: "235.4")!, currencyCode: "USD", locale: locale)
        #expect(fractional.contains("235.40"))
    }

    @Test("Compact pads fractional cents and omits whole-dollar cents")
    func moneyCompactVital() {
        let locale = Locale(identifier: "en_US")
        let fractional = MoneyFormatters.compact(from: Decimal(string: "235.4")!, currencyCode: "USD", locale: locale)
        #expect(fractional.contains("235.40"))
        let whole = MoneyFormatters.compact(from: 3_450, currencyCode: "USD", locale: locale)
        #expect(whole.contains("3,450") || whole.contains("3450"))
        #expect(!whole.contains(".00"))
    }

    // MARK: - Bill schedule

    @Test("Bill next-due rolls monthly and advances weekly")
    func billScheduleVital() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let from = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20))!

        let monthly = DateHelpers.nextDueDate(dueDay: 15, from: from)
        #expect(calendar.component(.day, from: monthly) == 15)
        #expect(calendar.component(.month, from: monthly) == 10)

        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        let weekly = DateHelpers.nextDueDate(
            startDate: start,
            recurrence: .weekly,
            dueDay: 1,
            from: from
        )
        #expect(weekly >= calendar.startOfDay(for: from))
    }

    // MARK: - Apple Pay capture draft

    @Test("Apple Pay draft rejects bad amounts and builds valid expense")
    func applePayCaptureVital() {
        #expect(
            ApplePayCaptureLogic.makeDraft(
                amount: 0,
                merchant: "Cafe",
                currencyCode: "CAD",
                cardName: nil
            ) == nil
        )

        let draft = ApplePayCaptureLogic.makeDraft(
            amount: 18.5,
            merchant: "Starbucks",
            currencyCode: "CAD",
            cardName: "Apple Card"
        )
        #expect(draft != nil)
        #expect(draft?.title == "Starbucks")
        #expect(draft?.categoryName == "Food")
        #expect(draft?.amount == Decimal(string: "18.50") || draft?.amount == Decimal(string: "18.5"))

        let a = ApplePayCaptureLogic.externalIdentifier(
            amount: Decimal(string: "18.50")!,
            merchant: "Starbucks",
            cardName: "Apple Card",
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let b = ApplePayCaptureLogic.externalIdentifier(
            amount: Decimal(string: "18.50")!,
            merchant: "Starbucks",
            cardName: "Apple Card",
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )
        #expect(a == b)
    }
}
