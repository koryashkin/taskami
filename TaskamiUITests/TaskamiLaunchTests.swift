import XCTest

/// Launch-time performance test — measures cold-start time.
final class TaskamiLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool { true }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["--ui-testing"]
            app.launch()
        }
    }

    /// Verifies the app reaches a usable state (file browser visible) within 3 seconds.
    func testLaunchCompletesQuickly() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        let newItemMenu = app.buttons["newItemMenu"]
        XCTAssertTrue(newItemMenu.waitForExistence(timeout: 3),
                      "File browser did not appear within 3 seconds of launch")
    }
}
