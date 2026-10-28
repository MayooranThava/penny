import Foundation
import Testing
@testable import Penny

@Suite("Bill reminder schedule", .isolatedTestResources)
struct BillReminderScheduleTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }

    @Test("Schedules the reminder N days before the due date at 9:00")
    func schedulesNDaysBeforeDue() {
        let due = date(year: 2026, month: 11, day: 15, hour: 17)
        let now = date(year: 2026, month: 11, day: 1, hour: 8)
        let trigger = NotificationService.reminderTriggerDate(
            dueDate: due,
            daysBefore: 3,
            now: now,
            calendar: calendar
        )
        let expected = date(year: 2026, month: 11, day: 12, hour: 17)
        #expect(calendar.isDate(trigger, inSameDayAs: expected))

        let comps = NotificationService.reminderTriggerComponents(
            dueDate: due,
            daysBefore: 3,
            now: now,
            calendar: calendar
        )
        #expect(comps.year == 2026)
        #expect(comps.month == 11)
        #expect(comps.day == 12)
        #expect(comps.hour == 9)
    }

    @Test("Falls back to the due date when the reminder day is already past")
    func fallsBackWhenReminderDayPassed() {
        let due = date(year: 2026, month: 11, day: 10, hour: 12)
        let now = date(year: 2026, month: 11, day: 9, hour: 10)
        let trigger = NotificationService.reminderTriggerDate(
            dueDate: due,
            daysBefore: 2,
            now: now,
            calendar: calendar
        )
        #expect(calendar.isDate(trigger, inSameDayAs: due))

        let comps = NotificationService.reminderTriggerComponents(
            dueDate: due,
            daysBefore: 2,
            now: now,
            calendar: calendar
        )
        #expect(comps.day == 10)
        #expect(comps.hour == 9)
    }

    @Test("Zero days before fires on the due date")
    func zeroDaysBeforeUsesDueDate() {
        let due = date(year: 2026, month: 4, day: 1, hour: 8)
        let now = date(year: 2026, month: 3, day: 20, hour: 8)
        let trigger = NotificationService.reminderTriggerDate(
            dueDate: due,
            daysBefore: 0,
            now: now,
            calendar: calendar
        )
        #expect(calendar.isDate(trigger, inSameDayAs: due))
    }

    private func date(year: Int, month: Int, day: Int, hour: Int) -> Date {
        calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour)
        )!
    }
}
