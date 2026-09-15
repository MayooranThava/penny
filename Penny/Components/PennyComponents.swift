import SwiftUI
import UIKit

extension View {
    /// Suppresses iOS AutoFill (contacts, credit cards, passwords) and predictive
    /// suggestions in the keyboard accessory bar for a text field.
    ///
    /// Those suggestions are drawn from the *device owner's* saved data (their
    /// contact name, Wallet/Safari cards, etc.), so they must never be offered as
    /// input for Penny's local money values and user-defined labels. Setting an
    /// empty `UITextContentType` opts the field out of AutoFill heuristics.
    func pennyNoAutoFill() -> some View {
        textContentType(UITextContentType(rawValue: ""))
            .autocorrectionDisabled(true)
    }
}

struct PennyCard<Content: View>: View {
    var padding: CGFloat = PennySpacing.cardPadding
    var fill: Color = PennyColors.surface
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PennySpacing.radiusLg, style: .continuous)
                    .fill(fill)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
            )
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PennyTypography.sectionHeading)
                    .foregroundStyle(PennyColors.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(PennyTypography.caption)
                        .foregroundStyle(PennyColors.textSecondary)
                }
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(PennyTypography.caption)
                    .foregroundStyle(PennyColors.brand)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct MoneyText: View {
    let amount: Decimal
    var currencyCode: String = "CAD"
    var font: Font = PennyTypography.mediumAmount
    var color: Color = PennyColors.textPrimary
    var compact: Bool = false
    var signed: Bool = false

    var body: some View {
        Text(display)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color)
            .accessibilityLabel(accessibility)
    }

    private var display: String {
        if signed {
            return MoneyFormatters.signed(from: amount, currencyCode: currencyCode)
        }
        if compact {
            return MoneyFormatters.compact(from: amount, currencyCode: currencyCode)
        }
        return MoneyFormatters.string(from: amount, currencyCode: currencyCode)
    }

    private var accessibility: String {
        MoneyFormatters.string(from: amount, currencyCode: currencyCode)
    }
}

struct CategoryIcon: View {
    let icon: String
    let colourIdentifier: String
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(PennyColors.category(colourIdentifier).opacity(0.16))
                .frame(width: size, height: size)
            Image(systemName: icon)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(PennyColors.category(colourIdentifier))
        }
        .accessibilityHidden(true)
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: PennySpacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(PennyColors.brand)
                .frame(width: 72, height: 72)
                .background(Circle().fill(PennyColors.brandMuted))

            Text(title)
                .font(PennyTypography.cardTitle)
                .foregroundStyle(PennyColors.textPrimary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(PennyTypography.callout)
                .foregroundStyle(PennyColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PennySpacing.lg)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.pennyPrimary)
                    .frame(maxWidth: 260)
                    .padding(.top, PennySpacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PennySpacing.xxl)
        .accessibilityElement(children: .combine)
    }
}

struct ProgressCard: View {
    let title: String
    let spent: Decimal
    let budget: Decimal
    let currencyCode: String
    var health: FinanceCalculator.BudgetHealth = .healthy

    private var progress: Double {
        FinanceCalculator.budgetProgressClamped(budgeted: budget, spent: spent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PennySpacing.sm) {
            HStack {
                Text(title)
                    .font(PennyTypography.caption)
                    .foregroundStyle(PennyColors.textSecondary)
                Spacer()
                Text(health.accessibilityLabel)
                    .font(PennyTypography.footnote)
                    .foregroundStyle(healthColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(healthColor.opacity(0.12)))
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                MoneyText(amount: spent, currencyCode: currencyCode, font: PennyTypography.mediumAmount)
                Text("of")
                    .font(PennyTypography.callout)
                    .foregroundStyle(PennyColors.textSecondary)
                MoneyText(amount: budget, currencyCode: currencyCode, font: PennyTypography.smallAmount, color: PennyColors.textSecondary, compact: true)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(PennyColors.secondarySurface)
                    Capsule()
                        .fill(healthColor)
                        .frame(width: max(8, geo.size.width * progress))
                }
            }
            .frame(height: 8)
            .accessibilityLabel("\(Int(progress * 100)) percent of budget used")
        }
    }

    private var healthColor: Color {
        switch health {
        case .healthy: return PennyColors.healthy
        case .nearLimit: return PennyColors.nearLimit
        case .overBudget: return PennyColors.overBudget
        case .unset: return PennyColors.textTertiary
        }
    }
}

