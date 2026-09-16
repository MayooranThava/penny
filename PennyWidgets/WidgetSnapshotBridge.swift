import Foundation

/// Mirror of the app's WidgetSnapshotStore for the extension target.
/// Keep fields in sync with `Penny/Services/WidgetSnapshotStore.swift`.
enum WidgetSnapshotBridge {
    static let appGroupID = "group.com.mayooran.penny"
    static let snapshotKey = "penny.widget.snapshot"

    struct Snapshot: Codable, Equatable {
        var safeToSpend: Double
        var currencyCode: String
        var monthLabel: String
        var nextReminderTitle: String?
        var nextReminderDetail: String?
        var displayName: String
        var updatedAt: Date

        /// Used by WidgetKit placeholder / snapshot fallbacks.
        static var placeholder: Snapshot {
            Snapshot(
                safeToSpend: 3_350,
                currencyCode: "CAD",
                monthLabel: "September",
                nextReminderTitle: "Rent due",
                nextReminderDetail: "$1,750 · Sep 1",
                displayName: "Alex",
                updatedAt: .now
            )
        }
    }

    static func load() -> Snapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }
}
