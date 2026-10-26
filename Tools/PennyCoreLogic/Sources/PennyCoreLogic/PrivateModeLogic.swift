import Foundation

/// Display rules for Private mode. Masking never changes stored amounts.
public enum PrivateAmountLogic {
    public static let dot = "●"
    public static let maskCount = 5
    public static let rowDotCount = 3
    /// Five-dot mask kept for widgets, insights, and any total outside the calmer treatment.
    public static let mask = "●●●●●"
    /// Widget and legacy in-app opacity. Home Screen and Lock Screen widgets read this directly.
    public static let maskOpacity = 0.60
    /// Safe to Spend hero dots. Raised only when 40% misses the graphic contrast floor.
    public static let heroDotOpacity = 0.40
    /// Row, category, and Includes-line dots. Raised only when 30% misses the floor.
    public static let rowDotOpacity = 0.30
    /// A filled bullet at the amount's font is about an em tall. This scale brings
    /// the dot down to the cap height of the digits it replaces.
    public static let dotCapHeightScale = 0.72
    /// Dots are non-text graphics. 3:1 against the surface replaces the old 4.5:1
    /// text-contrast clamp. Prefer the role's opacity, then raise just enough to pass.
    public static let minimumContrast = 3.0
    public static let monthlySuffix = "/mo"
    public static let crossfadeSeconds = 0.2
    public static let hiddenAccessibilityLabel = "Hidden amount"
    public static let hideTotalsLabel = "Hide totals"
    public static let showTotalsLabel = "Show totals"
    /// Spoken Shortcuts title. The phrase uses the app name so it reads “Toggle Penny private mode”.
    public static let shortcutTitle = "Toggle Penny private mode"

    public enum Style: Equatable {
        case standard
        case compact
        case signed(showPlus: Bool)
    }

    /// One place for dot count, opacity, and size. Views read this instead of
    /// picking their own numbers.
    public struct DotStyle: Equatable {
        public var count: Int
        public var text: String
        public var preferredOpacity: Double
        public var glyphScale: Double
    }

    public static func dotStyle(for site: PrivateTotalSite) -> DotStyle {
        switch site {
        case .homeSafeToSpendHero:
            return DotStyle(
                count: maskCount,
                text: mask,
                preferredOpacity: heroDotOpacity,
                glyphScale: dotCapHeightScale
            )
        case .homeBreakdownIncome,
             .homeBreakdownBills,
             .homeBreakdownDebtPayments,
             .homeBreakdownSpent,
             .homeBreakdownGoals,
             .homeBreakdownSafeToSpend,
             .budgetIncome,
             .budgetPlanned,
             .budgetSpent,
             .budgetRemaining,
             .budgetCategorySpent,
             .budgetCategoryBudgeted,
             .budgetCategoryRemaining,
             .homeIncludesDebtTarget,
             .homeIncludesGoalTarget:
            return DotStyle(
                count: rowDotCount,
                text: String(repeating: dot, count: rowDotCount),
                preferredOpacity: rowDotOpacity,
                glyphScale: dotCapHeightScale
            )
        case .homeSpendingSpent,
             .homeSpendingBudget,
             .homeNetWorth,
             .budgetTrendAxis,
             .planGoalSaved,
             .planGoalTarget,
             .planBillsMonthlyTotal,
             .planDebtBalance,
             .planDebtInterest,
             .planForecastTotal,
             .planForecastAxis,
             .accountBalance,
             .accountsNetWorth,
             .activityDailySum,
             .activityMonthlySum,
             .insightSentence,
             .widgetSafeToSpend,
             .widgetLockScreenSafeToSpend,
             .widgetMonthlyBudgetSpent,
             .widgetMonthlyBudgetPlanned,
             .widgetSavingsGoal,
             .widgetReminderSafeToSpend:
            return DotStyle(
                count: maskCount,
                text: mask,
                preferredOpacity: maskOpacity,
                glyphScale: 1
            )
        }
    }

