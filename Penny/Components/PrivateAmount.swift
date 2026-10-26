import Charts
import SwiftUI
import UIKit

enum PrivateAmountBackdrop {
    case surface
    case secondary
    case hero
}

struct PrivateAmount: View {
    var amount: Decimal
    var currencyCode: String
    var font: Font = PennyTypography.mediumAmount
    var color: Color = PennyColors.textPrimary
    var style: PrivateAmountLogic.Style = .standard
    var site: PrivateTotalSite
    var backdrop: PrivateAmountBackdrop = .surface
    var locale: Locale = .current

    @Environment(PrivateModeController.self) private var privateMode
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let privateOn = privateMode.isEnabled
        let appearance = maskAppearance
        let text = PrivateAmountLogic.display(
            amount: amount,
            currencyCode: currencyCode,
            style: style,
            isPrivate: privateOn,
            locale: locale
        )
        let spoken = PrivateAmountLogic.accessibilityText(
            amount: amount,
            currencyCode: currencyCode,
            style: style,
            isPrivate: privateOn,
            locale: locale
        )
        Text(text)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(privateOn ? appearance.color : color)
            .opacity(privateOn ? appearance.opacity : 1)
            .scaleEffect(privateOn ? dynamicScale : 1, anchor: .leading)
            .accessibilityLabel(spoken)
            .accessibilityIdentifier(site.rawValue)
            .animation(crossfade, value: privateMode.isEnabled)
    }

    private var maskAppearance: (color: Color, opacity: Double) {
        let style = PrivateAmountLogic.maskStyle(
            matching: color.privateSRGB(colorScheme),
            over: backgroundColors
        )
        return (
            Color(red: style.foreground.r, green: style.foreground.g, blue: style.foreground.b),
            style.opacity
        )
    }

    private var backgroundColors: [PrivateAmountLogic.SRGB] {
        switch backdrop {
        case .surface:
            return [PennyColors.surface.privateSRGB(colorScheme)]
        case .secondary:
            return [PennyColors.secondarySurface.privateSRGB(colorScheme)]
        case .hero:
            let theme = AccentTheme.active
            let stops: [Color] = colorScheme == .dark
                ? [theme.heroStartDark, theme.heroEndDark]
                : [theme.heroStartLight, theme.heroEndLight]
            return stops.map { $0.privateSRGB(colorScheme) }
        }
    }

    private var dynamicScale: CGFloat {
        let step: Int
        switch dynamicTypeSize {
        case .xSmall: step = 0
        case .small: step = 1
        case .medium: step = 2
        case .large: step = 3
        case .xLarge: step = 4
        case .xxLarge: step = 5
        case .xxxLarge: step = 6
        case .accessibility1: step = 7
        case .accessibility2: step = 8
        case .accessibility3: step = 9
        case .accessibility4: step = 10
        case .accessibility5: step = 11
        default: step = 3
        }
        return CGFloat(PrivateAmountLogic.dynamicTypeScale(step: step))
    }

    private var crossfade: Animation? {
        let seconds = PrivateAmountLogic.crossfadeSeconds(
            reduceMotion: reduceMotion,
            animationsSuppressed: privateMode.animationsSuppressed
        )
        return seconds == 0 ? nil : .easeInOut(duration: seconds)
    }
}

struct PrivateModeEyeButton: View {
    var onBrand = false
    @Environment(PrivateModeController.self) private var privateMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            privateMode.toggle()
            Haptics.light()
        } label: {
            Image(systemName: PrivateAmountLogic.eyeSymbol(isPrivate: privateMode.isEnabled))
                .font(.body.weight(.semibold))
                .foregroundStyle(onBrand ? PennyColors.textOnBrand : PennyColors.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PrivateAmountLogic.eyeAccessibilityLabel(isPrivate: privateMode.isEnabled))
        .animation(
            reduceMotion ? nil : .easeInOut(duration: PrivateAmountLogic.crossfadeSeconds),
            value: privateMode.isEnabled
        )
    }
}

struct PrivateInsightBlock: View {
    var title: String
    var detail: String
    var includesTotal: Bool
    @Environment(PrivateModeController.self) private var privateMode

