import Foundation
import Testing
@testable import Penny

@Suite("Monthly summary PDF", .isolatedTestResources)
struct MonthlySummaryPDFServiceTests {
    private let enUS = Locale(identifier: "en_US")

    @Test("Summary lines keep every total to the cent, including debt")
    func summaryLinesIncludeExactTotals() {
        let input = MonthlySummaryPDFService.Input(
            monthLabel: "October 2026",
            currencyCode: "CAD",
            displayName: "Mayooran",
            income: Decimal(string: "6200.00")!,
            spent: Decimal(string: "1227.35")!,
            billsMonthly: Decimal(string: "2522.98")!,
            debtMonthly: Decimal(string: "350.10")!,
            safeToSpend: Decimal(string: "1099.57")!,
            categoryLines: [
                (name: "Food", spent: Decimal(string: "210.05")!, budgeted: Decimal(string: "400.00")!)
            ],
            billLines: [
                (name: "Rent", amount: Decimal(string: "1850.00")!)
            ]
        )

        let lines = MonthlySummaryPDFService.summaryLines(for: input, locale: enUS)
        let joined = lines.joined(separator: "\n")
        #expect(joined.contains("6,200.00"))
        #expect(joined.contains("1,227.35"))
        #expect(joined.contains("2,522.98"))
        #expect(joined.contains("350.10"))
        #expect(joined.contains("1,099.57"))
        #expect(lines.contains { $0.hasPrefix("Debt payments:") })
        #expect(lines.contains { $0.hasPrefix("Safe to Spend*") })
    }

    @Test("Debt line is omitted when debt is zero")
    func omitsZeroDebt() {
        let input = MonthlySummaryPDFService.Input(
            monthLabel: "November 2026",
            currencyCode: "USD",
            displayName: "",
            income: 1,
            spent: 1,
            billsMonthly: 1,
            debtMonthly: 0,
            safeToSpend: 0,
            categoryLines: [],
            billLines: []
        )
        let lines = MonthlySummaryPDFService.summaryLines(for: input, locale: enUS)
        #expect(!lines.contains { $0.hasPrefix("Debt payments:") })
    }

    @Test("exportFile writes a non-empty PDF")
    func exportFileWritesPDF() throws {
        let input = MonthlySummaryPDFService.Input(
            monthLabel: "October 2026",
            currencyCode: "CAD",
            displayName: "Mayooran",
            income: Decimal(string: "5000.00")!,
            spent: Decimal(string: "999.35")!,
            billsMonthly: Decimal(string: "1750.00")!,
            debtMonthly: Decimal(string: "100.00")!,
            safeToSpend: Decimal(string: "2150.65")!,
            categoryLines: [
                (name: "Food", spent: Decimal(string: "99.35")!, budgeted: Decimal(string: "300.00")!)
            ],
            billLines: [
                (name: "Internet", amount: Decimal(string: "80.00")!)
            ]
        )
        let url = try MonthlySummaryPDFService.exportFile(input: input)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(url.pathExtension == "pdf")
        let data = try Data(contentsOf: url)
        #expect(data.count > 100)
        #expect(String(data: data.prefix(5), encoding: .ascii) == "%PDF-")
    }
}
