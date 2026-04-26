import UIKit
import OSLog

private let log = Logger(subsystem: "com.taskami", category: "Editor")

final class DocumentEditorViewController: UIViewController {

    private(set) var document: TaskDocument?
    /// Raw search text; changing it recompiles the filter and refreshes the snapshot.
    var searchText: String = "" {
        didSet {
            guard oldValue != searchText, isViewLoaded else { return }
            applySnapshot(animated: false)
        }
    }
    var theme: EditorTheme = .light {
        didSet {
            guard oldValue != theme else { return }
            applyTheme()
        }
    }
    /// Whether to append today's date to @done when toggling an item done.
    /// Mirrors AppPreferences.addDateToDone — updated by DocumentEditorView.updateUIViewController.
    var addDateToDone: Bool = true
    var onDocumentChanged: (() -> Void)?
    /// Called whenever fold state changes (toggle or undo/redo) so the host can persist it.
    var onFoldStateChanged: (() -> Void)?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, UUID>!

    private let dragDropHandler = EditorDragDropHandler()
    private let keyboardAccessory = EditorKeyboardAccessoryView()
    private let docUndoManager = DocumentUndoManager()
    private let focusBreadcrumb = FocusBreadcrumbView()

    /// The item whose subtree is currently shown exclusively (Focus In).
    private(set) var focusedItem: TaskItem?
    /// Stack of previously focused items, used to step back out through multiple levels.
    private var focusStack: [TaskItem] = []

    /// The cell currently in edit mode (at most one at a time).
    private weak var editingCell: TaskItemCell?

    /// Prevents nested dataSource.apply calls (e.g. when a UITextView delegate callback
    /// fires during an existing apply). Nested calls are deferred one run loop tick.
    private var isApplyingSnapshot = false

    /// When true the keyboard stays visible while the user scrolls (keyboardDismissMode = .none).
    private var isFreeScrollActive = false

    /// Tracks scroll position for unexpected-jump detection in scrollViewDidScroll.
    private var lastKnownContentOffset: CGFloat = 0

    /// Location (in collectionView coordinates) of the most recent tap that initiated
    /// an edit. Used to place the cursor where the user tapped rather than at the end.
    private var pendingTapLocation: (itemID: UUID, point: CGPoint)?

    private var highlighter: TaskPaperTextHighlighter {
        TaskPaperTextHighlighter(theme: theme)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupDataSource()
        setupDragDrop()
        setupKeyboardAccessory()
        setupKeyboardObservers()
        setupUndoRedoObservers()
        setupFocusBreadcrumb()
        applyTheme()
        applySnapshot(animated: false)
    }

    func setDocument(_ document: TaskDocument) {
        self.document = document
        if isViewLoaded {
            applySnapshot(animated: false)
        }
    }

    // MARK: - Setup

    private func setupCollectionView() {
        var config = UICollectionLayoutListConfiguration(appearance: .plain)
        config.showsSeparators = false
        config.backgroundColor = .clear

        config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self, let item = self.item(at: indexPath) else { return nil }
            // Disable swipe actions while editing — the interactive keyboard dismiss pan
            // can look like a swipe, causing unintended Done/Delete triggers.
            guard self.editingCell == nil else { return nil }

            let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { _, _, completion in
                self.deleteItem(item)
                completion(true)
            }
            deleteAction.image = UIImage(systemName: "trash")

            let doneAction = UIContextualAction(style: .normal, title: item.isDone ? "Undone" : "Done") { _, _, completion in
                self.toggleDone(item)
                completion(true)
            }
            doneAction.backgroundColor = .systemGreen
            doneAction.image = UIImage(systemName: item.isDone ? "arrow.uturn.backward" : "checkmark")

            return UISwipeActionsConfiguration(actions: [deleteAction, doneAction])
        }

