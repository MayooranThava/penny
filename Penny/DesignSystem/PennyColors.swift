import SwiftUI
import UIKit

/// Semantic color tokens for Penny's warm modern finance identity.
/// Brand, healthy/progress, savings, and caution hues follow `AccentTheme.active`.
/// Expense/debt stay fixed reds so overspending remains unambiguous.
enum PennyColors {
    private static var theme: AccentTheme { AccentTheme.active }

    static var brand: Color {
        Color(light: theme.brandLight, dark: theme.brandDark)
    }

    static var brandMuted: Color {
        Color(light: theme.brandLight.opacity(0.14), dark: theme.brandDark.opacity(0.18))
    }

    /// Semantic alias used throughout the app
    static var primary: Color { brand }
    static var primarySoft: Color { brandMuted }

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

    // MARK: - Semantic finance (theme-aware where it should feel “on brand”)

    /// Positive money / within-budget — same family as the accent.
    static var income: Color {
        Color(light: theme.successLight, dark: theme.successDark)
    }

    /// Overspend stays a fixed red across themes for clarity.
    static let expense = Color(light: Color(red: 0.82, green: 0.32, blue: 0.28),
                               dark: Color(red: 0.95, green: 0.48, blue: 0.42))

    /// Goals / secondary progress — complementary hue of the active theme.
    static var savings: Color {
        Color(light: theme.secondaryLight, dark: theme.secondaryDark)
    }

    /// Near-limit caution — theme-tuned so it doesn’t collide with amber brand.
    static var warning: Color {
        Color(light: theme.warningLight, dark: theme.warningDark)
    }

    static let debt = Color(light: Color(red: 0.72, green: 0.28, blue: 0.38),
                            dark: Color(red: 0.92, green: 0.48, blue: 0.55))

    // MARK: - Status (not color-only; paired with symbols/labels)

    static var healthy: Color { income }
    static var nearLimit: Color { warning }
    static var overBudget: Color { expense }

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

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(light: theme.heroStartLight, dark: theme.heroStartDark),
                Color(light: theme.heroEndLight, dark: theme.heroEndDark)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var softBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                background,
                Color(light: theme.softWashLight, dark: theme.softWashDark)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}
