import Foundation
import SwiftData

/// Demo seed used by the screenshot and performance UI tests.
///
/// Honored in Debug and Release, but only when XCUITest launched the app.
/// The test runner passes `-PennyUITestSeed` and copies its own
/// `XCTestConfigurationFilePath` into `PENNY_XCUI_CONFIGURATION`. A person
/// opening Penny, including a Release build from the Home Screen, does not
/// have that configuration path, so this seed never runs. There is no
/// `#if DEBUG` gate: the screenshot job builds Release so the pixels match
/// the shipped app, and the XCUITest check is what keeps the path closed.
enum UITestSeedLaunch {
    static let seedArgument = "-PennyUITestSeed"
    static let configurationEnvironment = "PENNY_XCUI_CONFIGURATION"
    static let appearanceArgument = "-PennyAppearance"
    static let privateModeArgument = "-PennyPrivateMode"
    static let transactionCountArgument = "-PennyUITestTransactionCount"

    static var isEnabled: Bool {
        let process = ProcessInfo.processInfo
        guard process.arguments.contains(seedArgument) else { return false }
        guard let token = process.environment[configurationEnvironment], !token.isEmpty else {
            return false
        }
        return token.lowercased().contains("xctestconfiguration")
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