        config.leadingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self, let item = self.item(at: indexPath) else { return nil }
            guard self.editingCell == nil, !item.children.isEmpty else { return nil }
            let focusAction = UIContextualAction(style: .normal, title: "Focus") { _, _, completion in
                self.focusIn(item: item)
                completion(true)
            }
            focusAction.backgroundColor = .systemIndigo
            focusAction.image = UIImage(systemName: "scope")
            return UISwipeActionsConfiguration(actions: [focusAction])
        }

        let layout = UICollectionViewCompositionalLayout.list(using: config)
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .clear
        collectionView.delegate = self   // also serves as UIScrollViewDelegate
        collectionView.keyboardDismissMode = .interactive
        view.addSubview(collectionView)
    }

    private func setupDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<TaskItemCell, UUID> { [weak self] cell, _, itemID in
            guard let self, let item = self.document?.item(withID: itemID) else { return }
            cell.configure(with: item, highlighter: self.highlighter, addDateToDone: self.addDateToDone)
            cell.delegate = self
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, itemID in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: itemID)
        }
    }

    private func setupDragDrop() {
        dragDropHandler.editorVC = self
        collectionView.dragDelegate = dragDropHandler
        collectionView.dropDelegate = dragDropHandler
        collectionView.dragInteractionEnabled = true
    }

    private func setupKeyboardAccessory() {
        keyboardAccessory.delegate = self
    }

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil
        )
    }

    private func setupFocusBreadcrumb() {
        focusBreadcrumb.translatesAutoresizingMaskIntoConstraints = false
        focusBreadcrumb.isHidden = true
        focusBreadcrumb.onFocusOut = { [weak self] in self?.focusOut() }
        view.addSubview(focusBreadcrumb)
        NSLayoutConstraint.activate([
            focusBreadcrumb.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            focusBreadcrumb.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            focusBreadcrumb.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    // MARK: - Focus In / Out

    func focusIn(item: TaskItem) {
        guard !item.children.isEmpty else { return }
        commitCurrentEdit()
        if let current = focusedItem {
            focusStack.append(current)
        }
        focusedItem = item
        updateFocusBreadcrumb(animated: true)
        applySnapshot(animated: true)
    }

    func focusOut() {
        commitCurrentEdit()
        focusedItem = focusStack.popLast()
        updateFocusBreadcrumb(animated: true)
        applySnapshot(animated: true)
    }

    private func updateFocusBreadcrumb(animated: Bool) {
        let isFocused = focusedItem != nil
        if let item = focusedItem {
            let parts = item.ancestors.reversed().map(\.content) + [item.content]
            focusBreadcrumb.setPath(parts)
        }
        let inset: CGFloat = isFocused ? 44 : 0
        let update = {
            self.focusBreadcrumb.isHidden = !isFocused
            self.collectionView.contentInset.top = inset
            self.collectionView.verticalScrollIndicatorInsets.top = inset
        }
        if animated {
            UIView.animate(withDuration: 0.25, animations: update)
        } else {
            update()
        }
    }

    private func setupUndoRedoObservers() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(undoRedoDidHappen),
            name: .NSUndoManagerDidUndoChange, object: docUndoManager.undoManager
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(undoRedoDidHappen),
            name: .NSUndoManagerDidRedoChange, object: docUndoManager.undoManager
        )
    }

    @objc private func undoRedoDidHappen() {
        applySnapshot(animated: false)
        onFoldStateChanged?()
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curveRaw = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 0
        let inset = frame.height - view.safeAreaInsets.bottom
        let offsetBefore = collectionView.contentOffset.y
        log.debug("keyboardWillShow: frame=\(frame.height) inset=\(inset) duration=\(duration) offsetBefore=\(offsetBefore)")
        // Disable drag-to-reorder while editing — the interactive keyboard dismiss pan
        // gesture would otherwise be misinterpreted as a drop operation.
        collectionView.dragInteractionEnabled = false
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: UIView.AnimationOptions(rawValue: curveRaw << 16),
            animations: {
                self.collectionView.contentInset.bottom = inset
                self.collectionView.verticalScrollIndicatorInsets.bottom = inset
                // Scroll the editing cell above the keyboard if it would be covered.
                // This runs inside the same animation block as the inset change so
                // the scroll tracks the keyboard slide-up — no separate jump.
                if let cell = self.editingCell,
                   let indexPath = self.collectionView.indexPath(for: cell) {
                    let cellFrame = cell.frame  // in collectionView content coordinates
                    let visibleBottom = self.collectionView.contentOffset.y
                        + self.collectionView.bounds.height
                        - inset
                    if cellFrame.maxY > visibleBottom {
                        self.collectionView.scrollToItem(at: indexPath, at: .bottom, animated: false)
                    }
                }
            }
        )
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curveRaw = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 0
        let offsetBefore = collectionView.contentOffset.y
        log.debug("keyboardWillHide: duration=\(duration) offsetBefore=\(offsetBefore)")
        // Reset free-scroll so the next editing session starts in default dismiss mode.
        if isFreeScrollActive {
            isFreeScrollActive = false
            collectionView.keyboardDismissMode = .interactive
            keyboardAccessory.isFreeScrollActive = false
        }
        collectionView.dragInteractionEnabled = true
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: UIView.AnimationOptions(rawValue: curveRaw << 16),
            animations: {
                self.collectionView.contentInset.bottom = 0
                self.collectionView.verticalScrollIndicatorInsets.bottom = 0
            }
        )
    }

    // MARK: - Theme

    private func applyTheme() {
        log.debug("applyTheme: editingCell=\(self.editingCell != nil)")
        view.backgroundColor = theme.backgroundColor.uiColor
        collectionView?.backgroundColor = .clear
        // Skip reloadData while a cell is editing to avoid _UIReparentingView issues
        if editingCell == nil {
            collectionView?.reloadData()
        }
    }

    // MARK: - Snapshot

    func applySnapshot(animated: Bool, caller: String = #function) {
        guard let document else { return }

        // If the focused item was removed from the document, pop the focus stack.
        if let focused = focusedItem, document.item(withID: focused.id) == nil {
            focusedItem = focusStack.popLast()
            updateFocusBreadcrumb(animated: false)
        }

        // Guard against nested applies (e.g. a UITextView delegate callback fires
        // mid-apply and tries to apply again). Defer one run loop tick instead.
        guard !isApplyingSnapshot else {
            log.debug("applySnapshot deferred (already applying) from \(caller)")
            DispatchQueue.main.async { [weak self] in self?.applySnapshot(animated: animated, caller: caller) }
            return
        }

        let filteredItems: [TaskItem]
        if searchText.isEmpty {
            filteredItems = document.visibleItems(focusedOn: focusedItem)
        } else {
            let filter = QueryEngine.compile(searchText)
            filteredItems = document.allItems.filter(filter)
        }

        let visibleBefore = collectionView.indexPathsForVisibleItems.sorted()
        log.debug("applySnapshot [\(caller)]: \(filteredItems.count) items, visible before=\(visibleBefore.map(\.item))")

        var snapshot = NSDiffableDataSourceSnapshot<Int, UUID>()
        snapshot.appendSections([0])
        snapshot.appendItems(filteredItems.map(\.id))

        isApplyingSnapshot = true
        dataSource.apply(snapshot, animatingDifferences: animated)
        isApplyingSnapshot = false

        let visibleAfter = collectionView.indexPathsForVisibleItems.sorted()
        log.debug("applySnapshot done: visible after=\(visibleAfter.map(\.item)), editingCell=\(self.editingCell != nil)")
    }

    // MARK: - Item Access

    func item(at indexPath: IndexPath) -> TaskItem? {
        guard let itemID = dataSource.itemIdentifier(for: indexPath) else {
            log.warning("item(at: \(indexPath)): dataSource has no identifier (snapshot count=\(self.dataSource.snapshot().numberOfItems))")
            return nil
        }
        guard let item = document?.item(withID: itemID) else {
            log.warning("item(at: \(indexPath)): document can't find id \(itemID.uuidString.prefix(8)) (allItems count=\(self.document?.allItems.count ?? -1))")
            return nil
        }
        return item
    }

    /// Reconfigures a single item without rebuilding the snapshot.
    /// Use this for content-only changes (toggleDone, cellDidCommit) where the item list
    /// and order are unchanged.
    private func reconfigureItem(_ itemID: UUID) {
        guard dataSource.indexPath(for: itemID) != nil else {
            log.warning("reconfigureItem: \(itemID.uuidString.prefix(8)) not in snapshot, falling back to applySnapshot")
            applySnapshot(animated: false)
            return
        }
        guard let item = document?.item(withID: itemID) else { return }
        // Search visibleCells by item ID instead of using cellForItem(at:).
        // cellForItem(at:) returns nil when the collection view is in the middle of a
        // keyboard-dismiss animation (contentInset.bottom is transitioning), even though
        // the cell is visually on screen. Iterating visibleCells is immune to this.
        if let cell = collectionView.visibleCells
            .compactMap({ $0 as? TaskItemCell })
            .first(where: { $0.item?.id == itemID }) {
            cell.configure(with: item, highlighter: highlighter, addDateToDone: addDateToDone)
        }
        // If the cell is off-screen, the registration handler will configure it correctly
        // when it comes into view, because item is a reference type updated in-place.
    }

    private func isCellFullyVisible(at indexPath: IndexPath) -> Bool {
        guard let layoutAttr = collectionView.layoutAttributesForItem(at: indexPath) else { return false }
        let visibleRect = CGRect(
            x: collectionView.contentOffset.x,
            y: collectionView.contentOffset.y,
            width: collectionView.bounds.width,
            height: collectionView.bounds.height - collectionView.contentInset.bottom
        )
        return visibleRect.contains(layoutAttr.frame)
    }

    // MARK: - Begin editing

    func beginEditing(item: TaskItem, isRetry: Bool = false) {
        guard document != nil else { return }

        log.debug("beginEditing\(isRetry ? "(retry)" : ""): '\(item.content.prefix(40))'")

        // Commit the current edit first; this may trigger applySnapshot which can
        // shift index paths, so resolve the target cell AFTER committing.
        if !isRetry { commitCurrentEdit() }

        // Use the snapshot's positions, not allItems — when search is active the snapshot
        // contains only filteredItems, so allItems indices don't map to IndexPaths.
        let snapshot = dataSource.snapshot()
        guard let index = snapshot.itemIdentifiers.firstIndex(of: item.id) else {
            log.warning("beginEditing: item \(item.id.uuidString.prefix(8)) not in current snapshot (filtered out?)")
            return
        }
        let indexPath = IndexPath(item: index, section: 0)

        // Flush any pending layout (e.g. height changes from a recent configure call
        // after keyboard dismiss) BEFORE checking visibility. If we check visibility
        // with stale layout attributes the cell can appear "in bounds" but then shift
        // off-screen once the deferred layout pass runs, making cellForItem return nil.
        collectionView.layoutIfNeeded()

        // Only scroll if the target cell isn't already fully visible — avoids a
        // jarring jump when the user taps a cell that's already on screen.
        // Use .bottom so off-screen cells scroll into view with minimal movement
        // (the keyboard will take care of the final positioning in keyboardWillShow).
        if !isCellFullyVisible(at: indexPath) {
            collectionView.scrollToItem(at: indexPath, at: .bottom, animated: false)
            collectionView.layoutIfNeeded()
        }

        let cell = collectionView.cellForItem(at: indexPath) as? TaskItemCell
        // If cellForItem still returns nil (e.g. contentInset animation still in flight),
        // defer one run-loop tick and retry once.
        if cell == nil, !isRetry {
            log.warning("beginEditing: no cell at \(indexPath) — deferring one run-loop tick")
            DispatchQueue.main.async { [weak self] in self?.beginEditing(item: item, isRetry: true) }
            return
        }
        guard let cell else {
            log.error("beginEditing: cell not found for \(indexPath) after all retries")
            return
        }
        log.debug("beginEditing: activating cell at \(indexPath)")
        editingCell = cell
        cell.beginEditing(inputAccessoryView: keyboardAccessory)

        // If a tap location was captured for this exact item, place the cursor there.
        // beginEditing sets cursor to end-of-text by default; we override it here.
        if let pending = pendingTapLocation, pending.itemID == item.id {
            pendingTapLocation = nil
            let pointInCell = collectionView.convert(pending.point, to: cell)
            let pointInTextView = CGPoint(
                x: pointInCell.x - cell.textViewFrame.minX,
                y: pointInCell.y - cell.textViewFrame.minY
            )
            cell.placeCursor(at: pointInTextView)
        }
    }

    func commitCurrentEdit() {
        if editingCell != nil { log.debug("commitCurrentEdit") }
        editingCell?.commitEditing()
        editingCell = nil
    }

    // MARK: - Add new item

    func addNewItem(after item: TaskItem? = nil) {
        guard let document else { return }

        // Commit any in-progress edit first
        commitCurrentEdit()

        let newItem = TaskItem(type: .task, content: "", indentLevel: item?.indentLevel ?? 0)

        if let item {
            document.insertItem(newItem, after: item)
            docUndoManager.registerInsert(item: newItem, parent: newItem.parent, index: 0, document: document)
        } else {
            document.appendItem(newItem)
        }

        applySnapshot(animated: false)
        onDocumentChanged?()

        DispatchQueue.main.async { [weak self] in
            self?.beginEditing(item: newItem)
        }
    }

    // MARK: - Delete item

    func deleteItem(_ item: TaskItem) {
        guard let document else { return }
        let parent = item.parent
        let index: Int
        if let parent {
            index = parent.children.firstIndex(where: { $0.id == item.id }) ?? 0
        } else {
            index = document.items.firstIndex(where: { $0.id == item.id }) ?? 0
        }

        document.removeItem(item)
        docUndoManager.registerDelete(item: item, parent: parent, index: index, document: document)
        applySnapshot(animated: false)
        onDocumentChanged?()
    }

    // MARK: - Toggle done

    func toggleDone(_ item: TaskItem) {
        guard let document else { return }
        log.debug("toggleDone: '\(item.content.prefix(30))'")
        let oldContent = item.content
        item.toggleDone(addDate: addDateToDone)
        docUndoManager.registerContentChange(item: item, oldContent: oldContent, newContent: item.content, document: document)
        reconfigureItem(item.id)
        onDocumentChanged?()
    }

    // MARK: - Indent / Outdent

    private func indentItem(_ item: TaskItem) {
        guard let document else { return }
        let oldLevel = item.indentLevel
        document.indentItem(item)
        docUndoManager.registerIndentChange(item: item, oldLevel: oldLevel, newLevel: item.indentLevel, document: document)
        applySnapshot(animated: false)
        onDocumentChanged?()
    }

    private func outdentItem(_ item: TaskItem) {
        guard let document else { return }
        let oldLevel = item.indentLevel
        document.outdentItem(item)
        docUndoManager.registerIndentChange(item: item, oldLevel: oldLevel, newLevel: item.indentLevel, document: document)
        applySnapshot(animated: false)
        onDocumentChanged?()
    }
}

