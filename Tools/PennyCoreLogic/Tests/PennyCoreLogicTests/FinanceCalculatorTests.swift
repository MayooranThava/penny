import Foundation
import Testing
@testable import PennyCoreLogic

@Suite("FinanceCalculator")
struct FinanceCalculatorTests {

    @Test("Safe to spend subtracts commitments, spending, and savings")
    func safeToSpendBasic() {
        let value = FinanceCalculator.safeToSpend(
            monthlyIncome: 6_200,
            recurringCommitted: 2_522.98,
            discretionarySpent: 1_227,
            plannedSavings: 1_000
        )
        #expect(value == Decimal(string: "1450.02"))
    }

    @Test("Negative safe to spend is preserved (over budget)")
    func safeToSpendNegative() {
        let breakdown = FinanceCalculator.safeToSpendBreakdown(
            monthlyIncome: 3_000,
            recurringCommitted: 2_500,
            discretionarySpent: 800,
            plannedSavings: 500
        )
        #expect(breakdown.safeToSpend == Decimal(-800))
        #expect(breakdown.isOverBudget)
    }

    @Test("Budget remaining and progress")
    func budgetMath() {
        #expect(FinanceCalculator.budgetRemaining(budgeted: 550, spent: 410) == 140)
        #expect(FinanceCalculator.budgetProgress(budgeted: 100, spent: 50) == 0.5)
        #expect(FinanceCalculator.budgetProgressClamped(budgeted: 100, spent: 150) == 1.0)
        #expect(FinanceCalculator.budgetHealth(budgeted: 100, spent: 50) == .healthy)
        #expect(FinanceCalculator.budgetHealth(budgeted: 100, spent: 90) == .nearLimit)
        #expect(FinanceCalculator.budgetHealth(budgeted: 100, spent: 120) == .overBudget)
    }

    @Test("Goal progress clamps and remaining")
    func goalProgress() {
        let progress = FinanceCalculator.goalProgress(current: 18_400, target: 30_000)
        #expect(abs(progress - (18400.0 / 30000.0)) < 0.000_000_1)
        #expect(FinanceCalculator.goalProgressClamped(current: 35_000, target: 30_000) == 1.0)
        #expect(FinanceCalculator.goalRemaining(current: 8_100, target: 10_000) == 1_900)
        #expect(FinanceCalculator.goalRemaining(current: 12_000, target: 10_000) == 0)
    }

    @Test("Required monthly savings respects target date")
    func requiredMonthlySavings() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let from = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        let target = calendar.date(from: DateComponents(year: 2027, month: 6, day: 1))!

        let required = FinanceCalculator.requiredMonthlySavings(
            current: 18_400,
            target: 30_000,
            targetDate: target,
            from: from,
            calendar: calendar
        )
        #expect(required != nil)
        // 9 months Sep→Jun inclusive-ish; remaining 11600
        #expect(required! > 1_000)
        #expect(required! < 2_000)

        let past = FinanceCalculator.requiredMonthlySavings(
            current: 1_000,
            target: 5_000,
            targetDate: from,
            from: target,
            calendar: calendar
        )
        #expect(past == nil)
    }

    @Test("Zero-interest debt payoff")
    func debtPayoffZeroInterest() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let from = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!

        let result = FinanceCalculator.debtPayoff(
            balance: 1_200,
            aprPercent: 0,
            monthlyPayment: 100,
            from: from,
            calendar: calendar
        )
        guard case .paidOff(_, let months, let interest) = result else {
            Issue.record("Expected paidOff")
            return
        }
        #expect(months == 12)
        #expect(interest == 0)
    }

    @Test("Debt payment too low versus interest")
    func debtPaymentTooLow() {
        let result = FinanceCalculator.debtPayoff(
            balance: 5_000,
            aprPercent: 24,
            monthlyPayment: 50
        )
        guard case .paymentTooLow(let minimum) = result else {
            Issue.record("Expected paymentTooLow")
            return
        }
        #expect(minimum > 50)
    }

    @Test("Interest-bearing debt eventually pays off")
    func debtAmortization() {
        let result = FinanceCalculator.debtPayoff(
            balance: 2_850,
            aprPercent: 19.99,
            monthlyPayment: 250
        )
        guard case .paidOff(_, let months, let interest) = result else {
            Issue.record("Expected paidOff for Visa demo debt")
            return
        }
        #expect(months > 0)
        #expect(months < 36)
        #expect(interest > 0)
    }

    @Test("Balance projections scale with monthly net")
    func projections() {
        let points = FinanceCalculator.projectBalance(
            currentBalance: 10_000,
            monthlyIncome: 6_000,
            recurringBills: 2_000,
            averageDiscretionary: 1_500,
            plannedSavings: 500,
            debtPayments: 0,
            horizons: [0, 1, 3, 12]
        )
        #expect(points.count == 4)
        #expect(points[0].projectedBalance == 10_000)
        // monthly net = 6000-2000-1500-500 = 2000
        #expect(points.first(where: { $0.monthsAhead == 3 })?.projectedBalance == 16_000)
        #expect(points.first(where: { $0.monthsAhead == 12 })?.projectedBalance == 34_000)
    }

    @Test("Percent change handles zeros")
    func percentChange() {
        #expect(FinanceCalculator.percentChange(current: 82, previous: 100) == -0.18)
        #expect(FinanceCalculator.percentChange(current: 0, previous: 0) == 0)
        #expect(FinanceCalculator.percentChange(current: 50, previous: 0) == nil)
    }
}

