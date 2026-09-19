import Foundation

/// Declares app metadata constants used in Settings / About.
enum PennyAppInfo {
    static let displayName = "Penny"
    static let marketingVersion = "1.0.0"
    static let buildNumber = "1"
    static let privacySummary = "Penny stores financial data on-device only. No bank connections, analytics, or tracking in this prototype."

    /// GitHub Pages (same pattern as Void Runner). Keep in sync with `docs/` + App Store Connect.
    static let privacyPolicyURL = URL(string: "https://mayooranthava.github.io/penny/privacy-policy.html")!
    static let supportURL = URL(string: "https://mayooranthava.github.io/penny/support.html")!
}
