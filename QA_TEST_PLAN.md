# Taskami QA Test Plan

## Purpose

This plan is written for a QA engineer based on the current code in the repository. It is intended to:

- explain what the app does today
- identify the highest-risk areas from the implementation
- define a practical test strategy
- provide a large set of concrete test cases covering functional, regression, UX, state, and integration behavior

## Product Summary

Taskami is an iOS TaskPaper-compatible outliner. Based on the code, the app currently includes:

- file browser for `.taskpaper` and `.txt` files plus folders
- document editor with task/project/note lines
- inline editing with keyboard accessory actions
- indentation and hierarchical outline behavior
- done/undone toggling
- fold/unfold and focus-in/focus-out navigation
- search and query filtering
- date parsing and inline date picker
- HTML export
- OPML import
- reminders sync
- theme/font/color settings
- autosave, reload-on-disk-change, fold-state persistence, and cursor restore
- optional biometric lock
- widget data export for today’s due tasks

## Code-Based Risk Assessment

The following areas deserve the most QA attention because the code suggests fragile or stateful behavior:

1. Editor cell lifecycle and layout refresh
   The editor relies on `UICollectionViewDiffableDataSource`, self-sizing cells, editing-state reuse, and reconfiguration shortcuts. Several comments explicitly reference previous regressions around stale visuals, missing cells, and layout races.

2. Editing while UI state changes
   Keyboard show/hide, item height changes, scrolling, fold/unfold, focus mode, search filtering, and snapshot refreshes all interact with the active editing cell.

3. Done-state toggling
   Done toggling is implemented from dash button, swipe action, and keyboard accessory, with special handling to avoid stale cell display.

4. Outline mutations
   Insert, delete, indent, outdent, drag/drop reorder, undo/redo, and focus navigation all mutate shared tree state.

5. Query and search behavior
   Search can be plain text or query syntax. The filter works across all items, including collapsed ones, and query parsing falls back permissively on invalid input.

6. Persistence and external file changes
   Autosave, editor-state sidecar files, encoding/line-ending preservation, and external reload behavior are all important and easy to regress.

7. Integrations
   OPML import, HTML export, Reminders sync, widget update, biometric lock, and system file opening all require separate verification.

## Existing Automated Coverage

Current automated tests already cover some important areas:

- Unit tests:
  - TaskPaper parsing and serialization
  - tag parsing
  - date parsing/normalization
  - query tokenization and evaluation
  - task/document model behaviors
  - HTML export
- UI tests:
  - done toggle regressions
  - `@done` tag add/remove behavior
  - tap-to-edit regressions after toggling done

## Biggest Remaining Manual QA Gaps

The code indicates these still need strong manual coverage:

- file browser flows
- search suggestions UI
- focus mode and breadcrumb behavior
- folding with active editing descendants
- drag/drop reorder behavior
- undo/redo end-to-end UX
- date picker UI behavior
- settings persistence and visual theme changes
- reminders sync outcomes
- OPML import flows and failure handling
- biometric lock flows
- external file change/reload behavior
- widget-facing “today” task propagation
- shortcut-driven entry points and system open URL flows

## Recommended Test Environments

- iPhone simulator, latest supported iOS
- at least one smaller-screen iPhone
- at least one larger-screen iPhone
- light mode and dark mode device appearance
- normal text size and larger Dynamic Type size
- device/simulator with and without biometric capability where possible
- test data stored locally and, if available, in iCloud Drive

## Suggested Test Data Sets

Prepare these documents before execution:

- `Simple.taskpaper`
  - 5 to 10 mixed tasks, projects, and notes
- `DeepHierarchy.taskpaper`
  - 5+ indent levels, mixed child tasks and notes
- `TagsAndDates.taskpaper`
  - `@due`, `@start`, `@done`, `@priority`, `@cost`, repeated tags, invalid dates, natural-language dates
- `LongContent.taskpaper`
  - very long lines, multiline-feel long wrapping content, emoji, punctuation, regex-like text
- `LargeDocument.taskpaper`
  - 300+ items for scroll/reuse/performance sanity
- `ImportValid.opml`
  - nested OPML outline with title
- `ImportInvalid.opml`
  - malformed XML or non-OPML XML

## Test Strategy

- Run smoke tests first on file browser, open document, create/edit/toggle/save.
- Run high-risk editor regressions next.
- Run feature suites by area.
- Run cross-feature tests last.
- For issues found in editor, always retest with:
  - document scrolled
  - search active
  - focus mode active
  - larger text size if relevant

## Entry / Exit Criteria

### Entry Criteria

- app launches successfully
- at least one editable document exists
- test files are available
- reminders and biometrics test conditions are understood

### Exit Criteria

- all P0 and P1 test cases pass
- no blocker in create/open/edit/save/delete/search flows
- no data loss in autosave/reopen/reload scenarios
- no critical accessibility or navigation regression in the editor