    public struct SRGB: Equatable {
        public var r: Double
        public var g: Double
        public var b: Double

        public var relativeLuminance: Double {
            func linear(_ channel: Double) -> Double {
                let c = min(max(channel, 0), 1)
                if c <= 0.04045 { return c / 12.92 }
                return pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        }
    }

    public static func formatted(
        amount: Decimal,
        currencyCode: String,
        style: Style,
        locale: Locale
    ) -> String {
        switch style {
        case .standard:
            return MoneyFormatters.string(from: amount, currencyCode: currencyCode, locale: locale)
        case .compact:
            return MoneyFormatters.compact(from: amount, currencyCode: currencyCode, locale: locale)
        case .signed(let showPlus):
            return MoneyFormatters.signed(
                from: amount,
                currencyCode: currencyCode,
                showPlus: showPlus,
                locale: locale
            )
        }
    }

    /// Totals become dots. The hero keeps five; listed rows use three.
    /// Callers that omit `site` keep the five-dot widget mask.
    /// Individual amounts pass `isTotal: false` and stay exact.
    public static func display(
        amount: Decimal,
        currencyCode: String,
        style: Style,
        isPrivate: Bool,
        isTotal: Bool = true,
        site: PrivateTotalSite? = nil,
        locale: Locale
    ) -> String {
        if isPrivate && isTotal {
            if let site { return dotStyle(for: site).text }
            return mask
        }
        return formatted(amount: amount, currencyCode: currencyCode, style: style, locale: locale)
    }

    /// Visible amounts may keep a suffix such as "/mo". A mask never does, so the
    /// suffix cannot hint at the size of a hidden Includes amount.
    public static func displayWithTrailing(
        amount: Decimal,
        currencyCode: String,
        style: Style,
        isPrivate: Bool,
        isTotal: Bool = true,
        site: PrivateTotalSite? = nil,
        trailing: String = "",
        locale: Locale
    ) -> String {
        let base = display(
            amount: amount,
            currencyCode: currencyCode,
            style: style,
            isPrivate: isPrivate,
            isTotal: isTotal,
            site: site,
            locale: locale
        )
        if isPrivate || trailing.isEmpty { return base }
        return base + trailing
    }

    /// Category rows show spent and budget side by side. Private mode collapses
    /// that pair to one mask so the row does not read as two hidden totals.
    public static func showsPairedCategoryAmounts(isPrivate: Bool) -> Bool {
        !isPrivate
    }

    public static func categoryAmountLine(spent: String, budgeted: String, isPrivate: Bool) -> String {
        if isPrivate { return dotStyle(for: .budgetCategorySpent).text }
        return "\(spent) / \(budgeted)"
    }

    public static func accessibilityText(
        amount: Decimal,
        currencyCode: String,
        style: Style,
        isPrivate: Bool,
        isTotal: Bool = true,
        locale: Locale
    ) -> String {
        if isPrivate && isTotal { return hiddenAccessibilityLabel }
        return formatted(amount: amount, currencyCode: currencyCode, style: style, locale: locale)
    }

    public static func eyeSymbol(isPrivate: Bool) -> String {
        isPrivate ? "eye.slash" : "eye"
    }

    public static func eyeAccessibilityLabel(isPrivate: Bool) -> String {
        isPrivate ? showTotalsLabel : hideTotalsLabel
    }

    public static func crossfadeSeconds(reduceMotion: Bool, animationsSuppressed: Bool) -> Double {
        (reduceMotion || animationsSuppressed) ? 0 : crossfadeSeconds
    }

    /// Dynamic Type steps, xSmall = 0 through accessibility5 = 11. Large is 1.
    public static func dynamicTypeScale(step: Int) -> Double {
        let scales = [0.82, 0.88, 0.94, 1.0, 1.12, 1.23, 1.35, 1.64, 1.94, 2.35, 2.76, 3.12]
        let index = min(max(step, 0), scales.count - 1)
        return scales[index]
    }

