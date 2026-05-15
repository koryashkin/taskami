import XCTest

/// Regression tests for tap-to-edit behaviour.
///
/// Bug: after tapping the dash button (toggle done), tapping on another cell's
/// text failed to enter edit mode because the height change from adding/removing
/// the @done tag shifted cells off-screen, making cellForItem(at:) return nil
/// in beginEditing. Fixed by adding a scroll+retry in beginEditing.
final class EditModeUITests: XCTestCase {
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

    private func openFirstDocument() {
        let docList = app.collectionViews.firstMatch
        guard docList.waitForExistence(timeout: 5) else { return }
        if app.cells.count > 0 {
            app.cells.firstMatch.tap()
        } else {
            app.buttons["+"].tap()
        }
        _ = itemCells.element(boundBy: 0).waitForExistence(timeout: 5)
    }

    private func makeIsolatedDocumentsDirectory() -> URL {
        let testRun = ProcessInfo.processInfo.globallyUniqueString
        let testName = name.replacingOccurrences(of: "/", with: "-")
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("TaskamiUITests", isDirectory: true)
            .appendingPathComponent("\(testRun)-\(testName)", isDirectory: true)
    }

    // MARK: - Helpers

    private var itemCells: XCUIElementQuery {
        app.cells.matching(NSPredicate(format: "identifier BEGINSWITH 'item-'"))
    }

    private var dashButtons: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'dash-'"))
    }

    /// Taps a cell and asserts the keyboard appears, indicating edit mode started.
    private func tapAndExpectKeyboard(_ cell: XCUIElement, label: String) {
        cell.tap()
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(
            keyboard.waitForExistence(timeout: 3),
            "\(label): keyboard did not appear after tapping cell — edit mode not entered"
        )
        // Dismiss keyboard for the next assertion
        app.typeText("\r")
    }

    // MARK: - Tests

    /// Basic sanity: tapping any cell opens the keyboard.
    func testTapCellEntersEditMode() throws {
        let cells = itemCells
        XCTAssertGreaterThan(cells.count, 0, "Need at least one item cell")
        tapAndExpectKeyboard(cells.element(boundBy: 0), label: "first cell")
    }

    /// Core regression: toggle done on one task, then tap a different task to edit.
    /// Before the fix, beginEditing silently failed if the height change from
    /// the toggle pushed the target cell off-screen.
    func testToggleThenEditDifferentCell() throws {
        let buttons = dashButtons
        let cells = itemCells

        guard buttons.count >= 1, cells.count >= 2 else {
            XCTFail("Need ≥1 dash button and ≥2 item cells (got \(buttons.count) buttons, \(cells.count) cells)")
            return
        }

        // Toggle done on the first task — this changes cell height and shifts others
        buttons.element(boundBy: 0).tap()

        // Immediately try to edit the second cell — this is the repro case
        let secondCell = cells.element(boundBy: 1)
        XCTAssertTrue(secondCell.waitForExistence(timeout: 3))
        tapAndExpectKeyboard(secondCell, label: "second cell after toggle")
    }

    /// Toggle done multiple times, then tap each visible cell to verify editing still works.
    func testEditingWorksAfterRepeatedToggles() throws {
        let buttons = dashButtons
        let cells = itemCells

        guard buttons.count >= 2, cells.count >= 2 else {
            XCTFail("Need ≥2 dash buttons and ≥2 item cells")
            return
        }

        // Rapidly toggle two different tasks
        for _ in 0..<3 {
            buttons.element(boundBy: 0).tap()
            buttons.element(boundBy: 1).tap()
        }

        // Both cells must still be editable
        tapAndExpectKeyboard(cells.element(boundBy: 0), label: "cell-0 after toggles")
        tapAndExpectKeyboard(cells.element(boundBy: 1), label: "cell-1 after toggles")
    }
}
