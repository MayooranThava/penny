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
        let key = BillPaymentCycle.key(recurrence: .monthly, asOf: date, calendar: calendar)
        #expect(key == "m:2026-09")
        // Same condition the app can apply to a stored paidCycleKey (the helper
        // is not a separate shared function — keep it next to `key`).
        #expect(!key.isEmpty && "m:2026-09" == key)
        #expect("m:2026-08" != key)
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
