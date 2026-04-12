# Taskami — Claude Code Guidelines

## Self-Testing Policy

**You must verify every UI change yourself using the simulator — do not ask the user to test.**

After any change that affects visible behaviour:
1. Build and run with `build_run_sim`
2. Run the relevant UI tests with `test_sim -only-testing TaskamiUITests`
3. If the tests catch a failure, fix it before reporting done
4. If no test covers the scenario yet, write one first, confirm it fails on the broken code, then fix

Only report a fix as complete after the automated tests pass.

## Project Overview

- **Language**: Swift 5.9, UIKit (iOS 17+)
- **Architecture**: UICollectionViewDiffableDataSource + compositional list layout, self-sizing cells
- **Key files**:
  - `Taskami/Editor/DocumentEditorViewController.swift` — main editor, data source, delegate hub
  - `Taskami/Editor/TaskItemCell.swift` — cell: display + edit mode, dash button toggle
  - `Taskami/Parser/` — TaskPaper format parser and serializer
  - `Taskami/Query/` — query AST parser and evaluator
- **Test targets**:
  - `TaskamiTests/` — Swift Testing unit tests (`@Test`, `#expect`)
  - `TaskamiUITests/` — XCUITest UI regression tests

## Build & Test Commands

```
# Build + run on simulator
mcp__XcodeBuildMCP__build_run_sim

# Run all tests
mcp__XcodeBuildMCP__test_sim

# Run only UI tests
mcp__XcodeBuildMCP__test_sim -only-testing TaskamiUITests

# Run only unit tests
mcp__XcodeBuildMCP__test_sim -only-testing TaskamiTests
```

## Known Gotchas

- `cellForItem(at:)` returns nil if a cell's height changed since the last layout pass and the cell shifted off-screen. Always call `scrollToItem` + `layoutIfNeeded` before relying on `cellForItem`.
- `reconfigureItems` + `apply(animatingDifferences: false)` silently skips the cell registration handler for stable-identity items — use `animatingDifferences: true` or call `configure` directly.
- `DispatchQueue.main.async` deferral for `visibleCells` scan races with `preferredLayoutAttributesFitting` height changes — the cell can be off-screen by the time the block runs.
- `UIButton(type: .custom)` absorbs its own touch so `didSelectItemAt` does NOT also fire when the dash button is tapped.
- Logger subsystem is `"com.taskami"` (not the bundle ID `"com.koryashkin.taskami"`). Use `subsystemFilter: ["com.taskami"]` when capturing logs.
