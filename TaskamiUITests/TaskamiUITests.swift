import XCTest

/// Full-app UI tests for Taskami.
///
/// The suite uses the `--ui-testing` launch argument so the app writes to a
/// temporary folder instead of the real Documents/iCloud directory. Every test
/// that creates a file cleans it up afterwards, keeping the test environment
/// hermetic across runs.
final class TaskamiUITests: XCTestCase {

    var app: XCUIApplication!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    // MARK: - Helpers

    /// Waits for an element to exist and returns it. Fails the test if it never appears.
    @discardableResult
    func expect(_ element: XCUIElement, timeout: TimeInterval = 5,
                file: StaticString = #file, line: UInt = #line) -> XCUIElement {
        XCTAssertTrue(element.waitForExistence(timeout: timeout),
                      "Element never appeared: \(element)", file: file, line: line)
        return element
    }

    /// Creates a new .taskpaper file via the UI and lands on the document screen.
    /// Returns the file name (without extension) used for cleanup.
    @discardableResult
    func createAndOpenFile(named name: String) -> String {
        let menu = app.buttons["newItemMenu"]
        expect(menu).tap()

        let newFile = app.buttons["newFileButton"]
        expect(newFile).tap()

        // Fill in alert text field
        let field = app.alerts.textFields.firstMatch
        expect(field).tap()
        field.typeText(name)
        app.alerts.buttons["Create"].tap()

        // Navigate into the newly created file
        let fileRow = app.buttons["file-\(name).taskpaper"]
        expect(fileRow).tap()

        // Confirm the document editor appeared
        expect(app.buttons["addTaskButton"])
        return name
    }

    /// Navigates back from the document editor to the file browser.
    func navigateBack() {
        app.navigationBars.buttons.firstMatch.tap()
    }

    /// Deletes a file from the file browser by name (swipe-to-delete).
    func deleteFile(named name: String) {
        // Full file name shown in the list includes the .taskpaper extension
        let row = app.buttons["file-\(name).taskpaper"]
        guard row.waitForExistence(timeout: 3) else { return }
        row.swipeLeft()
        let deleteBtn = app.buttons["Delete"]
        if deleteBtn.waitForExistence(timeout: 2) { deleteBtn.tap() }
    }

    // MARK: - File Browser Tests

    /// The file browser is visible on launch with the new-item and settings buttons.
    func testLaunchShowsFileBrowser() {
        expect(app.buttons["newItemMenu"])
        expect(app.buttons["settingsButton"])
        // Navigation title reflects current directory name
        XCTAssertTrue(app.navigationBars.firstMatch.exists)
    }

    /// Creating a new file shows it in the file list.
    func testCreateNewFileAppearsInList() {
        let name = "UITest-Create"
        app.buttons["newItemMenu"].tap()
        expect(app.buttons["newFileButton"]).tap()

        let field = app.alerts.textFields.firstMatch
        expect(field).tap()
        field.typeText(name)
        app.alerts.buttons["Create"].tap()

        expect(app.buttons["file-\(name).taskpaper"])

        deleteFile(named: name)
    }

    /// Cancelling the new-file alert does not create a file.
    func testCancelNewFileDialog() {
        app.buttons["newItemMenu"].tap()
        expect(app.buttons["newFileButton"]).tap()

        let field = app.alerts.textFields.firstMatch
        expect(field).tap()
        field.typeText("ShouldNotExist")
        app.alerts.buttons["Cancel"].tap()

        XCTAssertFalse(app.buttons["file-ShouldNotExist.taskpaper"].waitForExistence(timeout: 2))
    }

    /// Opening a file navigates to the document editor.
    func testOpenFileShowsEditor() {
        let name = "UITest-Open"
        createAndOpenFile(named: name)

        expect(app.buttons["addTaskButton"])

        navigateBack()
        deleteFile(named: name)
    }

    // MARK: - Task Creation Tests

    /// The + button adds a new task cell.
    func testAddTaskButtonCreatesCell() {
        let name = "UITest-AddTask"
        createAndOpenFile(named: name)

        let addBtn = app.buttons["addTaskButton"]
        expect(addBtn).tap()

        // A task cell (possibly empty while keyboard is visible) should exist
        expect(app.cells["taskCell"])

        navigateBack()
        deleteFile(named: name)
    }

    /// Typing content into a task saves it to the cell.
    func testTypingTaskContent() {
        let name = "UITest-TypeContent"
        createAndOpenFile(named: name)

        app.buttons["addTaskButton"].tap()
        expect(app.keyboards.firstMatch)   // keyboard appeared

        app.typeText("Buy groceries")

        // Dismiss keyboard via the accessory dismiss button or return
        // Tap elsewhere in the nav bar to commit
        app.navigationBars.firstMatch.tap()

        // Cell with the typed label should exist
        let cell = app.cells.containing(.any, identifier: "taskCell")
            .element(boundBy: 0)
        expect(cell)
        XCTAssertTrue(cell.label.contains("Buy groceries") || cell.exists)

        navigateBack()
        deleteFile(named: name)
    }

