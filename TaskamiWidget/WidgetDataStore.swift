import Foundation
import WidgetKit

struct WidgetDataStore {

    static let appGroupID = "group.com.taskami.app"
    static let tasksKey = "widgetTodayTasks"

    struct WidgetTask: Codable {
        let content: String
        let isDone: Bool
        let dueDate: Date?

        var cleanContent: String {
            guard content.contains("@"),
                  let match = Self.trailingTagsRE.firstMatch(
                      in: content,
                      range: NSRange(content.startIndex..., in: content)),
                  let range = Range(match.range, in: content)
            else { return content }
            return content[content.startIndex..<range.lowerBound]
                .trimmingCharacters(in: .whitespaces)
        }

        private static let trailingTagsRE = try! NSRegularExpression(
            pattern: #"(?:(?:^|\s)@([^\(\s]*)(\([^\)]*\))?)+$"#)
    }

    static func readTasks() -> [WidgetTask] {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: tasksKey),
              let tasks = try? JSONDecoder().decode([WidgetTask].self, from: data)
        else { return [] }
        return tasks
    }
}
