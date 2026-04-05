import UIKit

struct TaskPaperTextHighlighter {
    var theme: EditorTheme

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

        // Apply indent via paragraph style
        if item.indentLevel > 0 || item.type == .task {
            let paragraph = NSMutableParagraphStyle()
            let indentPoints = CGFloat(item.indentLevel) * theme.indentWidth
            paragraph.headIndent = indentPoints
            paragraph.firstLineHeadIndent = indentPoints
            result.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: result.length))
        }

        return result
    }

    /// Apply tag-specific coloring to an attributed string.
    private func highlightTags(in attrString: NSMutableAttributedString, content: String) {
        let tagsWithRanges = TagParser.parseTagsWithRanges(in: content)
        for (_, range) in tagsWithRanges {
            guard let nsRange = content.nsRange(from: range) else { continue }
            attrString.addAttribute(.foregroundColor, value: theme.tagColor.uiColor, range: nsRange)
        }
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
