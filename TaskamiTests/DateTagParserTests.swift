import Testing
import Foundation
@testable import Taskami

@Suite("DateTagParser Tests")
struct DateTagParserTests {

    private var cal: Calendar { Calendar.current }
    private var today: Date { cal.startOfDay(for: Date()) }

    // MARK: - ISO Parsing

    @Test("Parse valid ISO date")
    func parseISO() throws {
        let date = try #require(DateTagParser.parseDate(from: "2024-06-15"))
        let c = cal.dateComponents([.year, .month, .day], from: date)
        #expect(c.year == 2024)
        #expect(c.month == 6)
        #expect(c.day == 15)
    }

    @Test("Parse today")
    func parseToday() {
        #expect(DateTagParser.parseDate(from: "today") == today)
    }

    @Test("Parse tomorrow")
    func parseTomorrow() {
        let expected = cal.date(byAdding: .day, value: 1, to: today)
        #expect(DateTagParser.parseDate(from: "tomorrow") == expected)
    }

    @Test("Parse yesterday")
    func parseYesterday() {
        let expected = cal.date(byAdding: .day, value: -1, to: today)
        #expect(DateTagParser.parseDate(from: "yesterday") == expected)
    }

    @Test("Parse next week")
    func parseNextWeek() {
        let expected = cal.date(byAdding: .weekOfYear, value: 1, to: today)
        #expect(DateTagParser.parseDate(from: "next week") == expected)
    }

    @Test("Parse next month")
    func parseNextMonth() {
        let expected = cal.date(byAdding: .month, value: 1, to: today)
        #expect(DateTagParser.parseDate(from: "next month") == expected)
    }

    @Test("Parse in N days")
    func parseInNDays() {
        let expected = cal.date(byAdding: .day, value: 5, to: today)
        #expect(DateTagParser.parseDate(from: "in 5 days") == expected)
    }

    @Test("Parse in N weeks")
    func parseInNWeeks() {
        let expected = cal.date(byAdding: .weekOfYear, value: 2, to: today)
        #expect(DateTagParser.parseDate(from: "in 2 weeks") == expected)
    }

    @Test("Parse in N months")
    func parseInNMonths() {
        let expected = cal.date(byAdding: .month, value: 3, to: today)
        #expect(DateTagParser.parseDate(from: "in 3 months") == expected)
    }

    @Test("Parse singular form: in 1 day")
    func parseInOneDay() {
        let expected = cal.date(byAdding: .day, value: 1, to: today)
        #expect(DateTagParser.parseDate(from: "in 1 day") == expected)
    }

    @Test("Parse next weekday is strictly in the future")
    func parseNextWeekday() {
        // "next monday" should be 1–7 days from now
        if let date = DateTagParser.parseDate(from: "next monday") {
            let days = cal.dateComponents([.day], from: today, to: date).day ?? 0
            #expect(days >= 1)
            #expect(days <= 7)
            #expect(cal.component(.weekday, from: date) == 2) // Monday = 2
        }
    }

    @Test("Invalid strings return nil")
    func parseInvalid() {
        #expect(DateTagParser.parseDate(from: "not a date") == nil)
        #expect(DateTagParser.parseDate(from: "") == nil)
        #expect(DateTagParser.parseDate(from: "high") == nil)
        #expect(DateTagParser.parseDate(from: "12345") == nil)
    }

    @Test("Parsing is case-insensitive")
    func parseCaseInsensitive() {
        #expect(DateTagParser.parseDate(from: "Today") == today)
        #expect(DateTagParser.parseDate(from: "TOMORROW") != nil)
        #expect(DateTagParser.parseDate(from: "Next Week") != nil)
    }

    // MARK: - Format

    @Test("Format produces ISO yyyy-MM-dd string")
    func formatDate() {
        var c = DateComponents()
        c.year = 2024; c.month = 6; c.day = 15
        let date = cal.date(from: c)!
        #expect(DateTagParser.formatDate(date) == "2024-06-15")
    }

    @Test("Format and parse are inverse operations")
    func formatParseRoundTrip() {
        let iso = DateTagParser.formatDate(today)
        #expect(DateTagParser.parseDate(from: iso) == today)
    }

    // MARK: - Normalize content

