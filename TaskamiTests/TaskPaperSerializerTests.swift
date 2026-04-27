import Foundation
import Testing
@testable import Taskami

@Suite("TaskPaperSerializer Tests")
struct TaskPaperSerializerTests {

    @Test("Serialize task")
    func serializeTask() {
        let item = TaskItem(type: .task, content: "Buy milk", indentLevel: 0)
        let line = TaskPaperSerializer.serializeLine(item)
        #expect(line == "- Buy milk\n")
    }

    @Test("Serialize project")
    func serializeProject() {
        let item = TaskItem(type: .project, content: "Inbox", indentLevel: 0)
        let line = TaskPaperSerializer.serializeLine(item)
        #expect(line == "Inbox:\n")
    }

    @Test("Serialize note")
    func serializeNote() {
        let item = TaskItem(type: .note, content: "Just a note", indentLevel: 0)
        let line = TaskPaperSerializer.serializeLine(item)
        #expect(line == "Just a note\n")
    }

    @Test("Serialize indented task")
    func serializeIndentedTask() {
        let item = TaskItem(type: .task, content: "Subtask", indentLevel: 2)
        let line = TaskPaperSerializer.serializeLine(item)
        #expect(line == "\t\t- Subtask\n")
    }

    @Test("Serialize project with tags")
    func serializeProjectWithTags() {
        let item = TaskItem(
            type: .project,
            content: "Home @due(2025-04-04)",
            tags: [Tag(name: "due", value: "2025-04-04")],
            indentLevel: 0
        )
        let line = TaskPaperSerializer.serializeLine(item)
        // Tags should come after the colon
        #expect(line.contains("Home:"))
        #expect(line.contains("@due(2025-04-04)"))
    }

    @Test("Serialize empty line")
    func serializeEmptyLine() {
        let item = TaskItem(type: .note, content: "", indentLevel: 0)
        let line = TaskPaperSerializer.serializeLine(item)
        #expect(line == "\n")
    }

    @Test("Round trip: parse then serialize")
    func roundTrip() {
        let original = """
        Inbox:
        \t- Buy milk @today
        \t- Walk dog @done(2025-04-04)
        Home:
        \t- Clean house
        \t\tNotes about cleaning
        \t- Fix leak @priority(1)

        """
        let items = TaskPaperParser.parse(original)
        let serialized = TaskPaperSerializer.serialize(items)

        #expect(serialized == original)
    }

    @Test("Round trip: simple task")
    func roundTripSimpleTask() {
        let original = "- Buy milk\n"
        let items = TaskPaperParser.parse(original)
        let serialized = TaskPaperSerializer.serialize(items)
        #expect(serialized == original)
    }

    @Test("Round trip: project with tags")
    func roundTripProjectWithTags() {
        let original = "Home: @due(2025-04-04)\n"
        let items = TaskPaperParser.parse(original)
        let serialized = TaskPaperSerializer.serialize(items)
        #expect(serialized == original)
    }

    @Test("Serialize tree with children")
    func serializeTree() {
        let child1 = TaskItem(type: .task, content: "Child 1", indentLevel: 1)
        let child2 = TaskItem(type: .task, content: "Child 2", indentLevel: 1)
        let parent = TaskItem(
            type: .project,
            content: "Parent",
            indentLevel: 0,
            children: [child1, child2]
        )

        let result = TaskPaperSerializer.serialize([parent])
        let expected = "Parent:\n\t- Child 1\n\t- Child 2\n"
        #expect(result == expected)
    }
}
