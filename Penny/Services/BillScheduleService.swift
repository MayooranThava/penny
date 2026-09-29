import Foundation
import SwiftData

/// Keeps stored bill due dates aligned with today so Upcoming / reminders stay current.
@MainActor
enum BillScheduleService {
    /// Advances each active bill’s `nextDueDate` when the stored date is in the past.
    /// Returns `true` when any bill changed.
    @discardableResult
    static func rollForwardDueDates(
        bills: [RecurringBill],
        in context: ModelContext,
        asOf date: Date = .now
    ) -> Bool {
        var changed = false
        for bill in bills where bill.isActive {
            let next = DateHelpers.nextDueDate(
                startDate: bill.startDate,
                recurrence: bill.recurrence,
                dueDay: bill.dueDay,
                from: date
            )
            if next != bill.nextDueDate {
                bill.nextDueDate = next
                changed = true
            }
        }
        if changed {
            try? context.save()
        }
        return changed
    }
}
