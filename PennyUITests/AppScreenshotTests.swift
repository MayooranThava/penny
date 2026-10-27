import XCTest

/// Captures Home, Budget, Plan, Activity, and Settings from the demo seed.
/// Each screen is shot with Private mode off and on, in Light and Dark.
/// Private-mode shots fail if a total amount label still shows a currency amount.
final class AppScreenshotTests: XCTestCase {
    private let screens = ["Home", "Budget", "Plan", "Activity", "Settings"]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureDemoScreens() throws {
        for appearance in ["light", "dark"] {
            for privateMode in ["off", "on"] {
                let app = ScreenshotLaunch.makeApp(
                    appearance: appearance,
                    privateMode: privateMode,
                    transactions: nil
                )
                app.launch()
                for screen in screens {
                    open(screen, in: app)
                    let suffix = privateMode == "on" ? "-private" : ""
                    attachScreenshot(named: "\(screen.lowercased())-\(appearance)\(suffix).png")
                    if privateMode == "on" {
                        if screen == "Settings" {
                            reveal(
                                NSPredicate(format: "identifier == 'accountsNetWorth' OR label CONTAINS[c] 'Net worth'"),
                                in: app
                            )
                        }
                        assertPrivateTotalsHideDigits(in: app, screen: screen)
                    }
                }
                app.terminate()
            }
        }
    }

    private func open(_ screen: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[screen]
        XCTAssertTrue(
            tab.waitForExistence(timeout: 60),
            "Tab \(screen) did not appear. The demo seed may not have skipped onboarding."
        )
        tab.tap()
        if screen == "Home" {
            let hero = app.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS[c] 'Safe to spend'")
            ).firstMatch
            XCTAssertTrue(hero.waitForExistence(timeout: 20))
        } else {
            XCTAssertTrue(app.navigationBars[screen].waitForExistence(timeout: 20))
        }
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Totals identified by `PrivateTotalSite` must not contain a digit.
    /// Combined sentences (a percent plus a remaining amount) use the same
    /// currency regex as `PrivateAmountLogic.maskCurrencyAmounts`, so a
    /// percent or a date does not fail the shot.
    private func assertPrivateTotalsHideDigits(in app: XCUIApplication, screen: String) {
        let sites = Set(PrivateTotalSite.allCases.map(\.rawValue))
        var failures: [String] = []
        var checked = 0
        let elements = app.descendants(matching: .any)
        for index in 0..<elements.count {
            let element = elements.element(boundBy: index)
            let label = element.label
            let value = (element.value as? String) ?? ""
            if sites.contains(element.identifier) {
                for text in [label, value] where !text.isEmpty {
                    checked += 1
                    if PrivateAmountLogic.containsDigit(text) || PrivateAmountLogic.containsCurrencyAmount(text) {
                        failures.append("\(element.identifier): \(text)")
                    }
                }
                continue
            }
            if let clause = goalProgressClause(in: label) {
                // Currency inside "Name, 42 percent complete" is a leak.
                // A button concatenates that sentence with later lines (funding
                // caption, monthly pace). Those lines are not the goal total.
                // Currency that this element itself appends after the clause,
                // with no descendant owning that trailing text, still fails.
                let trailing = trailingText(after: clause, in: label)
                if PrivateAmountLogic.containsCurrencyAmount(clause) {
                    checked += 1
                    failures.append("\(screen) total: \(label)")
                } else if trailing.isEmpty {
                    checked += 1
                } else if !trailingBelongsToDescendant(element, trailing: trailing) {
                    checked += 1
                    if PrivateAmountLogic.containsCurrencyAmount(label) {
                        failures.append("\(screen) total: \(label)")
                    }
                }
                continue
            }
            guard isTotalSentence(label) else { continue }
            checked += 1
            if PrivateAmountLogic.containsCurrencyAmount(label) {
                failures.append("\(screen) total: \(label)")
            }
            if sentenceMustHideEveryDigit(label) && PrivateAmountLogic.containsDigit(label) {
                failures.append("\(screen) total digit: \(label)")
            }
        }
        XCTAssertTrue(
            failures.isEmpty,
            "Private mode on \(screen) still shows a total amount:\n\(failures.joined(separator: "\n"))"
        )
        XCTAssertGreaterThan(checked, 0, "Private mode on \(screen) did not expose a total amount label")
    }

    /// Home's Safe to Spend label is only words plus the amount, so any digit is a leak.
    /// Budget and goal rows include a percent, which is not an amount.
    private func sentenceMustHideEveryDigit(_ label: String) -> Bool {
        let lowered = label.lowercased()
        if lowered.contains("percent") { return false }
        return lowered.contains("safe to spend")
    }

    private func isTotalSentence(_ label: String) -> Bool {
        let lowered = label.lowercased()
        if lowered.contains("safe to spend") { return true }
        if lowered.contains("percent used") && lowered.contains("remaining") { return true }
        if lowered.contains("net worth") { return true }
        return false
    }

    /// Text from the start of `label` through the goal progress phrase.
    private func goalProgressClause(in label: String) -> String? {
        guard let range = label.range(of: "percent complete", options: [.caseInsensitive]) else { return nil }
        return String(label[..<range.upperBound])
    }

    private func trailingText(after clause: String, in label: String) -> String {
        guard label.count >= clause.count else { return "" }
        let tail = label.dropFirst(clause.count)
        return tail.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
    }

    /// True when `trailing` is other accessibility elements joined onto the goal clause.
    private func trailingBelongsToDescendant(_ element: XCUIElement, trailing: String) -> Bool {
        let children = element.children(matching: .any)
        for index in 0..<children.count {
            let child = children.element(boundBy: index)
            let childLabel = child.label.trimmingCharacters(in: .whitespacesAndNewlines)
            if childLabel.count > 3,
               !childLabel.localizedCaseInsensitiveContains("percent complete"),
               trailing.localizedCaseInsensitiveContains(childLabel) {
                return true
            }
            if trailingBelongsToDescendant(child, trailing: trailing) {
                return true
            }
        }
        return false
    }

    private func reveal(_ predicate: NSPredicate, in app: XCUIApplication) {
        let match = app.descendants(matching: .any).matching(predicate).firstMatch
        if match.exists { return }
        let scroller = scrollable(in: app)
        guard scroller.exists else { return }
        for _ in 0..<8 {
            scroller.swipeUp()
            if match.waitForExistence(timeout: 1) { return }
        }
    }

    private func scrollable(in app: XCUIApplication) -> XCUIElement {
        if app.tables.firstMatch.exists { return app.tables.firstMatch }
        return app.collectionViews.firstMatch
    }
}
