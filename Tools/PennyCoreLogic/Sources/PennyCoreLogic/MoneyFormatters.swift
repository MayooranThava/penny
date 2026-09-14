import Foundation

/// Centralized currency formatting. Never manually concatenate currency symbols.
enum MoneyFormatters {
    private static var cache: [String: NumberFormatter] = [:]
    private static let lock = NSLock()

    static func formatter(currencyCode: String, locale: Locale = .current) -> NumberFormatter {
        let key = "\(currencyCode)|\(locale.identifier)"
        lock.lock()
        defer { lock.unlock() }
        if let existing = cache[key] { return existing }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = locale
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        cache[key] = formatter
        return formatter
    }

    static func string(from amount: Decimal, currencyCode: String, locale: Locale = .current) -> String {
        let ns = NSDecimalNumber(decimal: amount)
        return formatter(currencyCode: currencyCode, locale: locale).string(from: ns) ?? "\(amount)"
    }

    /// Compact whole-dollar display for large heroes when cents aren't useful.
    static func compact(from amount: Decimal, currencyCode: String, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = locale
        formatter.maximumFractionDigits = amount == amount.rounded(scale: 0) ? 0 : 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? string(from: amount, currencyCode: currencyCode, locale: locale)
    }

    static func signed(from amount: Decimal, currencyCode: String, showPlus: Bool = true, locale: Locale = .current) -> String {
        let absString = string(from: abs(amount), currencyCode: currencyCode, locale: locale)
        if amount > 0, showPlus { return "+\(absString)" }
        if amount < 0 { return "-\(absString)" }
        return absString
    }
}

extension Decimal {
    func rounded(scale: Int, mode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, mode)
        return result
    }

    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }

    static func from(_ string: String) -> Decimal? {
        let cleaned = string
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return Decimal(string: cleaned)
    }
}
