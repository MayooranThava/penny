import WidgetKit
import SwiftUI

struct SafeToSpendEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshotBridge.Snapshot
}

struct SafeToSpendProvider: TimelineProvider {
    func placeholder(in context: Context) -> SafeToSpendEntry {
        SafeToSpendEntry(date: .now, snapshot: WidgetSnapshotBridge.Snapshot.placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SafeToSpendEntry) -> Void) {
        let snapshot = WidgetSnapshotBridge.load() ?? WidgetSnapshotBridge.Snapshot.placeholder
        completion(SafeToSpendEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SafeToSpendEntry>) -> Void) {
        let snapshot = WidgetSnapshotBridge.load() ?? WidgetSnapshotBridge.Snapshot.placeholder
        let entry = SafeToSpendEntry(date: .now, snapshot: snapshot)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1_800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct SafeToSpendWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: SafeToSpendEntry

    private var amountText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = entry.snapshot.currencyCode
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: entry.snapshot.safeToSpend))
            ?? String(format: "%.0f", entry.snapshot.safeToSpend)
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Text("Safe")
                        .font(.caption2)
                    Text(amountText)
                        .font(.caption.weight(.bold))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
            }
            .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Safe to spend")
                    .font(.caption2)
                Text(amountText)
                    .font(.headline)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(entry.snapshot.monthLabel)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        default:
            homeScreenBody
        }
    }

    private var homeScreenBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SAFE TO SPEND")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text(amountText)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text("Rest of \(entry.snapshot.monthLabel)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
            Spacer(minLength: 0)
            if !entry.snapshot.displayName.isEmpty {
                Text("Hi, \(entry.snapshot.displayName)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.45, blue: 0.40),
                    Color(red: 0.08, green: 0.28, blue: 0.26)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct SafeToSpendWidget: Widget {
    let kind = "PennySafeToSpendWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SafeToSpendProvider()) { entry in
            SafeToSpendWidgetView(entry: entry)
        }
        .configurationDisplayName("Safe to Spend")
        .description("See how much you can spend for the rest of the month.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}
