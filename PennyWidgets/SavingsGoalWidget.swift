import WidgetKit
import SwiftUI

struct SavingsGoalEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshotBridge.Snapshot
}

struct SavingsGoalProvider: TimelineProvider {
    func placeholder(in context: Context) -> SavingsGoalEntry {
        SavingsGoalEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SavingsGoalEntry) -> Void) {
        completion(SavingsGoalEntry(date: .now, snapshot: WidgetSnapshotBridge.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SavingsGoalEntry>) -> Void) {
        let entry = SavingsGoalEntry(date: .now, snapshot: WidgetSnapshotBridge.load() ?? .placeholder)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1_800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct SavingsGoalWidgetView: View {
    var entry: SavingsGoalEntry

    private var progress: Double {
        min(max(entry.snapshot.topGoalProgress ?? 0, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Savings goal", systemImage: "target")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(red: 0.25, green: 0.55, blue: 0.85))

            if let name = entry.snapshot.topGoalName {
                Text(name)
                    .font(.headline)
                    .lineLimit(2)

                ProgressView(value: progress)
                    .tint(Color(red: 0.25, green: 0.55, blue: 0.85))

                Text("\(Int((progress * 100).rounded()))%")
                    .font(.title3.weight(.bold).monospacedDigit())

                if let detail = entry.snapshot.topGoalDetail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            } else {
                Text("No goals yet")
                    .font(.headline)
                Text("Add a goal in Plan")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            Color(uiColor: .systemBackground)
        }
    }
}

struct SavingsGoalWidget: Widget {
    let kind = "PennySavingsGoalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SavingsGoalProvider()) { entry in
            SavingsGoalWidgetView(entry: entry)
        }
        .configurationDisplayName("Savings goal")
        .description("See progress on your top savings goal.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
