import Foundation

/// Mirrors app `BillPaymentCycle` for Linux CI (recurrence raw strings).
public enum BillPaymentCycle {
    public enum Recurrence: String, Sendable {
        case weekly, biweekly, monthly, yearly
    }

    public static func key(
        recurrence: Recurrence,
        asOf date: Date,
        calendar: Calendar = .current
    ) -> String {
        switch recurrence {
        case .monthly, .yearly:
            let comps = calendar.dateComponents([.year, .month], from: date)
            let y = comps.year ?? 0
            let m = comps.month ?? 0
            return String(format: "m:%04d-%02d", y, m)
        case .weekly:
            let y = calendar.component(.yearForWeekOfYear, from: date)
            let w = calendar.component(.weekOfYear, from: date)
            return String(format: "w:%04d-%02d", y, w)
        case .biweekly:
            let day = calendar.startOfDay(for: date)
            let epoch = calendar.date(from: DateComponents(year: 2020, month: 1, day: 6)) ?? day
            let days = calendar.dateComponents([.day], from: epoch, to: day).day ?? 0
            let fortnights = max(0, days) / 14
            return "b:\(fortnights)"
        }
    }

    public static func isPaid(paidCycleKey: String, recurrence: Recurrence, asOf date: Date) -> Bool {
        !paidCycleKey.isEmpty && paidCycleKey == key(recurrence: recurrence, asOf: date)
    }
}
