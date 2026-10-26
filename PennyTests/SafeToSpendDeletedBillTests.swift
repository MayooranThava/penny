import Foundation
import SwiftData
import Testing
@testable import Penny

/// Safe to Spend must ignore bills Plan → Delete has turned off (`isActive == false`).
/// The widget snapshot is written by the same total the app uses.
@Suite("Safe to Spend deleted bills", .serialized, .isolatedTestResources)
struct SafeToSpendDeletedBillTests {
    @Test("A deleted bill does not count toward Safe to Spend")
    @MainActor
    func deletedBillDoesNotCount() throws {
        let income = money("5000.00")
        let rent = makeBill(name: "Rent", amount: money("2000.00"), isActive: false)
        let phone = makeBill(name: "Phone", amount: money("80.00"), isActive: true, paidCycleKey: "")
        let safe = appSafeToSpend(income: income, bills: [rent, phone])
        #expect(safe == money("4920.00"))
        #expect(safe != money("2920.00"))

        let snapshot = try publishSnapshot(income: income, bills: [rent, phone])
        #expect(snapshot.safeToSpend == safe)
    }

    @Test("An active unpaid bill still counts toward Safe to Spend")
    @MainActor
    func activeUnpaidBillStillCounts() throws {
        let income = money("1000.00")
        let phone = makeBill(name: "Phone", amount: money("80.10"), isActive: true, paidCycleKey: "")
        #expect(phone.paidCycleKey.isEmpty)
        #expect(BillPaymentCycle.includesInCommittedSpend(isActive: phone.isActive))

        let without = appSafeToSpend(income: income, bills: [])
        let withPhone = appSafeToSpend(income: income, bills: [phone])
        #expect(without == income)
        #expect(withPhone == income - money("80.10"))

        // The old paid-cycle checklist is not how a bill is marked paid.
        // An active bill still counts when that key is filled in.
        let cycle = BillPaymentCycle.key(recurrence: .monthly, asOf: .now)
        let checkedOff = makeBill(name: "Internet", amount: money("70.00"), isActive: true, paidCycleKey: cycle)
        #expect(checkedOff.paidCycleKey == cycle)
        let withBoth = appSafeToSpend(income: income, bills: [phone, checkedOff])
        #expect(withBoth == income - money("80.10") - money("70.00"))

        let snapshot = try publishSnapshot(income: income, bills: [phone, checkedOff])
        #expect(snapshot.safeToSpend == withBoth)
    }

    @Test("The widget snapshot matches the app Safe to Spend to the cent")
    @MainActor
    func widgetSnapshotMatchesApp() throws {
        let income = money("2500.10")
        let phone = makeBill(name: "Phone", amount: money("100.20"), isActive: true, paidCycleKey: "")
        let cable = makeBill(name: "Cable", amount: money("19.99"), isActive: false)
        let coffee = Transaction(
            title: "Coffee",
            amount: money("0.10"),
            transactionType: .expense,
            categoryName: "Food"
        )
        let tea = Transaction(
            title: "Tea",
            amount: money("0.20"),
            transactionType: .expense,
            categoryName: "Food"
        )
        let safe = appSafeToSpend(
            income: income,
            bills: [phone, cable],
            transactions: [coffee, tea]
        )
        #expect(safe == money("2399.60"))
        #expect(safe != money("2379.61"))

        let snapshot = try publishSnapshot(
            income: income,
            bills: [phone, cable],
            transactions: [coffee, tea]
        )
        #expect(snapshot.safeToSpend == safe)
    }

    @Test("Deleting a bill removes its amount from Safe to Spend straight away")
    @MainActor
    func deletingABillUpdatesSafeToSpendAndWidget() throws {
        let container = try PennyPersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let income = money("5000.00")
        let rent = makeBill(name: "Rent", amount: money("2000.00"), isActive: true)
        let phone = makeBill(name: "Phone", amount: money("80.00"), isActive: true, paidCycleKey: "")
        context.insert(rent)
        context.insert(phone)
        context.insert(UserSettings(
            currencyCode: "CAD",
            monthlyIncome: income,
            plannedMonthlySavings: 0,
            hasCompletedOnboarding: true
        ))
        try context.save()

        let beforeBills = try context.fetch(FetchDescriptor<RecurringBill>())
        let beforeApp = appSafeToSpend(income: income, bills: beforeBills)
        let before = try publishSnapshot(income: income, bills: beforeBills)
        #expect(beforeApp == money("2920.00"))
        #expect(before.safeToSpend == beforeApp)

        rent.isActive = false
        try context.save()

        let afterBills = try context.fetch(FetchDescriptor<RecurringBill>())
        #expect(afterBills.count == 2)
        #expect(afterBills.contains { $0.name == "Rent" && !$0.isActive })
        let afterApp = appSafeToSpend(income: income, bills: afterBills)
        let after = try publishSnapshot(income: income, bills: afterBills)
        #expect(afterApp == money("4920.00"))
        #expect(after.safeToSpend == afterApp)
        #expect(after.safeToSpend == before.safeToSpend + money("2000.00"))
    }