    public static func containsDigit(_ text: String) -> Bool {
        text.unicodeScalars.contains { CharacterSet.decimalDigits.contains($0) }
    }

    /// True when `text` contains a currency amount. Same pattern `maskCurrencyAmounts` uses.
    /// Percents, dates, and the "Hidden amount" label do not match.
    public static func containsCurrencyAmount(_ text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: currencyPattern) else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }

    public static func maskCurrencyAmounts(in text: String, replacement: String = mask) -> String {
        let pattern = currencyPattern
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        guard !matches.isEmpty else { return text }
        var result = text
        for match in matches.reversed() {
            guard let swiftRange = Range(match.range, in: result) else { continue }
            result.replaceSubrange(swiftRange, with: replacement)
        }
        return result
    }

    public static func contrast(_ lhs: SRGB, _ rhs: SRGB) -> Double {
        let left = lhs.relativeLuminance
        let right = rhs.relativeLuminance
        let lighter = max(left, right)
        let darker = min(left, right)
        return (lighter + 0.05) / (darker + 0.05)
    }

    public static func blend(_ foreground: SRGB, over background: SRGB, opacity: Double) -> SRGB {
        let t = min(max(opacity, 0), 1)
        return SRGB(
            r: foreground.r * t + background.r * (1 - t),
            g: foreground.g * t + background.g * (1 - t),
            b: foreground.b * t + background.b * (1 - t)
        )
    }

    public struct MaskStyle: Equatable {
        public var foreground: SRGB
        public var opacity: Double
    }

    /// Prefers the role's opacity (40% hero, 30% rows, 60% legacy). Raises opacity
    /// only until the dots clear 3:1 on every surface. When no opacity can clear
    /// that floor, this returns the strongest pair.
    public static func maskStyle(
        matching amount: SRGB,
        over backgrounds: [SRGB],
        preferredOpacity: Double = maskOpacity,
        minimum: Double = minimumContrast
    ) -> MaskStyle {
        let surfaces = backgrounds.isEmpty ? [SRGB(r: 1, g: 1, b: 1)] : backgrounds
        let start = min(max(preferredOpacity, 0), 1)
        let preferred = foreground(matching: amount, over: surfaces, opacity: start, minimum: minimum)
        if minimumContrast(of: preferred, over: surfaces, opacity: start) >= minimum {
            return MaskStyle(foreground: preferred, opacity: start)
        }
        var best = MaskStyle(foreground: preferred, opacity: start)
        var bestScore = minimumContrast(of: preferred, over: surfaces, opacity: start)
        var opacity = start
        while opacity < 1 {
            opacity = min(1, opacity + 0.01)
            let ink = foreground(matching: amount, over: surfaces, opacity: opacity, minimum: minimum)
            let score = minimumContrast(of: ink, over: surfaces, opacity: opacity)
            if score > bestScore {
                bestScore = score
                best = MaskStyle(foreground: ink, opacity: opacity)
            }
            if score >= minimum {
                return MaskStyle(foreground: ink, opacity: opacity)
            }
        }
        return best
    }

    /// Ink colour which, drawn at `opacity` over every background, meets the
    /// graphic contrast floor when that is possible. Otherwise the higher-contrast
    /// mix of black or white.
    public static func foreground(
        matching amount: SRGB,
        over backgrounds: [SRGB],
        opacity: Double = maskOpacity,
        minimum: Double = minimumContrast
    ) -> SRGB {
        let surfaces = backgrounds.isEmpty ? [SRGB(r: 1, g: 1, b: 1)] : backgrounds
        let target = minimum
        if passes(amount, over: surfaces, opacity: opacity, minimum: target) {
            return amount
        }
        let black = SRGB(r: 0, g: 0, b: 0)
        let white = SRGB(r: 1, g: 1, b: 1)
        var best = amount
        var bestDistance = Double.greatestFiniteMagnitude
        var found = false
        for extreme in [black, white] {
            guard let candidate = nearestPassing(
                from: amount,
                toward: extreme,
                over: surfaces,
                opacity: opacity,
                minimum: target
            ) else { continue }
            let distance = abs(candidate.relativeLuminance - amount.relativeLuminance)
            if !found || distance < bestDistance {
                found = true
                bestDistance = distance
                best = candidate
            }
        }
        if found { return best }
        let blackScore = minimumContrast(of: black, over: surfaces, opacity: opacity)
        let whiteScore = minimumContrast(of: white, over: surfaces, opacity: opacity)
        return whiteScore > blackScore ? white : black
    }