@Suite("MoneyFormatters")
struct MoneyFormatterTests {
    @Test("Formats CAD without manual concatenation")
    func formatsCAD() {
        let text = MoneyFormatters.string(from: 1_450.5, currencyCode: "CAD", locale: Locale(identifier: "en_CA"))
        #expect(text.contains("1,450.50") || text.contains("1450.50"))
        #expect(text.contains("$") || text.contains("CA"))
    }

    @Test("Signed amounts")
    func signed() {
        let positive = MoneyFormatters.signed(from: 100, currencyCode: "USD", locale: Locale(identifier: "en_US"))
        #expect(positive.hasPrefix("+"))
        let negative = MoneyFormatters.signed(from: -100, currencyCode: "USD", locale: Locale(identifier: "en_US"))
        #expect(negative.hasPrefix("-"))
    }

    @Test("Decimal parsing")
    func parsing() {
        #expect(Decimal.from("1234.56") == Decimal(string: "1234.56"))
        #expect(Decimal.from("1,234.56") == Decimal(string: "1234.56"))
        #expect(Decimal.from("") == nil)
    }
}

@Suite("DateHelpers")
struct DateHelperTests {
    @Test("Next due date rolls to following month when needed")
    func nextDueDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let from = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20))!
        let due = DateHelpers.nextDueDate(dueDay: 15, from: from)
        let day = calendar.component(.day, from: due)
        let month = calendar.component(.month, from: due)
        #expect(day == 15)
        #expect(month == 10)
    }

    @Test("Greeting buckets")
    func greeting() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 8))!
        let afternoon = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 14))!
        let evening = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 20))!
        #expect(DateHelpers.greeting(for: morning) == "Good morning")
        #expect(DateHelpers.greeting(for: afternoon) == "Good afternoon")
        #expect(DateHelpers.greeting(for: evening) == "Good evening")
    }
}

@Suite("InsightEngine")
struct InsightEngineTests {
    @Test("Generates lower-spending insight")
    func lowerSpending() {
        let insights = InsightEngine.generate(
            from: .init(
                categorySpends: [
                    .init(name: "Food", current: 410, previous: 500, budgeted: 550)
                ],
                upcomingBillsWithinDays: [],
                goals: [],
                monthlyBudget: 3_400,
                spentSoFar: 1_000,
                dayOfMonth: 10,
                daysInMonth: 30,
                currencyCode: "CAD",
                now: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            limit: 5
        )
        #expect(insights.contains { $0.title.localizedCaseInsensitiveContains("lower") })
    }

    @Test("Bill due soon insight")
    func billDue() {
        let insights = InsightEngine.generate(
            from: .init(
                categorySpends: [],
                upcomingBillsWithinDays: [("Internet", 2, 79.99)],
                goals: [],
                monthlyBudget: 0,
                spentSoFar: 0,
                dayOfMonth: 1,
                daysInMonth: 30,
                currencyCode: "CAD",
                now: .now
            ),
            limit: 3
        )
        #expect(insights.contains { $0.title.contains("Internet") })
    }
}
