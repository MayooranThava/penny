import SwiftUI

/// Accent colour themes. Mint is free; other accents unlock with Penny Pro.
enum AccentTheme: String, Codable, CaseIterable, Identifiable {
    case mint
    case ocean
    case slate
    case amber

    /// Active theme used by `PennyColors` computed tokens. Updated from Settings / RootView.
    nonisolated(unsafe) static var active: AccentTheme = .mint

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mint: return "Mint"
        case .ocean: return "Ocean"
        case .slate: return "Slate"
        case .amber: return "Amber"
        }
    }

    /// Only Mint is available without Penny Pro.
    var requiresPro: Bool { self != .mint }

    // MARK: - Brand (primary accent)

    var brandLight: Color {
        switch self {
        case .mint: return Color(red: 0.12, green: 0.62, blue: 0.48)
        case .ocean: return Color(red: 0.14, green: 0.45, blue: 0.72)
        case .slate: return Color(red: 0.28, green: 0.36, blue: 0.46)
        case .amber: return Color(red: 0.78, green: 0.52, blue: 0.14)
        }
    }

    var brandDark: Color {
        switch self {
        case .mint: return Color(red: 0.30, green: 0.82, blue: 0.66)
        case .ocean: return Color(red: 0.40, green: 0.72, blue: 0.95)
        case .slate: return Color(red: 0.62, green: 0.70, blue: 0.80)
        case .amber: return Color(red: 0.96, green: 0.74, blue: 0.32)
        }
    }

    // MARK: - Success / healthy (same family as brand)

    var successLight: Color { brandLight }
    var successDark: Color { brandDark }

    // MARK: - Caution (near-limit) — distinct from brand within each theme

    var warningLight: Color {
        switch self {
        case .mint: return Color(red: 0.86, green: 0.58, blue: 0.12)
        case .ocean: return Color(red: 0.90, green: 0.55, blue: 0.18)
        case .slate: return Color(red: 0.82, green: 0.56, blue: 0.22)
        // Amber brand is already warm — push caution toward deeper orange/coral.
        case .amber: return Color(red: 0.88, green: 0.38, blue: 0.16)
        }
    }

    var warningDark: Color {
        switch self {
        case .mint: return Color(red: 0.96, green: 0.72, blue: 0.28)
        case .ocean: return Color(red: 0.98, green: 0.70, blue: 0.32)
        case .slate: return Color(red: 0.94, green: 0.70, blue: 0.36)
        case .amber: return Color(red: 1.00, green: 0.55, blue: 0.32)
        }
    }

    // MARK: - Secondary accent (goals / savings bars)

    var secondaryLight: Color {
        switch self {
        case .mint: return Color(red: 0.18, green: 0.48, blue: 0.72)
        case .ocean: return Color(red: 0.22, green: 0.58, blue: 0.68)
        case .slate: return Color(red: 0.36, green: 0.48, blue: 0.62)
        case .amber: return Color(red: 0.62, green: 0.40, blue: 0.22)
        }
    }

    var secondaryDark: Color {
        switch self {
        case .mint: return Color(red: 0.45, green: 0.72, blue: 0.95)
        case .ocean: return Color(red: 0.48, green: 0.82, blue: 0.90)
        case .slate: return Color(red: 0.58, green: 0.70, blue: 0.84)
        case .amber: return Color(red: 0.88, green: 0.62, blue: 0.38)
        }
    }

    // MARK: - Soft page wash

    var softWashLight: Color {
        switch self {
        case .mint: return Color(red: 0.94, green: 0.96, blue: 0.94)
        case .ocean: return Color(red: 0.93, green: 0.95, blue: 0.97)
        case .slate: return Color(red: 0.94, green: 0.94, blue: 0.95)
        case .amber: return Color(red: 0.97, green: 0.95, blue: 0.91)
        }
    }

    var softWashDark: Color {
        switch self {
        case .mint: return Color(red: 0.06, green: 0.09, blue: 0.09)
        case .ocean: return Color(red: 0.06, green: 0.08, blue: 0.11)
        case .slate: return Color(red: 0.07, green: 0.08, blue: 0.10)
        case .amber: return Color(red: 0.09, green: 0.07, blue: 0.05)
        }
    }

    // MARK: - Hero

    var heroStartLight: Color {
        switch self {
        case .mint: return Color(red: 0.10, green: 0.55, blue: 0.45)
        case .ocean: return Color(red: 0.10, green: 0.40, blue: 0.68)
        case .slate: return Color(red: 0.22, green: 0.30, blue: 0.40)
        case .amber: return Color(red: 0.72, green: 0.46, blue: 0.12)
        }
    }

    var heroEndLight: Color {
        switch self {
        case .mint: return Color(red: 0.08, green: 0.42, blue: 0.48)
        case .ocean: return Color(red: 0.08, green: 0.28, blue: 0.52)
        case .slate: return Color(red: 0.14, green: 0.18, blue: 0.26)
        case .amber: return Color(red: 0.55, green: 0.32, blue: 0.10)
        }
    }

    var heroStartDark: Color {
        switch self {
        case .mint: return Color(red: 0.12, green: 0.42, blue: 0.38)
        case .ocean: return Color(red: 0.10, green: 0.30, blue: 0.48)
        case .slate: return Color(red: 0.16, green: 0.20, blue: 0.28)
        case .amber: return Color(red: 0.42, green: 0.28, blue: 0.10)
        }
    }

    var heroEndDark: Color {
        switch self {
        case .mint: return Color(red: 0.08, green: 0.28, blue: 0.36)
        case .ocean: return Color(red: 0.06, green: 0.18, blue: 0.36)
        case .slate: return Color(red: 0.08, green: 0.10, blue: 0.16)
        case .amber: return Color(red: 0.28, green: 0.16, blue: 0.06)
        }
    }

    /// Resolve a stored preference, falling back to mint for unknown values.
    static func resolved(_ raw: String?) -> AccentTheme {
        AccentTheme(rawValue: raw ?? "") ?? .mint
    }

    /// Theme actually applied: non-Pro users always get mint.
    static func effective(storedRaw: String?, isPro: Bool) -> AccentTheme {
        let stored = resolved(storedRaw)
        if stored.requiresPro && !isPro { return .mint }
        return stored
    }
}