    public static func netWorth(balances: [(balance: Decimal, included: Bool)]) -> Decimal {
        balances.reduce(0) { partial, row in
            row.included ? partial + row.balance : partial
        }
    }

    public static func goalPaceSentence(
        monthlyRequired: String,
        target: String,
        dateLabel: String,
        isPrivate: Bool
    ) -> String {
        let shownTarget = isPrivate ? mask : target
        return "About \(monthlyRequired)/month to reach \(shownTarget) by \(dateLabel)"
    }

    public static func minimumContrast(of foreground: SRGB, over backgrounds: [SRGB], opacity: Double) -> Double {
        backgrounds.reduce(Double.greatestFiniteMagnitude) { partial, background in
            min(partial, contrast(blend(foreground, over: background, opacity: opacity), background))
        }
    }

    private static func passes(_ foreground: SRGB, over backgrounds: [SRGB], opacity: Double, minimum: Double) -> Bool {
        minimumContrast(of: foreground, over: backgrounds, opacity: opacity) >= minimum
    }

    private static func mix(_ start: SRGB, _ end: SRGB, _ t: Double) -> SRGB {
        SRGB(
            r: start.r + (end.r - start.r) * t,
            g: start.g + (end.g - start.g) * t,
            b: start.b + (end.b - start.b) * t
        )
    }

    private static func nearestPassing(
        from amount: SRGB,
        toward extreme: SRGB,
        over backgrounds: [SRGB],
        opacity: Double,
        minimum: Double
    ) -> SRGB? {
        guard passes(extreme, over: backgrounds, opacity: opacity, minimum: minimum) else { return nil }
        var low = 0.0
        var high = 1.0
        var candidate = extreme
        for _ in 0..<24 {
            let mid = (low + high) / 2
            let mixed = mix(amount, extreme, mid)
            if passes(mixed, over: backgrounds, opacity: opacity, minimum: minimum) {
                candidate = mixed
                high = mid
            } else {
                low = mid
            }
        }
        let score = minimumContrast(of: candidate, over: backgrounds, opacity: opacity)
        if score + 0.001 < minimum {
            return extreme
        }
        return candidate
    }

    /// Currency tokens only. Dates, percents, and plain words stay put.
    private static let currencyPattern = [
        #"[+\-−]?\s*\(?\s*(?:CA\$|US\$|A\$|NZ\$|C\$|\$|€|£|¥)\s*\d{1,3}(?:[\s\u00A0,.]\d{3})*(?:[.,]\d+)?\s*\)?"#,
        #"[+\-−]?\s*\(?\s*\d{1,3}(?:[\s\u00A0,.]\d{3})*(?:[.,]\d+)?\s*(?:CA\$|US\$|A\$|NZ\$|C\$|\$|€|£|¥)\s*\)?"#,
        #"[+\-−]?\s*\d{1,3}(?:[\s\u00A0,.]\d{3})*(?:[.,]\d+)?\s*(?:CAD|USD|EUR|GBP|AUD)\b"#
    ].joined(separator: "|")
}

public enum PrivateModeDefaults {
    public static let key = "penny.privateMode.enabled"

    public static func isEnabled(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: key) as? Bool ?? false
    }

    public static func setEnabled(_ enabled: Bool, in defaults: UserDefaults) {
        defaults.set(enabled, forKey: key)
    }
}