---

## Test Cases

### A. App Launch, Navigation, and Shell

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| A-001 | Launch app to file browser | P0 | App installed | Launch app | App opens without crash and shows file browser or lock screen if enabled |
| A-002 | Relaunch after force close | P1 | App previously used | Force close, relaunch | App launches cleanly and preserves prior persisted state where applicable |
| A-003 | Navigation from file browser to document | P0 | Existing document | Tap a file | Document view opens with correct title |
| A-004 | Back navigation from document to browser | P0 | Document open | Tap back | Returns to file browser without crash |
| A-005 | Open nested folder then return | P1 | Existing folder | Open folder, then back | Folder contents load and back returns to parent directory |
| A-006 | Open app with no existing files | P2 | Empty directory | Launch app | App remains usable and user can create a file |
| A-007 | App handles repeated open-close-open navigation | P1 | Existing documents | Open doc A, back, open doc B, back, open doc A | No stale content, wrong title, or crash |
| A-008 | App state after background/foreground | P1 | App unlocked | Background app, foreground app | App resumes correctly and document/file browser state remains coherent |

### B. File Browser

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| B-001 | Show only supported file types and folders | P1 | Directory contains folders, `.taskpaper`, `.txt`, and unsupported files | Open directory | Only folders, `.taskpaper`, and `.txt` are listed |
| B-002 | Directory rows appear before files | P2 | Mixed items | Observe list | Folders sort before files |
| B-003 | Search filters files by name case-insensitively | P1 | Several files/folders | Use search bar with partial name and different case | Matching items only are shown |
| B-004 | Clear file search restores list | P2 | Search active | Clear search text | Full list returns |
| B-005 | Pull to refresh updates list | P2 | Add/remove file externally if possible | Pull to refresh | File browser refreshes to current directory contents |
| B-006 | Create new file without extension | P0 | In file browser | Create file named `Inbox` | File is created as `Inbox.taskpaper` |
| B-007 | Create new file with `.taskpaper` extension | P1 | In file browser | Create `Work.taskpaper` | File created once with no duplicate extension |
| B-008 | Create new file with empty name | P1 | New file dialog open | Leave name empty, tap Create | File is not created |
| B-009 | Create new folder | P0 | In file browser | Create folder `Projects` | Folder appears in list |
| B-010 | Create new folder with empty name | P1 | New folder dialog open | Leave blank, tap Create | Folder is not created |
| B-011 | Delete file from list | P0 | Existing file | Swipe/delete file | File is removed from file system and list refreshes |
| B-012 | Delete folder from list | P1 | Existing folder | Delete folder | Folder is removed if deletion is allowed by contents/state |
| B-013 | Sort by Name A-Z | P1 | Several files | Select Name A-Z | Items sort correctly |
| B-014 | Sort by Name Z-A | P1 | Several files | Select Name Z-A | Items sort correctly |
| B-015 | Sort by Modified Newest | P1 | Files with different timestamps | Select Modified Newest | Files sort newest first after folders |
| B-016 | Sort by Modified Oldest | P1 | Files with different timestamps | Select Modified Oldest | Files sort oldest first after folders |
| B-017 | Show file extensions OFF | P2 | File browser visible | Disable Show File Extensions | `.taskpaper` file rows display without extension |
| B-018 | Show file extensions ON | P2 | File browser visible | Enable Show File Extensions | `.taskpaper` file rows display full name |
| B-019 | Navigate into folder while search is active | P2 | Search text entered, matching folder visible | Open folder | Navigation works and new folder view loads correctly |
| B-020 | New file uses bundled default content | P1 | Create new file | Open created file | Default document content is present, not a blank or corrupted file |

### C. Document Open, Save, and Persistence

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| C-001 | Open existing TaskPaper file | P0 | Existing `.taskpaper` file | Open file | Document content renders correctly |
| C-002 | Open existing `.txt` file | P1 | Existing `.txt` file in valid format | Open file | Document opens and content is parsed |
| C-003 | Autosave after edit | P0 | Document open | Edit an item, wait >1 second, leave and reopen | Edit persists |
| C-004 | Debounced autosave with rapid typing | P1 | Document open | Make several fast edits, stop typing | Final content persists without duplication or truncation |
| C-005 | Close document after unsaved change | P0 | Document open | Edit and immediately back out | Content is saved on disappear and persists when reopened |
| C-006 | Preserve line endings | P2 | File prepared with CRLF | Open, make small edit, save | File remains readable and line ending behavior remains correct |
| C-007 | Preserve encoding | P2 | File with non-ASCII and known encoding | Open, edit, save | Content remains readable and not mojibake |
| C-008 | Reopen same document restores fold state | P1 | Collapse some items | Leave document, reopen | Same items remain collapsed |
| C-009 | Reopen same document restores cursor location | P1 | Edit item mid-line, leave | Reopen document | Editing resumes at saved item and near saved offset |
| C-010 | Open document with malformed content | P2 | Odd content file | Open file | App handles gracefully and does not crash |