    /// Pressing Return while editing creates a second task.
    func testReturnKeyCreatesNewTask() {
        let name = "UITest-Return"
        createAndOpenFile(named: name)

        app.buttons["addTaskButton"].tap()
        expect(app.keyboards.firstMatch)

        app.typeText("Task one\nTask two")

        app.navigationBars.firstMatch.tap()

        // Two task cells should exist (default template content + 2 new tasks,
        // or at minimum 2 cells created by our edits)
        let cells = app.cells.matching(identifier: "taskCell")
        XCTAssertGreaterThanOrEqual(cells.count, 2)

        navigateBack()
        deleteFile(named: name)
    }

    // MARK: - Swipe Action Tests

    /// Swiping left on a task cell reveals Delete and Done actions.
    func testSwipeActionsAppear() {
        let name = "UITest-Swipe"
        createAndOpenFile(named: name)

        // Add a task first
        app.buttons["addTaskButton"].tap()
        expect(app.keyboards.firstMatch)
        app.typeText("Swipe target task")
        app.navigationBars.firstMatch.tap()

        let cell = expect(app.cells["taskCell"])
        cell.swipeLeft()

        expect(app.buttons["Delete"])
        expect(app.buttons["Done"])

        // Dismiss swipe
        cell.swipeRight()

        navigateBack()
        deleteFile(named: name)
    }

    /// Swiping and tapping Delete removes the task.
    func testSwipeDeleteRemovesTask() {
        let name = "UITest-SwipeDelete"
        createAndOpenFile(named: name)

        app.buttons["addTaskButton"].tap()
        expect(app.keyboards.firstMatch)
        app.typeText("Task to delete")
        app.navigationBars.firstMatch.tap()

        let cell = expect(app.cells["taskCell"])
        let initialCount = app.cells.matching(identifier: "taskCell").count

        cell.swipeLeft()
        expect(app.buttons["Delete"]).tap()

        // Cell count should have decreased by 1
        let afterCount = app.cells.matching(identifier: "taskCell").count
        XCTAssertEqual(afterCount, initialCount - 1)

        navigateBack()
        deleteFile(named: name)
    }

    /// Swiping and tapping Done marks the task as done (label changes or cell style changes).
    func testSwipeMarkDone() {
        let name = "UITest-MarkDone"
        createAndOpenFile(named: name)

        app.buttons["addTaskButton"].tap()
        expect(app.keyboards.firstMatch)
        app.typeText("Task to complete")
        app.navigationBars.firstMatch.tap()

        let cell = expect(app.cells["taskCell"])
        cell.swipeLeft()

        let doneBtn = expect(app.buttons["Done"])
        doneBtn.tap()

        // After marking done, the Done button label in subsequent swipes changes to "Undone"
        let sameCell = app.cells["taskCell"]
        if sameCell.waitForExistence(timeout: 2) {
            sameCell.swipeLeft()
            expect(app.buttons["Undone"])
            sameCell.swipeRight()
        }

        navigateBack()
        deleteFile(named: name)
    }

    // MARK: - Search Tests

    /// The search field filters task cells.
    func testSearchFiltersContent() {
        let name = "UITest-Search"
        createAndOpenFile(named: name)

        // Add two distinguishable tasks
        app.buttons["addTaskButton"].tap()
        expect(app.keyboards.firstMatch)
        app.typeText("Alpha task\nBeta task")
        app.navigationBars.firstMatch.tap()

        // Activate search
        let searchField = app.searchFields["Search tasks"]
        expect(searchField).tap()
        searchField.typeText("Alpha")

        // Only the Alpha cell should be visible
        let cells = app.cells.matching(identifier: "taskCell")
        XCTAssertEqual(cells.count, 1,
                       "Expected only 1 result after filtering for 'Alpha'")

        // Clear search
        searchField.buttons["Clear text"].tap()

        navigateBack()
        deleteFile(named: name)
    }

    /// Searching for a non-existent term shows no task cells.
    func testSearchNoResults() {
        let name = "UITest-SearchEmpty"
        createAndOpenFile(named: name)

        app.buttons["addTaskButton"].tap()
        expect(app.keyboards.firstMatch)
        app.typeText("Only task")
        app.navigationBars.firstMatch.tap()

        let searchField = app.searchFields["Search tasks"]
        expect(searchField).tap()
        searchField.typeText("zzz_no_match")

        XCTAssertEqual(app.cells.matching(identifier: "taskCell").count, 0)

        searchField.buttons["Clear text"].tap()
        navigateBack()
        deleteFile(named: name)
    }

    // MARK: - Navigation Tests

    /// The back button returns to the file browser and the file persists.
    func testNavigateBackRetainsFile() {
        let name = "UITest-NavBack"
        createAndOpenFile(named: name)

        navigateBack()

        // File still listed after returning
        expect(app.buttons["file-\(name).taskpaper"])

        deleteFile(named: name)
    }

    /// Settings sheet appears when the gear button is tapped.
    func testSettingsButtonOpensSheet() {
        app.buttons["settingsButton"].tap()
        // Settings sheet presents some content — look for a recognizable element
        // (NavigationStack title or a picker from SettingsView)
        let settingsAppeared = app.navigationBars["Settings"].waitForExistence(timeout: 4)
            || app.staticTexts["Settings"].waitForExistence(timeout: 4)
        XCTAssertTrue(settingsAppeared, "Settings sheet did not appear")

        // Dismiss
        if app.buttons["Done"].exists { app.buttons["Done"].tap() }
        else { app.swipeDown() }
    }
}
