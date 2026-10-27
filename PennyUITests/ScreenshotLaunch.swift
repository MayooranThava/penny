import XCTest

/// Builds an `XCUIApplication` that seeds demo data.
///
/// The app compiles the seed only in the Screenshots configuration
/// (`SCREENSHOT_SEED`). These tests run that configuration and pass
/// `-PennyUITestSeed` so the launch replaces the simulator store with the
/// fictional household.
enum ScreenshotLaunch {
    static func makeApp(appearance: String, privateMode: String, transactions: Int?) -> XCUIApplication {
        let app = XCUIApplication()
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
    static let appearanceArgument = "-PennyAppearance"
    static let privateModeArgument = "-PennyPrivateMode"
    static let transactionCountArgument = "-PennyUITestTransactionCount"
}
