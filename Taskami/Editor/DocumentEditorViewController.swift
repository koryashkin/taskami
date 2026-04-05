import UIKit

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
    var onDocumentChanged: (() -> Void)?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, UUID>!

    private let dragDropHandler = EditorDragDropHandler()
    private let keyboardAccessory = EditorKeyboardAccessoryView()
    private let docUndoManager = DocumentUndoManager()

    /// The cell currently in edit mode (at most one at a time).
    private weak var editingCell: TaskItemCell?

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

        let layout = UICollectionViewCompositionalLayout.list(using: config)
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.keyboardDismissMode = .interactive
        view.addSubview(collectionView)
    }

    private func setupDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<TaskItemCell, UUID> { [weak self] cell, _, itemID in
            guard let self, let item = self.document?.item(withID: itemID) else { return }
            cell.configure(with: item, highlighter: self.highlighter)
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

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let inset = frame.height - view.safeAreaInsets.bottom
        collectionView.contentInset.bottom = inset
        collectionView.verticalScrollIndicatorInsets.bottom = inset
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        collectionView.contentInset.bottom = 0
        collectionView.verticalScrollIndicatorInsets.bottom = 0
    }

    // MARK: - Theme

    private func applyTheme() {
        view.backgroundColor = theme.backgroundColor.uiColor
        collectionView?.backgroundColor = .clear
        // Skip reloadData while a cell is editing to avoid _UIReparentingView issues
        if editingCell == nil {
            collectionView?.reloadData()
        }
    }

    // MARK: - Snapshot

    func applySnapshot(animated: Bool) {
        guard let document else { return }

        let allItems = document.allItems
        let filteredItems: [TaskItem]
        if searchText.isEmpty {
            filteredItems = allItems
        } else {
            let filter = QueryEngine.compile(searchText)
            filteredItems = allItems.filter(filter)
        }

        var snapshot = NSDiffableDataSourceSnapshot<Int, UUID>()
        snapshot.appendSections([0])
        snapshot.appendItems(filteredItems.map(\.id))
        dataSource.apply(snapshot, animatingDifferences: animated)
    }

    // MARK: - Item Access

    func item(at indexPath: IndexPath) -> TaskItem? {
        guard let itemID = dataSource.itemIdentifier(for: indexPath) else { return nil }
        return document?.item(withID: itemID)
    }

    // MARK: - Begin editing

    func beginEditing(item: TaskItem) {
        guard let document else { return }
        let allItems = document.allItems
        guard let index = allItems.firstIndex(where: { $0.id == item.id }) else { return }
        let indexPath = IndexPath(item: index, section: 0)

        collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        collectionView.layoutIfNeeded()

        guard let cell = collectionView.cellForItem(at: indexPath) as? TaskItemCell else { return }
        commitCurrentEdit()
        editingCell = cell
        cell.beginEditing(inputAccessoryView: keyboardAccessory)
    }

    private func commitCurrentEdit() {
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
        applySnapshot(animated: true)
        onDocumentChanged?()
    }

    // MARK: - Toggle done

    func toggleDone(_ item: TaskItem) {
        let oldContent = item.content
        item.toggleDone()
        docUndoManager.registerContentChange(item: item, oldContent: oldContent, newContent: item.content, document: document!)
        applySnapshot(animated: false)
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

// MARK: - UICollectionViewDelegate

extension DocumentEditorViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)

        guard let item = item(at: indexPath),
              let cell = collectionView.cellForItem(at: indexPath) as? TaskItemCell else { return }

        // If tapping the already-editing cell, do nothing
        if cell === editingCell { return }

        commitCurrentEdit()
        editingCell = cell
        cell.beginEditing(inputAccessoryView: keyboardAccessory)
    }
}

// MARK: - TaskItemCellDelegate

extension DocumentEditorViewController: TaskItemCellDelegate {

    func cellDidCommit(_ cell: TaskItemCell, newContent: String) {
        guard let item = cell.item else { return }
        let oldContent = item.content
        item.content = newContent
        item.tags = TagParser.parseTags(in: newContent)
        docUndoManager.registerContentChange(item: item, oldContent: oldContent, newContent: newContent, document: document!)
        if cell === editingCell { editingCell = nil }
        applySnapshot(animated: false)
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

    func cellDidRequestNavigate(_ cell: TaskItemCell, direction: NavigationDirection) {
        guard let item = cell.item, let document else { return }
        let allItems = document.allItems
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
}
