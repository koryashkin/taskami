import XCTest

/// Regression test for the done/undone visual freeze bug.
///
/// The bug: tapping the dash button a few times on one task, then switching to
/// a different task, caused the second task's visual state to stop updating —
/// the model toggled correctly but the cell never refreshed.
///
/// The test drives that exact scenario automatically and fails on the first tap
/// where the accessibilityValue of the dash button stops alternating.
final class DoneToggleUITests: XCTestCase {
    private enum LaunchEnvironment {
        static let directory = "TASKAMI_UI_TEST_DIRECTORY"
    }

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment[LaunchEnvironment.directory] = makeIsolatedDocumentsDirectory().path
        app.launch()
        openFirstDocument()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    // MARK: - Navigation

    /// Opens the first document in the list, or creates one if none exist.
    private func openFirstDocument() {
        // Wait for the document list to appear
        let docList = app.collectionViews.firstMatch
        guard docList.waitForExistence(timeout: 5) else { return }

        if app.cells.count > 0 {
            app.cells.firstMatch.tap()
        } else {
            // Create a new document via the "+" button
            app.buttons["+"].tap()
        }

        // Wait for the editor (dash button) to appear — up to 5 s
        _ = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'dash-'"))
                        .element(boundBy: 0)
                        .waitForExistence(timeout: 5)
    }

    private func makeIsolatedDocumentsDirectory() -> URL {
        let testRun = ProcessInfo.processInfo.globallyUniqueString
        let testName = name.replacingOccurrences(of: "/", with: "-")
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("TaskamiUITests", isDirectory: true)
            .appendingPathComponent("\(testRun)-\(testName)", isDirectory: true)
    }

    // MARK: - Helpers

    /// Returns all currently visible dash buttons.
    private var dashButtons: [XCUIElement] {
        let query = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'dash-'"))
        return (0..<query.count).map { query.element(boundBy: $0) }
    }

    /// Taps `button` `count` times, asserting the accessibilityValue
    /// alternates between "done" and "undone" on every tap.
    private func toggleRepeatedly(_ button: XCUIElement, label: String, times count: Int) {
        var expectDone = button.value as? String != "done"
        for tap in 1...count {
            button.tap()
            let expectedValue = expectDone ? "done" : "undone"
            let predicate = NSPredicate(format: "value == %@", expectedValue)
            let expectation = XCTNSPredicateExpectation(predicate: predicate, object: button)
            let result = XCTWaiter.wait(for: [expectation], timeout: 1.5)
            XCTAssertEqual(
                result, .completed,
                "\(label) tap \(tap): expected '\(expectedValue)' but got '\(button.value as? String ?? "nil")' — visual freeze"
            )
            expectDone.toggle()
        }
    }

    // MARK: - Tests

    /// Tap the first visible task 6 times, then the second visible task 6 times.
    func testToggleDoneOnTwoConsecutiveTasks() throws {
        let buttons = dashButtons
        guard buttons.count >= 2 else {
            XCTFail("Need ≥2 visible task dash buttons (found \(buttons.count))")
            return
        }

        toggleRepeatedly(buttons[0], label: "task-1", times: 6)
        toggleRepeatedly(buttons[1], label: "task-2", times: 6)
    }

    /// Scrolls down to reveal tasks further down the list, then toggles them.
    /// Replicates the exact repro case: toggle items below the initial viewport.
    func testToggleDoneAfterScrolling() throws {
        // First toggle top items a few times so the layout has some history
        let initialButtons = dashButtons
        if !initialButtons.isEmpty {
            toggleRepeatedly(initialButtons[0], label: "pre-scroll-task", times: 4)
        }

        // Scroll down to expose new cells
        app.swipeUp()
        app.swipeUp()

        let buttons = dashButtons
        guard !buttons.isEmpty else {
            XCTFail("No dash buttons visible after scrolling")
            return
        }

        toggleRepeatedly(buttons[0], label: "post-scroll-task-0", times: 8)
        if buttons.count >= 2 {
            toggleRepeatedly(buttons[1], label: "post-scroll-task-1", times: 8)
        }
    }
}