// MARK: - UIScrollViewDelegate (jump detection)

extension DocumentEditorViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Only log large unexpected jumps (>100pt) to avoid flooding
        // We track the last offset via a stored property set after intentional scrolls.
        let offset = scrollView.contentOffset.y
        if abs(offset - lastKnownContentOffset) > 100 && !scrollView.isDragging && !scrollView.isDecelerating {
            log.warning("scrollViewDidScroll: unexpected jump \(self.lastKnownContentOffset) → \(offset)")
        }
        lastKnownContentOffset = offset
    }
}

// MARK: - UICollectionViewDelegate

extension DocumentEditorViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)

        log.debug("didSelectItemAt \(indexPath)")

        // Only look up the item from the data source (stable during layout flux).
        // Resolving the actual cell is deferred to beginEditing(item:) which calls
        // scrollToItem + layoutIfNeeded first, so it works even if the keyboard
        // inset animation is in progress when this fires.
        guard let item = item(at: indexPath) else {
            // Data source may still be settling after a reconfigureItems call.
            // Retry on the next run loop tick — by then layout is fully committed.
            log.warning("didSelectItemAt: no item at \(indexPath), scheduling retry")
            DispatchQueue.main.async { [weak self] in
                guard let self, let item = self.item(at: indexPath) else {
                    log.error("didSelectItemAt: retry also failed for \(indexPath)")
                    return
                }
                if self.editingCell?.item?.id == item.id { return }
                self.beginEditing(item: item)
            }
            return
        }

        // If tapping the already-editing item, do nothing
        if editingCell?.item?.id == item.id {
            log.debug("didSelectItemAt: already editing this item")
            return
        }

        // Read the tap location from the collection view's own tap recognizer while it
        // is still in .ended state — no separate gesture recognizer needed, no conflict.
        let tapLocation = collectionView.gestureRecognizers?
            .compactMap { $0 as? UITapGestureRecognizer }
            .first { $0.state == .ended }
            .map { $0.location(in: collectionView) }

        if let loc = tapLocation {
            log.debug("didSelectItemAt: tap at (\(loc.x), \(loc.y))")
            pendingTapLocation = (itemID: item.id, point: loc)
        }

        DispatchQueue.main.async { [weak self] in
            self?.beginEditing(item: item)
        }
    }
}

