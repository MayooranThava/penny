import XCTest

/// Builds an `XCUIApplication` that can seed demo data.
///
/// The app honors the seed only when this runner copies `XCTestConfigurationFilePath`
/// into `PENNY_XCUI_CONFIGURATION`. A normal launch cannot satisfy that check.
enum ScreenshotLaunch {
    static func makeApp(appearance: String, privateMode: String, transactions: Int?) -> XCUIApplication {
        let app = XCUIApplication()
        let config = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] ?? ""
        XCTAssertTrue(
            config.lowercased().contains("xctestconfiguration"),
            "The demo seed is only available when XCUITest is running"
        )
        app.launchEnvironment = [UITestLaunchContract.configurationEnvironment: config]
        var arguments = [
            UITestLaunchContract.seedArgument,
            UITestLaunchContract.appearanceArgument, appearance,
            UITestLaunchContract.privateModeArgument, privateMode,
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_CA"
        ]
        if let transactions {
            arguments += [UITestLaunchContract.transactionCountArgument, String(transactions)]
        }
        app.launchArguments = arguments
        return app
    }
}

/// Argument names shared with `UITestSeedLaunch` in the app. Duplicated here so the
/// UI test target does not need to compile the app target.
enum UITestLaunchContract {
    static let seedArgument = "-PennyUITestSeed"
    static let configurationEnvironment = "PENNY_XCUI_CONFIGURATION"
    static let appearanceArgument = "-PennyAppearance"
    static let privateModeArgument = "-PennyPrivateMode"
    static let transactionCountArgument = "-PennyUITestTransactionCount"
}
