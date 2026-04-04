import Foundation

struct TaskPaperParser {

    /// Parse a complete .taskpaper file string into a tree of TaskItems.
    /// Returns the top-level items with children properly nested based on indentation.
    static func parse(_ text: String) -> [TaskItem] {
        let lines = splitIntoLines(text)
        var flatItems: [TaskItem] = []

        for line in lines {
            flatItems.append(parseLine(line))
        }

        return buildTree(from: flatItems)
    }

    /// Parse a single line into a TaskItem (without tree relationships).
    /// Ported from TaskPaperSection.m setSelfString:
    static func parseLine(_ line: String) -> TaskItem {
        var s = line

        // Strip trailing newline/carriage return
        while s.hasSuffix("\n") || s.hasSuffix("\r") {
            s.removeLast()
        }

        let fullLength = s.count

        // Count leading tabs -> indent level
        var indentLevel = 0
        var idx = s.startIndex
        while idx < s.endIndex && s[idx] == "\t" {
            indentLevel += 1
            idx = s.index(after: idx)
        }

        // Content after tabs
        let afterTabs = String(s[idx...])
        let afterTabsLength = afterTabs.count

        // Detect trailing tags range (for type detection, tags are trimmed temporarily)
        let trailingRange = TagParser.trailingTagsRange(in: afterTabs)

        // Content without trailing tags (for type detection)
        let contentForTypeDetection: String
        if let trailingRange {
            contentForTypeDetection = String(afterTabs[afterTabs.startIndex..<trailingRange.lowerBound])
        } else {
            contentForTypeDetection = afterTabs
        }

        let type: ItemType
        let content: String

        if afterTabsLength >= 2 && afterTabs.hasPrefix("- ") {
            // Task: starts with "- "
            type = .task
            let afterDash = String(afterTabs.dropFirst(2))
            content = afterDash
        } else if !contentForTypeDetection.isEmpty && contentForTypeDetection.hasSuffix(":") {
            // Project: ends with ":"
            type = .project
            // Content includes everything except the structural ":" at the end
            // But tags that come after ":" are part of content
            if let trailingRange {
                let beforeColon = String(contentForTypeDetection.dropLast())
                let tagsStr = String(afterTabs[trailingRange])
                content = beforeColon + tagsStr
            } else {
                content = String(contentForTypeDetection.dropLast())
            }
        } else {
            // Note: everything else
            type = .note
            content = afterTabs
        }

        let tags = TagParser.parseTags(in: content)

        return TaskItem(
            type: type,
            content: content,
            tags: tags,
            indentLevel: indentLevel
        )
    }

    /// Build a tree from a flat list of indented items.
    static func buildTree(from flatItems: [TaskItem]) -> [TaskItem] {
        guard !flatItems.isEmpty else { return [] }

        var roots: [TaskItem] = []
        // Stack of (item, level) tracking the current ancestor chain
        var stack: [(item: TaskItem, level: Int)] = []

        for item in flatItems {
            let level = item.indentLevel

            // Pop stack until we find the parent (item at level - 1)
            while let last = stack.last, last.level >= level {
                stack.removeLast()
            }

            if let parentEntry = stack.last {
                item.parent = parentEntry.item
                parentEntry.item.children.append(item)
            } else {
                item.parent = nil
                roots.append(item)
            }

            stack.append((item, level))
        }

        return roots
    }

    /// Split text into lines preserving the line endings.
    private static func splitIntoLines(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }

        var lines: [String] = []
        text.enumerateLines { line, _ in
            lines.append(line)
        }

        // Handle empty document (produce at least one empty item)
        if lines.isEmpty {
            lines.append("")
        }

        return lines
    }
}
