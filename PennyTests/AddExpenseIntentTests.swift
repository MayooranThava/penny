import Foundation
import SwiftData
import Testing
@testable import Penny

@Suite("Add expense intent", .serialized, .isolatedTestResources)
@MainActor
struct AddExpenseIntentTests {
    @Test("The intent saves the amount, merchant, and settings currency")
    func savesAmountCurrencyAndMerchant() async throws {
        try saveSettings(currencyCode: "USD")
        let defaults = try #require(UserDefaults(suiteName: WidgetSnapshotStore.activeDefaultsSuite))
        let previous = PrivateModeStorage.load(from: defaults)
        defer { PrivateModeStorage.save(previous, to: defaults) }
        var visible = previous
        visible.isEnabled = false
        PrivateModeStorage.save(visible, to: defaults)
        let intent = AddExpenseIntent()
        intent.amount = 12.34
        intent.merchant = "Corner Cafe"
        intent.note = "Latte"
        intent.category = "Food"
        _ = try await intent.perform()

        let row = try #require(fetchExpenses().first { $0.title == "Corner Cafe" })
        #expect(row.amount == Decimal(string: "12.34"))
        #expect(row.note == "Latte")
        #expect(row.categoryName == "Food")
        #expect(row.transactionType == .expense)
        #expect(try fetchSettings()?.currencyCode == "USD")
        let reply = AddExpenseIntent.reply(
            for: QuickAddExpenseOutcome(
                title: row.title,
                amount: row.amount,
                currencyCode: "USD",
                categoryName: row.categoryName,
                note: row.note
            ),
            hidesAmount: false,
            locale: Locale(identifier: "en_US")
        )
        #expect(reply.contains("12.34"))
        #expect(reply.contains("Corner Cafe"))
    }

    @Test("Currency uses settings, then the phone locale")
    func currencyFallsBackToLocale() {
        #expect(QuickAddExpenseLogic.currencyCode(settingsCode: " usd ", locale: Locale(identifier: "en_GB")) == "USD")
        #expect(QuickAddExpenseLogic.currencyCode(settingsCode: nil, locale: Locale(identifier: "en_GB")) == "GBP")
        #expect(QuickAddExpenseLogic.currencyCode(settingsCode: " ", locale: Locale(identifier: "en_CA")) == "CAD")
    }

    @Test("Private mode on omits the amount and off includes it")
    func privateModeControlsTheReply() throws {
        let defaults = try #require(UserDefaults(suiteName: WidgetSnapshotStore.activeDefaultsSuite))
        let previous = PrivateModeStorage.load(from: defaults)
        defer { PrivateModeStorage.save(previous, to: defaults) }
        let controller = PrivateModeController(defaults: defaults)
        let wasEnabled = controller.isEnabled
        let hidTransactions = controller.settings.visibility.hideTransactions
        defer {
            controller.setHidden(.transactions, hidTransactions)
            controller.setEnabled(wasEnabled)
        }
        controller.setEnabled(true)
        controller.setHidden(.transactions, true)
        #expect(AddExpenseIntent.hidesTransactionAmounts)
        let hidden = AddExpenseIntent.reply(
            for: sampleOutcome,
            hidesAmount: AddExpenseIntent.hidesTransactionAmounts
        )
        #expect(hidden == "Added an expense at Corner Cafe.")
        #expect(!hidden.contains("12"))
        #expect(!hidden.contains("$"))

        controller.setEnabled(false)
        #expect(AddExpenseIntent.hidesTransactionAmounts == false)
        let shown = AddExpenseIntent.reply(
            for: sampleOutcome,
            hidesAmount: AddExpenseIntent.hidesTransactionAmounts,
            locale: Locale(identifier: "en_US")
        )
        #expect(shown.contains("12.34"))
        #expect(shown.contains("Corner Cafe"))
    }

