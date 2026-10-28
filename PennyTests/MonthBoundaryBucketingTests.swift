import Foundation
import Testing
@testable import Penny

/// Home, Budget, CSV and PDF all bucket month totals with `DateHelpers.isSameMonth`.
@Suite("Month-boundary and DST bucketing", .isolatedTestResources)
struct MonthBoundaryBucketingTests {
    private var toronto: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }

    private let enUS = Locale(identifier: "en_US")

    @Test("23:59 on the last day stays in the old month; 00:00 next day is the new month")
    func midnightBoundarySplitsMonths() {
        let endOfOctober = date(year: 2026, month: 10, day: 31, hour: 23, minute: 59)
        let startOfNovember = date(year: 2026, month: 11, day: 1, hour: 0, minute: 0)
        let october = DateHelpers.startOfMonth(for: endOfOctober, calendar: toronto)
        let november = DateHelpers.startOfMonth(for: startOfNovember, calendar: toronto)

        #expect(DateHelpers.isSameMonth(endOfOctober, october, calendar: toronto))
        #expect(!DateHelpers.isSameMonth(startOfNovember, october, calendar: toronto))
        #expect(DateHelpers.isSameMonth(startOfNovember, november, calendar: toronto))

        let rows: [(date: Date, amount: Decimal)] = [
            (endOfOctober, Decimal(string: "10.01")!),
            (startOfNovember, Decimal(string: "20.02")!)
        ]
        #expect(monthSpend(rows, month: october) == Decimal(string: "10.01"))
        #expect(monthSpend(rows, month: november) == Decimal(string: "20.02"))
    }

    @Test("Spring-forward DST night still buckets by civil month in Toronto")
    func springForwardStaysInMarch() {
        // 2026-03-08: clocks jump 02:00 → 03:00 in America/Toronto.
        let before = date(year: 2026, month: 3, day: 7, hour: 23, minute: 59)
        let after = date(year: 2026, month: 3, day: 8, hour: 3, minute: 30)
        let march = DateHelpers.startOfMonth(for: before, calendar: toronto)

        #expect(DateHelpers.isSameMonth(before, march, calendar: toronto))
        #expect(DateHelpers.isSameMonth(after, march, calendar: toronto))
        #expect(toronto.component(.month, from: before) == 3)
        #expect(toronto.component(.month, from: after) == 3)
    }

    @Test("Fall-back DST night still buckets by civil month in Toronto")
    func fallBackSplitsOctoberAndNovember() {
        // 2026-11-01: clocks fall back 02:00 → 01:00 in America/Toronto.
        let lateOctober = date(year: 2026, month: 10, day: 31, hour: 23, minute: 30)
        let earlyNovember = date(year: 2026, month: 11, day: 1, hour: 0, minute: 30)
        let october = DateHelpers.startOfMonth(for: lateOctober, calendar: toronto)

        #expect(DateHelpers.isSameMonth(lateOctober, october, calendar: toronto))
        #expect(!DateHelpers.isSameMonth(earlyNovember, october, calendar: toronto))
    }

    @Test("Home/Budget/CSV/PDF month totals agree to the cent across the boundary")
    func homeBudgetCSVAndPDFAgree() {
        let endOfOctober = date(year: 2026, month: 10, day: 31, hour: 23, minute: 59)
        let startOfNovember = date(year: 2026, month: 11, day: 1, hour: 0, minute: 0)
        let october = DateHelpers.startOfMonth(for: endOfOctober, calendar: toronto)

        let rows: [(date: Date, title: String, amount: Decimal)] = [
            (endOfOctober, "Halloween candy", Decimal(string: "12.34")!),
            (startOfNovember, "November coffee", Decimal(string: "5.67")!),
            (date(year: 2026, month: 10, day: 15, hour: 12, minute: 0), "Mid-month", Decimal(string: "100.00")!)
        ]

        let homeSpent = monthSpend(rows.map { ($0.date, $0.amount) }, month: october)
        #expect(homeSpent == Decimal(string: "112.34"))

        let csv = CSVExportLogic.makeCSV(
            rows: rows
                .filter { DateHelpers.isSameMonth($0.date, october, calendar: toronto) }
                .map {
                    .init(
                        date: $0.date,
                        title: $0.title,
                        amount: $0.amount,
                        type: "Expense",
                        category: "Food",
                        note: "",
                        merchant: "",
                        source: "Manual"
                    )
                },
            calendar: toronto
        )
        #expect(csv.contains("2026-10-31"))
        #expect(csv.contains("12.34"))
        #expect(csv.contains("100"))
        #expect(!csv.contains("2026-11-01"))
        #expect(!csv.contains("5.67"))

        let pdfLines = MonthlySummaryPDFService.summaryLines(
            for: .init(
                monthLabel: DateHelpers.monthYear(for: october, locale: enUS),
                currencyCode: "CAD",
                displayName: "",
                income: Decimal(string: "5000.00")!,
                spent: homeSpent,
                billsMonthly: 0,
                safeToSpend: Decimal(string: "5000.00")! - homeSpent,
                categoryLines: [],
                billLines: []
            ),
            locale: enUS
        )
        let joined = pdfLines.joined(separator: "\n")
        #expect(joined.contains("112.34"))
        #expect(!joined.contains("5.67"))
    }

    private func monthSpend(
        _ rows: [(date: Date, amount: Decimal)],
        month: Date
    ) -> Decimal {
        rows
            .filter { DateHelpers.isSameMonth($0.date, month, calendar: toronto) }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        toronto.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        )!
    }
}
