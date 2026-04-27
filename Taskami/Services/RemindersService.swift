import Foundation
import EventKit

/// One-way sync: exports tasks with @due dates from a TaskDocument to iOS Reminders.
/// All exported reminders are grouped in a "Taskami" calendar.
@MainActor
final class RemindersService {

    enum SyncResult {
        case success(created: Int, updated: Int)
        case denied
        case failed(String)

        var message: String {
            switch self {
            case .success(let c, let u):
                var parts: [String] = []
                if c > 0 { parts.append("\(c) created") }
                if u > 0 { parts.append("\(u) updated") }
                return parts.isEmpty ? "No tasks with @due dates found." : parts.joined(separator: ", ") + "."
            case .denied:
                return "Reminders access denied. Grant access in Settings → Privacy → Reminders."
            case .failed(let msg):
                return "Sync failed: \(msg)"
            }
        }
    }

    private let store = EKEventStore()

    // MARK: - Public API

    func sync(document: TaskDocument) async -> SyncResult {
        guard await requestAccess() else { return .denied }

        let calendar = findOrCreateCalendar()
        let existing = await fetchReminders(in: calendar)
        // Index by title for O(1) lookup — last writer wins if duplicates exist.
        var byTitle: [String: EKReminder] = [:]
        for reminder in existing {
            if let t = reminder.title { byTitle[t] = reminder }
        }

        let dueTasks = document.allItems.filter {
            $0.type == .task && $0.tag(named: "due") != nil
        }

        var created = 0, updated = 0
        for task in dueTasks {
            guard let dueDate = task.tag(named: "due")?.dateValue else { continue }
            let cleanTitle = task.content
            if let existing = byTitle[cleanTitle] {
                applyTask(task, dueDate: dueDate, to: existing)
                updated += 1
            } else {
                let reminder = EKReminder(eventStore: store)
                reminder.calendar = calendar
                applyTask(task, dueDate: dueDate, to: reminder)
                created += 1
            }
        }

        do {
            try store.commit()
            return .success(created: created, updated: updated)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - Private helpers

    private func requestAccess() async -> Bool {
        if #available(iOS 17, *) {
            return (try? await store.requestFullAccessToReminders()) ?? false
        }
        return await withCheckedContinuation { cont in
            store.requestAccess(to: .reminder) { granted, _ in
                cont.resume(returning: granted)
            }
        }
    }

    private func findOrCreateCalendar() -> EKCalendar {
        if let cal = store.calendars(for: .reminder).first(where: { $0.title == "Taskami" }) {
            return cal
        }
        let cal = EKCalendar(for: .reminder, eventStore: store)
        cal.title = "Taskami"
        cal.source = store.defaultCalendarForNewReminders()?.source
            ?? store.sources.first(where: { $0.sourceType == .local })
            ?? store.sources.first!
        try? store.saveCalendar(cal, commit: true)
        return cal
    }

    private func fetchReminders(in calendar: EKCalendar) async -> [EKReminder] {
        await withCheckedContinuation { cont in
            let pred = store.predicateForReminders(in: [calendar])
            store.fetchReminders(matching: pred) { cont.resume(returning: $0 ?? []) }
        }
    }

    private func applyTask(_ item: TaskItem, dueDate: Date, to reminder: EKReminder) {
        reminder.title = item.content
        reminder.isCompleted = item.isDone
        reminder.dueDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day], from: dueDate
        )
        try? store.save(reminder, commit: false)
    }
}
