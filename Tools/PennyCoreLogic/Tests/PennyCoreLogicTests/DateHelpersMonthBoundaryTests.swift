import Foundation
import Testing
@testable import PennyCoreLogic

@Suite("DateHelpers month boundaries")
struct DateHelpersMonthBoundaryTests {
    private var toronto: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }

    @Test("Last second of October is still October")
    func lastSecondOfOctober() {
        let end = toronto.date(
            from: DateComponents(year: 2026, month: 10, day: 31, hour: 23, minute: 59, second: 59)
        )!
        let start = toronto.date(
            from: DateComponents(year: 2026, month: 11, day: 1, hour: 0, minute: 0, second: 0)
        )!
        let october = DateHelpers.startOfMonth(for: end, calendar: toronto)
        #expect(DateHelpers.isSameMonth(end, october, calendar: toronto))
        #expect(!DateHelpers.isSameMonth(start, october, calendar: toronto))
        #expect(CSVExportLogic.formatDate(end, calendar: toronto) == "2026-10-31")
        #expect(CSVExportLogic.formatDate(start, calendar: toronto) == "2026-11-01")
    }

    @Test("Toronto spring-forward stays in March")
    func springForward() {
        let before = toronto.date(
            from: DateComponents(year: 2026, month: 3, day: 7, hour: 23, minute: 59)
        )!
        let after = toronto.date(
            from: DateComponents(year: 2026, month: 3, day: 8, hour: 3, minute: 30)
        )!
        #expect(DateHelpers.isSameMonth(before, after, calendar: toronto))
    }
}
