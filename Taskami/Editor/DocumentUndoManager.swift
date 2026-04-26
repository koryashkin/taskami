import Foundation

final class DocumentUndoManager {
    let undoManager: UndoManager

    init(undoManager: UndoManager = UndoManager()) {
        self.undoManager = undoManager
        self.undoManager.levelsOfUndo = 100
    }

    func registerContentChange(item: TaskItem, oldContent: String, newContent: String, document: TaskDocument) {
        let itemID = item.id
        undoManager.registerUndo(withTarget: document) { [weak self] doc in
            guard let targetItem = doc.item(withID: itemID) else { return }
            let currentContent = targetItem.content
            targetItem.content = oldContent
            targetItem.tags = TagParser.parseTags(in: oldContent)
            doc.hasUnsavedChanges = true
            self?.registerContentChange(item: targetItem, oldContent: currentContent, newContent: oldContent, document: doc)
        }
    }

    func registerInsert(item: TaskItem, parent: TaskItem?, index: Int, document: TaskDocument) {
        let itemID = item.id
        undoManager.registerUndo(withTarget: document) { [weak self] doc in
            guard let targetItem = doc.item(withID: itemID) else { return }
            let currentParent = targetItem.parent
            let currentIndex: Int
            if let currentParent {
                currentIndex = currentParent.children.firstIndex(where: { $0.id == itemID }) ?? 0
            } else {
                currentIndex = doc.items.firstIndex(where: { $0.id == itemID }) ?? 0
            }
            doc.removeItem(targetItem)
            self?.registerDelete(item: targetItem, parent: currentParent, index: currentIndex, document: doc)
        }
    }

    func registerDelete(item: TaskItem, parent: TaskItem?, index: Int, document: TaskDocument) {
        let savedItem = item
        let parentID = parent?.id
        undoManager.registerUndo(withTarget: document) { [weak self] doc in
            let targetParent = parentID.flatMap { doc.item(withID: $0) }
            if let targetParent {
                let clampedIndex = min(index, targetParent.children.count)
                savedItem.parent = targetParent
                savedItem.indentLevel = targetParent.indentLevel + 1
                targetParent.children.insert(savedItem, at: clampedIndex)
            } else {
                let clampedIndex = min(index, doc.items.count)
                savedItem.parent = nil
                savedItem.indentLevel = 0
                doc.items.insert(savedItem, at: clampedIndex)
            }
            doc.hasUnsavedChanges = true
            self?.registerInsert(item: savedItem, parent: targetParent, index: index, document: doc)
        }
    }

    func registerIndentChange(item: TaskItem, oldLevel: Int, newLevel: Int, document: TaskDocument) {
        let itemID = item.id
        undoManager.registerUndo(withTarget: document) { [weak self] doc in
            guard let targetItem = doc.item(withID: itemID) else { return }
            if oldLevel < newLevel {
                doc.outdentItem(targetItem)
            } else {
                doc.indentItem(targetItem)
            }
            self?.registerIndentChange(item: targetItem, oldLevel: newLevel, newLevel: oldLevel, document: doc)
        }
    }

    func registerCollapseChange(item: TaskItem, wasCollapsed: Bool, document: TaskDocument) {
        let itemID = item.id
        undoManager.registerUndo(withTarget: document) { [weak self] doc in
            guard let targetItem = doc.item(withID: itemID) else { return }
            let currentCollapsed = targetItem.isCollapsed
            targetItem.isCollapsed = wasCollapsed
            self?.registerCollapseChange(item: targetItem, wasCollapsed: currentCollapsed, document: doc)
        }
    }
}
