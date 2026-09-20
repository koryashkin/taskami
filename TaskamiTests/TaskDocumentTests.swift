import Testing
import Foundation
@testable import Taskami

@Suite("TaskDocument Tests")
struct TaskDocumentTests {

    @Test("Saving an older revision does not clear newer unsaved changes")
    func savingOlderRevisionKeepsDocumentDirty() {
        let document = TaskDocument(fileURL: URL(fileURLWithPath: "/tmp/Revision.taskpaper"))

        document.markChanged()
        let savedRevision = document.revision
        document.markChanged()
        document.markSaved(ifRevisionMatches: savedRevision)

        #expect(document.hasUnsavedChanges)
        #expect(document.revision > savedRevision)
    }

    private func makeDoc() -> TaskDocument {
        // Structure:
        //   Project A:        [0]
        //     - Task 1        [0,0]
        //       - Subtask 1a  [0,0,0]
        //     - Task 2        [0,1]
        //   Project B:        [1]
        //     - Task 3        [1,0]
        let text = "Project A:\n\t- Task 1\n\t\t- Subtask 1a\n\t- Task 2\nProject B:\n\t- Task 3\n"
        return TaskDocument(
            fileURL: URL(fileURLWithPath: "/tmp/test.taskpaper"),
            items: TaskPaperParser.parse(text)
        )
    }

    // MARK: - visibleItems

    @Test("visibleItems returns all items when nothing is collapsed")
    func visibleItemsAll() {
        let doc = makeDoc()
        #expect(doc.visibleItems().count == 6)
    }

    @Test("visibleItems omits children of collapsed item")
    func visibleItemsCollapsed() {
        let doc = makeDoc()
        doc.items[0].isCollapsed = true
        let visible = doc.visibleItems()
        // Project A (collapsed, hides 3 children) + Project B + Task 3 = 3
        #expect(visible.count == 3)
        #expect(visible[0].content == "Project A")
        #expect(visible[1].content == "Project B")
    }

    @Test("visibleItems still includes collapsed item itself")
    func visibleItemsIncludesCollapsed() {
        let doc = makeDoc()
        doc.items[0].isCollapsed = true
        let visible = doc.visibleItems()
        #expect(visible.contains { $0.content == "Project A" })
    }

    @Test("Collapsing intermediate node hides its subtree only")
    func visibleItemsPartialCollapse() {
        let doc = makeDoc()
        doc.items[0].children[0].isCollapsed = true // collapse Task 1 (hides Subtask 1a)
        let visible = doc.visibleItems()
        // All 6 minus Subtask 1a = 5
        #expect(visible.count == 5)
        #expect(!visible.contains { $0.content == "Subtask 1a" })
    }

    @Test("visibleItems(focusedOn:) restricts to subtree")
    func visibleItemsFocused() {
        let doc = makeDoc()
        let projectA = doc.items[0]
        let visible = doc.visibleItems(focusedOn: projectA)
        // Project A + Task1 + Subtask1a + Task2 = 4
        #expect(visible.count == 4)
        #expect(visible[0].content == "Project A")
        #expect(!visible.contains { $0.content == "Project B" })
    }

    @Test("visibleItems(focusedOn:) respects collapse within focused subtree")
    func visibleItemsFocusedWithCollapse() {
        let doc = makeDoc()
        let projectA = doc.items[0]
        projectA.children[0].isCollapsed = true // collapse Task 1
        let visible = doc.visibleItems(focusedOn: projectA)
        // Project A + Task1 (collapsed) + Task2 = 3
        #expect(visible.count == 3)
    }

    // MARK: - allItems

    @Test("allItems returns all items regardless of collapse")
    func allItemsCount() {
        let doc = makeDoc()
        doc.items[0].isCollapsed = true
        #expect(doc.allItems.count == 6) // collapse has no effect on allItems
    }

    @Test("allItems order is depth-first")
    func allItemsOrder() {
        let doc = makeDoc()
        let contents = doc.allItems.map(\.content)
        let subtaskIdx = contents.firstIndex(of: "Subtask 1a")!
        let task1Idx = contents.firstIndex(of: "Task 1")!
        let task2Idx = contents.firstIndex(of: "Task 2")!
        #expect(task1Idx < subtaskIdx)
        #expect(subtaskIdx < task2Idx)
    }

    // MARK: - Path resolution

    @Test("path(of:) returns correct index path")
    func pathOf() {
        let doc = makeDoc()
        let subtask = doc.items[0].children[0].children[0]
        #expect(doc.path(of: subtask) == [0, 0, 0])
    }

    @Test("path(of:) for root item")
    func pathOfRoot() {
        let doc = makeDoc()
        #expect(doc.path(of: doc.items[1]) == [1])
    }

    @Test("item(atPath:) resolves correct item")
    func itemAtPath() {
        let doc = makeDoc()
        #expect(doc.item(atPath: [0, 0, 0])?.content == "Subtask 1a")
        #expect(doc.item(atPath: [1, 0])?.content == "Task 3")
        #expect(doc.item(atPath: [0])?.content == "Project A")
    }

    @Test("item(atPath:) returns nil for out-of-range path")
    func itemAtPathOutOfRange() {
        let doc = makeDoc()
        #expect(doc.item(atPath: [99]) == nil)
        #expect(doc.item(atPath: [0, 99]) == nil)
        #expect(doc.item(atPath: []) == nil)
    }

