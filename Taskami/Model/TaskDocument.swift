import Foundation
import Observation

@Observable
final class TaskDocument: Identifiable {
    let id: UUID
    var fileURL: URL
    var items: [TaskItem]
    var encoding: String.Encoding
    var lineEnding: String
    var hasUnsavedChanges: Bool

    init(
        fileURL: URL,
        items: [TaskItem] = [],
        encoding: String.Encoding = .utf8,
        lineEnding: String = "\n"
    ) {
        self.id = UUID()
        self.fileURL = fileURL
        self.items = items
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.hasUnsavedChanges = false
    }

    /// All items flattened in depth-first order.
    var allItems: [TaskItem] {
        var result: [TaskItem] = []
        for item in items {
            result.append(contentsOf: item.selfAndDescendants)
        }
        return result
    }

    func item(withID id: UUID) -> TaskItem? {
        allItems.first { $0.id == id }
    }

    // MARK: - Mutations

    func insertItem(_ newItem: TaskItem, after existingItem: TaskItem) {
        let siblings: [TaskItem]
        let parent: TaskItem?

        if let p = existingItem.parent {
            siblings = p.children
            parent = p
        } else {
            siblings = items
            parent = nil
        }

        guard let index = siblings.firstIndex(where: { $0.id == existingItem.id }) else { return }

        newItem.parent = parent
        newItem.indentLevel = existingItem.indentLevel

        if let parent {
            parent.children.insert(newItem, at: index + 1)
        } else {
            items.insert(newItem, at: index + 1)
        }
        hasUnsavedChanges = true
    }

    func insertItem(_ newItem: TaskItem, before existingItem: TaskItem) {
        let parent = existingItem.parent

        newItem.parent = parent
        newItem.indentLevel = existingItem.indentLevel

        if let parent {
            guard let index = parent.children.firstIndex(where: { $0.id == existingItem.id }) else { return }
            parent.children.insert(newItem, at: index)
        } else {
            guard let index = items.firstIndex(where: { $0.id == existingItem.id }) else { return }
            items.insert(newItem, at: index)
        }
        hasUnsavedChanges = true
    }

    func appendItem(_ newItem: TaskItem) {
        newItem.parent = nil
        newItem.indentLevel = 0
        items.append(newItem)
        hasUnsavedChanges = true
    }

    func removeItem(_ item: TaskItem) {
        if let parent = item.parent {
            parent.children.removeAll { $0.id == item.id }
        } else {
            items.removeAll { $0.id == item.id }
        }
        item.parent = nil
        hasUnsavedChanges = true
    }

    func moveItem(_ item: TaskItem, toParent newParent: TaskItem?, atIndex index: Int) {
        // Remove from current location
        if let oldParent = item.parent {
            oldParent.children.removeAll { $0.id == item.id }
        } else {
            items.removeAll { $0.id == item.id }
        }

        // Insert at new location
        item.parent = newParent
        if let newParent {
            item.indentLevel = newParent.indentLevel + 1
            let clampedIndex = min(index, newParent.children.count)
            newParent.children.insert(item, at: clampedIndex)
        } else {
            item.indentLevel = 0
            let clampedIndex = min(index, items.count)
            items.insert(item, at: clampedIndex)
        }

        // Update children indent levels recursively
        updateChildIndentLevels(of: item)
        hasUnsavedChanges = true
    }

    func indentItem(_ item: TaskItem) {
        let siblings: [TaskItem]
        if let parent = item.parent {
            siblings = parent.children
        } else {
            siblings = items
        }

        guard let index = siblings.firstIndex(where: { $0.id == item.id }),
              index > 0 else { return }

        let newParent = siblings[index - 1]

        // Remove from current siblings
        if let parent = item.parent {
            parent.children.remove(at: index)
        } else {
            items.remove(at: index)
        }

        // Add as last child of previous sibling
        item.parent = newParent
        item.indentLevel = newParent.indentLevel + 1
        newParent.children.append(item)

        updateChildIndentLevels(of: item)
        hasUnsavedChanges = true
    }

    func outdentItem(_ item: TaskItem) {
        guard let oldParent = item.parent else { return }

        let grandparent = oldParent.parent
        guard let indexInParent = oldParent.children.firstIndex(where: { $0.id == item.id }) else { return }

        // Siblings after this item become children of this item
        let followingSiblings = Array(oldParent.children[(indexInParent + 1)...])
        oldParent.children.removeSubrange(indexInParent...)

        for sibling in followingSiblings {
            sibling.parent = item
            sibling.indentLevel = item.indentLevel // will be updated below
            item.children.append(sibling)
        }

        // Insert after oldParent in grandparent's children
        item.parent = grandparent
        if let grandparent {
            item.indentLevel = grandparent.indentLevel + 1
            if let parentIndex = grandparent.children.firstIndex(where: { $0.id == oldParent.id }) {
                grandparent.children.insert(item, at: parentIndex + 1)
            }
        } else {
            item.indentLevel = 0
            if let parentIndex = items.firstIndex(where: { $0.id == oldParent.id }) {
                items.insert(item, at: parentIndex + 1)
            }
        }

        updateChildIndentLevels(of: item)
        hasUnsavedChanges = true
    }

    private func updateChildIndentLevels(of item: TaskItem) {
        for child in item.children {
            child.indentLevel = item.indentLevel + 1
            updateChildIndentLevels(of: child)
        }
    }
}
