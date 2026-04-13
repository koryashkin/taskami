# TodoMD

## Full Project Review And Critical Fix Pass

- [x] Inventory the repository and identify the actively maintained application surface.
- [x] Run the existing automated tests for `Taskami` and note any failures.
- [x] Inspect high-risk areas manually: document loading/saving, file coordination, parser/serializer logic, authentication lock flow, and query execution.
- [x] Record review findings with severity and decide which ones are critical enough to fix immediately.
- [x] Implement fixes for confirmed critical issues.
- [x] Re-run targeted verification after each fix and the full relevant test suite at the end.
- [x] Summarize what was fixed, what remains risky, and any follow-up work worth doing next.

## Verification Notes

- `xcodebuild test -project Taskami.xcodeproj -scheme Taskami -destination 'platform=iOS Simulator,name=iPhone 16'` could not complete in this environment because `CoreSimulatorService` is unavailable.
- `xcodebuild build -project Taskami.xcodeproj -scheme Taskami -destination 'generic/platform=iOS'` was blocked by the same Xcode/CoreSimulator environment issue before reaching a useful compile result.
- Added regression tests covering blank-line preservation and tag-range trimming to protect the critical fixes once the project is run in a full Xcode environment.
