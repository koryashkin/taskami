import Foundation
import Testing
@testable import Taskami

@Suite("TagParser Tests")
struct TagParserTests {

    @Test("Parse single tag without value")
    func parseSingleTagNoValue() {
        let tags = TagParser.parseTags(in: "Buy milk @today")
        #expect(tags.count == 1)
        #expect(tags[0].name == "today")
        #expect(tags[0].value == nil)
    }

    @Test("Parse single tag with value")
    func parseSingleTagWithValue() {
        let tags = TagParser.parseTags(in: "Fix bug @priority(1)")
        #expect(tags.count == 1)
        #expect(tags[0].name == "priority")
        #expect(tags[0].value == "1")
    }

    @Test("Parse done tag with date value")
    func parseDoneTagWithDate() {
        let tags = TagParser.parseTags(in: "Task @done(2025-04-04)")
        #expect(tags.count == 1)
        #expect(tags[0].name == "done")
        #expect(tags[0].value == "2025-04-04")
    }

    @Test("Parse multiple tags")
    func parseMultipleTags() {
        let tags = TagParser.parseTags(in: "Task @today @priority(1) @done")
        #expect(tags.count == 3)
        #expect(tags[0].name == "today")
        #expect(tags[1].name == "priority")
        #expect(tags[1].value == "1")
        #expect(tags[2].name == "done")
    }

    @Test("Parse no tags")
    func parseNoTags() {
        let tags = TagParser.parseTags(in: "Just a plain line")
        #expect(tags.isEmpty)
    }

    @Test("Parse empty string")
    func parseEmptyString() {
        let tags = TagParser.parseTags(in: "")
        #expect(tags.isEmpty)
    }

    @Test("Parse tag at start of string")
    func parseTagAtStart() {
        let tags = TagParser.parseTags(in: "@done")
        #expect(tags.count == 1)
        #expect(tags[0].name == "done")
    }

    @Test("Tag description without value")
    func tagDescriptionNoValue() {
        let tag = Tag(name: "today")
        #expect(tag.description == "@today")
    }

    @Test("Tag description with value")
    func tagDescriptionWithValue() {
        let tag = Tag(name: "priority", value: "1")
        #expect(tag.description == "@priority(1)")
    }

    @Test("Tag number value")
    func tagNumberValue() {
        let tag = Tag(name: "priority", value: "3")
        #expect(tag.numberValue == 3.0)
    }

    @Test("Tag number value with non-numeric")
    func tagNumberValueNonNumeric() {
        let tag = Tag(name: "due", value: "2025-04-04")
        #expect(tag.numberValue == nil)
    }

    @Test("Trailing tags range detection")
    func trailingTagsRange() {
        let str = "Buy milk @today @priority(1)"
        let range = TagParser.trailingTagsRange(in: str)
        #expect(range != nil)
        if let range {
            let trailingStr = String(str[range])
            #expect(trailingStr.contains("@today"))
            #expect(trailingStr.contains("@priority(1)"))
        }
    }

    @Test("No trailing tags range for no tags")
    func noTrailingTagsRange() {
        let range = TagParser.trailingTagsRange(in: "Just text")
        #expect(range == nil)
    }

    // MARK: - Tag.dateValue

    @Test("Tag.dateValue parses ISO date string")
    func tagDateValueISO() throws {
        let tag = Tag(name: "due", value: "2024-06-15")
        let date = try #require(tag.dateValue)
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        #expect(c.year == 2024)
        #expect(c.month == 6)
        #expect(c.day == 15)
    }

    @Test("Tag.dateValue parses natural language")
    func tagDateValueNaturalLanguage() {
        let tag = Tag(name: "due", value: "today")
        #expect(tag.dateValue == Calendar.current.startOfDay(for: Date()))
    }

    @Test("Tag.dateValue returns nil for non-date value")
    func tagDateValueNonDate() {
        let tag = Tag(name: "priority", value: "high")
        #expect(tag.dateValue == nil)
    }

    @Test("Tag.dateValue returns nil when value is nil")
    func tagDateValueNilValue() {
        let tag = Tag(name: "done")
        #expect(tag.dateValue == nil)
    }

    @Test("Tag.numberValue returns nil for date strings")
    func tagNumberValueForDateString() {
        let tag = Tag(name: "due", value: "2024-06-15")
        #expect(tag.numberValue == nil)
    }
}
