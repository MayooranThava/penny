import Foundation
import SwiftUI

/// Lightweight app-level preferences that complement SwiftData `UserSettings`.
@Observable
@MainActor
final class AppSession {
    var selectedMonth: Date = DateHelpers.startOfMonth()
    var showAddTransaction: Bool = false

    func resetMonth() {
        selectedMonth = DateHelpers.startOfMonth()
    }
}

enum SupportedCurrency: String, CaseIterable, Identifiable {
    case cad = "CAD"
    case usd = "USD"
    case gbp = "GBP"
    case eur = "EUR"
    case aud = "AUD"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cad: return "Canadian Dollar"
        case .usd: return "US Dollar"
        case .gbp: return "British Pound"
        case .eur: return "Euro"
        case .aud: return "Australian Dollar"
        }
    }

    var flag: String {
        switch self {
        case .cad: return "🇨🇦"
        case .usd: return "🇺🇸"
        case .gbp: return "🇬🇧"
        case .eur: return "🇪🇺"
        case .aud: return "🇦🇺"
        }
    }
}