// MARK: - TaskItemCellDelegate

extension DocumentEditorViewController: TaskItemCellDelegate {

    func cellDidCommit(_ cell: TaskItemCell, newContent: String) {
        guard let item = cell.item, let document else { return }
        let oldContent = item.content
        let oldType = item.type

        // Re-detect item type from content (TaskPaper: line ending with ":" = project).
        // Existing projects keep their type when renamed without ":" so renaming doesn't
        // accidentally demote them. New tasks/notes ending with ":" are promoted to projects.
        let trimmed = newContent.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix(":") {
            item.type = .project
            item.content = String(trimmed.dropLast()).trimmingCharacters(in: .whitespaces)
        } else {
            item.content = newContent
            // type unchanged — don't demote an existing project just because it was renamed
        }
        item.tags = TagParser.parseTags(in: item.content)

        docUndoManager.registerContentChange(item: item, oldContent: oldContent, newContent: item.content, document: document)
        if cell === editingCell { editingCell = nil }

        if item.type != oldType {
            // Type changed (e.g. task → project): full snapshot needed to update the dash
            // label visibility and cell layout, not just reconfigure the content.
            applySnapshot(animated: false)
        } else {
            reconfigureItem(item.id)
        }
        onDocumentChanged?()
    }

    func cellDidRequestNewItem(after cell: TaskItemCell) {
        guard let item = cell.item else { return }
        // Cell already saved item.content in shouldChangeTextIn before calling this.
        // Defer out of UIKit's text-change pipeline to avoid a nested dataSource.apply call.
        if cell === editingCell { editingCell = nil }
        DispatchQueue.main.async { [weak self] in self?.addNewItem(after: item) }
    }

