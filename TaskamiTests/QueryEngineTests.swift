import Testing
@testable import Taskami

@Suite("QueryEngine Tests")
struct QueryEngineTests {

    // Helper to create a test document
    private func sampleItems() -> [TaskItem] {
        let text = """
        Inbox:
        \t- Buy milk @today
        \t- Walk dog @done(2025-04-04)
        \t- Fix bug @priority(1)
        Home:
        \t- Clean house @priority(2)
        \t- Mow lawn
        """
        return TaskPaperParser.parse(text)
    }

    private func allItems() -> [TaskItem] {
        var result: [TaskItem] = []
        for item in sampleItems() {
            result.append(contentsOf: item.selfAndDescendants)
        }
        return result
    }

    // MARK: - Simple Value Search

    @Test("Search by text content")
    func searchByText() {
        let filter = QueryEngine.compile("milk")
        let matches = allItems().filter(filter)
        #expect(matches.count == 1)
        #expect(matches[0].content.contains("milk"))
    }

    @Test("Search is case insensitive")
    func searchCaseInsensitive() {
        let filter = QueryEngine.compile("MILK")
        let matches = allItems().filter(filter)
        #expect(matches.count == 1)
    }

    // MARK: - Tag Search

    @Test("Search for tag existence")
    func searchTagExists() {
        let filter = QueryEngine.compile("@today")
        let matches = allItems().filter(filter)
        #expect(matches.count == 1)
        #expect(matches[0].content.contains("Buy milk"))
    }

    @Test("Search for @done tag")
    func searchDoneTag() {
        let filter = QueryEngine.compile("@done")
        let matches = allItems().filter(filter)
        #expect(matches.count == 1)
        #expect(matches[0].content.contains("Walk dog"))
    }

    // MARK: - Attribute Search

    @Test("Search by type")
    func searchByType() {
        let filter = QueryEngine.compile("type = project")
        let matches = allItems().filter(filter)
        #expect(matches.count == 2)
        #expect(matches.allSatisfy { $0.type == .project })
    }

    @Test("Search by type task")
    func searchByTypeTask() {
        let filter = QueryEngine.compile("type = task")
        let matches = allItems().filter(filter)
        #expect(matches.allSatisfy { $0.type == .task })
    }

    // MARK: - Tag with Relation

    @Test("Search tag with numeric comparison")
    func searchTagNumericComparison() {
        let filter = QueryEngine.compile("@priority > 1")
        let matches = allItems().filter(filter)
        #expect(matches.count == 1)
        #expect(matches[0].content.contains("Clean house"))
    }

    @Test("Search tag with equals")
    func searchTagEquals() {
        let filter = QueryEngine.compile("@priority = 1")
        let matches = allItems().filter(filter)
        #expect(matches.count == 1)
        #expect(matches[0].content.contains("Fix bug"))
    }

    // MARK: - Boolean Logic

    @Test("AND query")
    func andQuery() {
        let filter = QueryEngine.compile("@priority and @done")
        let matches = allItems().filter(filter)
        #expect(matches.isEmpty) // no item has both
    }

    @Test("OR query")
    func orQuery() {
        let filter = QueryEngine.compile("@today or @done")
        let matches = allItems().filter(filter)
        #expect(matches.count == 2)
    }

    @Test("NOT query")
    func notQuery() {
        let filter = QueryEngine.compile("not @done")
        let matches = allItems().filter(filter)
        // All items except "Walk dog" should match
        let total = allItems().count
        #expect(matches.count == total - 1)
    }

    // MARK: - Project Search

    @Test("Search by project")
    func searchByProject() {
        let filter = QueryEngine.compile("project = Inbox")
        let matches = allItems().filter(filter)
        // Should match the Inbox project itself and its children
        #expect(matches.count >= 1)
        #expect(matches.contains { $0.content == "Inbox" || $0.ancestors.contains { $0.content == "Inbox" } })
    }

    // MARK: - Parentheses

