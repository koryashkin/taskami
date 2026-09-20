import Foundation
import Observation

@Observable
final class TaskItem: Identifiable {
    let id: UUID
    var type: ItemType
    var content: String
    var tags: [Tag]
    var indentLevel: Int
    var children: [TaskItem]
    weak var parent: TaskItem?

    init(
        id: UUID = UUID(),
        type: ItemType = .note,
        content: String = "",
        tags: [Tag] = [],
        indentLevel: Int = 0,
        children: [TaskItem] = [],
        parent: TaskItem? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.tags = tags
        self.indentLevel = indentLevel
        self.children = children
        self.parent = parent
        for child in children {
            child.parent = self
        }
    }

    var isCollapsed: Bool = false

    var isBlank: Bool {
        content.trimmingCharacters(in: .whitespaces).isEmpty && tags.isEmpty
    }

    var isDone: Bool {
        tags.contains { $0.name.lowercased() == "done" }
    }

    func tag(named name: String) -> Tag? {
        tags.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    func addTag(_ tag: Tag) {
        if self.tag(named: tag.name) == nil {
            tags.append(tag)
            rebuildContent(addingTag: tag)
        }
    }

    func removeTag(named name: String) {
        let matchingRanges = TagParser.parseTagsWithRanges(in: content)
            .compactMap { parsed -> Range<String.Index>? in
                parsed.tag.name.caseInsensitiveCompare(name) == .orderedSame ? parsed.range : nil
            }
        guard !matchingRanges.isEmpty else { return }

        // Remove ranges from the end so earlier String indices remain valid.
        // Include one adjacent separator where available, while matching only
        // parsed tags so @done never damages text such as @doneLater.
        for tagRange in matchingRanges.reversed() {
            var removalRange = tagRange
            if removalRange.lowerBound > content.startIndex {
                let previous = content.index(before: removalRange.lowerBound)
                if content[previous].isWhitespace {
                    removalRange = previous..<removalRange.upperBound
                }
            } else if removalRange.upperBound < content.endIndex,
                      content[removalRange.upperBound].isWhitespace {
                removalRange = removalRange.lowerBound..<content.index(after: removalRange.upperBound)
            }
            content.removeSubrange(removalRange)
        }

        tags = TagParser.parseTags(in: content)
    }

    func toggleDone(addDate: Bool = true) {
        if isDone {
            removeTag(named: "done")
        } else {
            let value = addDate ? TaskItem.dateFormatter.string(from: Date()) : nil
            addTag(Tag(name: "done", value: value))
        }
    }

    /// Fraction of descendant tasks that are @done. Returns nil if there are no task descendants.
    var completionProgress: Double? {
        let tasks = allDescendants.filter { $0.type == .task }
        guard !tasks.isEmpty else { return nil }
        let done = tasks.filter { $0.isDone }.count
        return Double(done) / Double(tasks.count)
    }

    /// Sum of @cost(N) tag numeric values across direct children. Returns nil if none have @cost.
    var aggregateCost: Double? {
        let costs = children.compactMap { $0.tag(named: "cost")?.numberValue }
        guard !costs.isEmpty else { return nil }
        return costs.reduce(0, +)
    }

    /// All descendants in depth-first order (not including self).
    var allDescendants: [TaskItem] {
        var result: [TaskItem] = []
        for child in children {
            result.append(child)
            result.append(contentsOf: child.allDescendants)
        }
        return result
    }

    /// All descendants in depth-first order, including self.
    var selfAndDescendants: [TaskItem] {
        var result: [TaskItem] = [self]
        for child in children {
            result.append(contentsOf: child.selfAndDescendants)
        }
        return result
    }

    /// All ancestor items from parent to root.
    var ancestors: [TaskItem] {
        var result: [TaskItem] = []
        var current = parent
        while let p = current {
            result.append(p)
            current = p.parent
        }
        return result
    }

    /// The containing project (nearest ancestor or self that is a project).
    var containingProject: TaskItem? {
        if type == .project { return self }
        return parent?.containingProject
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func rebuildContent(addingTag tag: Tag) {
        let tagStr = tag.description
        if content.isEmpty {
            content = tagStr
        } else {
            content = content + " " + tagStr
        }
    }

}

extension TaskItem: Equatable {
    static func == (lhs: TaskItem, rhs: TaskItem) -> Bool {
        lhs.id == rhs.id
    }
}

extension TaskItem: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
