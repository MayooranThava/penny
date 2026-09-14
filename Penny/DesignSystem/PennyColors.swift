import SwiftUI
import UIKit

/// Semantic color tokens for Penny's warm modern finance identity.
/// Primary: fresh mint/emerald. Supporting: cream, charcoal, soft blue, amber.
enum PennyColors {
    // Fallback adaptive colors (canonical brand tokens)
    static let brand = Color(light: Color(red: 0.12, green: 0.62, blue: 0.48),
                             dark: Color(red: 0.30, green: 0.82, blue: 0.66))
    static let brandMuted = Color(light: Color(red: 0.12, green: 0.62, blue: 0.48).opacity(0.14),
                                  dark: Color(red: 0.30, green: 0.82, blue: 0.66).opacity(0.18))

    /// Semantic alias used throughout the app
    static let primary = brand
    static let primarySoft = brandMuted

    // MARK: - Surfaces

    static let background = Color(light: Color(red: 0.97, green: 0.96, blue: 0.94),
                                  dark: Color(red: 0.07, green: 0.08, blue: 0.09))
    static let surface = Color(light: .white,
                               dark: Color(red: 0.12, green: 0.13, blue: 0.15))
    static let secondarySurface = Color(light: Color(red: 0.94, green: 0.93, blue: 0.90),
                                        dark: Color(red: 0.16, green: 0.17, blue: 0.19))
    static let elevated = Color(light: .white,
                                dark: Color(red: 0.18, green: 0.19, blue: 0.22))

    // MARK: - Text

    static let textPrimary = Color(light: Color(red: 0.12, green: 0.14, blue: 0.16),
                                   dark: Color(red: 0.96, green: 0.96, blue: 0.95))
    static let textSecondary = Color(light: Color(red: 0.42, green: 0.45, blue: 0.48),
                                     dark: Color(red: 0.68, green: 0.70, blue: 0.72))
    static let textTertiary = Color(light: Color(red: 0.58, green: 0.60, blue: 0.62),
                                    dark: Color(red: 0.52, green: 0.54, blue: 0.56))
    static let textOnBrand = Color.white

    // MARK: - Semantic finance

    static let income = Color(light: Color(red: 0.10, green: 0.55, blue: 0.42),
                              dark: Color(red: 0.35, green: 0.85, blue: 0.65))
    static let expense = Color(light: Color(red: 0.82, green: 0.32, blue: 0.28),
                               dark: Color(red: 0.95, green: 0.48, blue: 0.42))
    static let savings = Color(light: Color(red: 0.18, green: 0.48, blue: 0.72),
                               dark: Color(red: 0.45, green: 0.72, blue: 0.95))
    static let warning = Color(light: Color(red: 0.86, green: 0.58, blue: 0.12),
                               dark: Color(red: 0.96, green: 0.72, blue: 0.28))
    static let debt = Color(light: Color(red: 0.72, green: 0.28, blue: 0.38),
                            dark: Color(red: 0.92, green: 0.48, blue: 0.55))

    // MARK: - Status (not color-only; paired with symbols/labels)

    static let healthy = income
    static let nearLimit = warning
    static let overBudget = expense

    // MARK: - Category accents

    static func category(_ identifier: String) -> Color {
        switch identifier.lowercased() {
        case "housing": return Color(red: 0.35, green: 0.45, blue: 0.72)
        case "food": return Color(red: 0.90, green: 0.55, blue: 0.20)
        case "transportation": return Color(red: 0.25, green: 0.58, blue: 0.62)
        case "shopping": return Color(red: 0.72, green: 0.38, blue: 0.58)
        case "entertainment": return Color(red: 0.58, green: 0.42, blue: 0.78)
        case "health": return Color(red: 0.28, green: 0.68, blue: 0.52)
        case "subscriptions": return Color(red: 0.42, green: 0.52, blue: 0.68)
        case "travel": return Color(red: 0.20, green: 0.62, blue: 0.78)
        case "savings": return savings
        case "income": return income
        default: return Color(red: 0.52, green: 0.54, blue: 0.56)
        }
    }

    // MARK: - Gradients

    static let heroGradient = LinearGradient(
        colors: [
            Color(light: Color(red: 0.10, green: 0.55, blue: 0.45),
                  dark: Color(red: 0.12, green: 0.42, blue: 0.38)),
            Color(light: Color(red: 0.08, green: 0.42, blue: 0.48),
                  dark: Color(red: 0.08, green: 0.28, blue: 0.36))
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let softBackgroundGradient = LinearGradient(
        colors: [
            background,
            Color(light: Color(red: 0.94, green: 0.96, blue: 0.94),
                  dark: Color(red: 0.06, green: 0.09, blue: 0.09))
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Adaptive color helper

extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}
