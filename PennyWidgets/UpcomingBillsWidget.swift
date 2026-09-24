import WidgetKit
import SwiftUI

struct UpcomingBillsEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshotBridge.Snapshot
}

struct UpcomingBillsProvider: TimelineProvider {
    func placeholder(in context: Context) -> UpcomingBillsEntry {
        UpcomingBillsEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (UpcomingBillsEntry) -> Void) {
        completion(UpcomingBillsEntry(date: .now, snapshot: WidgetSnapshotBridge.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpcomingBillsEntry>) -> Void) {
        let entry = UpcomingBillsEntry(date: .now, snapshot: WidgetSnapshotBridge.load() ?? .placeholder)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1_800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct UpcomingBillsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: UpcomingBillsEntry

    private var items: [WidgetSnapshotBridge.UpcomingLine] {
        Array(entry.snapshot.upcomingList.prefix(family == .systemSmall ? 2 : 4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Upcoming bills", systemImage: "calendar")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(red: 0.20, green: 0.72, blue: 0.55))

            if items.isEmpty {
                Text("No bills due soon")
                    .font(.headline)
                Text("Add bills in Plan")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: item.kind == "debt" ? "creditcard.fill" : "doc.text.fill")
                            .font(.caption2)
                            .foregroundStyle(Color(red: 0.20, green: 0.72, blue: 0.55))
                            .frame(width: 14)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            if !item.detail.isEmpty {
                                Text(item.detail)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            Color(uiColor: .systemBackground)
        }
    }
}

struct UpcomingBillsWidget: Widget {
    let kind = "PennyUpcomingBillsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UpcomingBillsProvider()) { entry in
            UpcomingBillsWidgetView(entry: entry)
        }
        .configurationDisplayName("Upcoming bills")
        .description("See your next bills and debt payments.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