    var body: some View {
        let shown = PrivateInsightText.present(
            title: title,
            detail: detail,
            includesTotal: includesTotal,
            isPrivate: privateMode.isEnabled,
            site: .insightSentence
        )
        VStack(alignment: .leading, spacing: 4) {
            Text(shown.title)
                .font(PennyTypography.bodyEmphasized)
                .foregroundStyle(PennyColors.textPrimary)
            Text(shown.detail)
                .font(PennyTypography.caption)
                .foregroundStyle(PennyColors.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(shown.accessibilityTitle). \(shown.accessibilityDetail)")
    }
}

struct PrivateGoalPaceText: View {
    var monthlyRequired: Decimal
    var target: Decimal
    var currencyCode: String
    var dateLabel: String
    var legalSuffix: String = ""
    @Environment(PrivateModeController.self) private var privateMode

    var body: some View {
        let monthly = MoneyFormatters.compact(from: monthlyRequired, currencyCode: currencyCode)
        let targetText = MoneyFormatters.compact(from: target, currencyCode: currencyCode)
        let sentence = PrivateAmountLogic.goalPaceSentence(
            monthlyRequired: monthly,
            target: targetText,
            dateLabel: dateLabel,
            isPrivate: privateMode.isEnabled
        ) + legalSuffix
        let spokenTarget = privateMode.isEnabled
            ? PrivateAmountLogic.hiddenAccessibilityLabel
            : targetText
        Text(sentence)
            .accessibilityLabel("About \(monthly) per month to reach \(spokenTarget) by \(dateLabel)")
    }
}

struct PrivateSafeToSpendLabel: ViewModifier {
    var amount: Decimal
    var currencyCode: String
    @Environment(PrivateModeController.self) private var privateMode

    func body(content: Content) -> some View {
        let spoken = PrivateAmountLogic.accessibilityText(
            amount: amount,
            currencyCode: currencyCode,
            style: .standard,
            isPrivate: privateMode.isEnabled,
            locale: .current
        )
        content.accessibilityLabel(
            "Safe to spend \(spoken). Estimate from your entries. See Terms of Use."
        )
    }
}

struct PrivateBudgetSummaryLabel: ViewModifier {
    var percent: Int
    var remaining: Decimal
    var currencyCode: String
    @Environment(PrivateModeController.self) private var privateMode

    func body(content: Content) -> some View {
        let spoken = PrivateAmountLogic.accessibilityText(
            amount: remaining,
            currencyCode: currencyCode,
            style: .standard,
            isPrivate: privateMode.isEnabled,
            locale: .current
        )
        content.accessibilityLabel("Budget \(percent) percent used. Remaining \(spoken)")
    }
}

struct PrivateForecastChartLabel: ViewModifier {
    var lines: [(label: String, amount: Decimal)]
    var currencyCode: String
    @Environment(PrivateModeController.self) private var privateMode

    func body(content: Content) -> some View {
        let text = lines.map { line in
            let spoken = PrivateAmountLogic.accessibilityText(
                amount: line.amount,
                currencyCode: currencyCode,
                style: .standard,
                isPrivate: privateMode.isEnabled,
                locale: .current
            )
            return "\(line.label): \(spoken)"
        }.joined(separator: ". ")
        content.accessibilityLabel(text)
    }
}

extension View {
    @ViewBuilder
    func privateCurrencyYAxis(isPrivate: Bool, site: PrivateTotalSite) -> some View {
        if isPrivate {
            self.chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                    AxisValueLabel {
                        Text(PrivateAmountLogic.mask)
                            .accessibilityLabel(PrivateAmountLogic.hiddenAccessibilityLabel)
                            .accessibilityIdentifier(site.rawValue)
                    }
                }
            }
        } else {
            self.accessibilityIdentifier(site.rawValue)
        }
    }
}

private struct PrivateCurrencyAxisReader: View {
    var isPrivate: Bool {
        controller.isEnabled
    }
    @Environment(PrivateModeController.self) private var controller
    var site: PrivateTotalSite
    var chart: AnyView

    var body: some View {
        chart.privateCurrencyYAxis(isPrivate: isPrivate, site: site)
    }
}

extension View {
    /// Y-axis money labels follow private mode without the parent recomputing the series.
    func privateModeYAxis(site: PrivateTotalSite) -> some View {
        PrivateCurrencyAxisReader(site: site, chart: AnyView(self))
    }
}

extension Color {
    func privateSRGB(_ scheme: ColorScheme) -> PrivateAmountLogic.SRGB {
        let style: UIUserInterfaceStyle = scheme == .dark ? .dark : .light
        let resolved = UIColor(self).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return PrivateAmountLogic.SRGB(r: 0, g: 0, b: 0)
        }
        return PrivateAmountLogic.SRGB(r: Double(red), g: Double(green), b: Double(blue))
    }
}
