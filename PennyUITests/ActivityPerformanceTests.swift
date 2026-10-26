import XCTest

/// Launch and Activity scroll metrics for a 5,000-transaction demo seed.
/// Hitch time is reported by the scroll signpost metrics (Hitch Time and
/// Hitch Time Ratio) inside the xcresult, next to the screenshots.
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
        measure(metrics: [
            XCTOSSignpostMetric.scrollDecelerationMetric,
            XCTOSSignpostMetric.scrollingAndDecelerationMetric
        ]) {
            list.swipeUp(velocity: .fast)
        }
    }

    private func activityList(in app: XCUIApplication) -> XCUIElement {
        if app.collectionViews.firstMatch.waitForExistence(timeout: 5) {
            return app.collectionViews.firstMatch
        }
        return app.tables.firstMatch
    }
}