    func cellDidRequestDelete(_ cell: TaskItemCell) {
        guard let item = cell.item else { return }
        // Same reason — defer out of the text-change pipeline.
        if cell === editingCell { editingCell = nil }
        DispatchQueue.main.async { [weak self] in self?.deleteItem(item) }
    }

    func cellDidRequestIndent(_ cell: TaskItemCell) {
        guard let item = cell.item else { return }
        indentItem(item)
        // Re-begin editing so the cell stays active after snapshot refresh
        DispatchQueue.main.async { [weak self] in self?.beginEditing(item: item) }
    }

    func cellDidRequestOutdent(_ cell: TaskItemCell) {
        guard let item = cell.item else { return }
        outdentItem(item)
        DispatchQueue.main.async { [weak self] in self?.beginEditing(item: item) }
    }

    func cellDidChange(_ cell: TaskItemCell, content: String) {
        document?.hasUnsavedChanges = true
        onDocumentChanged?()
    }

    func cellDidToggleDone(_ cell: TaskItemCell, oldContent: String) {
        guard let document, let item = cell.item else { return }
        // The cell already toggled the model and updated its own display.
        // Only register undo and schedule autosave here — do NOT call reconfigureItem.
        docUndoManager.registerContentChange(item: item, oldContent: oldContent, newContent: item.content, document: document)
        onDocumentChanged?()
    }

