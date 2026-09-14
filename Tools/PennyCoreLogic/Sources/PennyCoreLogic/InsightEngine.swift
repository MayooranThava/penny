import Foundation

struct PennyInsight: Identifiable, Equatable {
    let id: UUID
    let title: String
    let detail: String
    let symbolName: String
    let kind: Kind

    enum Kind: String, Equatable {
        case positive
        case caution
        case neutral
        case tip
    }

    init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        symbolName: String,
        kind: Kind
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.symbolName = symbolName
        self.kind = kind
    }
}

/// Deterministic local insight engine — no AI APIs.
enum InsightEngine {

    struct CategorySpend: Equatable {
        let name: String
        let current: Decimal
        let previous: Decimal
        let budgeted: Decimal
    }

    struct GoalSnapshot: Equatable {
        let name: String
        let current: Decimal
        let target: Decimal
        let targetDate: Date?
        let monthlyContributionEstimate: Decimal
    }

    struct Input {
        let categorySpends: [CategorySpend]
        let upcomingBillsWithinDays: [(name: String, daysUntil: Int, amount: Decimal)]
        let goals: [GoalSnapshot]
        let monthlyBudget: Decimal
        let spentSoFar: Decimal
        let dayOfMonth: Int
        let daysInMonth: Int
        let currencyCode: String
        let now: Date
    }

    static func generate(from input: Input, limit: Int = 4) -> [PennyInsight] {
        var insights: [PennyInsight] = []

        // Category vs previous month
        for category in input.categorySpends {
            if let change = FinanceCalculator.percentChange(current: category.current, previous: category.previous),
               abs(change) >= 0.10,
               category.previous > 0 {
                let pct = Int((abs(change) * 100).rounded())
                if change < 0 {
                    insights.append(
                        PennyInsight(
                            title: "\(category.name) spending is \(pct)% lower than last month.",
                            detail: "Nice progress keeping \(category.name.lowercased()) costs down.",
                            symbolName: "arrow.down.right.circle.fill",
                            kind: .positive
                        )
                    )
                } else {
                    insights.append(
                        PennyInsight(
                            title: "\(category.name) spending is \(pct)% higher than last month.",
                            detail: "Review recent \(category.name.lowercased()) purchases if you want to adjust.",
                            symbolName: "arrow.up.right.circle.fill",
                            kind: .caution
                        )
                    )
                }
            }

            // Near / remaining budget
            if category.budgeted > 0 {
                let remaining = FinanceCalculator.budgetRemaining(budgeted: category.budgeted, spent: category.current)
                let health = FinanceCalculator.budgetHealth(budgeted: category.budgeted, spent: category.current)
                switch health {
                case .nearLimit:
                    insights.append(
                        PennyInsight(
                            title: "You're close to your \(category.name) budget.",
                            detail: "\(MoneyFormatters.string(from: max(0, remaining), currencyCode: input.currencyCode)) left this month.",
                            symbolName: "exclamationmark.circle.fill",
                            kind: .caution
                        )
                    )
                case .healthy where remaining > 0 && category.current > 0:
                    insights.append(
                        PennyInsight(
                            title: "\(MoneyFormatters.string(from: remaining, currencyCode: input.currencyCode)) remains in \(category.name) this month.",
                            detail: "Still room in this category.",
                            symbolName: "checkmark.circle.fill",
                            kind: .neutral
                        )
                    )
                case .overBudget:
                    let over = abs(min(0, remaining))
                    insights.append(
                        PennyInsight(
                            title: "You're \(MoneyFormatters.string(from: over, currencyCode: input.currencyCode)) over your \(category.name) budget.",
                            detail: "Consider shifting spending from other categories.",
                            symbolName: "chart.bar.fill",
                            kind: .caution
                        )
                    )
                default:
                    break
                }
            }
        }

        // Bills due soon
        for bill in input.upcomingBillsWithinDays where bill.daysUntil <= 5 {
            let when = bill.daysUntil == 0 ? "today" : (bill.daysUntil == 1 ? "tomorrow" : "in \(bill.daysUntil) days")
            insights.append(
                PennyInsight(
                    title: "\(bill.name) is due \(when).",
                    detail: MoneyFormatters.string(from: bill.amount, currencyCode: input.currencyCode),
                    symbolName: "bell.fill",
                    kind: .tip
                )
            )
        }

        // Pace vs budget
        if input.monthlyBudget > 0, input.daysInMonth > 0 {
            let dayFraction = Decimal(input.dayOfMonth) / Decimal(input.daysInMonth)
            let projected = dayFraction > 0 ? (input.spentSoFar / dayFraction) : input.spentSoFar
            let projectedRounded = projected.rounded(scale: 0)
            if projected > input.monthlyBudget {
                let over = (projected - input.monthlyBudget).rounded(scale: 0)
                insights.append(
                    PennyInsight(
                        title: "At this pace you may exceed your monthly budget.",
                        detail: "Projected about \(MoneyFormatters.compact(from: over, currencyCode: input.currencyCode)) over.",
                        symbolName: "gauge.with.dots.needle.67percent",
                        kind: .caution
                    )
                )
            } else if projected < input.monthlyBudget * Decimal(9) / Decimal(10) {
                let under = (input.monthlyBudget - projectedRounded).rounded(scale: 0)
                insights.append(
                    PennyInsight(
                        title: "You're spending below your monthly budget pace.",
                        detail: "Roughly \(MoneyFormatters.compact(from: under, currencyCode: input.currencyCode)) of headroom if this continues.",
                        symbolName: "leaf.fill",
                        kind: .positive
                    )
                )
            }
        }

        // Goals
        for goal in input.goals {
            if let targetDate = goal.targetDate,
               let required = FinanceCalculator.requiredMonthlySavings(
                current: goal.current,
                target: goal.target,
                targetDate: targetDate,
                from: input.now
               ) {
                let progress = FinanceCalculator.goalProgressClamped(current: goal.current, target: goal.target)
                if progress >= 1 {
                    insights.append(
                        PennyInsight(
                            title: "You've reached your \(goal.name) goal.",
                            detail: "Great milestone — consider setting the next one.",
                            symbolName: "flag.fill",
                            kind: .positive
                        )
                    )
                } else if goal.monthlyContributionEstimate >= required {
                    insights.append(
                        PennyInsight(
                            title: "You're on track for \(goal.name).",
                            detail: "At your current rate you'll reach it by \(DateHelpers.monthYear(for: targetDate)).",
                            symbolName: "target",
                            kind: .positive
                        )
                    )
                } else if required > 0 {
                    insights.append(
                        PennyInsight(
                            title: "\(goal.name) needs about \(MoneyFormatters.compact(from: required, currencyCode: input.currencyCode))/month.",
                            detail: "To hit \(DateHelpers.monthYear(for: targetDate)).",
                            symbolName: "calendar",
                            kind: .tip
                        )
                    )
                }
            }
        }

        // De-dupe by title and limit
        var seen = Set<String>()
        let unique = insights.filter { seen.insert($0.title).inserted }
        return Array(unique.prefix(limit))
    }
}
