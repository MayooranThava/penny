import Foundation
import SwiftData
import Testing
@testable import Penny

/// Private mode acceptance checks. The suite is serialized because it reads
/// `WidgetSnapshotStore` and the shared App Group flag through the test suite.
@Suite("Private mode", .serialized, .isolatedTestResources)
struct PrivateModeTests {
    private let enUS = Locale(identifier: "en_US")

    @Test("Masked totals are five dots with no currency and no digits")
    func maskHidesMagnitude() {
        let samples: [Decimal] = [
            Decimal(string: "0.01")!,
            Decimal(string: "999.35")!,
            Decimal(string: "1234567.89")!,
            Decimal(string: "-1234567.89")!
        ]
        for amount in samples {
            let shown = PrivateAmountLogic.display(
                amount: amount,
                currencyCode: "USD",
                style: .standard,
                isPrivate: true,
                locale: enUS
            )
            #expect(shown == PrivateAmountLogic.mask)
            #expect(shown.count == 5)
            #expect(shown == "●●●●●")
            #expect(!shown.contains("$"))
            #expect(!PrivateAmountLogic.containsDigit(shown))
            let spoken = PrivateAmountLogic.accessibilityText(
                amount: amount,
                currencyCode: "USD",
                style: .standard,
                isPrivate: true,
                locale: enUS
            )
            #expect(spoken == "Hidden amount")
            #expect(!PrivateAmountLogic.containsDigit(spoken))
        }
    }

    @Test("Private mode off shows the formatted amount to the cent")
    func showsExactAmountWhenOff() {
        let amount = Decimal(string: "999.35")!
        let shown = PrivateAmountLogic.display(
            amount: amount,
            currencyCode: "USD",
            style: .standard,
            isPrivate: false,
            locale: enUS
        )
        #expect(shown == MoneyFormatters.string(from: amount, currencyCode: "USD", locale: enUS))
        #expect(shown.contains("999.35"))
    }

    @Test("Individual transaction and bill rows are not masked")
    func individualsStayVisible() throws {
        let amount = Decimal(string: "19.99")!
        let shown = PrivateAmountLogic.display(
            amount: amount,
            currencyCode: "CAD",
            style: .signed(showPlus: false),
            isPrivate: true,
            isTotal: false,
            locale: enUS
        )
        #expect(shown.contains("19.99"))
        #expect(shown != PrivateAmountLogic.mask)

        let components = try source("Penny/Components/PennyComponents.swift")
        let transaction = try slice(components, from: "struct TransactionRow", until: "struct RingProgressView")
        let bill = try slice(components, from: "struct BillRow", until: "struct TransactionRow")
        #expect(!transaction.contains("PrivateAmount"))
        #expect(transaction.contains("MoneyFormatters.signed"))
        #expect(!bill.contains("PrivateAmount"))
        #expect(bill.contains("MoneyText"))
    }

