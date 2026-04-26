import Foundation

struct DateTagParser {

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static var calendar: Calendar { Calendar.current }

    // MARK: - Parse

    /// Parse a date from a string. Supports:
    /// - ISO dates: "2024-01-15"
    /// - "today", "tomorrow", "yesterday"
    /// - "next monday" through "next sunday"
    /// - "next week", "next month"
    /// - "in N days", "in N weeks", "in N months"
    static func parseDate(from string: String) -> Date? {
        let s = string.trimmingCharacters(in: .whitespaces).lowercased()
        let today = calendar.startOfDay(for: Date())

        if let date = isoFormatter.date(from: s) {
            return calendar.startOfDay(for: date)
        }

        switch s {
        case "today":     return today
        case "tomorrow":  return calendar.date(byAdding: .day, value: 1, to: today)
        case "yesterday": return calendar.date(byAdding: .day, value: -1, to: today)
        default: break
        }

        if s.hasPrefix("next ") {
            let rest = String(s.dropFirst(5))
            let weekdays = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
                            "thursday": 5, "friday": 6, "saturday": 7]
            if let targetWeekday = weekdays[rest] {
                return nextWeekday(targetWeekday, after: today)
            }
            switch rest {
            case "week":  return calendar.date(byAdding: .weekOfYear, value: 1, to: today)
            case "month": return calendar.date(byAdding: .month, value: 1, to: today)
            default: break
            }
        }

        if s.hasPrefix("in ") {
            let parts = String(s.dropFirst(3)).components(separatedBy: " ")
            if parts.count == 2, let n = Int(parts[0]) {
                switch parts[1] {
                case "day", "days":     return calendar.date(byAdding: .day, value: n, to: today)
                case "week", "weeks":   return calendar.date(byAdding: .weekOfYear, value: n, to: today)
                case "month", "months": return calendar.date(byAdding: .month, value: n, to: today)
                default: break
                }
            }
        }

        return nil
    }

    private static func nextWeekday(_ weekday: Int, after today: Date) -> Date? {
        let current = calendar.component(.weekday, from: today)
        var daysAhead = weekday - current
        if daysAhead <= 0 { daysAhead += 7 }
        return calendar.date(byAdding: .day, value: daysAhead, to: today)
    }

    // MARK: - Format

    /// Format a Date to ISO "yyyy-MM-dd" string.
    static func formatDate(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }

    // MARK: - Normalize content

    /// Replace natural-language values in @due and @start tags with ISO dates.
    /// Processes from back-to-front to keep earlier string ranges valid after replacement.
    static func normalizeContent(_ content: String) -> String {
        let tagsWithRanges = TagParser.parseTagsWithRanges(in: content)
        var result = content

        for (tag, range) in tagsWithRanges.reversed() {
            let name = tag.name.lowercased()
            guard name == "due" || name == "start" else { continue }
            guard let value = tag.value else { continue }
            guard isoFormatter.date(from: value) == nil else { continue }
            guard let date = parseDate(from: value) else { continue }

            let newDescription = "@\(tag.name)(\(formatDate(date)))"
            result.replaceSubrange(range, with: newDescription)
        }

        return result
    }

    // MARK: - Insert / update date tag

    /// Insert or replace a @due or @start date tag value in an item.
    /// Updates both item.content and item.tags.
    static func insertOrUpdateDateTag(named tagName: String, date: Date, in item: TaskItem) {
        let isoDate = formatDate(date)

        if let existing = item.tag(named: tagName) {
            let oldDesc = existing.description
            let newDesc = "@\(tagName)(\(isoDate))"
            if let range = item.content.range(of: oldDesc) {
                item.content.replaceSubrange(range, with: newDesc)
            }
            if let idx = item.tags.firstIndex(where: { $0.name.caseInsensitiveCompare(tagName) == .orderedSame }) {
                item.tags[idx] = Tag(name: tagName, value: isoDate)
            }
        } else {
            let newTag = Tag(name: tagName, value: isoDate)
            item.content = item.content.isEmpty ? newTag.description : item.content + " " + newTag.description
            item.tags.append(newTag)
        }
    }

    // MARK: - Date proximity

    enum DateProximity {
        case overdue, today, upcoming, future
    }

    /// Classify a date relative to today. "upcoming" = within the next 7 days.
    static func proximity(of date: Date) -> DateProximity {
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0

        if days < 0  { return .overdue }
        if days == 0 { return .today }
        if days <= 7 { return .upcoming }
        return .future
    }
}
