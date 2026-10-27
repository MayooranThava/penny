/// Demo seed for the screenshot and performance UI tests.
///
/// Compiled only for the Screenshots configuration (`SCREENSHOT_SEED`).
/// Debug and Release do not include this type, so a Home Screen launch cannot
/// replace a real store. The UI tests pass `-PennyUITestSeed` to turn it on.
#if SCREENSHOT_SEED
import Foundation
import SwiftData

enum UITestSeedLaunch {
    static let seedArgument = "-PennyUITestSeed"
    static let appearanceArgument = "-PennyAppearance"
    static let privateModeArgument = "-PennyPrivateMode"
    static let transactionCountArgument = "-PennyUITestTransactionCount"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(seedArgument)
    }

    @MainActor
    static func openSeededContainer() throws -> ModelContainer {
        let container = try PennyPersistence.makeContainer()
        let context = container.mainContext
        try PennyPersistence.repairIfNeeded(in: context)
        try apply(to: context)
        return container
    }

    @MainActor
    static func apply(to context: ModelContext) throws {
        try DemoDataService.seedDemo(
            in: context,
            markOnboardingComplete: true,
            replaceExisting: true
        )
        if let count = transactionCount(), count > 0 {
            try DemoDataService.seedVolumeTransactions(count: count, in: context)
        }
        if let settings = try context.fetch(FetchDescriptor<UserSettings>()).first {
            settings.hasCompletedOnboarding = true
            settings.hasCompletedWalkthrough = true
            settings.appearance = appearance()
            settings.displayName = "Demo"
            try context.save()
        }
        if let defaults = PrivateModeController.currentDefaults() {
            PrivateModeDefaults.setEnabled(privateModeEnabled(), in: defaults)
        }
    }

    private static func appearance() -> AppAppearance {
        switch value(after: appearanceArgument)?.lowercased() {
        case "light": return .light
        case "dark": return .dark
        default: return .system
        }
    }

    private static func privateModeEnabled() -> Bool {
        switch value(after: privateModeArgument)?.lowercased() {
        case "on", "true", "1": return true
        default: return false
        }
    }

    private static func transactionCount() -> Int? {
        guard let raw = value(after: transactionCountArgument) else { return nil }
        return Int(raw)
    }

    private static func value(after flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else { return nil }
        let next = args[index + 1]
        guard !next.hasPrefix("-") else { return nil }
        return next
    }
}
#endif
