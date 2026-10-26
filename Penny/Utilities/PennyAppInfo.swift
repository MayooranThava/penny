import Foundation

/// Declares app metadata constants used in Settings / About.
enum PennyAppInfo {
    static let displayName = "Penny"
    static let marketingVersion = "1.1"
    /// `CFBundleVersion`, which Xcode sets from `CURRENT_PROJECT_VERSION`.
    /// Settings shows this. There is no second hardcoded build number.
    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "4"
    }
    /// Settings → Legal & privacy. One asterisk, then these lines in order.
    static let privacySummary =
        "Penny keeps your financial info on your iPhone and never sends it to us. Purchases are handled by Apple, and Apple may share crash reports with us only if you've turned that on in your iPhone settings."
    static let budgetingDisclaimer =
        "Penny is a budgeting tool, not financial, tax or investment advice. Amounts are estimates based on what you enter and may not match your bank."
    static let localCaptureSummary =
        "Penny doesn't connect to your bank. Wallet tap capture and widgets keep their data on this iPhone."
    static let deletionSummary =
        "Deleting Penny or using Reset permanently erases your data from this iPhone."
    static let audienceSummary =
        "Intended for adults; not directed to children under 13. Full details are in the Terms of Use."
    static let settingsFootnote = [
        privacySummary,
        budgetingDisclaimer,
        localCaptureSummary,
        deletionSummary,
        audienceSummary
    ]

    /// GitHub Pages (same pattern as Void Runner). Keep in sync with `docs/` + App Store Connect.
    static let privacyPolicyURL = URL(string: "https://mayooranthava.github.io/penny/privacy-policy.html")!
    static let termsOfUseURL = URL(string: "https://mayooranthava.github.io/penny/terms-of-use.html")!
    static let supportURL = URL(string: "https://mayooranthava.github.io/penny/support.html")!
    static let appleStandardEULA =
        URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