    @Test("A failed save leaves no row and throws")
    func saveFailureLeavesNoRow() async throws {
        let container = try PennyPersistence.makeContainer()
        let context = ModelContext(container)
        var threw = false
        try PennySaveTesting.$forcedError.withValue(PennyForcedSaveFailure()) {
            do {
                _ = try QuickAddExpenseService.add(
                    amount: 8.5,
                    merchant: "Failed Cafe",
                    note: nil,
                    category: nil,
                    in: context,
                    locale: Locale(identifier: "en_US")
                )
                Issue.record("Expected the save to throw")
            } catch is TransactionSaveError {
                threw = true
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
        #expect(threw)
        #expect(try context.fetch(FetchDescriptor<Transaction>()).isEmpty)

        threw = false
        let intent = AddExpenseIntent()
        intent.amount = 8.5
        intent.merchant = "Failed Cafe"
        await PennySaveTesting.$forcedError.withValue(PennyForcedSaveFailure()) {
            do {
                _ = try await intent.perform()
                Issue.record("Expected perform() to throw")
            } catch is TransactionSaveError {
                threw = true
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
        #expect(threw)
        #expect(try fetchExpenses().isEmpty)
    }

    @Test("Invalid and zero amounts are rejected without saving")
    func rejectsInvalidAmounts() async throws {
        for value in [0, -3, Double.nan, Double.infinity] {
            let intent = AddExpenseIntent()
            intent.amount = value
            intent.merchant = "Nope"
            do {
                _ = try await intent.perform()
                Issue.record("Expected \(value) to be rejected")
            } catch is QuickAddExpenseError {
            } catch {
                Issue.record("Unexpected error for \(value): \(error)")
            }
        }
        #expect(try fetchExpenses().isEmpty)
    }

    @Test("A successful add reloads only the spending widgets")
    func reloadsOnlyAffectedWidgets() async throws {
        let previous = QuickAddWidgetRefresh.reload
        defer { QuickAddWidgetRefresh.reload = previous }
        var calls: [[String]] = []
        QuickAddWidgetRefresh.reload = { calls.append($0) }
        let intent = AddExpenseIntent()
        intent.amount = 3
        intent.merchant = "Bus"
        _ = try await intent.perform()
        #expect(calls == [QuickAddWidgetRefresh.affectedKinds])
        let kinds = try #require(calls.first)
        #expect(kinds.contains(PrivateWidgetKinds.safeToSpend))
        #expect(kinds.contains(PrivateWidgetKinds.monthlyBudget))
        #expect(kinds.contains(PrivateWidgetKinds.upcomingReminder))
        #expect(!kinds.contains(PrivateWidgetKinds.upcomingBills))
        #expect(!kinds.contains(PrivateWidgetKinds.savingsGoal))
    }

    @Test("The dialog is built from LocalizedStringResource and reloads by kind")
    func dialogAndReloadStayNarrow() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("Penny/Intents/AddExpenseIntent.swift"),
            encoding: .utf8
        )
        #expect(source.contains("LocalizedStringResource(stringLiteral:"))
        #expect(!source.contains("String.LocalizationValue"))
        #expect(source.contains("PrivateModeStorage.load"))
        #expect(source.contains(".masks(.transactions)"))
        #expect(source.contains("QuickAddWidgetRefresh.reloadAffected()"))
        #expect(!source.contains("reloadAllTimelines"))
    }

    @Test("Quick add runs without opening Penny")
    func runsWithoutOpeningTheApp() throws {
        #expect(AddExpenseIntent.openAppWhenRun == false)
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("Penny/Intents/AddExpenseIntent.swift"),
            encoding: .utf8
        )
        #expect(source.contains("static let openAppWhenRun = false"))
    }

    @Test("A saved Private mode setting hides the amount without refreshing the controller")
    func savedPrivateModeHidesAmount() throws {
        let defaults = try #require(UserDefaults(suiteName: WidgetSnapshotStore.activeDefaultsSuite))
        let previous = PrivateModeStorage.load(from: defaults)
        defer { PrivateModeStorage.save(previous, to: defaults) }
        let controller = PrivateModeController(defaults: defaults)
        controller.setEnabled(false)
        #expect(controller.masks(.transactions) == false)

        var record = PrivateModeRecord.fresh
        record.isEnabled = true
        record.visibility.hideTransactions = true
        PrivateModeStorage.save(record, to: defaults)
        #expect(controller.masks(.transactions) == false)

        #expect(AddExpenseIntent.hidesTransactionAmounts)
        let reply = AddExpenseIntent.reply(
            for: sampleOutcome,
            hidesAmount: AddExpenseIntent.hidesTransactionAmounts,
            locale: Locale(identifier: "en_US")
        )
        #expect(reply == "Added an expense at Corner Cafe.")
        #expect(!reply.contains("12"))
        #expect(!reply.contains("$"))
    }

    @Test("A spoken category matches an existing name, and a new one is created only when nothing matches")
    func categoryMatchesOrCreates() throws {
        #expect(QuickAddExpenseLogic.categoryChoice(spoken: "food", existingNames: ["Food"]).name == "Food")
        #expect(QuickAddExpenseLogic.categoryChoice(spoken: "food", existingNames: ["Food"]).createNew == false)
        #expect(QuickAddExpenseLogic.categoryChoice(spoken: "Kennel", existingNames: ["Food"]) == .init(name: "Kennel", createNew: true))

        let container = try PennyPersistence.makeContainer()
        let context = ModelContext(container)
        context.insert(BudgetCategory(
            name: "Food",
            icon: "fork.knife",
            budgetedAmount: 0,
            colourIdentifier: "food",
            sortOrder: 1
        ))
        try context.save()

        let matched = try QuickAddExpenseService.add(
            amount: 4,
            merchant: "Cafe",
            note: nil,
            category: "food",
            in: context,
            locale: Locale(identifier: "en_US")
        )
        #expect(matched.categoryName == "Food")
        let created = try QuickAddExpenseService.add(
            amount: 9,
            merchant: "Vet",
            note: nil,
            category: "Kennel",
            in: context,
            locale: Locale(identifier: "en_US")
        )
        #expect(created.categoryName == "Kennel")
        let categories = try context.fetch(FetchDescriptor<BudgetCategory>())
        #expect(categories.filter { $0.name.caseInsensitiveCompare("Food") == .orderedSame }.count == 1)
        #expect(categories.contains { $0.name == "Kennel" })
    }

    private var sampleOutcome: QuickAddExpenseOutcome {
        QuickAddExpenseOutcome(
            title: "Corner Cafe",
            amount: Decimal(string: "12.34")!,
            currencyCode: "USD",
            categoryName: "Food",
            note: ""
        )
    }

    private func saveSettings(currencyCode: String) throws {
        let container = try PennyPersistence.makeContainer()
        let context = ModelContext(container)
        context.insert(UserSettings(currencyCode: currencyCode, hasCompletedOnboarding: true))
        try context.save()
    }

    private func fetchExpenses() throws -> [Transaction] {
        let container = try PennyPersistence.makeContainer()
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<Transaction>())
    }

    private func fetchSettings() throws -> UserSettings? {
        let container = try PennyPersistence.makeContainer()
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<UserSettings>()).first
    }
}