    func cellDidDismissEditing(_ cell: TaskItemCell) {
        // Cell was reused or scrolled off-screen mid-edit — clear the stale reference.
        if cell === editingCell { editingCell = nil }
    }

    func cellDidToggleFold(_ cell: TaskItemCell) {
        guard let item = cell.item, let document else { return }
        // If collapsing and a descendant is currently being edited, commit it first
        // so no invisible cell is left holding first responder.
        if !item.isCollapsed,
           let editing = editingCell,
           let editedItem = editing.item,
           item.allDescendants.contains(editedItem) {
            commitCurrentEdit()
        }
        let wasCollapsed = item.isCollapsed
        item.isCollapsed.toggle()
        docUndoManager.registerCollapseChange(item: item, wasCollapsed: wasCollapsed, document: document)
        reconfigureItem(item.id)
        applySnapshot(animated: true)
        onFoldStateChanged?()
    }

    func cellDidRequestNavigate(_ cell: TaskItemCell, direction: NavigationDirection) {
        guard let item = cell.item, let document else { return }
        let allItems = searchText.isEmpty
            ? document.visibleItems(focusedOn: focusedItem)
            : document.allItems.filter(QueryEngine.compile(searchText))
        guard let currentIndex = allItems.firstIndex(where: { $0.id == item.id }) else { return }

        let targetIndex: Int
        switch direction {
        case .previous: targetIndex = currentIndex - 1
        case .next:     targetIndex = currentIndex + 1
        }

        guard allItems.indices.contains(targetIndex) else { return }
        let targetItem = allItems[targetIndex]

        // Save current content before moving
        item.content = cell.textViewCurrentContent

        DispatchQueue.main.async { [weak self] in
            self?.beginEditing(item: targetItem)
        }
    }

}

