import Foundation

/// Pure CSV builders for transaction export (mirrors app `CSVExportLogic`).
public enum CSVExportLogic {
    public struct TransactionRow: Equatable, Sendable {
        public var date: Date
        public var title: String
        public var amount: Decimal
        public var type: String
        public var category: String
        public var note: String
        public var merchant: String
        public var source: String

        public init(
            date: Date,
            title: String,
            amount: Decimal,
            type: String,
            category: String,
            note: String,
            merchant: String,
            source: String
        ) {
            self.date = date
            self.title = title
            self.amount = amount
            self.type = type
            self.category = category
            self.note = note
            self.merchant = merchant
            self.source = source
        }
    }

    public static let header = "Date,Title,Amount,Type,Category,Note,Merchant,Source"

    public static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

    public static func formatDate(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let y = parts.year ?? 0
        let m = parts.month ?? 0
        let d = parts.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    public static func formatAmount(_ amount: Decimal) -> String {
        NSDecimalNumber(decimal: amount).stringValue
    }

    public static func line(for row: TransactionRow, calendar: Calendar = .current) -> String {
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

    public static func makeCSV(rows: [TransactionRow], calendar: Calendar = .current) -> String {
        var lines = [header]
        lines.append(contentsOf: rows.map { line(for: $0, calendar: calendar) })
        return lines.joined(separator: "\n") + "\n"
    }
}
