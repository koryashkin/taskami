import UIKit

struct TaskPaperTextHighlighter {
    var theme: EditorTheme
    var dueTintingEnabled: Bool = false

    /// Returns the cell background color for an item, applying a subtle tint for overdue/today @due tags.
    func cellBackgroundColor(for item: TaskItem) -> UIColor {
        guard dueTintingEnabled, let dueTag = item.tag(named: "due"), let dueDate = dueTag.dateValue else {
            return theme.backgroundColor.uiColor
        }
        switch DateTagParser.proximity(of: dueDate) {
        case .overdue:  return UIColor.systemRed.withAlphaComponent(0.10)
        case .today:    return UIColor.systemOrange.withAlphaComponent(0.10)
        default:        return theme.backgroundColor.uiColor
        }
    }

    /// Create an NSAttributedString for a TaskItem's display text.
    func highlight(_ item: TaskItem) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let baseFont = theme.font
        let content = item.content

        switch item.type {
        case .project:
            let projectFont = UIFont(descriptor: baseFont.fontDescriptor.withSymbolicTraits(.traitBold) ?? baseFont.fontDescriptor, size: baseFont.pointSize)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: projectFont,
                .foregroundColor: theme.projectColor.uiColor
            ]
            result.append(NSAttributedString(string: content, attributes: attrs))
            appendProjectStats(for: item, projectFont: projectFont, to: result)

        case .task:
            // Build the full display string and highlight tags within it
            let baseAttrs: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: item.isDone ? theme.doneColor.uiColor : theme.taskColor.uiColor
            ]

            if item.isDone {
                var doneAttrs = baseAttrs
                doneAttrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                doneAttrs[.strikethroughColor] = theme.doneColor.uiColor
                result.append(NSAttributedString(string: content, attributes: doneAttrs))
            } else {
                result.append(NSAttributedString(string: content, attributes: baseAttrs))
            }

            // Highlight tags
            highlightTags(in: result, content: content)

        case .note:
            let attrs: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: theme.noteColor.uiColor
            ]
            result.append(NSAttributedString(string: content, attributes: attrs))
        }

        return result
    }

    /// Apply tag-specific coloring to an attributed string.
    private func highlightTags(in attrString: NSMutableAttributedString, content: String) {
        let tagsWithRanges = TagParser.parseTagsWithRanges(in: content)
        for (tag, range) in tagsWithRanges {
            guard let nsRange = content.nsRange(from: range) else { continue }
            attrString.addAttribute(.foregroundColor, value: tagDisplayColor(for: tag), range: nsRange)
        }
    }

    /// Return the display color for a tag — date-aware for @due and @start.
    private func tagDisplayColor(for tag: Tag) -> UIColor {
        let name = tag.name.lowercased()
        guard (name == "due" || name == "start"), let date = tag.dateValue else {
            return theme.tagColor.uiColor
        }
        switch DateTagParser.proximity(of: date) {
        case .overdue:  return .systemRed
        case .today:    return .systemOrange
        case .upcoming: return .systemYellow
        case .future:   return theme.tagColor.uiColor
        }
    }

    /// Append a compact progress + cost summary line for project items that have task descendants.
    private func appendProjectStats(for item: TaskItem, projectFont: UIFont, to result: NSMutableAttributedString) {
        let progress = item.completionProgress
        let cost = item.aggregateCost
        guard progress != nil || cost != nil else { return }

        var parts: [String] = []

        if let progress {
            let total = item.allDescendants.filter { $0.type == .task }.count
            let done = Int(round(progress * Double(total)))
            let filled = Int(round(progress * 8))
            let bar = String(repeating: "▓", count: filled) + String(repeating: "░", count: 8 - filled)
            parts.append("\(bar) \(done)/\(total)")
        }

        if let cost {
            let formatted = cost.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(cost)) : String(cost)
            parts.append("@cost(\(formatted))")
        }

        let statsText = "\n" + parts.joined(separator: "  ")
        let smallFont = UIFont(descriptor: projectFont.fontDescriptor, size: projectFont.pointSize * 0.78)
        let statsAttrs: [NSAttributedString.Key: Any] = [
            .font: smallFont,
            .foregroundColor: theme.noteColor.uiColor
        ]
        result.append(NSAttributedString(string: statsText, attributes: statsAttrs))
    }
}

// MARK: - String Range Conversion Helper

extension String {
    func nsRange(from range: Range<String.Index>) -> NSRange? {
        guard let from = range.lowerBound.samePosition(in: utf16),
              let to = range.upperBound.samePosition(in: utf16) else { return nil }
        return NSRange(location: utf16.distance(from: utf16.startIndex, to: from),
                       length: utf16.distance(from: from, to: to))
    }
}
