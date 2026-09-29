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
        #expect(BillPaymentCycle.isPaid(paidCycleKey: "m:2026-09", recurrence: .monthly, asOf: date))
        #expect(!BillPaymentCycle.isPaid(paidCycleKey: "m:2026-08", recurrence: .monthly, asOf: date))
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
