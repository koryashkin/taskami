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
    private var highlighter: TaskPaperTextHighlighter?

    override init() {
        textView = UITextView()
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 8)
        textView.textContainer.lineFragmentPadding = 0
        textView.autocorrectionType = .default
        textView.autocapitalizationType = .sentences
        textView.returnKeyType = .default
        super.init()
        textView.delegate = self
    }

    /// Show the field editor overlaid on a cell.
    func beginEditing(item: TaskItem, in cell: TaskItemCell, highlighter: TaskPaperTextHighlighter) {
        self.editingItem = item
        self.highlighter = highlighter

        textView.text = item.content
        textView.font = highlighter.theme.font
        textView.textColor = highlighter.theme.textColor
        textView.backgroundColor = highlighter.theme.backgroundColor
        textView.tintColor = highlighter.theme.cursorColor

        // Position the text view over the cell's content area
        textView.frame = cell.contentView.bounds
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        cell.contentView.addSubview(textView)
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

    /// Dismiss without committing.
    func dismiss() {
        textView.resignFirstResponder()
        textView.removeFromSuperview()
        editingItem = nil
    }

    // MARK: - UITextViewDelegate

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard let item = editingItem else { return true }

        // Return key: commit current item and create new one
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
