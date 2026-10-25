import SwiftUI

/// Short banner for a failed save. It does not block the screen the user is editing.
struct SaveErrorBanner: View {
    let message: String
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: PennySpacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(PennyColors.warning)
                .accessibilityHidden(true)
            Text(message)
                .font(PennyTypography.callout)
                .foregroundStyle(PennyColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Dismiss", action: onDismiss)
                .font(PennyTypography.caption.weight(.semibold))
                .foregroundStyle(PennyColors.brand)
        }
        .padding(PennySpacing.md)
        .background(PennyColors.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(PennyColors.warning.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityAction(named: "Dismiss", onDismiss)
    }
}
