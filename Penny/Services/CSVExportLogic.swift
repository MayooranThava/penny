import Foundation

/// Pure CSV builders for transaction export (no UI / ShareSheet).
enum CSVExportLogic {
    struct TransactionRow: Equatable {
        var date: Date
        var title: String
        var amount: Decimal
        var type: String
        var category: String
        var note: String
        var merchant: String
        var source: String
    }

    static let header = "Date,Title,Amount,Type,Category,Note,Merchant,Source"

    static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

    static func formatDate(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let y = parts.year ?? 0
        let m = parts.month ?? 0
        let d = parts.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func formatAmount(_ amount: Decimal) -> String {
        NSDecimalNumber(decimal: amount).stringValue
    }

    static func line(for row: TransactionRow, calendar: Calendar = .current) -> String {
        [
            formatDate(row.date, calendar: calendar),
            escape(row.title),
            formatAmount(row.amount),
            escape(row.type),
            escape(row.category),
            escape(row.note),
            escape(row.merchant),
            escape(row.source)
        ].joined(separator: ",")
    }

    static func makeCSV(rows: [TransactionRow], calendar: Calendar = .current) -> String {
        var lines = [header]
        lines.append(contentsOf: rows.map { line(for: $0, calendar: calendar) })
        return lines.joined(separator: "\n") + "\n"
    }
}
