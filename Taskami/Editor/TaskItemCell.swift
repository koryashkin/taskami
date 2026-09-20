import UIKit
import OSLog

private let log = Logger(subsystem: "com.taskami", category: "Cell")

enum NavigationDirection { case previous, next }

protocol TaskItemCellDelegate: AnyObject {
    func cellDidCommit(_ cell: TaskItemCell, newContent: String)
    func cellDidRequestNewItem(after cell: TaskItemCell)
    func cellDidRequestDelete(_ cell: TaskItemCell)
    func cellDidRequestIndent(_ cell: TaskItemCell)
    func cellDidRequestOutdent(_ cell: TaskItemCell)
    func cellDidChange(_ cell: TaskItemCell, content: String)
    func cellDidRequestNavigate(_ cell: TaskItemCell, direction: NavigationDirection)
    /// Called after the cell has already toggled the item and updated its own display.
    /// The delegate should only handle undo registration and autosave — NOT call reconfigureItem.
    func cellDidToggleDone(_ cell: TaskItemCell, oldContent: String)
    /// Called when the cell exits edit mode without committing (e.g. scrolled off-screen and reused).
    func cellDidDismissEditing(_ cell: TaskItemCell)
    /// Called when the user taps the disclosure triangle to fold/unfold children.
    func cellDidToggleFold(_ cell: TaskItemCell)
}

final class TaskItemCell: UICollectionViewCell {

    weak var delegate: TaskItemCellDelegate?

    // The single UITextView serves dual purpose: display (non-editable attributed) and edit (editable plain)
    private let textView = TaskItemTextView()
    // UIButton absorbs its own tap so the collection view does NOT also fire didSelectItemAt,
    // which would otherwise open edit mode immediately after toggling done.
    private let dashButton = UIButton(type: .custom)
    // Same absorption pattern as dashButton — prevents didSelectItemAt from firing on fold tap.
    private let disclosureButton = UIButton(type: .custom)
    private var indentLeadingConstraint: NSLayoutConstraint!
    private var dashWidthConstraint: NSLayoutConstraint!
    private var disclosureWidthConstraint: NSLayoutConstraint!

    private(set) var item: TaskItem?
    private var highlighter: TaskPaperTextHighlighter?
    private(set) var isInEditMode = false
    /// Mirrors DocumentEditorViewController.addDateToDone — set via configure(with:highlighter:addDateToDone:).
    private var addDateToDone: Bool = true
    private var autocorrectionEnabled: Bool = true

    /// The live text content while editing (for accessory actions that need it mid-edit).
    var textViewCurrentContent: String { textView.text ?? "" }

    /// Exposes the textView to the VC for cursor movement accessory buttons.
    var editingTextView: UITextView? { isInEditMode ? textView : nil }

    /// The textView's frame in the cell's coordinate space (for tap-to-cursor conversion).
    var textViewFrame: CGRect { textView.frame }

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