// MARK: - EditorKeyboardAccessoryDelegate

extension DocumentEditorViewController: EditorKeyboardAccessoryDelegate {

    func accessoryDidTapIndent() {
        guard let cell = editingCell, let item = cell.item else { return }
        // Save current text before indent so content isn't lost
        item.content = cell.textViewCurrentContent
        cellDidRequestIndent(cell)
    }

    func accessoryDidTapOutdent() {
        guard let cell = editingCell, let item = cell.item else { return }
        item.content = cell.textViewCurrentContent
        cellDidRequestOutdent(cell)
    }

    func accessoryDidTapToggleDone() {
        guard let cell = editingCell, let item = cell.item else { return }
        item.content = cell.textViewCurrentContent
        cell.commitEditing()
        editingCell = nil
        toggleDone(item)
    }

    func accessoryDidTapCursorLeft() {
        guard let tv = editingCell?.editingTextView,
              let range = tv.selectedTextRange,
              let newPos = tv.position(from: range.start, offset: -1) else { return }
        tv.selectedTextRange = tv.textRange(from: newPos, to: newPos)
    }

    func accessoryDidTapCursorRight() {
        guard let tv = editingCell?.editingTextView,
              let range = tv.selectedTextRange,
              let newPos = tv.position(from: range.end, offset: 1) else { return }
        tv.selectedTextRange = tv.textRange(from: newPos, to: newPos)
    }

    func accessoryDidTapDismiss() {
        commitCurrentEdit()
    }

    func accessoryDidTapFreeScroll() {
        isFreeScrollActive.toggle()
        collectionView.keyboardDismissMode = isFreeScrollActive ? .none : .interactive
        keyboardAccessory.isFreeScrollActive = isFreeScrollActive
        log.debug("freeScroll: \(self.isFreeScrollActive)")
    }
}
