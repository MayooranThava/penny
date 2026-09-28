import Foundation

/// Declares app metadata constants used in Settings / About.
enum PennyAppInfo {
    static let displayName = "Penny"
    static let marketingVersion = "1.0.2"
    static let buildNumber = "1"
    static let privacySummary =
        "Penny stores financial data on-device. No bank connections, analytics, or advertising tracking."

    /// GitHub Pages (same pattern as Void Runner). Keep in sync with `docs/` + App Store Connect.
    static let privacyPolicyURL = URL(string: "https://mayooranthava.github.io/penny/privacy-policy.html")!
    static let termsOfUseURL = URL(string: "https://mayooranthava.github.io/penny/terms-of-use.html")!
    static let supportURL = URL(string: "https://mayooranthava.github.io/penny/support.html")!
    static let appleStandardEULA =
        URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
