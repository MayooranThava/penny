import Foundation

/// Lightweight snapshot shared with WidgetKit via App Group.
///
/// PennyWidgets compiles this file together with `MoneyFormatters` so every
/// amount on a widget uses the same cents as the app. Money is `Decimal`.
/// `topGoalProgress` is a 0...1 ratio, not a currency amount.
/// Older snapshots stored those amounts as JSON numbers (`Double`); `Decimal`
/// still decodes that shape.
enum WidgetSnapshotStore {
    static let appGroupID = "group.com.mayooran.penny"
    static let snapshotKey = "penny.widget.snapshot"

    /// Set only by PennyTests. Nil in the app, so widgets keep using the App Group.
    @TaskLocal static var defaultsSuiteOverride: String?

    static var activeDefaultsSuite: String {
        defaultsSuiteOverride ?? appGroupID
    }

    struct UpcomingLine: Codable, Equatable {
        var title: String
        var detail: String
        var kind: String
    }

    struct Snapshot: Codable, Equatable {
        var safeToSpend: Decimal
        var currencyCode: String
        var monthLabel: String
        var nextReminderTitle: String?
        var nextReminderDetail: String?
        var displayName: String
        var updatedAt: Date

        /// Next bills / debt payments (newest schema — optional for older snapshots).
        var upcomingItems: [UpcomingLine]?
        var spentThisMonth: Decimal?
        var plannedSpending: Decimal?
        /// `healthy` | `near` | `over`
        var budgetHealth: String?
        var topGoalName: String?
        /// Fraction from 0...1 for the goal ring. Not a currency amount.
        var topGoalProgress: Double?
        var topGoalDetail: String?

        /// Used by WidgetKit placeholder / snapshot fallbacks.
        static var placeholder: Snapshot {
            Snapshot(
                safeToSpend: 3_350,
                currencyCode: "CAD",
                monthLabel: "September",
                nextReminderTitle: "Rent due",
                nextReminderDetail: "$1,750 · Oct 1",
                displayName: "Alex",
                updatedAt: .now,
                upcomingItems: [
                    .init(title: "Rent", detail: "$1,750 · Oct 1", kind: "bill"),
                    .init(title: "Internet", detail: "$75 · Oct 15", kind: "bill"),
                    .init(title: "Credit Card", detail: "$250 · Oct 15", kind: "debt")
                ],
                spentThisMonth: 1_240,
                plannedSpending: 2_000,
                budgetHealth: "healthy",
                topGoalName: "Emergency fund",
                topGoalProgress: 0.62,
                topGoalDetail: "$6,200 of $10,000"
            )
        }

        var upcomingList: [UpcomingLine] {
            if let upcomingItems, !upcomingItems.isEmpty { return upcomingItems }
            if let title = nextReminderTitle {
                return [.init(title: title, detail: nextReminderDetail ?? "", kind: "bill")]
            }
            return []
        }

        /// Home shows Safe to Spend with `MoneyFormatters.string` (always two decimal places).
        func formattedSafeToSpend(locale: Locale = .current) -> String {
            MoneyFormatters.string(from: safeToSpend, currencyCode: currencyCode, locale: locale)
        }

        /// Budget shows spent and planned with `MoneyFormatters.compact`.
        func formattedBudgetAmount(_ amount: Decimal, locale: Locale = .current) -> String {
            MoneyFormatters.compact(from: amount, currencyCode: currencyCode, locale: locale)
        }
    }

    static func save(_ snapshot: Snapshot) {
        guard let defaults = UserDefaults(suiteName: activeDefaultsSuite) else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    static func load() -> Snapshot? {
        guard let defaults = UserDefaults(suiteName: activeDefaultsSuite),
              let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }
}
