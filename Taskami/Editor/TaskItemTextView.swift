import UIKit

/// UITextView subclass that adds hardware-keyboard navigation for the TaskPaper editor:
/// - Tab            → indent item
/// - Shift+Tab      → outdent item
/// - Up arrow       → move focus to the previous item (when cursor is on the first line)
/// - Down arrow     → move focus to the next item (when cursor is on the last line)
final class TaskItemTextView: UITextView {

    var onIndent: (() -> Void)?
    var onOutdent: (() -> Void)?
    var onNavigatePrevious: (() -> Void)?
    var onNavigateNext: (() -> Void)?

    // MARK: - Key commands

    override var keyCommands: [UIKeyCommand]? {
        var commands = super.keyCommands ?? []

        // Tab → indent
        commands.append(UIKeyCommand(
            input: "\t",
            modifierFlags: [],
            action: #selector(handleTab)
        ))

        // Shift+Tab → outdent
        commands.append(UIKeyCommand(
            input: "\t",
            modifierFlags: .shift,
            action: #selector(handleShiftTab)
        ))

        // Up arrow
        commands.append(UIKeyCommand(
            input: UIKeyCommand.inputUpArrow,
            modifierFlags: [],
            action: #selector(handleUpArrow)
        ))

        // Down arrow
        commands.append(UIKeyCommand(
            input: UIKeyCommand.inputDownArrow,
            modifierFlags: [],
            action: #selector(handleDownArrow)
        ))

        return commands
    }

    // MARK: - Handlers

    @objc private func handleTab() {
        onIndent?()
    }

    @objc private func handleShiftTab() {
        onOutdent?()
    }

    @objc private func handleUpArrow() {
        // Only navigate to the previous item when the cursor is already on the first line.
        if isCursorOnFirstLine {
            onNavigatePrevious?()
        } else {
            // Let the default behaviour move the cursor up within the text.
            moveCursorUp()
        }
    }

    @objc private func handleDownArrow() {
        if isCursorOnLastLine {
            onNavigateNext?()
        } else {
            moveCursorDown()
        }
    }

    // MARK: - Cursor helpers

    private var isCursorOnFirstLine: Bool {
        guard let selectedRange = selectedTextRange else { return true }
        let cursorOffset = offset(from: beginningOfDocument, to: selectedRange.start)
        // The cursor is on the first line if there is no newline before it
        let beforeCursor = text.prefix(cursorOffset)
        return !beforeCursor.contains("\n")
    }

    private var isCursorOnLastLine: Bool {
        guard let selectedRange = selectedTextRange else { return true }
        let cursorOffset = offset(from: beginningOfDocument, to: selectedRange.end)
        let afterCursor = text.dropFirst(cursorOffset)
        return !afterCursor.contains("\n")
    }

    private func moveCursorUp() {
        guard let range = selectedTextRange,
              let newPos = tokenizer.position(
                from: range.start,
                toBoundary: .line,
                inDirection: UITextDirection(rawValue: UITextStorageDirection.backward.rawValue)
              ),
              let lineStart = tokenizer.position(
                from: newPos,
                toBoundary: .line,
                inDirection: UITextDirection(rawValue: UITextStorageDirection.backward.rawValue)
              )
        else { return }
        selectedTextRange = textRange(from: lineStart, to: lineStart)
    }

    private func moveCursorDown() {
        guard let range = selectedTextRange,
              let lineEnd = tokenizer.position(
                from: range.end,
                toBoundary: .line,
                inDirection: UITextDirection(rawValue: UITextStorageDirection.forward.rawValue)
              ),
              let newPos = position(from: lineEnd, offset: 1)
        else { return }
        selectedTextRange = textRange(from: newPos, to: newPos)
    }
}