    @Test("path and item(atPath:) are inverse operations for every item")
    func pathRoundTrip() {
        let doc = makeDoc()
        for item in doc.allItems {
            if let path = doc.path(of: item) {
                #expect(doc.item(atPath: path)?.id == item.id)
            }
        }
    }

    // MARK: - item(withID:)

    @Test("item(withID:) finds any item in the tree")
    func itemWithID() {
        let doc = makeDoc()
        for item in doc.allItems {
            #expect(doc.item(withID: item.id)?.id == item.id)
        }
    }

    @Test("item(withID:) returns nil for unknown ID")
    func itemWithIDUnknown() {
        let doc = makeDoc()
        #expect(doc.item(withID: UUID()) == nil)
    }

    // MARK: - Fold state persistence

    @Test("collapsedPaths captures all collapsed items")
    func collapsedPaths() {
        let doc = makeDoc()
        doc.items[0].isCollapsed = true
        doc.items[0].children[0].isCollapsed = true
        let paths = doc.collapsedPaths
        #expect(paths.contains([0]))
        #expect(paths.contains([0, 0]))
        #expect(!paths.contains([1]))
    }

    @Test("collapsedPaths is empty when nothing is collapsed")
    func collapsedPathsEmpty() {
        let doc = makeDoc()
        #expect(doc.collapsedPaths.isEmpty)
    }

    @Test("applyCollapsedPaths restores fold state")
    func applyCollapsedPaths() {
        let doc = makeDoc()
        doc.applyCollapsedPaths([[0], [0, 0]])
        #expect(doc.items[0].isCollapsed)
        #expect(doc.items[0].children[0].isCollapsed)
        #expect(!doc.items[1].isCollapsed)
    }

    @Test("applyCollapsedPaths ignores invalid paths silently")
    func applyCollapsedPathsInvalid() {
        let doc = makeDoc()
        doc.applyCollapsedPaths([[99, 99]]) // should not crash
        #expect(doc.collapsedPaths.isEmpty)
    }

    @Test("collapsedPaths/applyCollapsedPaths round-trip")
    func collapsedPathsRoundTrip() {
        let doc = makeDoc()
        doc.items[0].isCollapsed = true
        doc.items[1].children[0].isCollapsed = true
        let paths = doc.collapsedPaths

        // Reset
        for item in doc.allItems { item.isCollapsed = false }

        // Restore
        doc.applyCollapsedPaths(paths)

        #expect(doc.items[0].isCollapsed)
        #expect(doc.items[1].children[0].isCollapsed)
        #expect(!doc.items[1].isCollapsed)
    }

    // MARK: - Mutations

    @Test("insertItem(after:) places new item at correct position")
    func insertItemAfter() {
        let doc = makeDoc()
        let newItem = TaskItem(type: .task, content: "Inserted")
        let task1 = doc.items[0].children[0]
        doc.insertItem(newItem, after: task1)
        #expect(doc.items[0].children[1].content == "Inserted")
        #expect(doc.hasUnsavedChanges)
    }

    @Test("insertItem(before:) places new item before target")
    func insertItemBefore() {
        let doc = makeDoc()
        let newItem = TaskItem(type: .task, content: "Before")
        let task1 = doc.items[0].children[0]
        doc.insertItem(newItem, before: task1)
        #expect(doc.items[0].children[0].content == "Before")
    }

    @Test("appendItem adds at root level")
    func appendItem() {
        let doc = makeDoc()
        let newItem = TaskItem(type: .note, content: "Footer note")
        let countBefore = doc.items.count
        doc.appendItem(newItem)
        #expect(doc.items.count == countBefore + 1)
        #expect(doc.items.last?.content == "Footer note")
    }

    @Test("removeItem removes from the tree")
    func removeItem() {
        let doc = makeDoc()
        let task1 = doc.items[0].children[0]
        doc.removeItem(task1)
        #expect(!doc.items[0].children.contains { $0.id == task1.id })
        #expect(task1.parent == nil)
        #expect(doc.hasUnsavedChanges)
    }

    @Test("indentItem makes item a child of previous sibling")
    func indentItem() {
        let doc = makeDoc()
        let task2 = doc.items[0].children[1] // Task 2
        doc.indentItem(task2)
        // Task 2 should now be a child of Task 1
        let task1 = doc.items[0].children[0]
        #expect(task1.children.contains { $0.id == task2.id })
        #expect(task2.indentLevel == task1.indentLevel + 1)
    }

    @Test("outdentItem moves item up one level")
    func outdentItem() {
        let doc = makeDoc()
        let subtask = doc.items[0].children[0].children[0] // Subtask 1a
        let originalLevel = subtask.indentLevel
        doc.outdentItem(subtask)
        #expect(subtask.indentLevel < originalLevel)
        #expect(subtask.parent?.content == "Project A")
    }

    @Test("moveItem rejects moving an item inside its own subtree")
    func moveItemRejectsDescendantAsParent() {
        let doc = makeDoc()
        let project = doc.items[0]
        let descendant = project.children[0].children[0]

        doc.moveItem(project, toParent: descendant, atIndex: 0)

        #expect(doc.items.first?.id == project.id)
        #expect(descendant.parent?.id == project.children[0].id)
    }
}
