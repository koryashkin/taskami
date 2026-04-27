import Foundation
import WidgetKit

/// Shared storage between the app and the Today Tasks widget.
/// Data is written to an App Group UserDefaults so the widget extension can read it.
struct WidgetDataStore {

    static let appGroupID = "group.com.koryashkin.taskami"
    static let tasksKey = "widgetTodayTasks"

    struct WidgetTask: Codable {
        let content: String
        let isDone: Bool
        let dueDate: Date?

        var cleanContent: String {
            if let range = TagParser.trailingTagsRange(in: content) {
                return String(content[content.startIndex..<range.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
            }
            return content
        }
    }

    /// Write today's due tasks to the shared container and reload widget timelines.
    static func update(from document: TaskDocument) {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        let tasks: [WidgetTask] = document.allItems
            .filter { $0.type == .task }
            .compactMap { item -> WidgetTask? in
                guard let dueDate = item.tag(named: "due")?.dateValue,
                      dueDate >= today && dueDate < tomorrow else { return nil }
                return WidgetTask(content: item.content, isDone: item.isDone, dueDate: dueDate)
            }

        guard let defaults = UserDefaults(suiteName: appGroupID),
              let encoded = try? JSONEncoder().encode(tasks) else { return }
        defaults.set(encoded, forKey: tasksKey)

        WidgetCenter.shared.reloadTimelines(ofKind: "TodayTasksWidget")
    }

    /// Read today's tasks from the shared container (called by the widget extension).
    static func readTasks() -> [WidgetTask] {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: tasksKey),
              let tasks = try? JSONDecoder().decode([WidgetTask].self, from: data) else {
            return []
        }
        return tasks
    }
}