    @Test("Grouped expression")
    func groupedExpression() {
        let filter = QueryEngine.compile("(@today or @done) and type = task")
        let matches = allItems().filter(filter)
        #expect(matches.count == 2) // Buy milk and Walk dog
        #expect(matches.allSatisfy { $0.type == .task })
    }

    // MARK: - Empty Query

    @Test("Empty query matches all")
    func emptyQueryMatchesAll() {
        let filter = QueryEngine.compile("")
        let matches = allItems().filter(filter)
        #expect(matches.count == allItems().count)
    }

    // MARK: - Date Comparison Queries

    private func dateItems() -> [TaskItem] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = DateTagParser.formatDate(cal.date(byAdding: .day, value: -1, to: today)!)
        let todayStr = DateTagParser.formatDate(today)
        let nextWeek = DateTagParser.formatDate(cal.date(byAdding: .day, value: 7, to: today)!)
        let text = """
        - Overdue task @due(\(yesterday))
        - Today task @due(\(todayStr))
        - Future task @due(\(nextWeek))
        - No due task
        """
        return TaskPaperParser.parse(text).flatMap { $0.selfAndDescendants }
    }

    @Test("@due < today matches only overdue items")
    func dueLessThanToday() {
        let filter = QueryEngine.compile("@due < today")
        let matches = dateItems().filter(filter)
        #expect(matches.count == 1)
        #expect(matches[0].content.contains("Overdue"))
    }

    @Test("@due = today matches today's item")
    func dueEqualsToday() {
        let filter = QueryEngine.compile("@due = today")
        let matches = dateItems().filter(filter)
        #expect(matches.count == 1)
        #expect(matches[0].content.contains("Today"))
    }

    @Test("@due > today matches only future items")
    func dueGreaterThanToday() {
        let filter = QueryEngine.compile("@due > today")
        let matches = dateItems().filter(filter)
        #expect(matches.count == 1)
        #expect(matches[0].content.contains("Future"))
    }

    @Test("@due <= today matches overdue and today")
    func dueLessOrEqualToday() {
        let filter = QueryEngine.compile("@due <= today")
        let matches = dateItems().filter(filter)
        #expect(matches.count == 2)
    }

    @Test("@due < tomorrow matches overdue and today")
    func dueLessThanTomorrow() {
        let filter = QueryEngine.compile("@due < tomorrow")
        let matches = dateItems().filter(filter)
        #expect(matches.count == 2)
    }

    @Test("@due matches items that have any @due tag")
    func dueTagExists() {
        let filter = QueryEngine.compile("@due")
        let matches = dateItems().filter(filter)
        #expect(matches.count == 3) // all except "No due task"
    }

    @Test("Date query does not match items without @due tag")
    func dueLessThanTodayNoMatch() {
        let filter = QueryEngine.compile("@due < today")
        let noDueTasks = [TaskItem(type: .task, content: "No due")]
        #expect(noDueTasks.filter(filter).isEmpty)
    }

    // MARK: - Tokenizer

    @Test("Tokenize simple query")
    func tokenizeSimple() {
        let tokens = QueryTokenizer.tokenize("@done")
        #expect(tokens.count == 1)
        #expect(tokens[0] == .word("@done"))
    }

    @Test("Tokenize complex query")
    func tokenizeComplex() {
        let tokens = QueryTokenizer.tokenize("@priority >= 1 and not @done")
        #expect(tokens.contains(.word("@priority")))
        #expect(tokens.contains(.symbol(">=")))
        #expect(tokens.contains(.word("1")))
        #expect(tokens.contains(.word("and")))
        #expect(tokens.contains(.word("not")))
        #expect(tokens.contains(.word("@done")))
    }

    @Test("Tokenize quoted string")
    func tokenizeQuotedString() {
        let tokens = QueryTokenizer.tokenize("content = \"hello world\"")
        #expect(tokens.contains(.quotedString("hello world")))
    }

    @Test("Tokenize parentheses")
    func tokenizeParens() {
        let tokens = QueryTokenizer.tokenize("(@done or @today)")
        #expect(tokens[0] == .leftParen)
        #expect(tokens[tokens.count - 1] == .rightParen)
    }
}
