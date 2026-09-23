import Foundation

/// Pure helpers for turning a Wallet tap (via Shortcuts) into a Penny expense.
enum ApplePayCaptureLogic {
    struct Draft: Equatable {
        var amount: Decimal
        var merchant: String
        var currencyCode: String
        var cardName: String
        var date: Date
        var categoryName: String
        var externalIdentifier: String
        var title: String
        var note: String
    }

    /// Builds a draft ready to insert, or `nil` when amount is not positive.
    static func makeDraft(
        amount: Double,
        merchant: String?,
        currencyCode: String?,
        cardName: String?,
        date: Date = .now,
        calendar: Calendar = .current
    ) -> Draft? {
        let decimalAmount = Decimal(amount).rounded(scale: 2)
        guard decimalAmount > 0 else { return nil }

        let cleanedMerchant = cleaned(merchant)
        let cleanedCard = cleaned(cardName)
        let cleanedCurrency = cleaned(currencyCode).uppercased()
        let title = cleanedMerchant.isEmpty ? "Apple Pay" : cleanedMerchant
        let category = suggestCategory(for: title)
        let externalID = externalIdentifier(
            amount: decimalAmount,
            merchant: title,
            cardName: cleanedCard,
            date: date,
            calendar: calendar
        )

        var noteParts: [String] = ["Captured from Apple Pay"]
        if !cleanedCard.isEmpty {
            noteParts.append(cleanedCard)
        }
        if !cleanedCurrency.isEmpty {
            noteParts.append(cleanedCurrency)
        }

        return Draft(
            amount: decimalAmount,
            merchant: cleanedMerchant,
            currencyCode: cleanedCurrency,
            cardName: cleanedCard,
            date: date,
            categoryName: category,
            externalIdentifier: externalID,
            title: title,
            note: noteParts.joined(separator: " · ")
        )
    }

    static func suggestCategory(for merchant: String) -> String {
        let value = merchant.lowercased()
        guard !value.isEmpty else { return "Other" }

        let food = [
            "tim hortons", "starbucks", "mcdonald", "burger", "pizza", "sushi",
            "cafe", "coffee", "restaurant", "loblaws", "no frills", "walmart",
            "costco", "metro", "sobeys", "grocery", "food", "kitchen", "bakery",
            "diner", "chipotle", "subway"
        ]
        if food.contains(where: { value.contains($0) }) { return "Food" }

        let transport = [
            "uber", "lyft", "taxi", "transit", "ttc", "presto", "shell", "esso",
            "petro", "gas", "parking", "bolt", "via rail"
        ]
        if transport.contains(where: { value.contains($0) }) { return "Transportation" }

        let health = ["pharmacy", "shoppers", "dental", "clinic", "hospital", "gym", "fitness"]
        if health.contains(where: { value.contains($0) }) { return "Health" }

        let shopping = [
            "amazon", "apple store", "best buy", "winners", "indigo", "nike",
            "uniqlo", "zara", "h&m", "target", "ikea"
        ]
        if shopping.contains(where: { value.contains($0) }) { return "Shopping" }

        let entertainment = [
            "cineplex", "netflix", "spotify", "steam", "ticket", "concert",
            "theatre", "game", "playstation", "xbox"
        ]
        if entertainment.contains(where: { value.contains($0) }) {
            if value.contains("netflix") || value.contains("spotify") {
                return "Subscriptions"
            }
            return "Entertainment"
        }

        let travel = ["air canada", "westjet", "airline", "hotel", "airbnb", "booking.com"]
        if travel.contains(where: { value.contains($0) }) { return "Travel" }

        let housing = ["hydro", "enbridge", "rent", "landlord", "property"]
        if housing.contains(where: { value.contains($0) }) { return "Housing" }

        let subscriptions = ["icloud", "adobe", "microsoft 365", "google one", "youtube premium"]
        if subscriptions.contains(where: { value.contains($0) }) { return "Subscriptions" }

        return "Other"
    }

    static func externalIdentifier(
        amount: Decimal,
        merchant: String,
        cardName: String,
        date: Date,
        calendar: Calendar = .current
    ) -> String {
        let day = calendar.startOfDay(for: date)
        let dayKey = ISO8601DateFormatter.string(from: day, options: [.withFullDate], timeZone: calendar.timeZone)
        let amountKey = NSDecimalNumber(decimal: amount).stringValue
        let merchantKey = merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cardKey = cardName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "applepay:\(amountKey)|\(merchantKey)|\(dayKey)|\(cardKey)"
    }

    private static func cleaned(_ value: String?) -> String {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{00a0}", with: " ")
    }
}

private extension ISO8601DateFormatter {
    static func string(from date: Date, options: Options, timeZone: TimeZone) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = options
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}
