import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct TodayTasksProvider: TimelineProvider {

    func placeholder(in context: Context) -> TodayTasksEntry {
        TodayTasksEntry(date: Date(), tasks: [
            .init(content: "Buy milk @due(today)", isDone: false, dueDate: Date()),
            .init(content: "Call dentist @due(today)", isDone: true, dueDate: Date()),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayTasksEntry) -> Void) {
        completion(TodayTasksEntry(date: Date(), tasks: WidgetDataStore.readTasks()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayTasksEntry>) -> Void) {
        let entry = TodayTasksEntry(date: Date(), tasks: WidgetDataStore.readTasks())
        // Refresh at midnight so the widget always shows today's tasks.
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86_400))
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

// MARK: - Entry

struct TodayTasksEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetDataStore.WidgetTask]
}

// MARK: - Widget Views

struct TodayTasksWidgetView: View {
    let entry: TodayTasksEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:  SmallView(entry: entry)
        case .systemMedium: MediumView(entry: entry)
        default:            MediumView(entry: entry)
        }
    }
}

private struct SmallView: View {
    let entry: TodayTasksEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Today", systemImage: "calendar")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            let pending = entry.tasks.filter { !$0.isDone }
            if pending.isEmpty {
                Text(entry.tasks.isEmpty ? "No tasks due today" : "All done!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity)
            } else {
                ForEach(pending.prefix(4), id: \.content) { task in
                    TaskRow(task: task)
                }
                if pending.count > 4 {
                    Text("+\(pending.count - 4) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .containerBackground(.background, for: .widget)
    }
}

private struct MediumView: View {
    let entry: TodayTasksEntry

    private var pending: [WidgetDataStore.WidgetTask] { entry.tasks.filter { !$0.isDone } }
    private var done: [WidgetDataStore.WidgetTask]    { entry.tasks.filter {  $0.isDone } }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Today's Tasks", systemImage: "calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !entry.tasks.isEmpty {
                    Text("\(done.count)/\(entry.tasks.count)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if entry.tasks.isEmpty {
                Text("No tasks due today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity)
            } else {
                let visible = Array((pending + done).prefix(6))
                ForEach(visible, id: \.content) { task in
                    TaskRow(task: task)
                }
                if entry.tasks.count > 6 {
                    Text("+\(entry.tasks.count - 6) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .containerBackground(.background, for: .widget)
    }
}

private struct TaskRow: View {
    let task: WidgetDataStore.WidgetTask

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(task.isDone ? Color.green : Color.secondary)
                .font(.system(size: 13))
            Text(task.cleanContent)
                .font(.caption)
                .lineLimit(1)
                .strikethrough(task.isDone, color: .secondary)
                .foregroundStyle(task.isDone ? Color.secondary : Color.primary)
        }
    }
}

// MARK: - Widget Declaration

@main
struct TodayTasksWidget: Widget {
    let kind = "TodayTasksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayTasksProvider()) { entry in
            TodayTasksWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Tasks")
        .description("Tasks due today from your Taskami documents.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