        dashButton.translatesAutoresizingMaskIntoConstraints = false
        dashButton.setContentHuggingPriority(.required, for: .horizontal)
        dashButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        // UIButton(type: .custom) has zero content insets by default — no configuration
        // needed. Using UIButton.Configuration alongside setAttributedTitle is unsupported
        // on iOS 15+ and causes the button to stop responding after a few taps.
        dashButton.addTarget(self, action: #selector(dashTapped), for: .touchUpInside)

        disclosureButton.translatesAutoresizingMaskIntoConstraints = false
        disclosureButton.setContentHuggingPriority(.required, for: .horizontal)
        disclosureButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        disclosureButton.addTarget(self, action: #selector(disclosureTapped), for: .touchUpInside)

        contentView.addSubview(disclosureButton)
        contentView.addSubview(dashButton)
        contentView.addSubview(textView)

        // disclosureButton anchors at the indent position; dashButton and textView follow it.
        indentLeadingConstraint = disclosureButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        disclosureWidthConstraint = disclosureButton.widthAnchor.constraint(equalToConstant: 0)
        dashWidthConstraint = dashButton.widthAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            indentLeadingConstraint,
            disclosureWidthConstraint,
            disclosureButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),

            dashButton.leadingAnchor.constraint(equalTo: disclosureButton.trailingAnchor),
            dashButton.topAnchor.constraint(equalTo: contentView.topAnchor),
            dashButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            textView.leadingAnchor.constraint(equalTo: dashButton.trailingAnchor),
            textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            textView.topAnchor.constraint(equalTo: contentView.topAnchor),
            textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    // MARK: - Configure (display mode)

    func configure(
        with item: TaskItem,
        highlighter: TaskPaperTextHighlighter,
        addDateToDone: Bool = true,
        autocorrectionEnabled: Bool = true
    ) {
        self.addDateToDone = addDateToDone
        self.autocorrectionEnabled = autocorrectionEnabled
        log.debug("configure: '\(item.content.prefix(30))' editMode=\(self.isInEditMode)")
        self.item = item
        self.highlighter = highlighter
        accessibilityIdentifier = "item-\(item.id.uuidString)"
        updateAccessibility(for: item)

        let indentOffset = CGFloat(item.indentLevel) * highlighter.theme.indentWidth + 16
        indentLeadingConstraint.constant = indentOffset

        let isTask = item.type == .task
        dashButton.isHidden = !isTask
        if isTask {
            let color = item.isDone ? highlighter.theme.doneColor.uiColor : highlighter.theme.taskColor.uiColor
            let attrs: [NSAttributedString.Key: Any] = [.font: highlighter.theme.font, .foregroundColor: color]
            dashButton.setAttributedTitle(NSAttributedString(string: "-", attributes: attrs), for: .normal)
            dashWidthConstraint.constant = 44
            dashWidthConstraint.isActive = true
            // Accessibility: stable ID + value so UI tests can find and verify the button
            dashButton.accessibilityIdentifier = "dash-\(item.id.uuidString)"
            dashButton.accessibilityValue = item.isDone ? "done" : "undone"
        } else {
            dashWidthConstraint.constant = 0
            dashWidthConstraint.isActive = true
        }

        let hasChildren = !item.children.isEmpty
        disclosureButton.isHidden = !hasChildren
        if hasChildren {
            disclosureWidthConstraint.constant = 20
            let symbolName = item.isCollapsed ? "chevron.right" : "chevron.down"
            let config = UIImage.SymbolConfiguration(pointSize: highlighter.theme.font.pointSize * 0.65, weight: .medium)
            disclosureButton.setImage(UIImage(systemName: symbolName, withConfiguration: config), for: .normal)
            disclosureButton.tintColor = highlighter.theme.textColor.uiColor.withAlphaComponent(0.45)
            disclosureButton.accessibilityIdentifier = "disclosure-\(item.id.uuidString)"
            disclosureButton.accessibilityValue = item.isCollapsed ? "collapsed" : "expanded"
        } else {
            disclosureWidthConstraint.constant = 0
        }

        // Only update display if not currently editing
        if !isInEditMode {
            textView.attributedText = highlighter.highlight(item)
            contentView.backgroundColor = highlighter.cellBackgroundColor(for: item)
        } else {
            log.debug("configure: skipping display update — cell is in edit mode")
        }
    }

    // MARK: - Accessibility

    private func updateAccessibility(for item: TaskItem) {
        isAccessibilityElement = true
        // Keep subviews out of the VoiceOver focus order — their actions are
        // exposed via UIAccessibilityCustomAction below.
        dashButton.isAccessibilityElement = false
        disclosureButton.isAccessibilityElement = false

        // Raw content exposed as value so UI tests can check for tags like @done.
        accessibilityValue = item.content

        switch item.type {
        case .project:
            accessibilityLabel = item.content
            let tasks = item.allDescendants.filter { $0.type == .task }
            if !tasks.isEmpty {
                let done = tasks.filter(\.isDone).count
                accessibilityValue = "\(done) of \(tasks.count) tasks done"
            }
            accessibilityTraits = [.header]
            accessibilityHint = item.children.isEmpty ? nil
                : (item.isCollapsed ? "Collapsed. Double-tap to expand." : "Expanded. Double-tap to collapse.")
        case .task:
            let status = item.isDone ? "Done" : "Task"
            accessibilityLabel = "\(status): \(item.content)"
            accessibilityTraits = item.isDone ? [.notEnabled] : []
            accessibilityHint = "Double-tap to edit."
        case .note:
            accessibilityLabel = item.content
            accessibilityTraits = [.staticText]
            accessibilityHint = "Double-tap to edit."
        }

        var actions: [UIAccessibilityCustomAction] = []
        if item.type == .task {
            let title = item.isDone ? "Mark as not done" : "Mark as done"
            actions.append(UIAccessibilityCustomAction(name: title) { [weak self] _ in
                self?.dashTapped()
                return true
            })
        }
        if !item.children.isEmpty {
            let title = item.isCollapsed ? "Expand" : "Collapse"
            actions.append(UIAccessibilityCustomAction(name: title) { [weak self] _ in
                self?.disclosureTapped()
                return true
            })
        }
        accessibilityCustomActions = actions.isEmpty ? nil : actions
    }

    // MARK: - Edit mode

    func beginEditing(inputAccessoryView: UIView?) {
        guard let item, let highlighter, !isInEditMode else {
            log.debug("beginEditing skipped: isInEditMode=\(self.isInEditMode) hasItem=\(self.item != nil)")
            return
        }
        log.debug("beginEditing: '\(item.content.prefix(40))'")

        isInEditMode = true

        // Re-enable interaction so the textView can become first responder
        textView.isUserInteractionEnabled = true
        // Switch to plain text for editing
        textView.attributedText = nil
        textView.text = item.content
        textView.font = highlighter.theme.font
        textView.textColor = highlighter.theme.textColor.uiColor
        textView.tintColor = highlighter.theme.cursorColor.uiColor
        textView.autocorrectionType = autocorrectionEnabled ? .default : .no
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

    /// Place the cursor at the closest text position to `pointInTextView`.
    /// Call after `beginEditing` so the text view is in edit mode.
    func placeCursor(at pointInTextView: CGPoint) {
        guard isInEditMode,
              let position = textView.closestPosition(to: pointInTextView) else { return }
        log.debug("placeCursor at (\(pointInTextView.x), \(pointInTextView.y))")
        textView.selectedTextRange = textView.textRange(from: position, to: position)
    }

    func commitEditing() {
        guard isInEditMode else { return }
        let newContent = textView.text ?? ""
        log.debug("commitEditing: '\(newContent.prefix(40))'")
        endEditMode()
        delegate?.cellDidCommit(self, newContent: newContent)
    }

    func dismissEditing() {
        guard isInEditMode else { return }
        endEditMode()
        delegate?.cellDidDismissEditing(self)
    }

    private func endEditMode() {
        log.debug("endEditMode: '\((self.item?.content ?? "").prefix(30))'")
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
            contentView.backgroundColor = highlighter.cellBackgroundColor(for: item)
        } else {
            log.warning("endEditMode: no item or highlighter — cell will show blank")
        }
    }

    @objc func disclosureTapped() {
        delegate?.cellDidToggleFold(self)
        // Announce the new fold state to VoiceOver after the delegate has toggled it.
        if UIAccessibility.isVoiceOverRunning, let item {
            let announcement = item.isCollapsed ? "Collapsed" : "Expanded"
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
    }

    @objc func dashTapped() {
        guard let item, let highlighter else { return }
        // Toggle the model and update our own display immediately — no round-trip
        // through cellForItem(at:) which can race with UICollectionView layout passes.
        let oldContent = item.content
        item.toggleDone(addDate: addDateToDone)
        configure(
            with: item,
            highlighter: highlighter,
            addDateToDone: addDateToDone,
            autocorrectionEnabled: autocorrectionEnabled
        )
        delegate?.cellDidToggleDone(self, oldContent: oldContent)
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: item.isDone ? "Done" : "Not done")
        }
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        log.debug("prepareForReuse: '\((self.item?.content ?? "").prefix(30))' editMode=\(self.isInEditMode)")
        // Never reuse a cell mid-edit
        if isInEditMode { dismissEditing() }
        textView.attributedText = nil
        dashWidthConstraint.constant = 0
        dashWidthConstraint.isActive = true
        dashButton.isHidden = false
        disclosureWidthConstraint.constant = 0
        disclosureButton.isHidden = false
        disclosureButton.setImage(nil, for: .normal)
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
        let oldHeight = layoutAttributes.frame.size.height
        let newHeight = max(size.height, 32)
        attributes.frame.size.height = newHeight
        if abs(oldHeight - newHeight) > 1 {
            log.debug("preferredLayoutAttributesFitting: '\((self.item?.content ?? "").prefix(20))' height \(oldHeight) → \(newHeight) editMode=\(self.isInEditMode)")
        }
        return attributes
    }
}

// MARK: - UITextViewDelegate

extension TaskItemCell: UITextViewDelegate {

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // Return key → commit + new item below
        if text == "\n" {
            let current = textView.text ?? ""
            log.debug("shouldChangeText: Return key → new item after '\(current.prefix(30))'")
            // Apply the same type detection used in cellDidCommit so that
            // "Project Name:" pressed Return is saved as a project, not a task.
            let trimmed = current.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix(":"), let item {
                item.type = .project
                item.content = String(trimmed.dropLast()).trimmingCharacters(in: .whitespaces)
            } else {
                item?.content = current
            }
            item?.tags = TagParser.parseTags(in: item?.content ?? "")
            delegate?.cellDidRequestNewItem(after: self)
            return false
        }

        // Backspace at beginning of empty line → delete item
        if text == "" && range.location == 0 && range.length == 0 && (textView.text ?? "").isEmpty {
            log.debug("shouldChangeText: Backspace on empty → delete item")
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
        log.debug("textViewDidEndEditing → commitEditing")
        commitEditing()
    }
}
