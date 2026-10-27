import XCTest

/// Launch and Activity scroll metrics for a 5,000-transaction demo seed.
/// Xcode 26's scroll signpost metrics report duration only. Hitch time is
/// measured with `XCTHitchMetric` so the xcresult still contains it.
final class ActivityPerformanceTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFiveThousandTransactionLaunch() throws {
        let app = ScreenshotLaunch.makeApp(appearance: "light", privateMode: "off", transactions: 5_000)
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }

    func testFiveThousandTransactionActivityScroll() throws {
        let app = ScreenshotLaunch.makeApp(appearance: "light", privateMode: "off", transactions: 5_000)
        app.launch()
        let activity = app.tabBars.buttons["Activity"]
        XCTAssertTrue(activity.waitForExistence(timeout: 180), "Activity did not appear after the 5,000-transaction seed")
        activity.tap()
        let list = activityList(in: app)
        XCTAssertTrue(list.waitForExistence(timeout: 30))
        measure(metrics: scrollMetrics(for: app)) {
            list.swipeUp(velocity: .fast)
        }
    }

    /// Scroll duration, plus hitch time on iOS 26 where `XCTHitchMetric` exists.
    /// The app still deploys to iOS 17, so the new metric stays behind an availability check.
    private func scrollMetrics(for app: XCUIApplication) -> [XCTMetric] {
        var metrics: [XCTMetric] = [
            XCTOSSignpostMetric.scrollDecelerationMetric,
            XCTOSSignpostMetric.scrollingAndDecelerationMetric
        ]
        if #available(iOS 26.0, *) {
            metrics.append(XCTHitchMetric(application: app))
        }
        return metrics
    }

    private func activityList(in app: XCUIApplication) -> XCUIElement {
        if app.collectionViews.firstMatch.waitForExistence(timeout: 5) {
            return app.collectionViews.firstMatch
        }
        return app.tables.firstMatch
    }
}
