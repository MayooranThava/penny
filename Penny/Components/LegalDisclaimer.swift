import SwiftUI

/// Short, reusable “not financial advice / estimates only” copy for finance surfaces.
enum LegalCopy {
    static let notAdviceShort =
        "Penny is a planning tool, not financial, tax, or investment advice. Figures are estimates from the numbers you enter."

    static let safeToSpendFootnote =
        "Based on your entries — not a bank balance. Estimates only; not financial advice."

    static let debtFootnote =
        "Payoff and interest figures are simplified estimates from the balance, rate, and payment you entered — not a lender quote."

    static let insightsFootnote =
        "Insights summarize your entries. They are not personalized financial advice."

    static let onboardingDisclaimer =
        "Penny helps you plan with numbers you enter. It is not financial, tax, or investment advice, and estimates are not guarantees."
}

struct LegalDisclaimerBanner: View {
    var text: String = LegalCopy.notAdviceShort
    var symbolName: String = "info.circle"

    var body: some View {
        HStack(alignment: .top, spacing: PennySpacing.sm) {
            Image(systemName: symbolName)
                .font(.body)
                .foregroundStyle(PennyColors.textSecondary)
                .accessibilityHidden(true)
            Text(text)
                .font(PennyTypography.caption)
                .foregroundStyle(PennyColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(PennySpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PennySpacing.radiusMd, style: .continuous)
                .fill(PennyColors.secondarySurface)
        )
        .accessibilityElement(children: .combine)
    }
}