### D. Basic Editing

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| D-001 | Tap task cell enters edit mode | P0 | Document open | Tap a task row | Keyboard appears and row becomes editable |
| D-002 | Tap note cell enters edit mode | P1 | Document open | Tap a note row | Keyboard appears and note is editable |
| D-003 | Tap project cell enters edit mode | P1 | Document open | Tap a project row | Keyboard appears and project is editable |
| D-004 | Editing text updates visible content after commit | P0 | In edit mode | Change text, dismiss keyboard | Display updates to new content |
| D-005 | Return creates new item below current item | P0 | Editing non-empty item | Press Return | New task inserted below and enters edit mode |
| D-006 | Backspace on empty line deletes item | P1 | Editing blank item | Press Backspace on empty content | Item is deleted |
| D-007 | Editing long wrapped text does not clip | P1 | Long content document | Edit long item | Cell grows and content remains visible |
| D-008 | Tap already editing cell | P2 | One item editing | Tap same cell again | No duplicate editing state or crash |
| D-009 | Tap different cell while editing current one | P0 | One item editing | Tap another cell | First edit commits and second cell enters edit mode |
| D-010 | Dismiss keyboard via accessory dismiss button | P1 | Editing item | Tap dismiss accessory | Keyboard hides and content commits |
| D-011 | Keyboard appearance does not cover editing cell | P1 | Edit near bottom of list | Tap cell near bottom | Collection scrolls enough to keep editor visible |
| D-012 | Keyboard hide resets layout cleanly | P1 | Editing item | Dismiss keyboard | Insets reset and no visual jump persists |
| D-013 | Edit top, middle, and bottom visible cells | P1 | Large document | Edit items in each region | All are editable reliably |
| D-014 | Edit after scrolling large document | P0 | Large document | Scroll far down, tap item | Edit mode still works |
| D-015 | Change task text to empty and commit | P2 | Task exists | Delete text and commit | Behavior is stable; no crash or ghost content |

### E. Item Types, Parsing, and Re-typing

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| E-001 | New line with `- ` remains task | P1 | Editing task | Commit regular task text | Item remains task |
| E-002 | Rename task to end with `:` | P1 | Task item editing | Change content to `Project X:` and commit | Item becomes project and displays as project |
| E-003 | Rename note to end with `:` | P1 | Note item editing | Add trailing colon and commit | Item becomes project |
| E-004 | Rename existing project to text without `:` | P1 | Project item editing | Remove colon and commit | Item stays project according to current code behavior |
| E-005 | Project with tags preserves tags after commit | P1 | Project with tags | Edit project name and commit | Tags remain and render correctly |
| E-006 | Note containing colon not at end stays note | P2 | Note item | Enter `Discuss: scope later` | Item remains note |

### F. Done / Undone Behavior

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| F-001 | Dash button marks undone task done | P0 | Visible undone task | Tap dash | Task becomes done visually and in content |
| F-002 | Dash button marks done task undone | P0 | Visible done task | Tap dash | `@done` removed and visual state updates |
| F-003 | Repeated dash toggle on same task | P0 | Visible task | Toggle 10 times | State alternates correctly every time |
| F-004 | Toggle first task then second task | P0 | At least two tasks visible | Toggle task 1 repeatedly then task 2 | Second task visual state also updates correctly |
| F-005 | Toggle after scrolling | P0 | Large document | Scroll and toggle deeper items | Visual state updates correctly |
| F-006 | Accessory done button toggles done while editing | P0 | Editing task | Tap accessory done | Edit commits, keyboard dismisses, task toggles |
| F-007 | Swipe done action toggles done | P1 | Visible task, not editing | Use trailing swipe done | Task toggles |
| F-008 | Done toggle with Add Date to `@done` ON | P1 | Setting enabled | Toggle undone task done | `@done(yyyy-mm-dd)` added |
| F-009 | Done toggle with Add Date to `@done` OFF | P1 | Setting disabled | Toggle undone task done | Bare `@done` added without date |
| F-010 | Undone removes dated `@done(...)` tag cleanly | P1 | Task with dated `@done` | Toggle to undone | Done tag fully removed without leftover punctuation/spaces |
| F-011 | Done task accessibility state changes | P2 | VoiceOver or accessibility inspection | Toggle task | Accessibility label/value changes appropriately |
| F-012 | Toggle done while search is active | P1 | Search/filter results visible | Toggle visible matching task | Toggle works and filter refresh remains stable |

