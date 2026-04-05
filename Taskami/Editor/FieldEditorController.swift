import UIKit

protocol FieldEditorDelegate: AnyObject {
    func fieldEditorDidCommit(item: TaskItem, newContent: String)
    func fieldEditorDidRequestNewItem(after item: TaskItem)
    func fieldEditorDidRequestIndent(item: TaskItem)
    func fieldEditorDidRequestOutdent(item: TaskItem)
    func fieldEditorDidRequestDelete(item: TaskItem)
    func fieldEditorDidChange(item: TaskItem)
}

final class FieldEditorController: NSObject, UITextViewDelegate {
    let textView: UITextView
    weak var delegate: FieldEditorDelegate?

    private(set) var editingItem: TaskItem?
    private var activeConstraints: [NSLayoutConstraint] = []

    override init() {
        textView = UITextView()
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 8)
        textView.textContainer.lineFragmentPadding = 0
        textView.autocorrectionType = .default
        textView.autocapitalizationType = .sentences
        textView.returnKeyType = .default
        // Must be false so we can use AutoLayout constraints on the overlay
        textView.translatesAutoresizingMaskIntoConstraints = false
        super.init()
        textView.delegate = self
    }

    /// Show the field editor overlaid on a cell using constraints (not autoresizingMask).
    func beginEditing(item: TaskItem, in cell: TaskItemCell, highlighter: TaskPaperTextHighlighter) {
        // Dismiss any existing editor first
        if textView.superview != nil {
            dismiss()
        }

        editingItem = item

        textView.text = item.content
        textView.font = highlighter.theme.font
        textView.textColor = highlighter.theme.textColor.uiColor
        textView.backgroundColor = highlighter.theme.backgroundColor.uiColor
        textView.tintColor = highlighter.theme.cursorColor.uiColor

        cell.contentView.addSubview(textView)

        // Pin the field editor to cover the cell's content area exactly
        activeConstraints = [
            textView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
            textView.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
            textView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
        ]
        NSLayoutConstraint.activate(activeConstraints)

        textView.becomeFirstResponder()
    }

    /// Commit changes and dismiss.
    func commit() {
        guard let item = editingItem else { return }
        let newContent = textView.text ?? ""

        item.content = newContent
        item.tags = TagParser.parseTags(in: newContent)

        delegate?.fieldEditorDidCommit(item: item, newContent: newContent)
        dismiss()
    }

    /// Dismiss without saving changes.
    func dismiss() {
        NSLayoutConstraint.deactivate(activeConstraints)
        activeConstraints = []
        textView.resignFirstResponder()
        textView.removeFromSuperview()
        editingItem = nil
    }

    // MARK: - UITextViewDelegate

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard let item = editingItem else { return true }

        // Return key: commit current line and request a new item below it
        if text == "\n" {
            let currentContent = textView.text ?? ""
            item.content = currentContent
            item.tags = TagParser.parseTags(in: currentContent)
            delegate?.fieldEditorDidCommit(item: item, newContent: currentContent)
            delegate?.fieldEditorDidRequestNewItem(after: item)
            return false
        }

        return true
    }

    func textViewDidChange(_ textView: UITextView) {
        guard let item = editingItem else { return }
        delegate?.fieldEditorDidChange(item: item)
    }
}
