import Foundation
import SwiftData

enum ApplePayCaptureResult: Equatable {
    case inserted(title: String, amount: Decimal, categoryName: String)
    case duplicate(title: String, amount: Decimal)
    case invalidAmount
}

/// Writes Wallet-captured expenses into the shared on-device Penny store.
@MainActor
enum ApplePayCaptureService {
    static func capture(
        amount: Double,
        merchant: String?,
        currencyCode: String?,
        cardName: String?,
        date: Date = .now,
        in context: ModelContext
    ) throws -> ApplePayCaptureResult {
        guard let draft = ApplePayCaptureLogic.makeDraft(
            amount: amount,
            merchant: merchant,
            currencyCode: currencyCode,
            cardName: cardName,
            date: date
        ) else {
            return .invalidAmount
        }

        if try existingTransaction(externalIdentifier: draft.externalIdentifier, in: context) != nil {
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
        try context.save()
        return .inserted(title: draft.title, amount: draft.amount, categoryName: draft.categoryName)
    }

    /// Opens the same on-disk store the UI uses so Shortcuts can write without launching the UI.
    static func captureUsingSharedStore(
        amount: Double,
        merchant: String?,
        currencyCode: String?,
        cardName: String?,
        date: Date = .now
    ) throws -> ApplePayCaptureResult {
        let container = try PennyPersistence.makeContainer()
        let context = ModelContext(container)
        return try capture(
            amount: amount,
            merchant: merchant,
            currencyCode: currencyCode,
            cardName: cardName,
            date: date,
            in: context
        )
    }

    private static func existingTransaction(
        externalIdentifier: String,
        in context: ModelContext
    ) throws -> Transaction? {
        guard !externalIdentifier.isEmpty else { return nil }
        let identifier = externalIdentifier
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.externalIdentifier == identifier }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
