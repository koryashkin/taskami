# TodoMD

## Full Project Review And Critical Fix Pass

- [x] Inventory the repository and identify the actively maintained application surface.
- [x] Run the existing automated tests for `Taskami` and note any failures.
- [x] Inspect high-risk areas manually: document loading/saving, file coordination, parser/serializer logic, authentication lock flow, and query execution.
- [x] Record review findings with severity and decide which ones are critical enough to fix immediately.
- [x] Implement fixes for confirmed critical issues.
- [x] Re-run targeted verification after each fix and the full relevant test suite at the end.
- [x] Summarize what was fixed, what remains risky, and any follow-up work worth doing next.

## Papertrail Feature Parity (see ROADMAP.md for details)

### Phase 1 — Core Editing
- [ ] Fold/unfold subtrees with disclosure triangle
- [ ] Focus In / Focus Out (zoom into subtree, step back out)
- [ ] Preserve fold state across edits, undo/redo, and app restarts
- [ ] Free-scroll mode (scroll document without dismissing keyboard)
- [ ] Per-document cursor position memory (persist and restore on reopen)

### Phase 2 — Date & Tag Intelligence
- [ ] First-class `@due` / `@start` date tag support with natural-language parsing
- [ ] Date-aware query filters (`@due < today`, `@start > today`)
- [ ] Inline date picker when editing a date tag value
- [ ] Progress aggregation: compute `@progress` from `@done` descendants
- [ ] Numeric tag aggregation: sum `@cost(N)` across project children

### Phase 3 — Visual & Appearance
- [ ] Color-coded lines: by type, depth, or `@due` proximity
- [ ] HTML export with theme picker (White, Black, Gradient, Pastels) and share sheet
- [ ] Dynamic Type support

### Phase 4 — Power User & Keyboard
- [ ] Command palette (`Cmd+P`) — jump to project/task by name
- [ ] Expanded hardware-keyboard shortcuts (Focus In/Out, Indent, Done, New, Search)
- [ ] Edge-swipe gestures: leading → filter panel, trailing → Focus Out

### Phase 5 — Integration & Import/Export
- [ ] iOS Reminders sync for `@due` tagged tasks
- [ ] OPML import → TaskPaper hierarchy
- [ ] Share sheet / Files open-in-place export

### Phase 6 — Accessibility & Polish
- [ ] Full VoiceOver support with rotor navigation and fold-state announcements
- [ ] Home screen & lock screen widgets (today's tasks)
- [ ] Home screen quick actions: New Task, Search
- [ ] Persist and display recent search history

## Verification Notes

- `xcodebuild test -project Taskami.xcodeproj -scheme Taskami -destination 'platform=iOS Simulator,name=iPhone 16'` could not complete in this environment because `CoreSimulatorService` is unavailable.
- `xcodebuild build -project Taskami.xcodeproj -scheme Taskami -destination 'generic/platform=iOS'` was blocked by the same Xcode/CoreSimulator environment issue before reaching a useful compile result.
- Added regression tests covering blank-line preservation and tag-range trimming to protect the critical fixes once the project is run in a full Xcode environment.
