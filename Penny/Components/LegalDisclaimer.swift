import SwiftUI

/// Legal copy lives primarily in Terms of Use. In-app surfaces use a quiet asterisk.
enum LegalCopy {
    /// Shown next to estimate labels (Safe to Spend*, Estimated payoff*, etc.).
    static let asterisk = "*"

    /// One-line footnote used sparingly (paywall / onboarding). Full text is in Terms.
    static let termsFootnote = "Estimates from your entries — not financial advice."
}

/// Tiny asterisk for estimate labels. Accessibility spells out the meaning.
struct EstimateAsterisk: View {
    var onBrand = false

    var body: some View {
        Text(LegalCopy.asterisk)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(onBrand ? PennyColors.textOnBrand.opacity(0.75) : PennyColors.textTertiary)
            .accessibilityLabel("Estimate. See Terms of Use for details.")
    }
}

/// Minimal footnote: "* … Terms" — use once per screen max, not on every card.
struct EstimateTermsFootnote: View {
    var onBrand = false

    private var textColor: Color {
        onBrand ? PennyColors.textOnBrand.opacity(0.7) : PennyColors.textTertiary
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(LegalCopy.asterisk)
                .font(PennyTypography.caption)
            Text(LegalCopy.termsFootnote)
                .font(PennyTypography.caption)
            Link("Terms", destination: PennyAppInfo.termsOfUseURL)
                .font(PennyTypography.caption)
        }
        .foregroundStyle(textColor)
        .tint(onBrand ? PennyColors.textOnBrand.opacity(0.9) : PennyColors.brand)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
