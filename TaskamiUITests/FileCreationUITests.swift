import XCTest

final class FileCreationUITests: XCTestCase {
    private enum LaunchEnvironment {
        static let directory = "TASKAMI_UI_TEST_DIRECTORY"
        static let sortOrder = "TASKAMI_UI_TEST_SORT_ORDER"
        static let liveSearch = "TASKAMI_UI_TEST_LIVE_SEARCH"
    }

    private var app: XCUIApplication!
    private var testDirectory: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        testDirectory = makeIsolatedDocumentsDirectory()
        app.launchEnvironment[LaunchEnvironment.directory] = testDirectory.path

        if name.contains("PersistedSort") {
            try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
            try "- Alpha\n".write(
                to: testDirectory.appendingPathComponent("Alpha.taskpaper"),
                atomically: true,
                encoding: .utf8
            )
            try "- Zulu\n".write(
                to: testDirectory.appendingPathComponent("Zulu.taskpaper"),
                atomically: true,
                encoding: .utf8
            )
            app.launchEnvironment[LaunchEnvironment.sortOrder] = "Name (Z-A)"
        }

        if name.contains("DisabledLiveSearch") {
            app.launchEnvironment[LaunchEnvironment.liveSearch] = "0"
        }
        app.launch()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testDuplicateFileNameShowsError() throws {
        XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(timeout: 5))

        let existingCount = app.cells.count
        XCTAssertGreaterThan(existingCount, 0, "Expected seeded document in isolated test directory")

        app.buttons["Add"].tap()
        app.buttons["New File"].tap()

        let nameField = app.textFields["File name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2), "New File prompt did not appear")
        nameField.tap()
        nameField.typeText("Test")
        app.buttons["Create"].tap()

        let errorAlert = app.alerts["Unable to Create File"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 2), "Duplicate file creation should show an error alert")
        XCTAssertEqual(app.cells.count, existingCount, "Duplicate file creation should not add another row")
    }

    func testReturningFromFolderRestoresParentDirectory() throws {
        XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Test"].exists, "Expected seeded parent document")

        app.buttons["Add"].tap()
        app.buttons["New Folder"].tap()

        let nameField = app.textFields["Folder name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2), "New Folder prompt did not appear")
        nameField.tap()
        nameField.typeText("Projects")
        app.buttons["Create"].tap()

        let folder = app.staticTexts["Projects"]
        XCTAssertTrue(folder.waitForExistence(timeout: 2), "Created folder did not appear")
        folder.tap()

        let folderNavigationBar = app.navigationBars["Projects"]
        XCTAssertTrue(folderNavigationBar.waitForExistence(timeout: 2), "Folder screen did not open")
        folderNavigationBar.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(
            app.staticTexts["Test"].waitForExistence(timeout: 2),
            "Returning from a folder should restore the parent directory contents"
        )
    }

    func testPersistedSortIsAppliedOnLaunch() throws {
        XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(timeout: 5))

        let browser = app.collectionViews.firstMatch
        let alpha = browser.staticTexts.matching(identifier: "Alpha").firstMatch
        let zulu = browser.staticTexts.matching(identifier: "Zulu").firstMatch
        XCTAssertTrue(alpha.waitForExistence(timeout: 2))
        XCTAssertTrue(zulu.waitForExistence(timeout: 2))
        XCTAssertLessThan(zulu.frame.minY, alpha.frame.minY, "Descending preference should put Zulu before Alpha")
    }

    func testDisabledLiveSearchWaitsForSubmit() throws {
        XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(timeout: 5))
        app.cells.firstMatch.tap()

        let itemCells = app.cells.matching(NSPredicate(format: "identifier BEGINSWITH 'item-'"))
        XCTAssertTrue(itemCells.element(boundBy: 0).waitForExistence(timeout: 5))
        let trackedCellID = itemCells.element(boundBy: 0).identifier
        let trackedCell = app.cells[trackedCellID]
        XCTAssertTrue(trackedCell.exists)

        let searchField = app.searchFields["Search tasks"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.tap()
        searchField.typeText("no-matching-task-phrase")

        XCTAssertTrue(trackedCell.exists, "Disabled Live Search should not filter while typing")

        app.typeText("\n")
        let removed = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: removed, object: trackedCell)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 2), .completed)
    }

    func testTypingAutosavesBeforeEditingEnds() throws {
        XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(timeout: 5))
        app.cells.firstMatch.tap()

        let itemCells = app.cells.matching(NSPredicate(format: "identifier BEGINSWITH 'item-'"))
        let firstCell = itemCells.element(boundBy: 0)
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5))
        firstCell.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))

        let marker = "autosave-marker"
        app.typeText(marker)

        let documentURL = testDirectory.appendingPathComponent("Test.taskpaper")
        let saved = NSPredicate { _, _ in
            (try? String(contentsOf: documentURL, encoding: .utf8))?.contains(marker) == true
        }
        let expectation = XCTNSPredicateExpectation(predicate: saved, object: nil)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 3),
            .completed,
            "Typing should persist after the debounce while the editor remains active"
        )
    }

    private func makeIsolatedDocumentsDirectory() -> URL {
        let testRun = ProcessInfo.processInfo.globallyUniqueString
        let testName = name.replacingOccurrences(of: "/", with: "-")
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("TaskamiUITests", isDirectory: true)
            .appendingPathComponent("\(testRun)-\(testName)", isDirectory: true)
    }
}
