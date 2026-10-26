import Foundation
import Testing
@testable import PennyCoreLogic

@Suite("Bill Payment Cycle")
struct BillPaymentCycleTests {
    @Test("Monthly key is year-month")
    func monthlyKey() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 15))!
        #expect(BillPaymentCycle.key(recurrence: .monthly, asOf: date, calendar: calendar) == "m:2026-09")
    }

    @Test("Deleting a bill drops it from committed spend")
    func inactiveBillIsOmittedFromCommittedSpend() {
        // Same rule as Plan → Delete Bill: isActive = false, then only active
        // bills are passed into totalMonthlyCommitted.
        let rent = (amount: Decimal(2_000), recurrence: BillRecurrence.monthly, isActive: false)
        let gym = (amount: Decimal(45), recurrence: BillRecurrence.monthly, isActive: true)
        #expect(!BillPaymentCycle.includesInCommittedSpend(isActive: rent.isActive))
        #expect(BillPaymentCycle.includesInCommittedSpend(isActive: gym.isActive))

        let included = [rent, gym].filter {
            BillPaymentCycle.includesInCommittedSpend(isActive: $0.isActive)
        }
        let committed = FinanceCalculator.totalMonthlyCommitted(
            billAmountsAndRecurrence: [rent, gym].map { ($0.amount, $0.recurrence, $0.isActive) },
            debtPayments: []
        )
        #expect(included.map(\.amount) == [45])
        #expect(committed == 45)
    }

    @Test("Weekly key changes across weeks")
    func weeklyKey() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        let a = calendar.date(from: DateComponents(year: 2026, month: 9, day: 14))! // Mon
        let b = calendar.date(from: DateComponents(year: 2026, month: 9, day: 21))! // next Mon
        let keyA = BillPaymentCycle.key(recurrence: .weekly, asOf: a, calendar: calendar)
        let keyB = BillPaymentCycle.key(recurrence: .weekly, asOf: b, calendar: calendar)
        #expect(keyA != keyB)
        #expect(keyA.hasPrefix("w:"))
    }
}
