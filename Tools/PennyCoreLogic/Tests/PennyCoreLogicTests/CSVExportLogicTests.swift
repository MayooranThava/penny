import Foundation
import Testing
@testable import PennyCoreLogic

@Suite("CSV Export")
struct CSVExportLogicTests {

    @Test("Escapes commas and quotes")
    func escapeFields() {
        #expect(CSVExportLogic.escape("plain") == "plain")
        #expect(CSVExportLogic.escape("a,b") == "\"a,b\"")
        #expect(CSVExportLogic.escape("say \"hi\"") == "\"say \"\"hi\"\"\"")
    }

    @Test("Builds a valid CSV with header and rows")
    func makeCSV() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 28))!

        let csv = CSVExportLogic.makeCSV(
            rows: [
                .init(
                    date: date,
                    title: "Coffee, shop",
                    amount: Decimal(string: "4.50")!,
                    type: "Expense",
                    category: "Food",
                    note: "",
                    merchant: "Cafe",
                    source: "Manual"
                )
            ],
            calendar: calendar
        )

        #expect(csv.hasPrefix(CSVExportLogic.header + "\n"))
        #expect(csv.contains("2026-09-28"))
        #expect(csv.contains("\"Coffee, shop\""))
        #expect(csv.contains("4.5") || csv.contains("4.50"))
        #expect(csv.hasSuffix("\n"))
    }
}
