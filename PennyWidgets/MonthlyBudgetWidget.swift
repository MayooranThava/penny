import WidgetKit
import SwiftUI

struct MonthlyBudgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshotBridge.Snapshot
}

struct MonthlyBudgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MonthlyBudgetEntry {
        MonthlyBudgetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (MonthlyBudgetEntry) -> Void) {
        completion(MonthlyBudgetEntry(date: .now, snapshot: WidgetSnapshotBridge.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonthlyBudgetEntry>) -> Void) {
        let entry = MonthlyBudgetEntry(date: .now, snapshot: WidgetSnapshotBridge.load() ?? .placeholder)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1_800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct MonthlyBudgetWidgetView: View {
    var entry: MonthlyBudgetEntry

    private var spent: Double { entry.snapshot.spentThisMonth ?? 0 }
    private var planned: Double { max(entry.snapshot.plannedSpending ?? 0, 0) }
    private var progress: Double {
        guard planned > 0 else { return spent > 0 ? 1 : 0 }
        return min(max(spent / planned, 0), 1.25)
    }

    private var healthColor: Color {
        switch entry.snapshot.budgetHealth {
        case "over": return Color(red: 0.86, green: 0.32, blue: 0.28)
        case "near": return Color(red: 0.90, green: 0.62, blue: 0.16)
        default: return Color(red: 0.20, green: 0.72, blue: 0.55)
        }
    }

    private var statusLabel: String {
        switch entry.snapshot.budgetHealth {
        case "over": return "Over budget"
        case "near": return "Near limit"
        default: return "On track"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BUDGET · \(entry.snapshot.monthLabel.uppercased())")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(entry.snapshot.money(spent))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text("of \(entry.snapshot.money(planned)) planned")
                .font(.caption)
                .foregroundStyle(.secondary)

            ProgressView(value: min(progress, 1))
                .tint(healthColor)

            Text(statusLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(healthColor)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            Color(uiColor: .systemBackground)
        }
    }
}

struct MonthlyBudgetWidget: Widget {
    let kind = "PennyMonthlyBudgetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MonthlyBudgetProvider()) { entry in
            MonthlyBudgetWidgetView(entry: entry)
        }
        .configurationDisplayName("Monthly budget")
        .description("Track planned vs spent for this month.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
