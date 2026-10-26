import Foundation
import Testing
@testable import Penny

@Suite("Widget snapshots", .serialized, .isolatedTestResources)
struct WidgetSnapshotTests {
    private let enUS = Locale(identifier: "en_US")
    private let germany = Locale(identifier: "de_DE")

    @Test("Snapshots use the test UserDefaults suite, not the App Group")
    func usesIsolatedDefaultsSuite() {
        let suite = WidgetSnapshotStore.activeDefaultsSuite
        #expect(suite != WidgetSnapshotStore.appGroupID)
        #expect(suite.hasPrefix("PennyTests."))
    }

    @Test("0.10 + 0.20 is stored as 0.30, not a binary fraction")
    func dimePlusTwentyCents() throws {
        let sum = Decimal(string: "0.10")! + Decimal(string: "0.20")!
        #expect(sum == Decimal(string: "0.30"))
        #expect(sum != Decimal(0.10 + 0.20))

        let loaded = try roundTrip(snapshot(safeToSpend: sum, currencyCode: "USD"))
        #expect(loaded.safeToSpend == Decimal(string: "0.30"))
        #expect(loaded.safeToSpend != Decimal(0.10 + 0.20))

        let shown = loaded.formattedSafeToSpend(locale: enUS)
        #expect(shown == MoneyFormatters.string(from: sum, currencyCode: "USD", locale: enUS))
        #expect(shown.contains("0.30"))

        let json = try storedJSON()
        #expect(!json.contains("0.30000000000000004"))
    }

    @Test("Half-cent amounts round like the app, not like Double")
    func halfCentRounding() throws {
        let oneAndAHalfCent = Decimal(string: "1.005")!
        #expect(oneAndAHalfCent != Decimal(1.005))

        let loaded = try roundTrip(snapshot(safeToSpend: oneAndAHalfCent, currencyCode: "USD"))
        #expect(loaded.safeToSpend == oneAndAHalfCent)

        let shown = loaded.formattedSafeToSpend(locale: enUS)
        let app = MoneyFormatters.string(from: oneAndAHalfCent, currencyCode: "USD", locale: enUS)
        let viaDouble = MoneyFormatters.string(from: Decimal(1.005), currencyCode: "USD", locale: enUS)
        // The widget must show whatever the app's NumberFormatter shows. Apple
        // rounds a half cent to even ($1.005 → $1.00); that display can match
        // the Double path even though the stored decimals differ.
        #expect(shown == app)
        #expect(shown.contains("1.00") || shown.contains("1.01"))
        #expect(viaDouble.contains("1.00"))
        #expect(loaded.safeToSpend != Decimal(1.005))

        let halfCent = Decimal(string: "0.005")!
        let halfLoaded = try roundTrip(snapshot(safeToSpend: halfCent, currencyCode: "USD"))
        #expect(halfLoaded.safeToSpend == halfCent)
        #expect(
            halfLoaded.formattedSafeToSpend(locale: enUS)
                == MoneyFormatters.string(from: halfCent, currencyCode: "USD", locale: enUS)
        )

