import Foundation

/// Billing-cycle helpers for recurring bills.
enum BillPaymentCycle {
    /// Key for the cycle containing `asOf`, based on recurrence.
    static func key(
        recurrence: BillRecurrence,
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
            // Fixed Monday epoch so fortnight indexes stay stable across launches.
            let epoch = calendar.date(from: DateComponents(year: 2020, month: 1, day: 6)) ?? day
            let days = calendar.dateComponents([.day], from: epoch, to: day).day ?? 0
            let fortnights = max(0, days) / 14
            return "b:\(fortnights)"
        }
    }

    /// Legacy manual paid-cycle marker (kept for older data / PDF). Prefer `hasDueDatePassed`.
    static func isPaid(paidCycleKey: String, recurrence: BillRecurrence, asOf date: Date) -> Bool {
        !paidCycleKey.isEmpty && paidCycleKey == key(recurrence: recurrence, asOf: date)
    }

    static func toggledKey(isCurrentlyPaid: Bool, recurrence: BillRecurrence, asOf date: Date) -> String {
        isCurrentlyPaid ? "" : key(recurrence: recurrence, asOf: date)
    }

    /// True once this cycle’s due date has arrived (on or after the due day).
    /// Used to show a small automatic checkmark — not a to-do toggle.
    static func hasDueDatePassed(
        dueDay: Int,
        recurrence: BillRecurrence,
        nextDueDate: Date,
        asOf date: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        let today = calendar.startOfDay(for: date)
        let next = calendar.startOfDay(for: nextDueDate)

        switch recurrence {
        case .monthly:
            let day = max(1, min(28, dueDay))
            return calendar.component(.day, from: today) >= day
        case .yearly:
            if calendar.component(.year, from: next) > calendar.component(.year, from: today) {
                return true
            }
            return next <= today
        case .weekly, .biweekly:
            return next <= today
        }
    }
}