public enum PrivateWidgetKinds {
    public static let safeToSpend = "PennySafeToSpendWidget"
    public static let monthlyBudget = "PennyMonthlyBudgetWidget"
    public static let savingsGoal = "PennySavingsGoalWidget"
    public static let upcomingBills = "PennyUpcomingBillsWidget"
    public static let upcomingReminder = "PennyUpcomingReminderWidget"

    /// Upcoming bills keep each bill's amount, so they are not reloaded.
    /// The reminder widget includes a Safe to Spend total, so it is.
    /// Lock Screen Safe to Spend uses `safeToSpend`.
    public static let totalShowing = [safeToSpend, monthlyBudget, savingsGoal, upcomingReminder]
}

/// Trailing debounce for widget timeline reloads. The flag is stored immediately.
/// Rapid taps collapse into one reload after a quiet second, and that reload
/// uses whatever the flag is then. Widget views read the flag when they render.
public struct PrivateWidgetReloadCoalescer {
    public static let defaultDebounce: TimeInterval = 1
    public var debounce: TimeInterval = defaultDebounce
    private var dueAt: Date?
    private var pending = false

    public mutating func noteChange(at now: Date) {
        pending = true
        dueAt = now.addingTimeInterval(debounce)
    }

    public mutating func takeDueReload(at now: Date) -> [String]? {
        guard pending, let dueAt, now >= dueAt else { return nil }
        pending = false
        self.dueAt = nil
        return PrivateWidgetKinds.totalShowing
    }
}

public enum PrivateScenePhase: Equatable {
    case active
    case inactive
    case background
    case other
}

public enum AppSwitcherPrivacy {
    public static func suppressAnimation(phase: PrivateScenePhase) -> Bool {
        phase == .inactive || phase == .background
    }
}

/// One flag, one reload list, no database. The app controller wraps this.
public struct PrivateModeSession {
    public private(set) var isEnabled: Bool
    public private(set) var animationsSuppressed = false
    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
        isEnabled = PrivateModeDefaults.isEnabled(in: defaults)
    }

    public mutating func setEnabled(_ newValue: Bool) -> [String]? {
        let changed = newValue != isEnabled
        PrivateModeDefaults.setEnabled(newValue, in: defaults)
        isEnabled = newValue
        guard changed else { return nil }
        return PrivateWidgetKinds.totalShowing
    }

    public mutating func toggle() -> [String]? {
        setEnabled(!isEnabled)
    }

    public mutating func noteScenePhase(_ phase: PrivateScenePhase) {
        if AppSwitcherPrivacy.suppressAnimation(phase: phase) {
            animationsSuppressed = true
        } else if phase == .active {
            animationsSuppressed = false
        }
        isEnabled = PrivateModeDefaults.isEnabled(in: defaults)
    }
}

public enum WidgetPrivateDisplay {
    public static func safeToSpend(
        amount: Decimal,
        currencyCode: String,
        isPrivate: Bool,
        site: PrivateTotalSite,
        locale: Locale = .current
    ) -> String {
        _ = site
        return PrivateAmountLogic.display(
            amount: amount,
            currencyCode: currencyCode,
            style: .standard,
            isPrivate: isPrivate,
            locale: locale
        )
    }

    public static func budget(
        amount: Decimal,
        currencyCode: String,
        isPrivate: Bool,
        site: PrivateTotalSite,
        locale: Locale = .current
    ) -> String {
        _ = site
        return PrivateAmountLogic.display(
            amount: amount,
            currencyCode: currencyCode,
            style: .compact,
            isPrivate: isPrivate,
            locale: locale
        )
    }

    public static func goalDetail(_ detail: String, isPrivate: Bool, site: PrivateTotalSite) -> String {
        _ = site
        guard isPrivate else { return detail }
        return PrivateAmountLogic.maskCurrencyAmounts(in: detail)
    }

