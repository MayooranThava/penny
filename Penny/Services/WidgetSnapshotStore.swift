import Foundation

/// Lightweight snapshot shared with WidgetKit via App Group.
enum WidgetSnapshotStore {
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

        /// Next bills / debt payments (newest schema — optional for older snapshots).
        var upcomingItems: [UpcomingLine]?
        var spentThisMonth: Double?
        var plannedSpending: Double?
        /// `healthy` | `near` | `over`
        var budgetHealth: String?
        var topGoalName: String?
        var topGoalProgress: Double?
        var topGoalDetail: String?
    }

    static func save(_ snapshot: Snapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    static func load() -> Snapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }
}