### G. Indent, Outdent, and Hierarchy

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| G-001 | Accessory indent indents current item | P0 | Editing item with previous sibling | Tap indent | Item becomes child of previous sibling |
| G-002 | Accessory outdent outdents current child | P0 | Editing child item | Tap outdent | Item moves up one level |
| G-003 | Tab indents while editing | P1 | Hardware keyboard or supported text input | Trigger indent shortcut | Item indents |
| G-004 | Shift-Tab outdents while editing | P1 | Same as above | Trigger outdent shortcut | Item outdents |
| G-005 | Indenting first sibling does nothing safely | P1 | First root/child item | Attempt indent | No crash; hierarchy remains valid |
| G-006 | Outdenting root item does nothing safely | P1 | Root item | Attempt outdent | No crash; hierarchy remains valid |
| G-007 | Outdent reparents following siblings under moved item | P1 | Parent with multiple children | Outdent middle child | Tree structure matches current algorithm |
| G-008 | Indent/outdent preserves descendant levels | P1 | Item with children | Indent then outdent | Descendant indentation remains coherent |
| G-009 | Edit continues after indent | P1 | Editing item | Indent | Item remains editable after refresh |
| G-010 | Edit continues after outdent | P1 | Editing item | Outdent | Item remains editable after refresh |

### H. Insert, Delete, and Reorder

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| H-001 | Add task from toolbar | P0 | Document open | Tap Add Task | New blank task created and editable |
| H-002 | Add task while another item is editing | P1 | Editing existing item | Tap Add Task | Current edit commits and new task opens |
| H-003 | Delete via swipe action | P0 | Existing item | Swipe delete | Item removed |
| H-004 | Delete via backspace on blank line | P1 | Blank editing row | Backspace | Item removed |
| H-005 | Delete currently last visible item | P1 | Last visible item present | Delete it | Snapshot updates correctly without stale cell |
| H-006 | Delete item with children | P1 | Project with subtree | Delete project | Entire subtree removed |
| H-007 | Undo delete restores item | P1 | Deleted item | Trigger undo | Item returns at correct position |
| H-008 | Undo insert removes inserted item | P1 | New item added | Trigger undo | Insert is reverted |
| H-009 | Drag root item to another root position | P1 | Large document | Drag item to new place | Order changes correctly |
| H-010 | Drag child within same parent | P1 | Parent with multiple children | Drag reorder child | Order updates correctly |
| H-011 | Drag item onto target with different parent | P1 | Mixed hierarchy | Drag item near another parent group | Resulting parent/index follow current implementation and remain valid |
| H-012 | Drag while editing is prevented cleanly | P1 | One item in edit mode | Attempt drag | No incorrect drop or corruption |
| H-013 | Delete item while search is active | P1 | Filtered list visible | Delete matching item | Item removed and filtered snapshot stays valid |

### I. Fold / Unfold / Focus

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| I-001 | Disclosure button collapses project | P0 | Project with children | Tap disclosure | Project collapses and descendants hide |
| I-002 | Disclosure button expands collapsed project | P0 | Collapsed project | Tap disclosure | Descendants show again |
| I-003 | Collapse then reopen document | P1 | Some items collapsed | Leave and reopen | Collapse state persists |
| I-004 | Collapse item with active editing descendant | P1 | Editing a child item | Collapse ancestor | Edit commits first and no invisible active editor remains |
| I-005 | Collapse item under search filter | P2 | Search active | Collapse matching project | UI remains stable |
| I-006 | Focus in via leading swipe on project with children | P1 | Visible project with children | Swipe leading, tap Focus | Only subtree is shown |
| I-007 | Focus action unavailable for leaf item | P2 | Visible leaf item | Attempt leading swipe | No Focus action appears |
| I-008 | Focus breadcrumb appears when focused | P1 | Focused into subtree | Observe top area | Breadcrumb visible with correct path |
| I-009 | Focus out via breadcrumb button | P1 | In focused subtree | Tap breadcrumb focus out | Returns to previous scope |
| I-010 | Nested focus stack works | P1 | Multiple project levels | Focus into child then grandchild; focus out twice | Returns one level at a time |
| I-011 | Focus out after focused item deleted | P1 | Focused item then deleted externally/by action | Refresh state | App falls back safely to previous focus level or root |
| I-012 | Focused list respects collapse rules | P1 | Focus inside subtree with collapsed child | Observe visible items | Collapsed descendants remain hidden |
| I-013 | Search while focused searches whole document or filtered list behavior remains stable | P1 | Focus active | Enter search | Results appear and no crash occurs; verify current behavior is consistent |
| I-014 | Two-finger right swipe focuses out | P2 | Focus active | Perform gesture | Focus exits |
| I-015 | Two-finger left swipe activates search | P2 | Document open | Perform gesture | Search field activates |

