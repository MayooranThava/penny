import Foundation

/// Declares app metadata constants used in Settings / About.
enum PennyAppInfo {
    static let displayName = "Penny"
    static let marketingVersion = "1.1"
    static let buildNumber = "1"
    /// Settings → Legal & privacy footnote. The view prefixes `LegalCopy.asterisk`.
    static let privacySummary =
        "Penny keeps your financial info on your iPhone and never sends it to us. Purchases are handled by Apple, and Apple may share crash reports with us only if you've turned that on in your iPhone settings."

    /// GitHub Pages (same pattern as Void Runner). Keep in sync with `docs/` + App Store Connect.
    static let privacyPolicyURL = URL(string: "https://mayooranthava.github.io/penny/privacy-policy.html")!
    static let termsOfUseURL = URL(string: "https://mayooranthava.github.io/penny/terms-of-use.html")!
    static let supportURL = URL(string: "https://mayooranthava.github.io/penny/support.html")!
    static let appleStandardEULA =
        URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
