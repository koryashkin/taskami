# Taskami UI QA Report

Date: 2026-05-15
Environment: `iPhone 16 Pro` simulator, iOS `18.6`
Scheme: `Taskami`

## QA Plan Executed

1. Built and launched the app on the simulator with `build_run_sim`.
2. Ran the UI regression suite for `TaskamiUITests`.
3. Re-opened the app in the simulator and performed an exploratory editor pass.
4. Collected repro details and artifacts for the senior engineering team.

## Findings

### 1. Full UI test suite is failing overall because the runner crashes mid-suite

- Severity: High
- Area: UI test reliability / CI signal

#### Summary

Running the full `TaskamiUITests` suite reports individual tests as passing after retries, but the overall `xcodebuild test` command still exits with code `65`.

The `.xcresult` bundle marks the run as failed and records two UI tests as crashing with `signal kill`:

- `DoneTagUITests/testAccessoryDoneButtonRemovesAtDoneTag()`
- `DoneTagUITests/testDashButtonRoundTrip()`

#### Repro

1. Run:
   `xcodebuild test -project /Users/mikhail/Projects/taskami/Taskami.xcodeproj -scheme Taskami -destination 'id=231D74F9-6049-47DC-9B78-2F2BCC25E29E' -only-testing:TaskamiUITests`
2. Observe that the test log prints:
   `Restarting after unexpected exit, crash, or test timeout; summary will include totals from previous launches.`
3. Observe the final process exit:
   `** TEST FAILED **`
4. Inspect the result bundle summary and note the recorded crashes.

#### Expected

The full UI suite should complete in a single pass and exit successfully when no assertions fail.

#### Actual

The suite restarts twice after unexpected termination, records two crashed tests in the result bundle, and the overall command fails even though later retries pass.

#### Evidence

- XCResult:
  `/Users/mikhail/Library/Developer/Xcode/DerivedData/Taskami-cvmapbcpdurpmsdrhdpvqouvocea/Logs/Test/Test-Taskami-2026.05.15_23-03-12-+0900.xcresult`
- Notable xcresult summary fields:
  - `result: Failed`
  - `failedTests: 2`
  - `passedTests: 8`
  - `totalTestCount: 10`
  - failure text: `Test crashed with signal kill.`

#### Notes

This is the most important issue from the QA pass because it makes CI and local regression runs untrustworthy.

#### Retest Status

Resolved on 2026-05-15.

After isolating each UI test launch into its own seeded documents directory and explicitly terminating the app in UI-test teardown, the full suite completed cleanly:

- `xcodebuild test ... -only-testing:TaskamiUITests`
- Result: `TEST SUCCEEDED`
- Executed `10` tests with `0` failures
- Passing xcresult:
  `/Users/mikhail/Library/Developer/Xcode/DerivedData/Taskami-cvmapbcpdurpmsdrhdpvqouvocea/Logs/Test/Test-Taskami-2026.05.15_23-18-55-+0900.xcresult`

### 2. UI tests leave the seed document visibly polluted after the run

- Severity: Medium
- Area: Test isolation / QA environment stability

#### Summary

After the UI suite finishes, reopening the app shows the `Test` document littered with blank completed tasks such as `- @done(2026-05-15)` and `- @done(2026-05-06)` near the top of the file.

This makes repeated exploratory QA passes noisy and suggests the UI tests are mutating persistent document state without cleanup.

#### Repro

1. Run the `TaskamiUITests` suite against the simulator.
2. Open the app manually after the suite completes.
3. Open the `Test` document from the Documents screen.
4. Inspect the top of the document.

#### Expected

The test fixture document should return to a known clean state, or the tests should operate on isolated throwaway data.

#### Actual

The shared document remains modified by previous test interactions and shows multiple blank completed tasks at the top of the outline.

#### Evidence

- Visual artifact observed in simulator immediately after the suite.
- Screenshot captured during QA:
  `/var/folders/kn/5pw_hmgx2lv5l724fkcfjq500000gn/T/screenshot_optimized_2246a3b7-39a3-4cd2-a06a-bf6679c187ba.jpg`

#### Notes

This may be a test-harness problem rather than a customer-facing app bug, but it materially affects QA repeatability and should be cleaned up.

#### Retest Status

Resolved for future UI runs on 2026-05-15.

UI tests now use isolated scratch directories, so they no longer mutate the app's normal documents directory during automation. The existing `Test` document visible in the simulator still contains historical pollution from earlier runs, but it was not re-mutated by the fixed suite.
