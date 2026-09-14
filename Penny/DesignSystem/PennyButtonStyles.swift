import SwiftUI

struct PennyPrimaryButtonStyle: ButtonStyle {
    var isDestructive: Bool = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PennyTypography.bodyEmphasized)
            .foregroundStyle(PennyColors.textOnBrand)
            .frame(maxWidth: .infinity)
            .frame(minHeight: PennySpacing.minTapTarget)
            .padding(.horizontal, PennySpacing.md)
            .background(
                RoundedRectangle(cornerRadius: PennySpacing.radiusMd, style: .continuous)
                    .fill(isDestructive ? PennyColors.expense : PennyColors.brand)
                    .opacity(isEnabled ? (configuration.isPressed ? 0.88 : 1) : 0.45)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(PennyAnimation.quick, value: configuration.isPressed)
    }
}

struct PennySecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PennyTypography.bodyEmphasized)
            .foregroundStyle(PennyColors.brand)
            .frame(maxWidth: .infinity)
            .frame(minHeight: PennySpacing.minTapTarget)
            .padding(.horizontal, PennySpacing.md)
            .background(
                RoundedRectangle(cornerRadius: PennySpacing.radiusMd, style: .continuous)
                    .fill(PennyColors.brandMuted)
                    .opacity(configuration.isPressed ? 0.7 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(PennyAnimation.quick, value: configuration.isPressed)
    }
}

struct PennyDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PennyPrimaryButtonStyle(isDestructive: true).makeBody(configuration: configuration)
    }
}

extension ButtonStyle where Self == PennyPrimaryButtonStyle {
    static var pennyPrimary: PennyPrimaryButtonStyle { PennyPrimaryButtonStyle() }
}

extension ButtonStyle where Self == PennySecondaryButtonStyle {
    static var pennySecondary: PennySecondaryButtonStyle { PennySecondaryButtonStyle() }
}

extension ButtonStyle where Self == PennyDestructiveButtonStyle {
    static var pennyDestructive: PennyDestructiveButtonStyle { PennyDestructiveButtonStyle() }
}
