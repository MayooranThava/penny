import Foundation
import SwiftData
import Testing
@testable import Penny

@Suite("Test isolation", .serialized, .isolatedTestResources)
@MainActor
struct TestIsolationTests {
    @Test("Each test gets its own SwiftData store and UserDefaults suite")
    func isolatedStoreAndDefaults() throws {
        #expect(PennyPersistence.storeName == "Penny")
        let storeName = try #require(PennyPersistence.activeIsolatedStoreName)
        #expect(storeName.hasPrefix("PennyTests-"))
        #expect(storeName != PennyPersistence.storeName)

        let defaultsSuite = WidgetSnapshotStore.activeDefaultsSuite
        #expect(defaultsSuite.hasPrefix("PennyTests."))
        #expect(defaultsSuite != WidgetSnapshotStore.appGroupID)

        do {
            let container = try PennyPersistence.makeContainer(inMemory: true)
            let context = ModelContext(container)
            context.insert(sampleBill(name: "Rent"))
            try context.save()
        }

        let reopened = try PennyPersistence.makeContainer(inMemory: true)
        #expect(try ModelContext(reopened).fetch(FetchDescriptor<RecurringBill>()).count == 1)

        let foreignDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("PennyTests-foreign-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: foreignDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: foreignDir) }
        let foreign = try ModelContainer(
            for: PennyPersistence.schema,
            configurations: [ModelConfiguration(url: foreignDir.appendingPathComponent("Penny.store"))]
        )
        #expect(try ModelContext(foreign).fetch(FetchDescriptor<RecurringBill>()).isEmpty)

        WidgetSnapshotStore.save(sampleSnapshot(displayName: "Alex"))
        #expect(WidgetSnapshotStore.load()?.displayName == "Alex")
        let own = UserDefaults(suiteName: defaultsSuite)
        #expect(own?.data(forKey: WidgetSnapshotStore.snapshotKey) != nil)
        let otherSuite = "PennyTests.foreign.\(UUID().uuidString)"
        let other = UserDefaults(suiteName: otherSuite)
        defer { other?.removePersistentDomain(forName: otherSuite) }
        #expect(other?.data(forKey: WidgetSnapshotStore.snapshotKey) == nil)
    }

    private func sampleBill(name: String) -> RecurringBill {
        RecurringBill(
            name: name,
            amount: 10,
            dueDay: 1,
            categoryName: "Housing",
            recurrence: .monthly,
            nextDueDate: .now,
            startDate: .now,
            icon: "house.fill"
        )
    }

    private func sampleSnapshot(displayName: String) -> WidgetSnapshotStore.Snapshot {
        WidgetSnapshotStore.Snapshot(
            safeToSpend: 12.5,
            currencyCode: "CAD",
            monthLabel: "Oct",
            nextReminderTitle: nil,
            nextReminderDetail: nil,
            displayName: displayName,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            upcomingItems: nil,
            spentThisMonth: nil,
            plannedSpending: nil,
            budgetHealth: nil,
            topGoalName: nil,
            topGoalProgress: nil,
            topGoalDetail: nil
        )
    }
}