### J. Search, Filter, and Suggestions

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| J-001 | Plain text search finds matching content | P0 | Document with searchable text | Search keyword | Matching items shown |
| J-002 | Search is case-insensitive | P1 | Searchable content | Search with different case | Same items match |
| J-003 | Search on collapsed descendant still finds item | P1 | Collapsed subtree contains target | Search target | Matching descendant appears |
| J-004 | Clear search restores visible outline state | P1 | Search active | Clear search | Normal visible list returns |
| J-005 | Search field activated by toolbar | P2 | Document open | Activate search UI | Search field becomes active |
| J-006 | Recent search saved when closing search | P2 | Search non-empty | Close search | Search is added to recent searches |
| J-007 | Recent search list deduplicates newest first | P2 | Repeat searches | Search same term multiple times | Only one recent entry remains at top |
| J-008 | Recent search list capped at 10 | P2 | Execute >10 unique searches | Open suggestions | Only 10 most recent remain |
| J-009 | Recent searches clear button works | P2 | Recent searches exist | Tap Clear | Recent list disappears |
| J-010 | Tag suggestions are generated from document tags | P2 | Document contains tags | Open suggestions | Tag section contains discovered tags |
| J-011 | Project suggestions are generated from project items | P2 | Document contains projects | Open suggestions | Project section contains projects |
| J-012 | Tap “Not Done” query suggestion | P2 | Suggestions visible | Tap Not Done | Search text becomes `not @done` and results update |
| J-013 | Tap recent search suggestion | P2 | Recent search exists | Tap suggestion | Search text is restored and used |
| J-014 | Invalid query text does not crash | P1 | Document open | Enter malformed query | App stays stable; current code likely falls back permissively |

### K. Query Syntax Coverage

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| K-001 | `@done` returns done items | P1 | Mixed done/undone tasks | Search `@done` | Only done-tagged items match |
| K-002 | `not @done` returns undone items | P1 | Mixed tasks | Search `not @done` | Undone items match |
| K-003 | `type = task` | P1 | Mixed item types | Search query | Only tasks shown |
| K-004 | `type = project` | P1 | Mixed item types | Search query | Only projects shown |
| K-005 | `@priority = high` | P1 | Tagged tasks exist | Search query | Matching priority items shown |
| K-006 | `@cost > 3` | P1 | Numeric `@cost` tags exist | Search query | Numeric comparison works |
| K-007 | `@due < today` | P1 | Past/today/future due items | Search query | Only overdue items shown |
| K-008 | `@due = today` | P1 | Item due today exists | Search query | Today item shown |
| K-009 | `@due > today` | P1 | Future due items exist | Search query | Future items shown |
| K-010 | `project = "Work"` | P1 | Tasks inside project `Work` | Search query | Project and descendants matching logic behave correctly |
| K-011 | `content contains foo` | P2 | Matching content exists | Search query | Contains relation works |
| K-012 | `content beginswith foo` | P2 | Matching content exists | Search query | Beginswith works |
| K-013 | `content endswith bar` | P2 | Matching content exists | Search query | Endswith works |
| K-014 | `content like *foo*` | P2 | Matching content exists | Search query | Wildcard like works |
| K-015 | `content matches` regex | P2 | Regex-matchable content exists | Search query | Regex matching works |
| K-016 | `(@done or @due < today) and type = task` | P2 | Mixed data exists | Search query | Grouping and boolean logic work |

### L. Date Tags and Date Picker

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| L-001 | Commit `@due(today)` normalizes to ISO date | P1 | Edit task | Enter natural language due tag and commit | Tag converts to `yyyy-mm-dd` |
| L-002 | Commit `@start(tomorrow)` normalizes to ISO date | P1 | Edit task | Enter start tag and commit | Tag converts to ISO |
| L-003 | Commit `@priority(today)` does not normalize | P1 | Edit task | Enter non-date tag with `today` | Value remains unchanged |
| L-004 | Commit invalid date string remains unchanged | P1 | Edit task | Enter `@due(whenever)` | Value remains as typed |
| L-005 | Date picker adds `@due` when no due/start tag exists | P1 | Editing task without date tags | Tap date picker and set date | `@due(yyyy-mm-dd)` appended |
| L-006 | Date picker updates existing `@due` | P1 | Editing task with due tag | Change date via picker | Existing due tag value replaced |
| L-007 | Date picker updates `@start` if no `@due` exists | P2 | Editing task with `@start` only | Change date via picker | `@start` updated |
| L-008 | Date picker cancel leaves content unchanged | P2 | Editing item | Open picker, cancel | Text remains unchanged |
| L-009 | Date picker initial value uses existing tag date | P2 | Item has due date | Open picker | Picker opens on current due date |
| L-010 | Overdue/today/upcoming tinting when setting enabled | P2 | Due tinting enabled, several due dates | Observe items | Colors reflect proximity |
| L-011 | Due tinting disabled removes special coloring | P2 | Same as above | Disable setting | Special tinting no longer shown |

