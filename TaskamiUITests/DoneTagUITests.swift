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
        let browser = app.collectionViews.firstMatch
        guard browser.waitForExistence(timeout: 5) else { return }
        if browser.cells.count > 0 {
            browser.cells.firstMatch.tap()
        } else {
            app.buttons["+"].tap()
        }
        let firstDash = dashButtons.element(boundBy: 0)
        if !firstDash.waitForExistence(timeout: 5), browser.cells.firstMatch.exists {
            browser.cells.firstMatch.tap()
        }
        XCTAssertTrue(firstDash.waitForExistence(timeout: 5), "Editor did not open")
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

    private func tapDash(_ dash: XCUIElement) {
        app.buttons[dash.identifier].tap()
    }

    private var welcomeProject: XCUIElement {
        app.cells.matching(NSPredicate(format: "label == 'Welcome'")).firstMatch
    }

    // MARK: - Assertion helpers

    /// Wait until the cell's accessibilityValue (= item.content) contains `@done`.
    @discardableResult
    private func waitForDoneTag(in cell: XCUIElement, timeout: TimeInterval = 2) -> Bool {
        let currentCell = app.cells[cell.identifier]
        let pred = NSPredicate(format: "value CONTAINS '@done'")
        let exp = XCTNSPredicateExpectation(predicate: pred, object: currentCell)
        return XCTWaiter.wait(for: [exp], timeout: timeout) == .completed
    }

    /// Wait until the cell's accessibilityValue no longer contains `@done`.
    @discardableResult
    private func waitForNoDoneTag(in cell: XCUIElement, timeout: TimeInterval = 2) -> Bool {
        let currentCell = app.cells[cell.identifier]
        let pred = NSPredicate(format: "NOT (value CONTAINS '@done')")
        let exp = XCTNSPredicateExpectation(predicate: pred, object: currentCell)
        return XCTWaiter.wait(for: [exp], timeout: timeout) == .completed
    }

    // MARK: - Dash button tests

    /// Completing a child task must immediately redraw its parent project's progress counter.
    func testProjectDoneCounterUpdatesAfterDashToggle() throws {
        let project = welcomeProject
        XCTAssertTrue(project.waitForExistence(timeout: 3), "Welcome project did not appear")
        XCTAssertEqual(project.value as? String, "0 of 3 tasks done")

        let dash = dashButtons.element(boundBy: 0)
        tapDash(dash)

        let refreshedProject = welcomeProject
        let updated = NSPredicate(format: "value == '1 of 3 tasks done'")
        let expectation = XCTNSPredicateExpectation(predicate: updated, object: refreshedProject)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 2), .completed,
                       "Project counter did not update after completing a child task; value=\(refreshedProject.value ?? "nil")")
    }

    /// Adding a sibling task inside a project must immediately increase its total count.
    func testProjectTotalUpdatesAfterAddingChildTask() throws {
        let project = welcomeProject
        XCTAssertTrue(project.waitForExistence(timeout: 3), "Welcome project did not appear")
        XCTAssertEqual(project.value as? String, "0 of 3 tasks done")

        let firstTask = cell(for: dashButtons.element(boundBy: 0))
        firstTask.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3),
                      "Keyboard did not appear for the first child task")
        app.typeText("\r")

        let dismissKeyboard = app.buttons["accessory-dismiss"]
        XCTAssertTrue(dismissKeyboard.waitForExistence(timeout: 3),
                      "New child task did not enter edit mode")
        dismissKeyboard.tap()
        app.swipeDown()

        let refreshedProject = welcomeProject
        XCTAssertTrue(refreshedProject.waitForExistence(timeout: 3),
                      "Welcome project did not return after adding the child task")
        let updated = NSPredicate(format: "value == '0 of 4 tasks done'")
        let expectation = XCTNSPredicateExpectation(predicate: updated, object: refreshedProject)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 2), .completed,
                       "Project total did not update after adding a child task; value=\(refreshedProject.value ?? "nil")")
    }

    /// Tapping the dash button on an undone task should append @done(date) to content.
    func testDashButtonAddsAtDoneTag() throws {
        let dash = dashButtons.element(boundBy: 0)
        let cell = cell(for: dash)

        // Ensure starting state is undone
        if dash.value as? String == "done" {
            tapDash(dash)
            XCTAssertTrue(waitForNoDoneTag(in: cell), "setup: could not clear done state")
        }

        tapDash(dash)
        XCTAssertTrue(waitForDoneTag(in: cell),
                      "@done tag not added to cell content after dash tap; value=\(cell.value ?? "nil")")
    }

    /// Tapping the dash button on a done task should remove @done from content.
    func testDashButtonRemovesAtDoneTag() throws {
        let dash = dashButtons.element(boundBy: 0)
        let cell = cell(for: dash)

        // Ensure starting state is done
        if dash.value as? String != "done" {
            tapDash(dash)
            XCTAssertTrue(waitForDoneTag(in: cell), "setup: could not set done state")
        }

        tapDash(dash)
        XCTAssertTrue(waitForNoDoneTag(in: cell),
                      "@done tag not removed from cell content after dash tap; value=\(cell.value ?? "nil")")
    }

    /// Round-trip: done → undone → done preserves @done tag correctly.
    func testDashButtonRoundTrip() throws {
        let dash = dashButtons.element(boundBy: 0)
        let cell = cell(for: dash)

        // Start from undone
        if dash.value as? String == "done" {
            tapDash(dash)
            XCTAssertTrue(waitForNoDoneTag(in: cell), "setup")
        }

        tapDash(dash)
        XCTAssertTrue(waitForDoneTag(in: cell), "step 1: @done not added")

        tapDash(dash)
        XCTAssertTrue(waitForNoDoneTag(in: cell), "step 2: @done not removed")

        tapDash(dash)
        XCTAssertTrue(waitForDoneTag(in: cell), "step 3: @done not re-added")
    }

    // MARK: - Accessory-bar done button tests

    /// Tapping the accessory-bar ✓ button while editing should add @done to the cell.
    func testAccessoryDoneButtonAddsAtDoneTag() throws {
        let dash = dashButtons.element(boundBy: 0)
        let cell = cell(for: dash)

        // Ensure starting state is undone
        if dash.value as? String == "done" {
            tapDash(dash)
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
            tapDash(dash)
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
