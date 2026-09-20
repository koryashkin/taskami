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
    private(set) var revision: UInt = 0

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

    /// All items flattened in depth-first order, ignoring fold state.
    /// Used for search (folded items are still searchable) and undo navigation.
    var allItems: [TaskItem] {
        var result: [TaskItem] = []
        for item in items {
            result.append(contentsOf: item.selfAndDescendants)
        }
        return result
    }

    /// Records an in-memory mutation that must reach disk.
    /// Each mutation receives a new revision so an older asynchronous save cannot
    /// mark a newer edit as persisted.
    func markChanged() {
        revision &+= 1
        hasUnsavedChanges = true
    }

    /// Clears the dirty state only when the completed write represents the latest
    /// in-memory revision.
    func markSaved(ifRevisionMatches savedRevision: UInt) {
        guard revision == savedRevision else { return }
        hasUnsavedChanges = false
    }

    /// Replaces the in-memory document from disk and invalidates any older save.
    func markLoadedFromDisk() {
        revision &+= 1
        hasUnsavedChanges = false
    }

    /// Items flattened in depth-first order, respecting fold state.
    /// Pass a `root` to restrict the result to that subtree (Focus In).
    /// Collapsed items are included but their descendants are omitted.
    func visibleItems(focusedOn root: TaskItem? = nil) -> [TaskItem] {
        var result: [TaskItem] = []
        for item in root.map({ [$0] }) ?? items {
            appendVisible(item, to: &result)
        }
        return result
    }

    private func appendVisible(_ item: TaskItem, to result: inout [TaskItem]) {
        result.append(item)
        guard !item.isCollapsed else { return }
        for child in item.children {
            appendVisible(child, to: &result)
        }
    }

    // MARK: - Fold state persistence helpers

    /// Index paths (from root) of every currently-collapsed item.
    /// Used to round-trip fold state to/from the sidecar file.
    var collapsedPaths: [[Int]] {
        var result: [[Int]] = []
        for (i, item) in items.enumerated() {
            collectCollapsed(item, path: [i], into: &result)
        }
        return result
    }

    private func collectCollapsed(_ item: TaskItem, path: [Int], into result: inout [[Int]]) {
        if item.isCollapsed { result.append(path) }
        for (i, child) in item.children.enumerated() {
            collectCollapsed(child, path: path + [i], into: &result)
        }
    }

    /// Apply a set of persisted index paths, collapsing the matched items.
    /// Silently ignores any path that no longer resolves (item moved/deleted).
    func applyCollapsedPaths(_ paths: [[Int]]) {
        for path in paths {
            item(atPath: path)?.isCollapsed = true
        }
    }

    /// Resolve an item from a root-to-leaf index path. Returns nil if any index is out of range.
    func item(atPath path: [Int]) -> TaskItem? {
        guard let first = path.first, first < items.count else { return nil }
        var current = items[first]
        for index in path.dropFirst() {
            guard index < current.children.count else { return nil }
            current = current.children[index]
        }
        return current
    }

    /// Compute the index path of an item in the tree. Returns nil if not found.
    func path(of target: TaskItem) -> [Int]? {
        for (i, item) in items.enumerated() {
            if let found = findPath(of: target, in: item, currentPath: [i]) {
                return found
            }
        }
        return nil
    }

    private func findPath(of target: TaskItem, in item: TaskItem, currentPath: [Int]) -> [Int]? {
        if item.id == target.id { return currentPath }
        for (i, child) in item.children.enumerated() {
            if let found = findPath(of: target, in: child, currentPath: currentPath + [i]) {
                return found
            }
        }
        return nil
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
        markChanged()
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
        markChanged()
    }

    func appendItem(_ newItem: TaskItem) {
        newItem.parent = nil
        newItem.indentLevel = 0
        items.append(newItem)
        markChanged()
    }

    func removeItem(_ item: TaskItem) {
        if let parent = item.parent {
            parent.children.removeAll { $0.id == item.id }
        } else {
            items.removeAll { $0.id == item.id }
        }
        item.parent = nil
        markChanged()
    }

    func moveItem(_ item: TaskItem, toParent newParent: TaskItem?, atIndex index: Int) {
        // A parent cannot be inserted into itself or one of its descendants.
        // Either would create a cycle and make tree traversals recurse forever.
        guard newParent !== item,
              newParent?.ancestors.contains(where: { $0.id == item.id }) != true else {
            return
        }

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
        markChanged()
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
        markChanged()
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
        markChanged()
    }

    private func updateChildIndentLevels(of item: TaskItem) {
        for child in item.children {
            child.indentLevel = item.indentLevel + 1
            updateChildIndentLevels(of: child)
        }
    }
}