        let json = try storedJSON()
        #expect(json.contains("0.005"))
        #expect(!json.contains("0.004999"))
    }

    @Test("Negative amounts keep their cents and their sign")
    func negatives() throws {
        let sum = Decimal(string: "-0.10")! + Decimal(string: "-0.20")!
        #expect(sum == Decimal(string: "-0.30"))

        let loaded = try roundTrip(
            snapshot(
                safeToSpend: Decimal(string: "-800.01")!,
                currencyCode: "USD",
                spent: sum,
                planned: Decimal(string: "-19.99")!
            )
        )
        #expect(loaded.safeToSpend == Decimal(string: "-800.01"))
        #expect(loaded.spentThisMonth == Decimal(string: "-0.30"))
        #expect(loaded.plannedSpending == Decimal(string: "-19.99"))

        let shown = loaded.formattedSafeToSpend(locale: enUS)
        #expect(shown == MoneyFormatters.string(from: loaded.safeToSpend, currencyCode: "USD", locale: enUS))
        #expect(shown.contains("-"))
        #expect(shown.contains("800.01"))

        let budget = loaded.formattedBudgetAmount(loaded.spentThisMonth ?? 0, locale: enUS)
        #expect(budget == MoneyFormatters.compact(from: sum, currencyCode: "USD", locale: enUS))
        #expect(budget.contains("0.30"))
    }

    @Test("Large amounts keep cents that Double cannot represent")
    func largeValues() throws {
        let large = Decimal(string: "9999999999999.99")!
        #expect(large != Decimal(9999999999999.99))

        let loaded = try roundTrip(
            snapshot(safeToSpend: large, currencyCode: "USD", spent: large, planned: large)
        )
        #expect(loaded.safeToSpend == large)
        #expect(loaded.spentThisMonth == large)
        #expect(loaded.plannedSpending == large)

        let shown = loaded.formattedSafeToSpend(locale: enUS)
        #expect(shown == MoneyFormatters.string(from: large, currencyCode: "USD", locale: enUS))
        #expect(shown.contains("999,999,999,999.99") || shown.contains("9999999999999.99"))

        let budget = loaded.formattedBudgetAmount(large, locale: enUS)
        #expect(budget == MoneyFormatters.compact(from: large, currencyCode: "USD", locale: enUS))
        #expect(budget.contains("999,999,999,999.99") || budget.contains("9999999999999.99"))

        let json = try storedJSON()
        #expect(json.contains("9999999999999.99"))
    }

    @Test("Non-USD locales use the same currency formatting as the app")
    func nonUSDLocale() throws {
        let amount = Decimal(string: "-1234.50")!
        let loaded = try roundTrip(snapshot(safeToSpend: amount, currencyCode: "EUR", spent: amount))
        #expect(loaded.safeToSpend == amount)

        let shown = loaded.formattedSafeToSpend(locale: germany)
        let app = MoneyFormatters.string(from: amount, currencyCode: "EUR", locale: germany)
        #expect(shown == app)
        #expect(shown.contains(",50"))
        #expect(shown.contains("€") || shown.contains("EUR"))

        let budget = loaded.formattedBudgetAmount(amount, locale: germany)
        #expect(budget == MoneyFormatters.compact(from: amount, currencyCode: "EUR", locale: germany))
    }

    @Test("Safe to Spend on the widget matches the app calculation to the cent")
    func safeToSpendMatchesApp() throws {
        let safe = FinanceCalculator.safeToSpend(
            monthlyIncome: Decimal(string: "2500.10")!,
            recurringCommitted: Decimal(string: "100.20")!,
            discretionarySpent: Decimal(string: "0.10")! + Decimal(string: "0.20")!,
            plannedSavings: Decimal(string: "1.005")!
        )
        #expect(safe == Decimal(string: "2398.595"))

        let loaded = try roundTrip(snapshot(safeToSpend: safe, currencyCode: "USD"))
        #expect(loaded.safeToSpend == safe)

        let shown = loaded.formattedSafeToSpend(locale: enUS)
        #expect(shown == MoneyFormatters.string(from: safe, currencyCode: "USD", locale: enUS))
        #expect(shown.contains("2,398.60") || shown.contains("2398.60"))
    }

    @Test("Snapshots written before cents were exact still load")
    func legacyDoubleSnapshotsRemainReadable() throws {
        let original = """
        {"safeToSpend":12.5,"currencyCode":"CAD","monthLabel":"Oct","displayName":"Alex","updatedAt":700000000}
        """
        let oldest = try loadJSON(original)
        #expect(oldest.safeToSpend == Decimal(string: "12.5"))
        #expect(oldest.currencyCode == "CAD")
        #expect(oldest.displayName == "Alex")
        #expect(oldest.monthLabel == "Oct")
        #expect(oldest.spentThisMonth == nil)
        #expect(oldest.plannedSpending == nil)
        #expect(oldest.upcomingItems == nil)
        #expect(oldest.updatedAt == Date(timeIntervalSinceReferenceDate: 700_000_000))
        #expect(oldest.formattedSafeToSpend(locale: Locale(identifier: "en_CA")).contains("12.50"))

        let previousSchema = """
        {"safeToSpend":1.005,"currencyCode":"USD","monthLabel":"October","nextReminderTitle":"Rent due","nextReminderDetail":"$10.25 · Oct 1","displayName":"Alex","updatedAt":751234567.5,"upcomingItems":[{"title":"Rent","detail":"$10.25 · Oct 1","kind":"bill"}],"spentThisMonth":19.99,"plannedSpending":-800.01,"budgetHealth":"near","topGoalName":"Emergency","topGoalProgress":0.62,"topGoalDetail":"$1.50 of $10.00"}
        """
        let previous = try loadJSON(previousSchema)
        #expect(previous.safeToSpend == Decimal(string: "1.005"))
        #expect(previous.spentThisMonth == Decimal(string: "19.99"))
        #expect(previous.plannedSpending == Decimal(string: "-800.01"))
        #expect(previous.nextReminderTitle == "Rent due")
        #expect(previous.upcomingList.count == 1)
        #expect(previous.upcomingList[0].title == "Rent")
        #expect(previous.budgetHealth == "near")
        #expect(previous.topGoalName == "Emergency")
        #expect(previous.topGoalProgress == 0.62)
        #expect(previous.topGoalDetail == "$1.50 of $10.00")
        let legacyShown = previous.formattedSafeToSpend(locale: enUS)
        #expect(legacyShown == MoneyFormatters.string(from: previous.safeToSpend, currencyCode: "USD", locale: enUS))
        #expect(legacyShown.contains("1.00") || legacyShown.contains("1.01"))

        let binaryResidue = """
        {"safeToSpend":0.30000000000000004,"currencyCode":"USD","monthLabel":"October","displayName":"Alex","updatedAt":700000000,"spentThisMonth":null}
        """
        let residue = try loadJSON(binaryResidue)
        #expect(residue.safeToSpend == Decimal(string: "0.30000000000000004"))
        #expect(residue.spentThisMonth == nil)
        #expect(residue.displayName == "Alex")
    }

    private func snapshot(
        safeToSpend: Decimal,
        currencyCode: String,
        spent: Decimal? = nil,
        planned: Decimal? = nil
    ) -> WidgetSnapshotStore.Snapshot {
        WidgetSnapshotStore.Snapshot(
            safeToSpend: safeToSpend,
            currencyCode: currencyCode,
            monthLabel: "October",
            nextReminderTitle: "Rent due",
            nextReminderDetail: "$10.25 · Oct 1",
            displayName: "Alex",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            upcomingItems: [.init(title: "Rent", detail: "$10.25 · Oct 1", kind: "bill")],
            spentThisMonth: spent,
            plannedSpending: planned,
            budgetHealth: "healthy",
            topGoalName: "Emergency fund",
            topGoalProgress: 0.62,
            topGoalDetail: "$6,200 of $10,000"
        )
    }

    private func roundTrip(_ snapshot: WidgetSnapshotStore.Snapshot) throws -> WidgetSnapshotStore.Snapshot {
        WidgetSnapshotStore.save(snapshot)
        return try #require(WidgetSnapshotStore.load())
    }

    private func loadJSON(_ json: String) throws -> WidgetSnapshotStore.Snapshot {
        let defaults = try #require(UserDefaults(suiteName: WidgetSnapshotStore.activeDefaultsSuite))
        defaults.set(Data(json.utf8), forKey: WidgetSnapshotStore.snapshotKey)
        return try #require(WidgetSnapshotStore.load())
    }

    private func storedJSON() throws -> String {
        let defaults = try #require(UserDefaults(suiteName: WidgetSnapshotStore.activeDefaultsSuite))
        let data = try #require(defaults.data(forKey: WidgetSnapshotStore.snapshotKey))
        return String(decoding: data, as: UTF8.self)
    }
}
