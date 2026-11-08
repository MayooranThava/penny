import Foundation
import SwiftData

enum ApplePayCaptureResult: Equatable {
    case inserted(title: String, amount: Decimal, categoryName: String)
    case duplicate(title: String, amount: Decimal)
    case invalidAmount
}

enum ApplePayCaptureSaveError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let detail) where detail.isEmpty:
            return "Penny couldn’t save this Wallet purchase."
        case .failed(let detail):
            return "Penny couldn’t save this Wallet purchase. \(detail)"
        }
    }
}

/// Writes Wallet-captured expenses into the shared on-device Penny store.
@MainActor
enum ApplePayCaptureService {
    static func capture(
        amount: Double,
        merchant: String?,
        name: String? = nil,
        currencyCode: String?,
        cardName: String?,
        date: Date = .now,
        in context: ModelContext
    ) throws -> ApplePayCaptureResult {
        guard let draft = ApplePayCaptureLogic.makeDraft(
            amount: amount,
            merchant: merchant,
            name: name,
            currencyCode: currencyCode,
            cardName: cardName,
            date: date
        ) else {
            return .invalidAmount
        }

        if try duplicateTap(matching: draft, in: context) {
            return .duplicate(title: draft.title, amount: draft.amount)
        }

        let transaction = Transaction(
            title: draft.title,
            amount: draft.amount,
            date: draft.date,
            transactionType: .expense,
            categoryName: draft.categoryName,
            note: draft.note,
            importSource: .applePayShortcut,
            externalIdentifier: draft.externalIdentifier,
            merchantName: draft.merchant,
            cardName: draft.cardName
        )
        context.insert(transaction)
        try saveOrThrow(context)
        return .inserted(title: draft.title, amount: draft.amount, categoryName: draft.categoryName)
    }

    /// Opens the same on-disk store the UI uses so Shortcuts can write without launching the UI.
    static func captureUsingSharedStore(
        amount: Double,
        merchant: String?,
        name: String? = nil,
        currencyCode: String?,
        cardName: String?,
        date: Date = .now
    ) throws -> ApplePayCaptureResult {
        let container = try PennyPersistence.makeContainer()
        let context = ModelContext(container)
        return try capture(
            amount: amount,
            merchant: merchant,
            name: name,
            currencyCode: currencyCode,
            cardName: cardName,
            date: date,
            in: context
        )
    }

    private static func duplicateTap(
        matching draft: ApplePayCaptureLogic.Draft,
        in context: ModelContext
    ) throws -> Bool {
        let source = TransactionImportSource.applePayShortcut.rawValue
        let earliest = draft.date.addingTimeInterval(-ApplePayCaptureLogic.duplicateWindow)
        let latest = draft.date.addingTimeInterval(ApplePayCaptureLogic.duplicateWindow)
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { row in
                row.importSourceRaw == source && row.date >= earliest && row.date <= latest
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 8
        let rows = try context.fetch(descriptor)
        return rows.contains { row in
            ApplePayCaptureLogic.isDuplicate(
                amount: draft.amount,
                merchant: draft.title,
                date: draft.date,
                existingAmount: row.amount,
                existingMerchant: row.title,
                existingDate: row.date
            )
        }
    }

    private static func saveOrThrow(_ context: ModelContext) throws {
        do {
            if let forced = PennySaveTesting.forcedError {
                throw forced
            }
            try context.save()
        } catch {
            let detail = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            throw ApplePayCaptureSaveError.failed(detail)
        }
    }
}