### M. Project Progress and Cost Aggregation

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| M-001 | Project with task descendants shows progress summary | P2 | Project with mixed child task completion | Observe project row | Progress indicator appears |
| M-002 | Progress updates after toggling child done | P2 | Project with children | Toggle child task done | Project summary updates |
| M-003 | Nested descendant tasks count toward progress | P2 | Multi-level project | Toggle deep descendant done | Progress reflects nested tasks |
| M-004 | Project with no task descendants does not show misleading progress | P2 | Project with notes only | Observe project row | No incorrect progress summary |
| M-005 | Aggregate cost sums direct child `@cost` values | P2 | Project with direct child costs | Observe project row | Total cost shown correctly |
| M-006 | Aggregate cost ignores non-numeric `@cost` | P2 | One child has invalid cost | Observe project row | Invalid value ignored |
| M-007 | Aggregate cost ignores grandchildren cost if not direct children | P2 | Nested cost tags | Observe total | Only direct children contribute |

### N. Keyboard Accessory and Input Behavior

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| N-001 | Accessory indent button visible while editing | P2 | Editing item | Observe accessory | Indent button present |
| N-002 | Accessory outdent button visible while editing | P2 | Editing item | Observe accessory | Outdent button present |
| N-003 | Accessory done button visible while editing | P2 | Editing item | Observe accessory | Done button present |
| N-004 | Accessory cursor-left moves cursor left | P2 | Editing text mid-line | Tap cursor-left | Cursor position moves left |
| N-005 | Accessory cursor-right moves cursor right | P2 | Editing text mid-line | Tap cursor-right | Cursor moves right |
| N-006 | Accessory free-scroll toggles active tint | P2 | Editing item | Tap free-scroll | Button tint changes |
| N-007 | Free-scroll keeps keyboard visible while scrolling | P1 | Editing item | Enable free-scroll and scroll list | Keyboard remains visible |
| N-008 | Dismissing keyboard resets free-scroll state | P1 | Free-scroll active | Dismiss keyboard, re-enter edit mode | Free-scroll returns to default OFF |
| N-009 | Drag interaction disabled while keyboard visible/editing | P1 | Editing item | Attempt drag/reorder | Drag does not interfere |

### O. Undo / Redo

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| O-001 | Undo content edit | P1 | Edited item | Trigger undo | Content reverts |
| O-002 | Redo content edit | P1 | After undo | Trigger redo | Content restores |
| O-003 | Undo done toggle | P1 | Toggle task done | Trigger undo | Done state reverts |
| O-004 | Redo done toggle | P1 | After undo | Trigger redo | Done state reapplies |
| O-005 | Undo insert | P1 | Insert item | Undo | Insert removed |
| O-006 | Undo delete | P1 | Delete item | Undo | Item restored at correct location |
| O-007 | Undo indent | P1 | Indent item | Undo | Item returns to prior level |
| O-008 | Undo outdent | P1 | Outdent item | Undo | Item returns to prior level |
| O-009 | Undo fold/unfold | P2 | Collapse or expand item | Undo | Fold state reverts |
| O-010 | Multiple sequential undos preserve document validity | P1 | Perform 5 mixed actions | Undo repeatedly | Tree remains valid and UI stable |

### P. HTML Export

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| P-001 | Export dialog opens from toolbar | P1 | Document open | Tap Export HTML | Theme chooser appears |
| P-002 | Export White theme | P2 | Export dialog open | Choose White | Share sheet opens with temp HTML file |
| P-003 | Export Black theme | P2 | Same | Choose Black | Share sheet opens |
| P-004 | Export Sepia theme | P2 | Same | Choose Sepia | Share sheet opens |
| P-005 | Export Gradient theme | P2 | Same | Choose Gradient | Share sheet opens |
| P-006 | Export after in-progress edit commits latest text | P1 | Editing item | Export HTML | Exported file reflects latest committed content |
| P-007 | Exported HTML preserves nesting and prefixes | P2 | Nested doc | Inspect exported file | Projects/tasks/notes render with expected structure |
| P-008 | Exported HTML escapes special characters | P2 | Content includes `<`, `>`, `&`, quotes | Export and inspect | HTML is escaped, not broken |

### Q. OPML Import

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| Q-001 | Import valid OPML from picker | P1 | Valid OPML file available | Import OPML | New `.taskpaper` file created in current directory |
| Q-002 | Imported file uses OPML title as suggested name | P2 | OPML with title | Import | New filename matches title when possible |
| Q-003 | Imported file name collision adds suffix | P2 | Existing file with same target name | Import same OPML twice | Second import gets numbered or alternate filename |
| Q-004 | OPML nested outlines map to projects with children | P1 | Valid nested OPML | Import and open | Parents become projects, leaves become tasks |
| Q-005 | Leaf-only outlines import as tasks | P2 | Simple OPML | Import and open | Leaves render as tasks |
| Q-006 | Invalid OPML shows import error alert | P1 | Invalid OPML/XML available | Import invalid file | Error alert shown; app does not crash |
| Q-007 | Import via pending open URL path | P2 | OPML routed from system open URL | Trigger import flow | App imports file correctly |

