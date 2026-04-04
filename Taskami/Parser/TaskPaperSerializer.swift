import Foundation

struct TaskPaperSerializer {

    /// Convert a tree of TaskItems back to a plain-text .taskpaper string.
    static func serialize(_ items: [TaskItem], lineEnding: String = "\n") -> String {
        var result = ""
        for item in items {
            serializeRecursive(item, into: &result, lineEnding: lineEnding)
        }
        return result
    }

    /// Serialize a single item and its descendants recursively.
    private static func serializeRecursive(_ item: TaskItem, into result: inout String, lineEnding: String) {
        result.append(serializeLine(item, lineEnding: lineEnding))
        for child in item.children {
            serializeRecursive(child, into: &result, lineEnding: lineEnding)
        }
    }

    /// Serialize a single item to its line representation (with line ending).
    /// Ported from TaskPaperSection.m writeSelfToString:includeTags:
    static func serializeLine(_ item: TaskItem, lineEnding: String = "\n") -> String {
        var line = ""

        // Leading tabs for indent level
        for _ in 0..<item.indentLevel {
            line.append("\t")
        }

        switch item.type {
        case .task:
            line.append("- ")
            line.append(item.content)

        case .project:
            // For projects, tags that are trailing need to go after the colon.
            // The content stores text without the ":" but may include tags.
            let trailingRange = TagParser.trailingTagsRange(in: item.content)
            if let trailingRange {
                let beforeTags = String(item.content[item.content.startIndex..<trailingRange.lowerBound])
                let tagsStr = String(item.content[trailingRange])
                line.append(beforeTags)
                line.append(":")
                line.append(tagsStr)
            } else {
                line.append(item.content)
                line.append(":")
            }

        case .note:
            line.append(item.content)
        }

        line.append(lineEnding)
        return line
    }
}
