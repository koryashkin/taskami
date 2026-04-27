import Foundation
import Testing
@testable import Taskami

@Suite("TaskPaperParser Tests")
struct TaskPaperParserTests {

    // MARK: - Single Line Parsing

    @Test("Parse task line")
    func parseTaskLine() {
        let item = TaskPaperParser.parseLine("- Buy milk")
        #expect(item.type == .task)
        #expect(item.content == "Buy milk")
        #expect(item.indentLevel == 0)
    }

    @Test("Parse project line")
    func parseProjectLine() {
        let item = TaskPaperParser.parseLine("Inbox:")
        #expect(item.type == .project)
        #expect(item.content == "Inbox")
        #expect(item.indentLevel == 0)
    }

    @Test("Parse note line")
    func parseNoteLine() {
        let item = TaskPaperParser.parseLine("Just a note")
        #expect(item.type == .note)
        #expect(item.content == "Just a note")
        #expect(item.indentLevel == 0)
    }

    @Test("Parse indented task")
    func parseIndentedTask() {
        let item = TaskPaperParser.parseLine("\t\t- Subtask")
        #expect(item.type == .task)
        #expect(item.content == "Subtask")
        #expect(item.indentLevel == 2)
    }

    @Test("Parse task with tags")
    func parseTaskWithTags() {
        let item = TaskPaperParser.parseLine("- Buy milk @today @priority(1)")
        #expect(item.type == .task)
        #expect(item.content == "Buy milk @today @priority(1)")
        #expect(item.tags.count == 2)
        #expect(item.tags[0].name == "today")
        #expect(item.tags[1].name == "priority")
        #expect(item.tags[1].value == "1")
    }

    @Test("Parse project with tags")
    func parseProjectWithTags() {
        let item = TaskPaperParser.parseLine("Home: @due(2025-04-04)")
        #expect(item.type == .project)
        // Content should include the tag but not the ":"
        #expect(item.content.contains("@due"))
    }

    @Test("Parse empty line")
    func parseEmptyLine() {
        let item = TaskPaperParser.parseLine("")
        #expect(item.type == .note)
        #expect(item.content == "")
        #expect(item.isBlank)
    }

    @Test("Parse task with no content")
    func parseEmptyTask() {
        let item = TaskPaperParser.parseLine("- ")
        #expect(item.type == .task)
    }

    // MARK: - Full Document Parsing

    @Test("Parse multi-line document")
    func parseDocument() {
        let text = """
        Inbox:
        \t- Buy milk
        \t- Walk dog @today
        Home:
        \t- Clean house
        \t\t- Kitchen
        \t\t- Bathroom
        """
        let items = TaskPaperParser.parse(text)

        // Should have 2 top-level items (Inbox and Home projects)
        #expect(items.count == 2)
        #expect(items[0].type == .project)
        #expect(items[0].content == "Inbox")
        #expect(items[0].children.count == 2)
        #expect(items[0].children[0].content == "Buy milk")
        #expect(items[0].children[1].content == "Walk dog @today")

        #expect(items[1].type == .project)
        #expect(items[1].content == "Home")
        #expect(items[1].children.count == 1)
        #expect(items[1].children[0].content == "Clean house")
        #expect(items[1].children[0].children.count == 2)
    }

    @Test("Parse preserves parent references")
    func parseParentReferences() {
        let text = "Project:\n\t- Task\n\t\t- Subtask"
        let items = TaskPaperParser.parse(text)

        let project = items[0]
        let task = project.children[0]
        let subtask = task.children[0]

        #expect(task.parent === project)
        #expect(subtask.parent === task)
        #expect(project.parent == nil)
    }

    @Test("Tree building with mixed indentation")
    func treeBuildingMixedIndent() {
        let text = "A:\n\tB:\n\t\t- C\n\t- D\nE:"
        let items = TaskPaperParser.parse(text)

        #expect(items.count == 2) // A and E at root
        #expect(items[0].children.count == 2) // B and D are children of A
        #expect(items[0].children[0].children.count == 1) // C is child of B
    }
}
