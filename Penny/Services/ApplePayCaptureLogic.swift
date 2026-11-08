import Foundation

/// Pure helpers for turning a Wallet tap (via Shortcuts) into a Penny expense.
enum ApplePayCaptureLogic {
    /// Two Wallet taps with the same amount and merchant inside this window are one purchase.
    /// A later tap the same day is a new expense.
    static let duplicateWindow: TimeInterval = 120

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

    /// Cents from a Wallet `Double`. `Decimal(amount)` keeps binary noise, and
    /// `String(format: "%.2f", amount)` follows the user's locale (so "10.2" can become "10,20").
    static func money(fromApplePayAmount amount: Double) -> Decimal {
        guard amount.isFinite else { return 0 }
        let magnitude = abs(amount)
        guard magnitude < 1_000_000_000 else { return 0 }
        let cents = (magnitude * 100).rounded()
        guard cents <= Double(Int.max) else { return 0 }
        let sign: FloatingPointSign = amount < 0 ? .minus : .plus
        return Decimal(sign: sign, exponent: -2, significand: Decimal(Int(cents)))
    }

    /// Merchant, then Name, then "Apple Pay".
    static func merchantTitle(merchant: String?, name: String?) -> String {
        let primary = cleaned(merchant)
        if !primary.isEmpty { return primary }
        let fallback = cleaned(name)
        if !fallback.isEmpty { return fallback }
        return "Apple Pay"
    }

    /// Parses a Shortcuts Amount such as "$12.34", "US$8.00", "12,50", or "1.234,56".
    /// When both separators appear, the last one is the decimal mark.
    /// One or two digits after the only separator are the decimal part, so "12.5" is 12.50
    /// even where the locale uses a comma. Three digits stay a thousands group.
    static func money(
        fromShortcutAmount text: String,
        currencyCode: String? = nil,
        locale: Locale = .current
    ) -> Decimal? {
        var value = cleaned(text)
        guard !value.isEmpty else { return nil }
        let tokens = ["CA$", "US$", "NZ$", "A$", "C$", "CAD", "USD", "EUR", "GBP", "AUD", "$", "€", "£", "¥"]
        for token in tokens {
            value = value.replacingOccurrences(of: token, with: "", options: .caseInsensitive)
        }
        value = value.replacingOccurrences(of: " ", with: "")
        value = value.replacingOccurrences(of: "\u{00a0}", with: "")
        guard !value.isEmpty else { return nil }
        let normalized = normalizedDecimalText(
            value,
            decimalSeparator: decimalSeparator(for: currencyCode, locale: locale)
        )
        guard let number = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        let decimal = money(fromApplePayAmount: NSDecimalNumber(decimal: number).doubleValue)
        guard decimal > 0 else { return nil }
        return decimal
    }

    private static func decimalSeparator(for currencyCode: String?, locale: Locale) -> String {
        switch cleaned(currencyCode).uppercased() {
        case "USD", "CAD", "AUD", "GBP", "NZD":
            return "."
        case "EUR":
            return ","
        default:
            return locale.decimalSeparator ?? "."
        }
    }

    private static func normalizedDecimalText(_ raw: String, decimalSeparator: String) -> String {
        let lastDot = raw.lastIndex(of: ".")
        let lastComma = raw.lastIndex(of: ",")
        if let lastDot, let lastComma {
            let decimalChar: Character = lastDot > lastComma ? "." : ","
            let groupingChar: Character = decimalChar == "." ? "," : "."
            return raw
                .replacingOccurrences(of: String(groupingChar), with: "")
                .replacingOccurrences(of: String(decimalChar), with: ".")
        }
        guard let separator = lastDot ?? lastComma else { return raw }
        let mark: Character = lastDot == nil ? "," : "."
        let fraction = raw[raw.index(after: separator)...].filter(\.isNumber)
        if fraction.count == 1 || fraction.count == 2 {
            return raw.replacingOccurrences(of: String(mark), with: ".")
        }
        if fraction.count == 3 {
            return raw.replacingOccurrences(of: String(mark), with: "")
        }
        if String(mark) == decimalSeparator, !fraction.isEmpty {
            return raw.replacingOccurrences(of: String(mark), with: ".")
        }
        return raw.replacingOccurrences(of: String(mark), with: "")
    }

    /// Same amount and merchant, and the timestamps fall inside `duplicateWindow`.
    static func isDuplicate(
        amount: Decimal,
        merchant: String,
        date: Date,
        existingAmount: Decimal,
        existingMerchant: String,
        existingDate: Date
    ) -> Bool {
        guard amount == existingAmount else { return false }
        let left = cleaned(merchant).lowercased()
        let right = cleaned(existingMerchant).lowercased()
        guard left == right else { return false }
        return abs(date.timeIntervalSince(existingDate)) <= duplicateWindow
    }

    /// Builds a draft ready to insert, or `nil` when amount is not positive.
    static func makeDraft(
        amount: Double,
        merchant: String?,
        name: String? = nil,
        currencyCode: String?,
        cardName: String?,
        date: Date = .now
    ) -> Draft? {
        let decimalAmount = money(fromApplePayAmount: amount)
        guard decimalAmount > 0 else { return nil }

        let cleanedCard = cleaned(cardName)
        let cleanedCurrency = cleaned(currencyCode).uppercased()
        let title = merchantTitle(merchant: merchant, name: name)
        let cleanedMerchant = title == "Apple Pay" && cleaned(merchant).isEmpty && cleaned(name).isEmpty
            ? ""
            : title
        let category = suggestCategory(for: title)
        let externalID = externalIdentifier(
            amount: decimalAmount,
            merchant: title,
            cardName: cleanedCard,
            date: date
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
        date: Date
    ) -> String {
        let bucket = Int(date.timeIntervalSince1970 / duplicateWindow)
        let amountKey = NSDecimalNumber(decimal: amount).stringValue
        let merchantKey = merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cardKey = cardName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "applepay:\(amountKey)|\(merchantKey)|\(bucket)|\(cardKey)"
    }

    private static func cleaned(_ value: String?) -> String {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{00a0}", with: " ")
    }
}
