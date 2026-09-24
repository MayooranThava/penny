import Foundation

/// Mirror of the app's WidgetSnapshotStore for the extension target.
/// Keep fields in sync with `Penny/Services/WidgetSnapshotStore.swift`.
enum WidgetSnapshotBridge {
    static let appGroupID = "group.com.mayooran.penny"
    static let snapshotKey = "penny.widget.snapshot"

    struct UpcomingLine: Codable, Equatable {
        var title: String
        var detail: String
        var kind: String
    }

    struct Snapshot: Codable, Equatable {
        var safeToSpend: Double
        var currencyCode: String
        var monthLabel: String
        var nextReminderTitle: String?
        var nextReminderDetail: String?
        var displayName: String
        var updatedAt: Date

        var upcomingItems: [UpcomingLine]?
        var spentThisMonth: Double?
        var plannedSpending: Double?
        var budgetHealth: String?
        var topGoalName: String?
        var topGoalProgress: Double?
        var topGoalDetail: String?

        /// Used by WidgetKit placeholder / snapshot fallbacks.
        static var placeholder: Snapshot {
            Snapshot(
                safeToSpend: 3_350,
                currencyCode: "CAD",
                monthLabel: "September",
                nextReminderTitle: "Rent due",
                nextReminderDetail: "$1,750 · Sep 1",
                displayName: "Alex",
                updatedAt: .now,
                upcomingItems: [
                    .init(title: "Rent", detail: "$1,750 · Sep 1", kind: "bill"),
                    .init(title: "Internet", detail: "$80 · Sep 12", kind: "bill"),
                    .init(title: "Car loan", detail: "$420 · Sep 15", kind: "debt")
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

        func money(_ value: Double) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currencyCode
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: value))
                ?? String(format: "%.0f", value)
        }
    }

    static func load() -> Snapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }
}
