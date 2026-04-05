import UIKit

enum NavigationDirection { case previous, next }

protocol TaskItemCellDelegate: AnyObject {
    func cellDidCommit(_ cell: TaskItemCell, newContent: String)
    func cellDidRequestNewItem(after cell: TaskItemCell)
    func cellDidRequestDelete(_ cell: TaskItemCell)
    func cellDidRequestIndent(_ cell: TaskItemCell)
    func cellDidRequestOutdent(_ cell: TaskItemCell)
    func cellDidChange(_ cell: TaskItemCell, content: String)
    func cellDidRequestNavigate(_ cell: TaskItemCell, direction: NavigationDirection)
}

final class TaskItemCell: UICollectionViewCell {

    weak var delegate: TaskItemCellDelegate?

    // The single UITextView serves dual purpose: display (non-editable attributed) and edit (editable plain)
    private let textView = TaskItemTextView()
    private let dashLabel = UILabel()
    private var indentLeadingConstraint: NSLayoutConstraint!
    private var dashWidthConstraint: NSLayoutConstraint!

    private(set) var item: TaskItem?
    private var highlighter: TaskPaperTextHighlighter?
    private(set) var isInEditMode = false

    /// The live text content while editing (for accessory actions that need it mid-edit).
    var textViewCurrentContent: String { textView.text ?? "" }

    /// Exposes the textView to the VC for cursor movement accessory buttons.
    var editingTextView: UITextView? { isInEditMode ? textView : nil }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        // textView — shared for display and editing.
        // User interaction is OFF in display mode so taps reach the collection view
        // (didSelectItemAt) rather than being absorbed by the UITextView.
        textView.isEditable = false
        textView.isSelectable = false
        textView.isScrollEnabled = false
        textView.isUserInteractionEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 8)
        textView.textContainer.lineFragmentPadding = 0
        textView.backgroundColor = .clear
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = self

        dashLabel.text = "- "
        dashLabel.translatesAutoresizingMaskIntoConstraints = false
        dashLabel.setContentHuggingPriority(.required, for: .horizontal)
        dashLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        contentView.addSubview(dashLabel)
        contentView.addSubview(textView)

        indentLeadingConstraint = dashLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        dashWidthConstraint = dashLabel.widthAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            indentLeadingConstraint,
            dashLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),

            textView.leadingAnchor.constraint(equalTo: dashLabel.trailingAnchor),
            textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            textView.topAnchor.constraint(equalTo: contentView.topAnchor),
            textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    // MARK: - Configure (display mode)

    func configure(with item: TaskItem, highlighter: TaskPaperTextHighlighter) {
        self.item = item
        self.highlighter = highlighter

        let indentOffset = CGFloat(item.indentLevel) * highlighter.theme.indentWidth + 16
        indentLeadingConstraint.constant = indentOffset

        let isTask = item.type == .task
        dashLabel.isHidden = !isTask
        if isTask {
            dashLabel.text = "- "
            dashLabel.font = highlighter.theme.font
            dashLabel.textColor = item.isDone
                ? highlighter.theme.doneColor.uiColor
                : highlighter.theme.taskColor.uiColor
            dashWidthConstraint.isActive = false
        } else {
            dashWidthConstraint.isActive = true
        }

        // Only update display if not currently editing
        if !isInEditMode {
            textView.attributedText = highlighter.highlight(item)
            contentView.backgroundColor = highlighter.theme.backgroundColor.uiColor
        }
    }

    // MARK: - Edit mode

    func beginEditing(inputAccessoryView: UIView?) {
        guard let item, let highlighter, !isInEditMode else { return }
        isInEditMode = true

        // Re-enable interaction so the textView can become first responder
        textView.isUserInteractionEnabled = true
        // Switch to plain text for editing
        textView.attributedText = nil
        textView.text = item.content
        textView.font = highlighter.theme.font
        textView.textColor = highlighter.theme.textColor.uiColor
        textView.tintColor = highlighter.theme.cursorColor.uiColor
        textView.autocorrectionType = .default
        textView.autocapitalizationType = .sentences
        textView.isEditable = true
        textView.isSelectable = true
        textView.inputAccessoryView = inputAccessoryView

        // Hardware keyboard navigation
        textView.onIndent  = { [weak self] in guard let self else { return }; delegate?.cellDidRequestIndent(self) }
        textView.onOutdent = { [weak self] in guard let self else { return }; delegate?.cellDidRequestOutdent(self) }
        textView.onNavigatePrevious = { [weak self] in guard let self else { return }; delegate?.cellDidRequestNavigate(self, direction: .previous) }
        textView.onNavigateNext     = { [weak self] in guard let self else { return }; delegate?.cellDidRequestNavigate(self, direction: .next) }

        textView.becomeFirstResponder()
        // Place cursor at end
        textView.selectedRange = NSRange(location: textView.text.utf16.count, length: 0)
    }

    func commitEditing() {
        guard isInEditMode else { return }
        let newContent = textView.text ?? ""
        endEditMode()
        delegate?.cellDidCommit(self, newContent: newContent)
    }

    func dismissEditing() {
        guard isInEditMode else { return }
        endEditMode()
    }

    private func endEditMode() {
        isInEditMode = false
        textView.isEditable = false
        textView.isSelectable = false
        textView.isUserInteractionEnabled = false
        textView.onIndent = nil
        textView.onOutdent = nil
        textView.onNavigatePrevious = nil
        textView.onNavigateNext = nil
        textView.resignFirstResponder()
        // Restore attributed display
        if let item, let highlighter {
            textView.attributedText = highlighter.highlight(item)
            contentView.backgroundColor = highlighter.theme.backgroundColor.uiColor
        }
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        // Never reuse a cell mid-edit
        if isInEditMode { dismissEditing() }
        textView.attributedText = nil
        dashWidthConstraint.isActive = false
        dashLabel.isHidden = false
        item = nil
        delegate = nil
        highlighter = nil
    }

    // MARK: - Self-sizing

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        let attributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        let targetSize = CGSize(width: layoutAttributes.frame.width, height: UIView.layoutFittingCompressedSize.height)
        let size = contentView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        attributes.frame.size.height = max(size.height, 32)
        return attributes
    }
}

// MARK: - UITextViewDelegate

extension TaskItemCell: UITextViewDelegate {

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // Return key → commit + new item below
        if text == "\n" {
            let current = textView.text ?? ""
            item?.content = current
            item?.tags = TagParser.parseTags(in: current)
            delegate?.cellDidRequestNewItem(after: self)
            return false
        }

        // Backspace at beginning of empty line → delete item
        if text == "" && range.location == 0 && range.length == 0 && (textView.text ?? "").isEmpty {
            delegate?.cellDidRequestDelete(self)
            return false
        }

        return true
    }

    func textViewDidChange(_ textView: UITextView) {
        delegate?.cellDidChange(self, content: textView.text ?? "")
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        // Commit when focus leaves (e.g. user taps another cell or dismisses keyboard)
        guard isInEditMode else { return }
        commitEditing()
    }
}
