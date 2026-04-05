import UIKit

final class DocumentEditorViewController: UIViewController {

    private(set) var document: TaskDocument?
    var searchFilter: ((TaskItem) -> Bool)?
    var theme: EditorTheme = .light {
        didSet { applyTheme() }
    }
    var onDocumentChanged: (() -> Void)?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, UUID>!

    let fieldEditor = FieldEditorController()
    private let dragDropHandler = EditorDragDropHandler()
    private let keyboardAccessory = EditorKeyboardAccessoryView()
    private let docUndoManager = DocumentUndoManager()

    private var highlighter: TaskPaperTextHighlighter {
        TaskPaperTextHighlighter(theme: theme)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupDataSource()
        setupFieldEditor()
        setupDragDrop()
        setupKeyboardAccessory()
        setupKeyboardObservers()
        applyTheme()
        // Apply snapshot now that dataSource is ready (document may have been set
        // before viewDidLoad via setDocument called from makeUIViewController)
        applySnapshot(animated: false)
    }

    func setDocument(_ document: TaskDocument) {
        self.document = document
        // Only apply snapshot if viewDidLoad has run and dataSource is set up.
        // If not yet loaded, viewDidLoad will call applySnapshot after setup.
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
        let cellRegistration = UICollectionView.CellRegistration<TaskItemCell, UUID> { [weak self] cell, indexPath, itemID in
            guard let self, let item = self.document?.item(withID: itemID) else { return }
            cell.configure(with: item, highlighter: self.highlighter)
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, itemID in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: itemID)
        }
    }

    private func setupFieldEditor() {
        fieldEditor.delegate = self
        fieldEditor.textView.inputAccessoryView = keyboardAccessory
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
        collectionView?.reloadData()
    }

    // MARK: - Snapshot

    func applySnapshot(animated: Bool) {
        guard let document else { return }

        let filteredItems: [TaskItem]
        if let filter = searchFilter {
            filteredItems = document.allItems.filter(filter)
        } else {
            filteredItems = document.allItems
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

    // MARK: - Actions

    func addNewItem(after item: TaskItem? = nil) {
        guard let document else { return }

        let newItem = TaskItem(type: .task, content: "", indentLevel: item?.indentLevel ?? 0)

        if let item {
            document.insertItem(newItem, after: item)
            docUndoManager.registerInsert(item: newItem, parent: newItem.parent, index: 0, document: document)
        } else {
            document.appendItem(newItem)
        }

        applySnapshot(animated: false)
        onDocumentChanged?()

        // Begin editing the new item after layout completes
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let allItems = document.allItems
            guard let index = allItems.firstIndex(where: { $0.id == newItem.id }) else { return }
            let indexPath = IndexPath(item: index, section: 0)
            self.collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
            self.collectionView.layoutIfNeeded()
            if let cell = self.collectionView.cellForItem(at: indexPath) as? TaskItemCell {
                self.fieldEditor.beginEditing(item: newItem, in: cell, highlighter: self.highlighter)
            }
        }
    }

    private func deleteItem(_ item: TaskItem) {
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

    private func toggleDone(_ item: TaskItem) {
        let oldContent = item.content
        item.toggleDone()
        docUndoManager.registerContentChange(item: item, oldContent: oldContent, newContent: item.content, document: document!)
        applySnapshot(animated: true)
        onDocumentChanged?()
    }
}

// MARK: - UICollectionViewDelegate

extension DocumentEditorViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        // Commit any existing edit
        fieldEditor.commit()

        guard let item = item(at: indexPath),
              let cell = collectionView.cellForItem(at: indexPath) as? TaskItemCell else { return }

        fieldEditor.beginEditing(item: item, in: cell, highlighter: highlighter)
    }
}

// MARK: - FieldEditorDelegate

extension DocumentEditorViewController: FieldEditorDelegate {
    func fieldEditorDidCommit(item: TaskItem, newContent: String) {
        applySnapshot(animated: false)
        onDocumentChanged?()
    }

    func fieldEditorDidRequestNewItem(after item: TaskItem) {
        fieldEditor.dismiss()
        addNewItem(after: item)
    }

    func fieldEditorDidRequestIndent(item: TaskItem) {
        guard let document else { return }
        let oldLevel = item.indentLevel
        document.indentItem(item)
        docUndoManager.registerIndentChange(item: item, oldLevel: oldLevel, newLevel: item.indentLevel, document: document)
        applySnapshot(animated: true)
        onDocumentChanged?()
    }

    func fieldEditorDidRequestOutdent(item: TaskItem) {
        guard let document else { return }
        let oldLevel = item.indentLevel
        document.outdentItem(item)
        docUndoManager.registerIndentChange(item: item, oldLevel: oldLevel, newLevel: item.indentLevel, document: document)
        applySnapshot(animated: true)
        onDocumentChanged?()
    }

    func fieldEditorDidRequestDelete(item: TaskItem) {
        deleteItem(item)
    }

    func fieldEditorDidChange(item: TaskItem) {
        document?.hasUnsavedChanges = true
    }
}

// MARK: - EditorKeyboardAccessoryDelegate

extension DocumentEditorViewController: EditorKeyboardAccessoryDelegate {
    func accessoryDidTapIndent() {
        guard let item = fieldEditor.editingItem else { return }
        fieldEditorDidRequestIndent(item: item)
    }

    func accessoryDidTapOutdent() {
        guard let item = fieldEditor.editingItem else { return }
        fieldEditorDidRequestOutdent(item: item)
    }

    func accessoryDidTapToggleDone() {
        guard let item = fieldEditor.editingItem else { return }
        toggleDone(item)
        fieldEditor.commit()
    }

    func accessoryDidTapCursorLeft() {
        let tv = fieldEditor.textView
        guard let range = tv.selectedTextRange,
              let newPos = tv.position(from: range.start, offset: -1) else { return }
        tv.selectedTextRange = tv.textRange(from: newPos, to: newPos)
    }

    func accessoryDidTapCursorRight() {
        let tv = fieldEditor.textView
        guard let range = tv.selectedTextRange,
              let newPos = tv.position(from: range.end, offset: 1) else { return }
        tv.selectedTextRange = tv.textRange(from: newPos, to: newPos)
    }

    func accessoryDidTapDismiss() {
        fieldEditor.commit()
    }
}
