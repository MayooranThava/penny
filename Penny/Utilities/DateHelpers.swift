import Foundation

enum DateHelpers {
    static var calendar: Calendar { Calendar.current }

    static func startOfMonth(for date: Date = .now) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }

    static func endOfMonth(for date: Date = .now) -> Date {
        guard let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
              let next = calendar.date(byAdding: .month, value: 1, to: start),
              let end = calendar.date(byAdding: .second, value: -1, to: next) else {
            return date
        }
        return end
    }

    static func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    static func isSameMonth(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, equalTo: rhs, toGranularity: .month)
    }

    static func monthName(for date: Date, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter.string(from: date)
    }

    static func monthYear(for date: Date, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: date)
    }

    static func shortMonthDay(for date: Date, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter.string(from: date)
    }

    static func mediumDate(for date: Date, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    static func relativeDayLabel(for date: Date, relativeTo now: Date = .now) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        return shortMonthDay(for: date).uppercased()
    }

    static func greeting(for date: Date = .now) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    /// Personalized home greeting. Uses "Welcome back {name}" when a display name is set.
    static func welcomeMessage(displayName: String?, date: Date = .now) -> String {
        let trimmed = (displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return greeting(for: date)
        }
        return "Welcome back \(trimmed)"
    }

    /// Next occurrence of a day-of-month (1–28) on or after `from`.
    static func nextDueDate(dueDay: Int, from: Date = .now) -> Date {
        let day = max(1, min(28, dueDay))
        var comps = calendar.dateComponents([.year, .month], from: from)
        comps.day = day
        guard let candidate = calendar.date(from: comps) else { return from }
        if candidate >= calendar.startOfDay(for: from) {
            return candidate
        }
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: candidate) else {
            return candidate
        }
        return nextMonth
    }

    /// Next due date from a schedule starting at `startDate` with the given recurrence.
    static func nextDueDate(
        startDate: Date,
        recurrence: BillRecurrence,
        dueDay: Int,
        from: Date = .now
    ) -> Date {
        let start = calendar.startOfDay(for: startDate)
        let today = calendar.startOfDay(for: from)

        switch recurrence {
        case .monthly, .yearly:
            // Prefer day-of-month cadence; yearly advances 12 months from start when needed.
            if recurrence == .monthly {
                return nextDueDate(dueDay: dueDay, from: from)
            }
            var candidate = start
            while candidate < today {
                guard let advanced = calendar.date(byAdding: .year, value: 1, to: candidate) else { break }
                candidate = advanced
            }
            return candidate

        case .weekly:
            var candidate = start
            while candidate < today {
                guard let advanced = calendar.date(byAdding: .day, value: 7, to: candidate) else { break }
                candidate = advanced
            }
            return candidate

        case .biweekly:
            var candidate = start
            while candidate < today {
                guard let advanced = calendar.date(byAdding: .day, value: 14, to: candidate) else { break }
                candidate = advanced
            }
            return candidate
        }
    }

    static func monthsBetween(_ start: Date, _ end: Date) -> Int {
        let comps = calendar.dateComponents([.month], from: startOfMonth(for: start), to: startOfMonth(for: end))
        return max(0, comps.month ?? 0)
    }

    static func addingMonths(_ months: Int, to date: Date) -> Date {
        calendar.date(byAdding: .month, value: months, to: date) ?? date
    }

    static func daysRemainingInMonth(from date: Date = .now) -> Int {
        let end = endOfMonth(for: date)
        let comps = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: end)
        return max(0, (comps.day ?? 0) + 1)
    }
}
