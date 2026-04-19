# Taskami Roadmap

Inspired by feature analysis of [Papertrail — TaskPaper Client](https://apps.apple.com/us/app/papertrail-taskpaper-client/id6751271083).

---

## Phase 1 — Core Editing Improvements

### Outline Focus & Folding
- Fold/unfold subtrees (tap disclosure triangle or keyboard shortcut)
- "Focus In" — zoom into a project/task subtree, hiding siblings
- "Focus Out" — step back up the outline hierarchy
- Preserve fold state across edits, undo/redo, and app restarts

### Free-Scroll Mode
- Allow document scrolling while the keyboard is open without dismissing it
- Cursor stays in its last position; user can scroll freely to read context

### Cursor Position Memory
- Persist per-document cursor position (and fold state) to disk
- Restore position when reopening a file

---

## Phase 2 — Date & Tag Intelligence

### @due / @start Date Tags
- Treat `@due(YYYY-MM-DD)` and `@start(YYYY-MM-DD)` as first-class date tags
- Natural-language date parsing ("today", "tomorrow", "next monday")
- Query filter: `@due < today`, `@start > today`
- Inline date picker when editing a date tag value

### Progress Aggregation
- Compute `@progress` as percentage of `@done` descendant tasks
- Display as a small progress bar in the cell (project rows only)

### Cost / Numeric Tag Aggregation
- Sum `@cost(N)` values across children of a project
- Show aggregate in the project cell

---

## Phase 3 — Visual & Appearance

### Color-Coded Lines
- Optional line coloring rule: by item type, indent depth, tag (`@priority`, `@due` proximity)
- Configurable in Settings → Appearance

### HTML Export
- Export document (or focused subtree) as a styled HTML file
- Theme picker: White, Black, Gradient, Pastels
- Include page navigation controls and progress bar
- Share via share sheet

### Dynamic Type Support
- Respect iOS Dynamic Type size setting in place of (or alongside) the manual font size

---

## Phase 4 — Power User & Keyboard

### Command Palette (Go To)
- `Cmd+P` — jump to project/task by name
- `Option+Cmd+P` — insert tag snippet
- `Control+Cmd+P` — apply filter preset

### Expanded Keyboard Shortcuts (iPad / hardware keyboard)
- `Option+Cmd+↓` / `Option+Cmd+↑` — Focus In / Focus Out
- `Cmd+[` / `Cmd+]` — Indent / Outdent
- `Cmd+/` — Toggle @done
- `Cmd+F` — Jump to search bar
- `Cmd+N` — New item below cursor
- Full discoverability via UIKeyCommandDiscoverability

### Edge-Swipe Gestures
- Leading edge swipe → open/dismiss filter panel
- Trailing edge swipe → Focus Out one level

---

## Phase 5 — Integration & Import/Export

### iOS Reminders Sync
- Two-way sync: tasks with `@reminder` tag ↔ iOS Reminders
- Push due-date reminders for `@due` tagged tasks

### OPML Import
- Convert OPML outlines into TaskPaper hierarchy on import

### Share Sheet / Files Integration
- Export `.taskpaper` files via native share sheet
- Open-in-place support for Files app

---

## Phase 6 — Accessibility & Polish

### VoiceOver
- Full VoiceOver support: rotor navigation by item type, actions for indent/done
- Announce fold state changes

### Widgets & Quick Actions
- Home screen widget showing today's tasks (`@due = today`)
- Lock screen widget
- Home screen quick actions: New Task, Search

### Search History
- Persist recent queries; show in search suggestions

---

## Deferred / Under Consideration

- Multi-user collaboration / sharing
- Recurring task support (`@repeat`)
- Markdown rendering mode
- File attachment support
- Completion statistics / analytics dashboard
- Print support
