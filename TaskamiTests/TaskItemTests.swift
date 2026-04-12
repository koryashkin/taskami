import Testing
@testable import Taskami

@Suite("TaskItem Tests")
struct TaskItemTests {

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
}