### R. Reminders Sync

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| R-001 | Sync with reminders permission denied | P1 | Deny reminders permission | Tap Sync Reminders | Banner reports access denied |
| R-002 | Sync with no due tasks | P1 | Document has no due-tagged tasks | Tap Sync Reminders | Banner says no tasks with due dates found |
| R-003 | Sync creates reminders for due tasks | P1 | Permission granted, due tasks exist | Tap Sync Reminders | Reminders created in Taskami calendar |
| R-004 | Sync updates existing reminders with same title | P2 | Existing reminders already synced | Change task, sync again | Matching reminder updates instead of duplicating where title matches |
| R-005 | Sync includes done status | P2 | Done task with due date | Sync and inspect reminder | Reminder marked completed |
| R-006 | Sync ignores tasks whose due value is not parseable as date | P2 | Task has invalid due value | Sync | Invalid due item is skipped safely |
| R-007 | Success banner appears then dismisses | P2 | Successful sync | Observe banner | Banner message visible then auto-hides |

### S. Settings and Preferences

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| S-001 | Open settings sheet | P1 | File browser visible | Tap gear | Settings sheet opens |
| S-002 | Dismiss settings with Done | P2 | Settings open | Tap Done | Sheet closes |
| S-003 | Toggle Dynamic Type | P2 | Settings open, document available | Enable setting and open document | Editor font scales larger |
| S-004 | Toggle Highlight Overdue Tasks | P2 | Due-tagged items exist | Toggle ON/OFF | Due tinting changes accordingly |
| S-005 | Toggle Autocorrection | P2 | Settings open | Change setting, return to edit mode | Behavior persists if wired in; note mismatch if no visible effect |
| S-006 | Toggle Add Date to `@done` | P1 | Settings open | Turn ON/OFF then toggle done in document | Done tag behavior follows setting |
| S-007 | Toggle Live Search | P2 | Settings open | Change setting and use search | Verify whether behavior changes; likely a candidate for dead-setting bug if no effect |
| S-008 | Change file sort preference in settings | P2 | Settings open | Change sort | File browser sort preference persists |
| S-009 | Toggle Show File Extensions | P2 | Settings open | Turn ON/OFF | File browser labels update accordingly |
| S-010 | Theme preset Light | P2 | Settings open | Set Light | Editor updates and setting persists |
| S-011 | Theme preset Dark | P2 | Settings open | Set Dark | Editor updates and setting persists |
| S-012 | Theme preset Sepia | P2 | Settings open | Set Sepia | Editor updates and setting persists |
| S-013 | Change font family | P2 | Font & Colors open | Select each font | Editor uses selected font |
| S-014 | Increase font size | P2 | Font & Colors open | Increase size | Editor text size increases |
| S-015 | Decrease font size | P2 | Font & Colors open | Decrease size | Editor text size decreases |
| S-016 | Change color picker values | P3 | Font & Colors open | Modify text/tag/background colors | Editor reflects selected colors |
| S-017 | Preferences persist after app relaunch | P1 | Several settings changed | Relaunch app | Settings remain saved |

### T. Biometric Lock

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| T-001 | Enable biometric lock | P2 | Device supports biometrics | Turn on setting | Preference saves successfully |
| T-002 | App shows lock screen when reopened and auth required | P1 | Lock enabled | Background and return | Lock screen appears when policy triggers |
| T-003 | Successful biometric unlock enters app | P1 | Lock screen shown | Authenticate successfully | App unlocks |
| T-004 | Failed biometric unlock remains locked | P1 | Lock screen shown | Fail/cancel auth | App remains locked |
| T-005 | Lock screen button label uses biometric type | P2 | Supported device | View lock screen | Button label matches Face ID/Touch ID/Optic ID/Biometric |
| T-006 | Lock prompt auto-starts on lock screen appear | P2 | Lock enabled | Reach lock screen | Authentication prompt appears automatically |

### U. External File Changes, Open URL, and Conflict-Adjacent Flows

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| U-001 | External disk change reloads document | P1 | Same file editable externally | Modify file on disk while open | Document reloads to current disk content |
| U-002 | Reload after external change clears unsaved flag behavior safely | P2 | Open file | Trigger reload | No crash; content reflects disk |
| U-003 | Open `.taskpaper` via system URL route | P2 | File-open routing setup available | Open file in app from Files/share sheet | App routes to target document |
| U-004 | Open `.opml` via system URL route | P2 | OPML route available | Open OPML in app | App routes into import flow |
| U-005 | Unsupported URL/file type is ignored safely | P3 | Non-file or unsupported file route | Trigger route | App remains stable |