    @Test("A paused bill and a deleted bill produce the same Safe to Spend")
    @MainActor
    func pausedAndDeletedBillsMatch() throws {
        let income = money("1000.00")
        let phone = makeBill(name: "Phone", amount: money("40.00"), isActive: true, paidCycleKey: "")
        let pausedGym = makeBill(name: "Gym", amount: money("45.00"), isActive: false)
        let paused = appSafeToSpend(income: income, bills: [phone, pausedGym])
        let pausedSnapshot = try publishSnapshot(income: income, bills: [phone, pausedGym])

        let deletedGym = makeBill(name: "Gym", amount: money("45.00"), isActive: true)
        deletedGym.isActive = false
        let phoneAgain = makeBill(name: "Phone", amount: money("40.00"), isActive: true, paidCycleKey: "")
        let deleted = appSafeToSpend(income: income, bills: [phoneAgain, deletedGym])
        let deletedSnapshot = try publishSnapshot(income: income, bills: [phoneAgain, deletedGym])

        let phoneOnly = appSafeToSpend(income: income, bills: [phone])
        #expect(paused == money("960.00"))
        #expect(deleted == paused)
        #expect(paused == phoneOnly)
        #expect(pausedSnapshot.safeToSpend == deletedSnapshot.safeToSpend)
        #expect(pausedSnapshot.safeToSpend == paused)
    }

    @Test("After Reset, there are no leftover bill amounts")
    @MainActor
    func resetLeavesNoBillAmounts() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("PennyResetBills-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let storeURL = root.appendingPathComponent("Penny.store")
        let income = money("5000.00")
        let rentAmount = money("2000.00")

        do {
            let container = try PennyPersistence.makeContainer(at: storeURL)
            let context = ModelContext(container)
            let rent = makeBill(name: "Rent", amount: rentAmount, isActive: true)
            context.insert(rent)
            context.insert(UserSettings(
                currencyCode: "CAD",
                monthlyIncome: income,
                plannedMonthlySavings: 0,
                hasCompletedOnboarding: true
            ))
            try context.save()

            let before = try publishSnapshot(income: income, bills: [rent])
            #expect(before.safeToSpend == income - rentAmount)

            _ = try await PennyPersistence.reset(in: context)
            #expect(WidgetSnapshotStore.load() == nil)
            let remaining = try context.fetch(FetchDescriptor<RecurringBill>())
            #expect(remaining.isEmpty)
            #expect(remaining.reduce(Decimal(0)) { $0 + $1.amount } == 0)

            let after = try publishSnapshot(income: income, bills: remaining)
            #expect(after.safeToSpend == income)
            #expect(after.safeToSpend != income - rentAmount)
        }

        let reopened = try PennyPersistence.makeContainer(at: storeURL)
        let rows = try ModelContext(reopened).fetch(FetchDescriptor<RecurringBill>())
        #expect(rows.isEmpty)
        #expect(rows.reduce(Decimal(0)) { $0 + $1.amount } == 0)
    }

    @MainActor
    private func makeBill(
        name: String,
        amount: Decimal,
        isActive: Bool,
        paidCycleKey: String = ""
    ) -> RecurringBill {
        RecurringBill(
            name: name,
            amount: amount,
            dueDay: 1,
            categoryName: "Housing",
            recurrence: .monthly,
            nextDueDate: .now,
            startDate: .now,
            isActive: isActive,
            icon: "doc.text.fill",
            paidCycleKey: paidCycleKey
        )
    }

    private func money(_ text: String) -> Decimal {
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))!
    }

    @MainActor
    private func appSafeToSpend(
        income: Decimal,
        bills: [RecurringBill],
        debts: [Debt] = [],
        transactions: [Transaction] = [],
        savings: Decimal = 0,
        month: Date = DateHelpers.startOfMonth()
    ) -> Decimal {
        let committed = FinanceCalculator.totalMonthlyCommitted(
            billAmountsAndRecurrence: bills.map { ($0.amount, $0.recurrence, $0.isActive) },
            debtPayments: debts.map(\.plannedMonthlyPayment)
        )
        let reserved = Set(bills.map { $0.name.lowercased() } + debts.map { $0.name.lowercased() })
        let discretionary = transactions
            .filter { DateHelpers.isSameMonth($0.date, month) && $0.transactionType == .expense }
            .filter { !reserved.contains($0.title.lowercased()) }
            .reduce(Decimal(0)) { $0 + $1.amount }
        let planned = FinanceCalculator.effectiveMonthlySavings(
            goals: [],
            fallbackPlannedSavings: savings
        )
        return FinanceCalculator.safeToSpend(
            monthlyIncome: income,
            recurringCommitted: committed,
            discretionarySpent: discretionary,
            plannedSavings: planned
        )
    }

    @MainActor
    private func publishSnapshot(
        income: Decimal,
        bills: [RecurringBill],
        debts: [Debt] = [],
        transactions: [Transaction] = [],
        savings: Decimal = 0,
        month: Date = DateHelpers.startOfMonth()
    ) throws -> WidgetSnapshotStore.Snapshot {
        let settings = UserSettings(
            currencyCode: "CAD",
            monthlyIncome: income,
            plannedMonthlySavings: savings,
            hasCompletedOnboarding: true,
            displayName: "Alex"
        )
        WidgetSnapshotPublisher.publish(
            transactions: transactions,
            categories: [],
            bills: bills,
            debts: debts,
            goals: [],
            allocations: [],
            settings: settings,
            month: month
        )
        return try #require(WidgetSnapshotStore.load())
    }
}
