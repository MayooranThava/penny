import WidgetKit
import SwiftUI

struct UpcomingReminderEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshotStore.Snapshot
}

struct UpcomingReminderProvider: TimelineProvider {
    func placeholder(in context: Context) -> UpcomingReminderEntry {
        UpcomingReminderEntry(date: .now, snapshot: WidgetSnapshotStore.Snapshot.placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (UpcomingReminderEntry) -> Void) {
        let snapshot = WidgetSnapshotStore.load() ?? WidgetSnapshotStore.Snapshot.placeholder
        completion(UpcomingReminderEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpcomingReminderEntry>) -> Void) {
        let snapshot = WidgetSnapshotStore.load() ?? WidgetSnapshotStore.Snapshot.placeholder
        let entry = UpcomingReminderEntry(date: .now, snapshot: snapshot)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1_800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct UpcomingReminderWidgetView: View {
    var entry: UpcomingReminderEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Upcoming", systemImage: "bell.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(red: 0.20, green: 0.72, blue: 0.55))

            if let title = entry.snapshot.nextReminderTitle {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if let detail = entry.snapshot.nextReminderDetail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No reminders yet")
                    .font(.headline)
                Text("Add bills or debt in Plan")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text("Safe to spend \(formattedSafeToSpend)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            Color(uiColor: .systemBackground)
        }
    }

    private var formattedSafeToSpend: String {
        entry.snapshot.formattedSafeToSpend()
    }
}

struct UpcomingReminderWidget: Widget {
    let kind = "PennyUpcomingReminderWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UpcomingReminderProvider()) { entry in
            UpcomingReminderWidgetView(entry: entry)
        }
        .configurationDisplayName("Upcoming reminder")
        .description("See your next bill or debt payment at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
