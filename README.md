# Taskami

A modern TaskPaper-compatible outliner for iOS, built with Swift and UIKit.

Taskami reads and writes plain `.taskpaper` files — a simple, human-readable format used by the original TaskPaper for Mac. Your files stay yours: no proprietary format, no lock-in.

---

## Features

### TaskPaper Format

- Full `.taskpaper` compatibility — projects, tasks, and notes with `@tag(value)` metadata
- Round-trips cleanly with TaskPaper for Mac and any plain-text editor
- Preserves original encoding and line endings

### Editing

- Tap any item to edit; Return creates a new task below
- Backspace on an empty line deletes the item
- Indent / outdent with Tab / Shift-Tab or the keyboard accessory bar
- Drag-and-drop to reorder items within the document
- Toggle `@done` via the dash button, swipe action, or keyboard accessory

### Outline Focus & Folding

- **Fold/unfold** subtrees with the disclosure triangle — collapsed items remain searchable
- **Focus In** — swipe an item to zoom into its subtree, hiding everything else; a breadcrumb bar shows your path
- **Focus Out** — step back up the hierarchy; nested focus levels are remembered
- Fold state and cursor position are persisted per-document across app restarts and undo/redo

### Date & Tag Intelligence

- `@due` and `@start` tags are date-aware: natural language input (`today`, `tomorrow`, `next monday`, `in 3 weeks`) is normalized to ISO `yyyy-MM-dd` on commit
- **Inline date picker** — tap the calendar button in the keyboard accessory to set or update a `@due` / `@start` date without typing
- Date tags are color-coded by proximity: red (overdue), orange (today), yellow (within 7 days)
- **Progress bar** — project cells show a compact `▓▓▓░░░░░ 3/5` summary of completed descendant tasks
- **Cost aggregation** — `@cost(N)` values across a project's children are summed and displayed in the project cell

### Search & Filtering

- Full-text search across all items, including inside collapsed subtrees
- **Query syntax** — filter by tag, type, indent level, and more:
  - `@due < today` — overdue tasks
  - `@priority = high` — tasks by tag value
  - `type = project` — only projects
  - `@done` — all completed items
  - Operators: `=`, `!=`, `<`, `<=`, `>`, `>=`, `contains`, `beginswith`, `endswith`, `like`, `matches`
  - Combine with `and`, `or`, `not`

### Themes & Appearance

- Light, Dark, and Sepia editor themes
- Configurable font family and size
- Syntax coloring: projects, tasks, notes, tags, and done items each have distinct colors

### Free-Scroll Mode

- Lock the keyboard open while scrolling the document freely — useful for reading context while writing
- Toggle via the scroll button in the keyboard accessory; resets automatically when the keyboard dismisses

### iCloud & File Management

- iCloud Drive integration — browse, open, and create `.taskpaper` files from any location
- NSFileCoordinator-based reads and writes for safe concurrent access
- 1-second debounced autosave; reloads automatically when the file changes on disk

---

## Requirements

- iOS 17+
- Xcode 15+

---

## Building

```
open Taskami.xcodeproj
```

Select a simulator or device and press Run. No additional dependencies are required.

### Tests

```sh
# All tests
xcodebuild test -scheme Taskami -destination 'platform=iOS Simulator,name=iPhone 16'

# Unit tests only
xcodebuild test -scheme Taskami -destination '...' -only-testing TaskamiTests

# UI tests only
xcodebuild test -scheme Taskami -destination '...' -only-testing TaskamiUITests
```

---

## File Format

Taskami uses the [TaskPaper](https://guide.taskpaper.com) plain-text format:

```
Inbox:
	- Buy milk @due(2024-12-01)
	- Call dentist @due(today) @priority(high)

Work:
	Project Alpha: @due(next friday)
		- Write spec @done(2024-11-20)
		- Review PR
		Notes go here without a dash prefix
```

- Lines ending with `:` are **projects**
- Lines starting with `- ` are **tasks**
- Everything else is a **note**
- Tags use `@name` or `@name(value)` syntax and can appear anywhere on a line

---

## License

MIT. See [LICENSE.md](LICENSE.md).
