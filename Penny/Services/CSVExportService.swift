import Foundation
import SwiftData
import UniformTypeIdentifiers

/// Builds a temporary CSV file from on-device transactions for the system share sheet.
enum CSVExportService {
    enum ExportError: Error, LocalizedError {
        case empty
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .empty: return "There are no transactions to export."
            case .writeFailed: return "Penny couldn’t write the CSV file."
            }
        }
    }

    static func makeRows(from transactions: [Transaction]) -> [CSVExportLogic.TransactionRow] {
        transactions
            .sorted { $0.date > $1.date }
            .map { tx in
                CSVExportLogic.TransactionRow(
                    date: tx.date,
                    title: tx.title,
                    amount: tx.amount,
                    type: tx.transactionType.displayName,
                    category: tx.categoryName,
                    note: tx.note,
                    merchant: tx.merchantName,
                    source: tx.importSource.displayName
                )
            }
    }

    static func exportFile(transactions: [Transaction]) throws -> URL {
        let rows = makeRows(from: transactions)
        guard !rows.isEmpty else { throw ExportError.empty }
        let csv = CSVExportLogic.makeCSV(rows: rows)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = "penny-transactions-\(formatter.string(from: Date())).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            throw ExportError.writeFailed
        }
    }
}