    @Test("Normalize today in @due tag to ISO")
    func normalizeToday() {
        let content = "Buy milk @due(today)"
        let result = DateTagParser.normalizeContent(content)
        let iso = DateTagParser.formatDate(today)
        #expect(result == "Buy milk @due(\(iso))")
    }

    @Test("Normalize @start tag")
    func normalizeStart() {
        let content = "Task @start(tomorrow)"
        let result = DateTagParser.normalizeContent(content)
        let iso = DateTagParser.formatDate(cal.date(byAdding: .day, value: 1, to: today)!)
        #expect(result == "Task @start(\(iso))")
    }

    @Test("Normalize does not change ISO dates")
    func normalizeAlreadyISO() {
        let content = "Buy milk @due(2024-06-15)"
        #expect(DateTagParser.normalizeContent(content) == content)
    }

    @Test("Normalize does not touch @priority")
    func normalizeIgnoresOtherTags() {
        let content = "Task @priority(tomorrow)"
        #expect(DateTagParser.normalizeContent(content) == content)
    }

    @Test("Normalize multiple date tags back-to-front")
    func normalizeMultiple() {
        let todayISO = DateTagParser.formatDate(today)
        let tomorrowISO = DateTagParser.formatDate(cal.date(byAdding: .day, value: 1, to: today)!)
        let content = "Task @start(today) @due(tomorrow)"
        let result = DateTagParser.normalizeContent(content)
        #expect(result == "Task @start(\(todayISO)) @due(\(tomorrowISO))")
    }

    @Test("Normalize leaves unrecognized values unchanged")
    func normalizeUnknown() {
        let content = "Task @due(sometime)"
        #expect(DateTagParser.normalizeContent(content) == content)
    }

    // MARK: - insertOrUpdateDateTag

    @Test("Insert new @due tag when none exists")
    func insertNew() {
        let item = TaskItem(type: .task, content: "Buy milk")
        DateTagParser.insertOrUpdateDateTag(named: "due", date: today, in: item)
        let iso = DateTagParser.formatDate(today)
        #expect(item.content == "Buy milk @due(\(iso))")
        #expect(item.tag(named: "due")?.value == iso)
    }

    @Test("Insert @due on empty content")
    func insertOnEmpty() {
        let item = TaskItem(type: .task, content: "")
        DateTagParser.insertOrUpdateDateTag(named: "due", date: today, in: item)
        let iso = DateTagParser.formatDate(today)
        #expect(item.content == "@due(\(iso))")
    }

    @Test("Update existing @due tag replaces old value")
    func updateExisting() {
        let item = TaskItem(
            type: .task,
            content: "Buy milk @due(2020-01-01)",
            tags: [Tag(name: "due", value: "2020-01-01")]
        )
        DateTagParser.insertOrUpdateDateTag(named: "due", date: today, in: item)
        let iso = DateTagParser.formatDate(today)
        #expect(item.content.contains("@due(\(iso))"))
        #expect(!item.content.contains("2020-01-01"))
        #expect(item.tags.count == 1)
        #expect(item.tag(named: "due")?.value == iso)
    }

    // MARK: - Proximity

    @Test("Past date is overdue")
    func proximityOverdue() {
        let past = cal.date(byAdding: .day, value: -1, to: today)!
        #expect(DateTagParser.proximity(of: past) == .overdue)
    }

    @Test("Today is .today")
    func proximityToday() {
        #expect(DateTagParser.proximity(of: today) == .today)
    }

    @Test("5 days from now is upcoming")
    func proximityUpcoming() {
        let soon = cal.date(byAdding: .day, value: 5, to: today)!
        #expect(DateTagParser.proximity(of: soon) == .upcoming)
    }

    @Test("7 days from now is still upcoming")
    func proximityUpcomingBoundary() {
        let boundary = cal.date(byAdding: .day, value: 7, to: today)!
        #expect(DateTagParser.proximity(of: boundary) == .upcoming)
    }

    @Test("8 days from now is future")
    func proximityFuture() {
        let far = cal.date(byAdding: .day, value: 8, to: today)!
        #expect(DateTagParser.proximity(of: far) == .future)
    }

    @Test("30 days from now is future")
    func proximityFarFuture() {
        let far = cal.date(byAdding: .day, value: 30, to: today)!
        #expect(DateTagParser.proximity(of: far) == .future)
    }
}