    /// Each bill amount stays visible. The private flag does not change the line.
    public static func upcomingBillDetail(_ detail: String, isPrivate: Bool) -> String {
        _ = isPrivate
        return detail
    }

    public static func reminderLine(
        amount: Decimal,
        currencyCode: String,
        isPrivate: Bool,
        locale: Locale = .current
    ) -> String {
        let shown = safeToSpend(
            amount: amount,
            currencyCode: currencyCode,
            isPrivate: isPrivate,
            site: .widgetReminderSafeToSpend,
            locale: locale
        )
        return "Safe to spend \(shown)"
    }
}

public enum PrivateInsightText {
    public struct Presented: Equatable {
        public var title: String
        public var detail: String
        public var accessibilityTitle: String
        public var accessibilityDetail: String
    }

    public static func present(
        title: String,
        detail: String,
        includesTotal: Bool,
        isPrivate: Bool,
        site: PrivateTotalSite = .insightSentence
    ) -> Presented {
        _ = site
        guard isPrivate, includesTotal else {
            return Presented(
                title: title,
                detail: detail,
                accessibilityTitle: title,
                accessibilityDetail: detail
            )
        }
        return Presented(
            title: PrivateAmountLogic.maskCurrencyAmounts(in: title),
            detail: PrivateAmountLogic.maskCurrencyAmounts(in: detail),
            accessibilityTitle: PrivateAmountLogic.maskCurrencyAmounts(
                in: title,
                replacement: PrivateAmountLogic.hiddenAccessibilityLabel
            ),
            accessibilityDetail: PrivateAmountLogic.maskCurrencyAmounts(
                in: detail,
                replacement: PrivateAmountLogic.hiddenAccessibilityLabel
            )
        )
    }
}

public struct PennyNotificationCopy: Equatable {
    public var title: String
    public var body: String
}

public enum PennyNotificationContent {
    public static func billReminder(
        name: String,
        individualAmount: Decimal?,
        billsTotal: Decimal?,
        currencyCode: String,
        isPrivate: Bool,
        locale: Locale
    ) -> PennyNotificationCopy {
        var body = "\(name) is due soon."
        if let individualAmount {
            let money = MoneyFormatters.string(from: individualAmount, currencyCode: currencyCode, locale: locale)
            body += " \(money)."
        }
        if let billsTotal, !isPrivate {
            let money = MoneyFormatters.string(from: billsTotal, currencyCode: currencyCode, locale: locale)
            body += " All bills this month: \(money)."
        }
        return PennyNotificationCopy(title: "Upcoming bill", body: body)
    }
}

/// Every total the spec hides. A test fails if one of these never reaches PrivateAmount.
public enum PrivateTotalSite: String, CaseIterable, Equatable {
    case homeSafeToSpendHero
    case homeBreakdownIncome
    case homeBreakdownBills
    case homeBreakdownDebtPayments
    case homeBreakdownSpent
    case homeBreakdownGoals
    case homeBreakdownSafeToSpend
    case homeIncludesDebtTarget
    case homeIncludesGoalTarget
    case homeSpendingSpent
    case homeSpendingBudget
    case homeNetWorth
    case budgetIncome
    case budgetPlanned
    case budgetSpent
    case budgetRemaining
    case budgetCategorySpent
    case budgetCategoryBudgeted
    case budgetCategoryRemaining
    case budgetTrendAxis
    case planGoalSaved
    case planGoalTarget
    case planBillsMonthlyTotal
    case planDebtBalance
    case planDebtInterest
    case planForecastTotal
    case planForecastAxis
    case accountBalance
    case accountsNetWorth
    case activityDailySum
    case activityMonthlySum
    case insightSentence
    case widgetSafeToSpend
    case widgetLockScreenSafeToSpend
    case widgetMonthlyBudgetSpent
    case widgetMonthlyBudgetPlanned
    case widgetSavingsGoal
    case widgetReminderSafeToSpend
}