struct GoalProgressView: View {
    let name: String
    let current: Decimal
    let target: Decimal
    let currencyCode: String
    var icon: String = "target"
    var colourIdentifier: String = "savings"
    var estimatedCompletion: Date? = nil
    var compact: Bool = false

    private var progress: Double {
        FinanceCalculator.goalProgressClamped(current: current, target: target)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PennySpacing.sm) {
            HStack(spacing: PennySpacing.sm) {
                CategoryIcon(icon: icon, colourIdentifier: colourIdentifier, size: compact ? 36 : 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(PennyTypography.cardTitle)
                        .foregroundStyle(PennyColors.textPrimary)
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(PennyTypography.caption)
                        .foregroundStyle(PennyColors.savings)
                }
                Spacer(minLength: 0)
            }

            MoneyText(amount: current, currencyCode: currencyCode, font: compact ? PennyTypography.smallAmount : PennyTypography.mediumAmount)
            Text("of \(MoneyFormatters.compact(from: target, currencyCode: currencyCode))")
                .font(PennyTypography.caption)
                .foregroundStyle(PennyColors.textSecondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(PennyColors.secondarySurface)
                    Capsule()
                        .fill(PennyColors.savings)
                        .frame(width: max(6, geo.size.width * progress))
                }
            }
            .frame(height: 7)

            if let estimatedCompletion {
                Text("Estimated completion: \(DateHelpers.monthYear(for: estimatedCompletion))")
                    .font(PennyTypography.footnote)
                    .foregroundStyle(PennyColors.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(Int(progress * 100)) percent complete")
    }
}

struct BillRow: View {
    let name: String
    let dueDate: Date
    let amount: Decimal
    let currencyCode: String
    var icon: String = "doc.text.fill"
    var categoryName: String = "Other"

    var body: some View {
        HStack(spacing: PennySpacing.sm) {
            CategoryIcon(icon: icon, colourIdentifier: categoryName.lowercased())
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(PennyTypography.bodyEmphasized)
                    .foregroundStyle(PennyColors.textPrimary)
                Text(DateHelpers.shortMonthDay(for: dueDate))
                    .font(PennyTypography.caption)
                    .foregroundStyle(PennyColors.textSecondary)
            }
            Spacer()
            MoneyText(amount: amount, currencyCode: currencyCode, font: PennyTypography.smallAmount)
        }
        .accessibilityElement(children: .combine)
    }
}

struct TransactionRow: View {
    let title: String
    let categoryName: String
    let amount: Decimal
    let type: TransactionType
    let currencyCode: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: PennySpacing.sm) {
            CategoryIcon(
                icon: icon ?? CategoryCatalog.icon(for: categoryName),
                colourIdentifier: type == .income ? "income" : categoryName.lowercased()
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PennyTypography.bodyEmphasized)
                    .foregroundStyle(PennyColors.textPrimary)
                    .lineLimit(1)
                Text(categoryName)
                    .font(PennyTypography.caption)
                    .foregroundStyle(PennyColors.textSecondary)
            }
            Spacer()
            Text(MoneyFormatters.signed(
                from: type == .income ? amount : -amount,
                currencyCode: currencyCode
            ))
            .font(PennyTypography.smallAmount)
            .monospacedDigit()
            .foregroundStyle(type == .income ? PennyColors.income : PennyColors.textPrimary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

struct RingProgressView: View {
    var progress: Double
    var lineWidth: CGFloat = 12
    var trackColor: Color = PennyColors.secondarySurface
    var progressColor: Color = PennyColors.brand

    var body: some View {
        let clamped = min(1, max(0, progress))
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(progressColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .accessibilityHidden(true)
    }
}
