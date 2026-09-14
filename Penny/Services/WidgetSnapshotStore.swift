import Foundation

/// Lightweight snapshot shared with WidgetKit via App Group.
enum WidgetSnapshotStore {
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