### V. Accessibility and Interaction Semantics

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| V-001 | Task cell accessibility label includes status | P2 | Task visible | Inspect accessibility | Label reflects Task/Done plus content |
| V-002 | Project cell accessibility hint reflects collapsed state | P2 | Collapsible project visible | Inspect before/after collapse | Hint changes between collapsed and expanded |
| V-003 | Custom accessibility action marks task done | P2 | VoiceOver/accessibility actions available | Invoke custom action | Task toggles done |
| V-004 | Custom accessibility action collapses/expands project | P2 | Project with children | Invoke action | Fold state changes |
| V-005 | Dash tap does not also enter edit mode | P1 | Visible task | Tap dash | Done toggles only; keyboard does not open |
| V-006 | Disclosure tap does not also enter edit mode | P1 | Visible project with children | Tap disclosure | Fold toggles only; keyboard does not open |
| V-007 | Search and editor usable with larger Dynamic Type | P2 | Larger text size | Navigate, search, edit | Controls remain operable and readable |

### W. Large Document / Scroll / Reuse Stress

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| W-001 | Scroll large document from top to bottom | P1 | Large document open | Scroll repeatedly | No crash, blank cells, or stuck content |
| W-002 | Toggle done on off-top reused cells | P1 | Large document | Scroll, toggle, scroll back | Correct items retain correct states |
| W-003 | Edit reused cell after many scrolls | P1 | Large document | Scroll multiple screens and edit | Keyboard opens and right content is edited |
| W-004 | Collapse/expand repeatedly in large document | P2 | Large document with projects | Collapse and expand many items | UI remains stable |
| W-005 | Search in large document | P2 | Large document | Search common and rare term | Results are stable and responsive enough |

### X. Widget Data Behavior

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| X-001 | Editing document updates widget data for tasks due today | P2 | App group/widget capable environment | Add due-today task and trigger save | Today tasks are written for widget use |
| X-002 | Task due tomorrow is excluded from today widget set | P2 | Same | Add tomorrow due task | Task not included in today dataset |
| X-003 | Done state propagates to widget data | P2 | Due-today task exists | Toggle done and save | Stored widget task reflects done status |
| X-004 | Clean content for widget strips trailing tags | P3 | Due-today task with trailing tags | Inspect widget-fed output if accessible | User-facing content excludes trailing tags |

### Y. Cross-Feature Regression Scenarios

| ID | Title | Priority | Preconditions | Steps | Expected Result |
|---|---|---|---|---|---|
| Y-001 | Toggle done, then immediately tap another cell to edit | P0 | At least two visible tasks | Perform exact sequence | Second cell reliably enters edit mode |
| Y-002 | Edit, indent, toggle done, undo, redo | P1 | Editable task | Perform sequence | Document remains coherent and final state matches actions |
| Y-003 | Search active, edit matching item, clear search | P1 | Search results shown | Edit result and clear search | Change persists and list returns normally |
| Y-004 | Focus into project, edit child, focus out | P1 | Focusable project exists | Perform sequence | Edit persists and focus out succeeds |
| Y-005 | Collapse project, search child, toggle child done, clear search | P1 | Collapsible project with child task | Perform sequence | Child update persists; collapsed state remains sensible |
| Y-006 | Edit item, open export, cancel, continue editing | P2 | Editing item | Open export dialog, cancel | Editing remains stable |
| Y-007 | Edit item, open date picker, set date, then toggle done | P2 | Editing task | Perform sequence | Both date and done states save correctly |
| Y-008 | Change theme while document open and one cell editing | P1 | Open document, edit item | Open settings and change theme | No crash; display updates safely |
| Y-009 | Drag item after multiple done toggles and scrolls | P2 | Large document | Toggle several items, scroll, drag item | Reorder still works |
| Y-010 | Background app during active edit, return, continue | P1 | Editing item | Background and foreground | App remains stable, edit state is sane, no data loss |

---

## Recommended Smoke Suite

If QA needs a short daily regression pack, run these first:

1. `A-001`, `A-003`, `B-006`, `C-003`
2. `D-001`, `D-005`, `D-009`
3. `F-001`, `F-004`, `F-006`
4. `G-001`, `G-002`
5. `I-001`, `I-006`, `I-009`
6. `J-001`, `J-003`
7. `L-001`, `L-005`
8. `O-001`, `O-003`
9. `Q-001`
10. `Y-001`, `Y-003`, `Y-004`

## Suggested Defect Logging Notes

When filing bugs against this app, always capture:

- file name used
- whether search was active
- whether focus mode was active
- whether the item was collapsed or inside collapsed subtree before action
- whether keyboard was visible
- whether free-scroll was enabled
- whether issue occurred after scrolling
- whether issue reproduces only on second or later item
- whether data was visually wrong, model wrong, or both

This will help engineering narrow down whether the bug is in model mutation, snapshot refresh, cell reuse, or persistence.