    @Test("Insight sentences keep the words and mask only the amount")
    func insightSentencesMaskTotals() throws {
        let over = MoneyFormatters.string(from: Decimal(string: "42.50")!, currencyCode: "CAD", locale: enUS)
        let presented = PrivateInsightText.present(
            title: "You're \(over) over your Food budget.",
            detail: "Based on the budget and spending you entered for this category.",
            includesTotal: true,
            isPrivate: true
        )
        #expect(presented.title.contains("You're"))
        #expect(presented.title.contains("over your Food budget."))
        #expect(presented.title.contains(PrivateAmountLogic.mask))
        #expect(!PrivateAmountLogic.containsDigit(presented.title))
        #expect(presented.accessibilityTitle.contains("Hidden amount"))
        #expect(presented.accessibilityTitle.contains("Food"))

        let insights = InsightEngine.generate(
            from: InsightEngine.Input(
                categorySpends: [
                    .init(name: "Food", current: 140, previous: 80, budgeted: 100)
                ],
                upcomingBillsWithinDays: [("Internet", 2, Decimal(string: "79.99")!)],
                goals: [],
                monthlyBudget: 0,
                spentSoFar: 0,
                dayOfMonth: 1,
                daysInMonth: 30,
                currencyCode: "CAD",
                now: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            limit: 8
        )
        let overBudget = try #require(insights.first { $0.title.contains("over your Food budget") })
        #expect(overBudget.includesTotal)
        let bill = try #require(insights.first { $0.title.contains("Internet") })
        #expect(bill.includesTotal == false)
        let masked = PrivateInsightText.present(
            title: overBudget.title,
            detail: overBudget.detail,
            includesTotal: overBudget.includesTotal,
            isPrivate: true
        )
        #expect(masked.title.contains("Food"))
        #expect(!PrivateAmountLogic.containsDigit(masked.title))
        let open = PrivateInsightText.present(
            title: bill.title,
            detail: bill.detail,
            includesTotal: bill.includesTotal,
            isPrivate: true
        )
        #expect(open.detail.contains("79.99"))
    }

    @Test("PDF and CSV exports keep real numbers when private mode is on")
    func exportsIgnorePrivateMode() throws {
        let defaults = try #require(UserDefaults(suiteName: WidgetSnapshotStore.activeDefaultsSuite))
        PrivateModeDefaults.setEnabled(true, in: defaults)
        #expect(PrivateModeStore.isEnabled)

        let lines = MonthlySummaryPDFService.summaryLines(
            for: MonthlySummaryPDFService.Input(
                monthLabel: "October",
                currencyCode: "USD",
                displayName: "Alex",
                income: Decimal(string: "5000")!,
                spent: Decimal(string: "999.35")!,
                billsMonthly: Decimal(string: "1750")!,
                safeToSpend: Decimal(string: "1234.56")!
            ),
            locale: enUS
        )
        let pdf = lines.joined(separator: "\n")
        #expect(pdf.contains("999.35"))
        #expect(pdf.contains("1,234.56"))
        #expect(!pdf.contains(PrivateAmountLogic.mask))

        let csv = CSVExportLogic.makeCSV(rows: [
            .init(
                date: Date(timeIntervalSince1970: 1_700_000_000),
                title: "Rent",
                amount: Decimal(string: "1234.56")!,
                type: "expense",
                category: "Housing",
                note: "",
                merchant: "",
                source: ""
            )
        ])
        #expect(csv.contains("1234.56"))
        #expect(!csv.contains(PrivateAmountLogic.mask))
    }

    @Test("The flag lives in the App Group suite, defaults off, and survives a new reader")
    func persistenceSurvivesRelaunch() throws {
        let suite = WidgetSnapshotStore.activeDefaultsSuite
        #expect(suite.hasPrefix("PennyTests."))
        let defaults = try #require(UserDefaults(suiteName: suite))
        #expect(PrivateModeDefaults.isEnabled(in: defaults) == false)
        #expect(defaults.object(forKey: PrivateModeDefaults.key) == nil)
        #expect(PrivateModeDefaults.key == "penny.privateMode.enabled")

        let settings = try source("Penny/Models/Models.swift")
        let userSettings = try slice(settings, from: "final class UserSettings", until: "enum AppAppearance")
        #expect(!userSettings.contains("privateMode"))

        let controllerSource = try source("Penny/Services/PrivateModeController.swift")
        #expect(controllerSource.contains("WidgetSnapshotStore.activeDefaultsSuite"))
        #expect(!controllerSource.contains("import SwiftData"))
        #expect(!controllerSource.contains("modelContext"))
        #expect(!controllerSource.contains("WidgetSnapshotPublisher"))
        #expect(!controllerSource.contains(".save("))

        let eye = PrivateModeController(reloader: RecordingPrivateReloader())
        eye.toggle()
        let relaunch = UserDefaults(suiteName: suite)
        #expect(relaunch?.bool(forKey: PrivateModeDefaults.key) == true)
        let next = PrivateModeController(reloader: RecordingPrivateReloader())
        #expect(next.isEnabled)
    }

    @Test("The eye, Settings, and the shortcut share one flag")
    @MainActor
    func controlsShareOneFlag() async throws {
        let suite = WidgetSnapshotStore.activeDefaultsSuite
        let defaults = try #require(UserDefaults(suiteName: suite))
        let eye = PrivateModeController(reloader: RecordingPrivateReloader())
        eye.toggle()
        #expect(PrivateModeDefaults.isEnabled(in: defaults))

        let settings = PrivateModeController(reloader: RecordingPrivateReloader())
        settings.setEnabled(false)
        #expect(PrivateModeDefaults.isEnabled(in: defaults) == false)

        try await TogglePrivateModeIntent().perform()
        #expect(PrivateModeDefaults.isEnabled(in: defaults))
        let afterShortcut = PrivateModeController(reloader: RecordingPrivateReloader())
        #expect(afterShortcut.isEnabled)
        #expect(PrivateAmountLogic.shortcutTitle == "Toggle Penny private mode")
        #expect(PrivateAmountLogic.eyeAccessibilityLabel(isPrivate: false) == "Hide totals")
        #expect(PrivateAmountLogic.eyeAccessibilityLabel(isPrivate: true) == "Show totals")
    }

    @Test("Widgets mask totals and keep each upcoming bill amount")
    func widgetDisplay() {
        let safe = WidgetPrivateDisplay.safeToSpend(
            amount: Decimal(string: "3350.40")!,
            currencyCode: "CAD",
            isPrivate: true,
            site: .widgetSafeToSpend,
            locale: enUS
        )
        let lock = WidgetPrivateDisplay.safeToSpend(
            amount: Decimal(string: "3350.40")!,
            currencyCode: "CAD",
            isPrivate: true,
            site: .widgetLockScreenSafeToSpend,
            locale: enUS
        )
        let spent = WidgetPrivateDisplay.budget(
            amount: 1240,
            currencyCode: "CAD",
            isPrivate: true,
            site: .widgetMonthlyBudgetSpent,
            locale: enUS
        )
        let goal = WidgetPrivateDisplay.goalDetail(
            "$6,200 of $10,000",
            isPrivate: true,
            site: .widgetSavingsGoal
        )
        let bill = WidgetPrivateDisplay.upcomingBillDetail("$1,750 · Oct 1", isPrivate: true)
        #expect(safe == PrivateAmountLogic.mask)
        #expect(lock == PrivateAmountLogic.mask)
        #expect(spent == PrivateAmountLogic.mask)
        #expect(!PrivateAmountLogic.containsDigit(goal))
        #expect(bill.contains("1,750"))
        #expect(bill.contains("Oct 1"))
    }

    @Test("Leaving the foreground suppresses the crossfade and re-reads the flag")
    @MainActor
    func appSwitcherMasksBeforeSnapshot() {
        let controller = PrivateModeController(reloader: RecordingPrivateReloader())
        controller.setEnabled(true)
        controller.noteScenePhase(.inactive)
        #expect(controller.isEnabled)
        #expect(controller.animationsSuppressed)
        #expect(PrivateAmountLogic.crossfadeSeconds(reduceMotion: false, animationsSuppressed: true) == 0)
        controller.noteScenePhase(.active)
        #expect(!controller.animationsSuppressed)
        #expect(PrivateAmountLogic.crossfadeSeconds(reduceMotion: false, animationsSuppressed: false) == 0.2)
    }

    @Test("Bill reminders keep the original wording when private mode is off")
    func billReminderMatchesPreviousCopy() throws {
        let open = PennyNotificationContent.billReminder(
            name: "Internet",
            individualAmount: nil,
            billsTotal: nil,
            currencyCode: "EUR",
            isPrivate: false,
            locale: enUS
        )
        #expect(open.title == "Upcoming bill")
        #expect(open.body == "Internet is due soon.")

        let service = try source("Penny/Services/NotificationService.swift")
        #expect(!service.contains("currencyCode: \"CAD\""))
        #expect(service.contains("currencyCode: currencyCode"))
        #expect(!service.contains("notifyWalletConnectedIfAuthorized"))
        #expect(!service.contains("Connected ✓"))
        let setup = try source("Penny/Features/Settings/ApplePayCaptureSetupView.swift")
        #expect(!setup.contains("notifyWalletConnectedIfAuthorized"))
    }

    @Test("Every hidden total is built through a PrivateAmount site")
    func everyTotalSiteIsWired() throws {
        var combined = ""
        for folder in ["Penny", "PennyWidgets"] {
            let root = repoRoot().appendingPathComponent(folder, isDirectory: true)
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
                Issue.record("Could not read \(folder)")
                continue
            }
            for case let url as URL in enumerator where url.pathExtension == "swift" {
                combined += (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                combined += "\n"
            }
        }
        var missing: [String] = []
        for site in PrivateTotalSite.allCases where !combined.contains(".\(site.rawValue)") {
            missing.append(site.rawValue)
        }
        #expect(missing.isEmpty, "Totals with no PrivateAmount site: \(missing.joined(separator: ", "))")
    }

    @Test("The eye button is its own VoiceOver control on the Safe to Spend card")
    func eyeButtonIsItsOwnAccessibilityElement() throws {
        let home = try source("Penny/Features/Home/HomeView.swift")
        let card = try slice(home, from: "private var safeToSpendCardBody", until: "private func breakdownRow")
        let combine = try #require(card.range(of: ".accessibilityElement(children: .combine)"))
        let beforeCombine = String(card[..<combine.lowerBound])
        let afterCombine = String(card[combine.upperBound...])
        #expect(!beforeCombine.contains("PrivateModeEyeButton"))
        #expect(afterCombine.contains("PrivateModeEyeButton"))
        #expect(afterCombine.contains(".accessibilityElement(children: .contain)"))

        let button = try slice(
            try source("Penny/Components/PrivateAmount.swift"),
            from: "struct PrivateModeEyeButton",
            until: "struct PrivateInsightBlock"
        )
        #expect(button.contains("Button"))
        #expect(button.contains(".accessibilityAddTraits(.isButton)"))
        #expect(button.contains("eyeAccessibilityLabel"))
        #expect(PrivateAmountLogic.eyeAccessibilityLabel(isPrivate: false) == "Hide totals")
        #expect(PrivateAmountLogic.eyeAccessibilityLabel(isPrivate: true) == "Show totals")
    }

    @Test("Widget timelines keep real snapshot numbers and mask them at render")
    func widgetsMaskFromTheFlagAtRender() throws {
        let defaults = try #require(UserDefaults(suiteName: WidgetSnapshotStore.activeDefaultsSuite))
        PrivateModeDefaults.setEnabled(true, in: defaults)
        let snapshot = WidgetSnapshotStore.Snapshot.placeholder
        WidgetSnapshotStore.save(snapshot)
        #expect(snapshot.safeToSpend > 0)
        let shown = WidgetPrivateDisplay.safeToSpend(
            amount: snapshot.safeToSpend,
            currencyCode: snapshot.currencyCode,
            isPrivate: PrivateModeStore.isEnabled,
            site: .widgetSafeToSpend,
            locale: enUS
        )
        #expect(shown == PrivateAmountLogic.mask)
        #expect(PrivateModeStore.isEnabled)
        let stored = try #require(defaults.data(forKey: WidgetSnapshotStore.snapshotKey))
        #expect(String(decoding: stored, as: UTF8.self).contains("3350"))

        let totalWidgets = [
            "PennyWidgets/SafeToSpendWidget.swift",
            "PennyWidgets/MonthlyBudgetWidget.swift",
            "PennyWidgets/SavingsGoalWidget.swift",
            "PennyWidgets/UpcomingReminderWidget.swift"
        ]
        for relative in totalWidgets {
            let source = try source(relative)
            #expect(source.contains("isPrivate: PrivateModeStore.isEnabled"))
            if let view = source.range(of: "WidgetView") {
                let provider = String(source[..<view.lowerBound])
                #expect(!provider.contains("MoneyFormatters"))
                #expect(!provider.contains("PrivateAmountLogic.display"))
            }
        }
        let bills = try source("PennyWidgets/UpcomingBillsWidget.swift")
        #expect(bills.contains("upcomingBillDetail"))
        #expect(bills.contains("PrivateModeStore.isEnabled"))
    }

    @Test("Fifty quick toggles reload once and do not save SwiftData")
    @MainActor
    func fiftyTogglesDoNotTouchData() async throws {
        let snapshot = WidgetSnapshotStore.Snapshot.placeholder
        WidgetSnapshotStore.save(snapshot)
        let defaults = try #require(UserDefaults(suiteName: WidgetSnapshotStore.activeDefaultsSuite))
        let before = try #require(defaults.data(forKey: WidgetSnapshotStore.snapshotKey))
        #expect(String(decoding: before, as: UTF8.self).contains("3350"))

        let container = try PennyPersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let containerSaves = PennyDataAccessCounter()
        let token = try observeContainerSaves(of: context, counter: containerSaves)
        defer { NotificationCenter.default.removeObserver(token) }

        context.insert(Transaction(
            title: "Coffee",
            amount: Decimal(string: "4.75")!,
            transactionType: .expense,
            categoryName: "Food"
        ))
        let probe = PennyDataAccessCounter()
        let reloader = RecordingPrivateReloader()
        let controller = PrivateModeController(reloader: reloader)
        controller.reloadCoalescer.debounce = 0.05

        try PennyDataAccessProbe.$counter.withValue(probe) {
            #expect(context.saveOrSurfaceError())
        }
        let proofDeadline = Date().addingTimeInterval(1)
        while containerSaves.saves < 1 && Date() < proofDeadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(containerSaves.saves >= 1)
        #expect(probe.saves >= 1)
        containerSaves.saves = 0
        probe.saves = 0
        probe.fetches = 0

        PennyDataAccessProbe.$counter.withValue(probe) {
            for _ in 0..<50 {
                controller.toggle()
            }
        }
        #expect(reloader.calls.isEmpty)
        // An even number of toggles from the default off ends off.
        #expect(controller.isEnabled == false)
        #expect(PrivateModeDefaults.isEnabled(in: defaults) == false)
        try await Task.sleep(nanoseconds: 400_000_000)

        #expect(probe.saves == 0)
        #expect(probe.fetches == 0)
        #expect(containerSaves.saves == 0)
        let after = try #require(defaults.data(forKey: WidgetSnapshotStore.snapshotKey))
        #expect(after == before)
        #expect(reloader.calls.count == 1)
        #expect(reloader.calls.count <= 3)
        #expect(reloader.calls.allSatisfy { $0 == PrivateWidgetKinds.totalShowing })
        #expect(!PrivateWidgetKinds.totalShowing.contains(PrivateWidgetKinds.upcomingBills))
    }

    @MainActor
    private func observeContainerSaves(
        of context: ModelContext,
        counter: PennyDataAccessCounter
    ) throws -> NSObjectProtocol {
        guard #available(iOS 18, *) else {
            throw PrivateModeTestError.missingMarker("ModelContext.didSave")
        }
        return NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: context,
            queue: .main
        ) { _ in
            counter.saves += 1
        }
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ relative: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(relative), encoding: .utf8)
    }

    private func slice(_ text: String, from start: String, until end: String) throws -> String {
        guard let startRange = text.range(of: start) else {
            throw PrivateModeTestError.missingMarker(start)
        }
        let tail = text[startRange.lowerBound...]
        guard let endRange = tail.range(of: end) else {
            throw PrivateModeTestError.missingMarker(end)
        }
        return String(tail[..<endRange.lowerBound])
    }
}

private final class RecordingPrivateReloader: PrivateWidgetReloading, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [[String]] = []

    var calls: [[String]] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func reload(kinds: [String]) {
        lock.lock()
        stored.append(kinds)
        lock.unlock()
    }
}

private enum PrivateModeTestError: Error {
    case missingMarker(String)
}
