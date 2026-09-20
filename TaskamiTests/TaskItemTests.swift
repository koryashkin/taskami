import Foundation
import Testing
import UIKit
@testable import Taskami

@Suite("TaskItem Tests")
struct TaskItemTests {

    @MainActor
    @Test("Editor cell disables autocorrection when the preference is off")
    func editorCellDisablesAutocorrection() {
        let cell = TaskItemCell(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        let item = TaskItem(type: .task, content: "Write release notes")
        cell.configure(
            with: item,
            highlighter: TaskPaperTextHighlighter(theme: .light),
            autocorrectionEnabled: false
        )

        cell.beginEditing(inputAccessoryView: nil)

        #expect(cell.editingTextView?.autocorrectionType == .no)
        cell.dismissEditing()
    }

    // MARK: - toggleDone

    @Test("Toggle done on undone task marks it done")
    func toggleDoneOn() {
        let item = TaskItem(type: .task, content: "Buy milk")
        #expect(!item.isDone)
        item.toggleDone(addDate: false)
        #expect(item.isDone)
        #expect(item.content.contains("@done"))
        #expect(item.tags.contains { $0.name == "done" })
    }

    @Test("Toggle done on already-done task removes @done tag")
    func toggleDoneOff() {
        let item = TaskItem(
            type: .task,
            content: "Buy milk @done(2026-04-12)",
            tags: [Tag(name: "done", value: "2026-04-12")]
        )
        #expect(item.isDone)
        item.toggleDone()
        #expect(!item.isDone)
        #expect(!item.content.contains("@done"))
        #expect(item.tags.isEmpty)
    }

    @Test("Toggle done twice returns to original content")
    func toggleDoneRoundTrip() {
        let original = "Buy milk"
        let item = TaskItem(type: .task, content: original)
        item.toggleDone(addDate: false)
        item.toggleDone()
        #expect(item.content == original)
        #expect(!item.isDone)
        #expect(item.tags.isEmpty)
    }

    // MARK: - done → undone (with date stamp)

    @Test("Toggle done with date then undone removes dated tag")
    func toggleDoneWithDateThenUndone() {
        let item = TaskItem(type: .task, content: "Buy milk")
        item.toggleDone(addDate: true)
        #expect(item.isDone)
        #expect(item.content.contains("@done("))
        #expect(item.tags.contains { $0.name == "done" && $0.value != nil })

        item.toggleDone()
        #expect(!item.isDone)
        #expect(!item.content.contains("@done"))
        #expect(item.tags.isEmpty)
    }

    @Test("Round-trip with date returns to original content")
    func toggleDoneWithDateRoundTrip() {
        let original = "Buy milk"
        let item = TaskItem(type: .task, content: original)
        item.toggleDone(addDate: true)
        item.toggleDone()
        #expect(item.content == original)
        #expect(!item.isDone)
        #expect(item.tags.isEmpty)
    }

    @Test("Undone then done marks item done again")
    func undoneThenDone() {
        let item = TaskItem(
            type: .task,
            content: "Buy milk @done(2026-04-12)",
            tags: [Tag(name: "done", value: "2026-04-12")]
        )
        #expect(item.isDone)

        // undo done
        item.toggleDone()
        #expect(!item.isDone)
        #expect(item.content == "Buy milk")
        #expect(item.tags.isEmpty)

        // mark done again
        item.toggleDone(addDate: false)
        #expect(item.isDone)
        #expect(item.content.contains("@done"))
        #expect(item.tags.contains { $0.name == "done" })
    }

    @Test("Removing done removes every duplicate done tag from content")
    func removingDuplicateDoneTagsRemovesAllOccurrences() {
        let item = TaskItem(
            type: .task,
            content: "Buy milk @done @done",
            tags: TagParser.parseTags(in: "Buy milk @done @done")
        )

        item.toggleDone()

        #expect(item.content == "Buy milk")
        #expect(item.tags.isEmpty)
        #expect(!item.isDone)
    }

    @Test("Removing done preserves similarly named tags")
    func removingDonePreservesSimilarTagNames() {
        let item = TaskItem(
            type: .task,
            content: "Buy milk @doneLater @done",
            tags: TagParser.parseTags(in: "Buy milk @doneLater @done")
        )

        item.toggleDone()

        #expect(item.content == "Buy milk @doneLater")
        #expect(item.tags == [Tag(name: "doneLater")])
        #expect(!item.isDone)
    }

    // MARK: - completionProgress

    @Test("completionProgress is nil for item with no task descendants")
    func completionProgressNoTasks() {
        let item = TaskItem(type: .project, content: "Empty")
        #expect(item.completionProgress == nil)
    }

    @Test("completionProgress is nil for item with only note descendants")
    func completionProgressOnlyNotes() {
        let parent = TaskItem(type: .project, content: "Project")
        let note = TaskItem(type: .note, content: "A note")
        note.parent = parent
        parent.children = [note]
        #expect(parent.completionProgress == nil)
    }

    @Test("completionProgress is 0.0 when no tasks are done")
    func completionProgressNone() {
        let parent = TaskItem(type: .project, content: "Project")
        let t1 = TaskItem(type: .task, content: "Task 1")
        let t2 = TaskItem(type: .task, content: "Task 2")
        t1.parent = parent; t2.parent = parent
        parent.children = [t1, t2]
        #expect(parent.completionProgress == 0.0)
    }

    @Test("completionProgress is 1.0 when all tasks are done")
    func completionProgressAll() {
        let parent = TaskItem(type: .project, content: "Project")
        let t1 = TaskItem(type: .task, content: "Task @done", tags: [Tag(name: "done")])
        t1.parent = parent
        parent.children = [t1]
        #expect(parent.completionProgress == 1.0)
    }

    @Test("completionProgress returns correct fraction")
    func completionProgressHalf() {
        let parent = TaskItem(type: .project, content: "Project")
        let done = TaskItem(type: .task, content: "Done @done", tags: [Tag(name: "done")])
        let todo = TaskItem(type: .task, content: "Todo")
        done.parent = parent; todo.parent = parent
        parent.children = [done, todo]
        #expect(parent.completionProgress == 0.5)
    }

    @Test("completionProgress counts nested task descendants")
    func completionProgressNested() {
        let parent = TaskItem(type: .project, content: "Project")
        let task = TaskItem(type: .task, content: "Task")
        let done = TaskItem(type: .task, content: "Done @done", tags: [Tag(name: "done")])
        task.parent = parent
        done.parent = task
        task.children = [done]
        parent.children = [task]
        // 1 done out of 2 total (task + done)
        #expect(parent.completionProgress == 0.5)
    }

    // MARK: - aggregateCost

    @Test("aggregateCost is nil when no children have @cost")
    func aggregateCostNil() {
        let parent = TaskItem(type: .project, content: "Project")
        let child = TaskItem(type: .task, content: "Task")
        child.parent = parent
        parent.children = [child]
        #expect(parent.aggregateCost == nil)
    }

    @Test("aggregateCost is nil for item with no children")
    func aggregateCostNoChildren() {
        let item = TaskItem(type: .project, content: "Empty")
        #expect(item.aggregateCost == nil)
    }

    @Test("aggregateCost sums @cost values from direct children")
    func aggregateCostSum() {
        let parent = TaskItem(type: .project, content: "Project")
        let c1 = TaskItem(type: .task, content: "Task @cost(10)", tags: [Tag(name: "cost", value: "10")])
        let c2 = TaskItem(type: .task, content: "Task @cost(5.5)", tags: [Tag(name: "cost", value: "5.5")])
        c1.parent = parent; c2.parent = parent
        parent.children = [c1, c2]
        #expect(parent.aggregateCost == 15.5)
    }

    @Test("aggregateCost ignores non-numeric @cost values")
    func aggregateCostIgnoresNonNumeric() {
        let parent = TaskItem(type: .project, content: "Project")
        let c1 = TaskItem(type: .task, content: "Task @cost(10)", tags: [Tag(name: "cost", value: "10")])
        let c2 = TaskItem(type: .task, content: "Task @cost(tbd)", tags: [Tag(name: "cost", value: "tbd")])
        c1.parent = parent; c2.parent = parent
        parent.children = [c1, c2]
        // Only the numeric one counts
        #expect(parent.aggregateCost == 10.0)
    }

    @Test("aggregateCost only sums direct children, not grandchildren")
    func aggregateCostDirectOnly() {
        let parent = TaskItem(type: .project, content: "Project")
        let child = TaskItem(type: .task, content: "Child @cost(5)", tags: [Tag(name: "cost", value: "5")])
        let grandchild = TaskItem(type: .task, content: "Grandchild @cost(100)", tags: [Tag(name: "cost", value: "100")])
        grandchild.parent = child
        child.children = [grandchild]
        child.parent = parent
        parent.children = [child]
        // Only child (5), not grandchild (100)
        #expect(parent.aggregateCost == 5.0)
    }
}
