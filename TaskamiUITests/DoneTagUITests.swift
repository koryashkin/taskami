import XCTest

/// Regression tests verifying that @done(date) is appended to cell content when an item
/// is toggled done, and removed when toggled undone.
///
/// Bugs covered:
/// 1. Accessory-bar "done" button: reconfigureItem called cellForItem after endEditMode set
///    textView.attributedText (dirtying the layout), so cellForItem returned nil and the
///    cell display was never updated — model was correct, visual was stale.
/// 2. Dash button toggle: verify @done appears and disappears reliably.
final class DoneTagUITests: XCTestCase {
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

    // MARK: - Navigation helpers

    private func openFirstDocument() {
        guard app.collectionViews.firstMatch.waitForExistence(timeout: 5) else { return }
        if app.cells.count > 0 {
            app.cells.firstMatch.tap()
        } else {
            app.buttons["+"].tap()
        }
        _ = dashButtons.element(boundBy: 0).waitForExistence(timeout: 5)
    }

    private func makeIsolatedDocumentsDirectory() -> URL {
        let testRun = ProcessInfo.processInfo.globallyUniqueString
        let testName = name.replacingOccurrences(of: "/", with: "-")
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("TaskamiUITests", isDirectory: true)
            .appendingPathComponent("\(testRun)-\(testName)", isDirectory: true)
    }

    // MARK: - Element helpers

    private var dashButtons: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'dash-'"))
    }

    private var accessoryDoneButton: XCUIElement {
        app.buttons["accessory-done"]
    }

    /// Returns the item cell that owns a given dash button (same UUID in identifier).
    /// dash identifier = "dash-<uuid>", cell identifier = "item-<uuid>"
    private func cell(for dash: XCUIElement) -> XCUIElement {
        let cellID = "item-" + dash.identifier.dropFirst("dash-".count)
        return app.cells[cellID]
    }

    // MARK: - Assertion helpers

    /// Wait until the cell's accessibilityValue (= item.content) contains `@done`.
    @discardableResult
    private func waitForDoneTag(in cell: XCUIElement, timeout: TimeInterval = 2) -> Bool {
        let pred = NSPredicate(format: "value CONTAINS '@done'")
        let exp = XCTNSPredicateExpectation(predicate: pred, object: cell)
        return XCTWaiter.wait(for: [exp], timeout: timeout) == .completed
    }

    /// Wait until the cell's accessibilityValue no longer contains `@done`.
    @discardableResult
    private func waitForNoDoneTag(in cell: XCUIElement, timeout: TimeInterval = 2) -> Bool {
        let pred = NSPredicate(format: "NOT (value CONTAINS '@done')")
        let exp = XCTNSPredicateExpectation(predicate: pred, object: cell)
        return XCTWaiter.wait(for: [exp], timeout: timeout) == .completed
    }

    // MARK: - Dash button tests

    /// Tapping the dash button on an undone task should append @done(date) to content.
    func testDashButtonAddsAtDoneTag() throws {
        let dash = dashButtons.element(boundBy: 0)
        let cell = cell(for: dash)

        // Ensure starting state is undone
        if dash.value as? String == "done" {
            dash.tap()
            XCTAssertTrue(waitForNoDoneTag(in: cell), "setup: could not clear done state")
        }

        dash.tap()
        XCTAssertTrue(waitForDoneTag(in: cell),
                      "@done tag not added to cell content after dash tap; value=\(cell.value ?? "nil")")
    }

    /// Tapping the dash button on a done task should remove @done from content.
    func testDashButtonRemovesAtDoneTag() throws {
        let dash = dashButtons.element(boundBy: 0)
        let cell = cell(for: dash)

        // Ensure starting state is done
        if dash.value as? String != "done" {
            dash.tap()
            XCTAssertTrue(waitForDoneTag(in: cell), "setup: could not set done state")
        }

        dash.tap()
        XCTAssertTrue(waitForNoDoneTag(in: cell),
                      "@done tag not removed from cell content after dash tap; value=\(cell.value ?? "nil")")
    }

    /// Round-trip: done → undone → done preserves @done tag correctly.
    func testDashButtonRoundTrip() throws {
        let dash = dashButtons.element(boundBy: 0)
        let cell = cell(for: dash)

        // Start from undone
        if dash.value as? String == "done" {
            dash.tap()
            XCTAssertTrue(waitForNoDoneTag(in: cell), "setup")
        }

        dash.tap()
        XCTAssertTrue(waitForDoneTag(in: cell), "step 1: @done not added")

        dash.tap()
        XCTAssertTrue(waitForNoDoneTag(in: cell), "step 2: @done not removed")

        dash.tap()
        XCTAssertTrue(waitForDoneTag(in: cell), "step 3: @done not re-added")
    }

    // MARK: - Accessory-bar done button tests

    /// Tapping the accessory-bar ✓ button while editing should add @done to the cell.
    func testAccessoryDoneButtonAddsAtDoneTag() throws {
        let dash = dashButtons.element(boundBy: 0)
        let cell = cell(for: dash)

        // Ensure starting state is undone
        if dash.value as? String == "done" {
            dash.tap()
            XCTAssertTrue(waitForNoDoneTag(in: cell), "setup: could not clear done state")
        }

        // Enter edit mode on this task's cell
        cell.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3),
                      "keyboard did not appear")

        // Tap accessory-bar done button
        accessoryDoneButton.tap()

        // Done button commits + toggles done, which dismisses the keyboard
        let keyboardGone = NSPredicate(format: "count == 0")
        let exp = XCTNSPredicateExpectation(predicate: keyboardGone, object: app.keyboards)
        XCTAssertEqual(XCTWaiter.wait(for: [exp], timeout: 2), .completed,
                       "keyboard did not dismiss after accessory done tap")

        XCTAssertTrue(waitForDoneTag(in: cell),
                      "@done tag not added via accessory bar; value=\(cell.value ?? "nil")")
    }

    /// Accessory-bar done on already-done task should remove @done.
    func testAccessoryDoneButtonRemovesAtDoneTag() throws {
        let dash = dashButtons.element(boundBy: 0)
        let cell = cell(for: dash)

        // Ensure starting state is done
        if dash.value as? String != "done" {
            dash.tap()
            XCTAssertTrue(waitForDoneTag(in: cell), "setup: could not set done state")
        }

        // Enter edit mode
        cell.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3),
                      "keyboard did not appear")

        // Tap accessory-bar done button (toggles done off)
        accessoryDoneButton.tap()

        let keyboardGone = NSPredicate(format: "count == 0")
        let exp = XCTNSPredicateExpectation(predicate: keyboardGone, object: app.keyboards)
        XCTAssertEqual(XCTWaiter.wait(for: [exp], timeout: 2), .completed,
                       "keyboard did not dismiss")

        XCTAssertTrue(waitForNoDoneTag(in: cell),
                      "@done tag not removed via accessory bar; value=\(cell.value ?? "nil")")
    }
}
