import Foundation
import UIKit

struct HTMLExporter {

    enum Theme: String, CaseIterable, Identifiable {
        case white = "White"
        case black = "Black"
        case sepia = "Sepia"
        case gradient = "Gradient"

        var id: String { rawValue }

        var css: String {
            let base = """
            *{box-sizing:border-box;margin:0;padding:0}
            body{font-family:'Menlo','Monaco','Courier New',monospace;font-size:15px;line-height:1.75;padding:32px 24px;max-width:720px;margin:0 auto}
            .item{padding:1px 0;word-wrap:break-word}
            .project{font-weight:bold;margin-top:1.1em}
            .project:first-child{margin-top:0}
            .done{text-decoration:line-through}
            .tag{font-weight:500}
            """
            switch self {
            case .white:
                return base + "body{background:#fff;color:#222}.project{color:#111}.note{color:#666}.done{color:#999}.tag{color:#0a5dc2}"
            case .black:
                return base + "body{background:#111;color:#ccc}.project{color:#eee}.note{color:#888}.done{color:#555}.tag{color:#5ab4ff}"
            case .sepia:
                return base + "body{background:#f5f0e8;color:#3a3028}.project{color:#1f1812}.note{color:#7a6a5a}.done{color:#a89888}.tag{color:#8b5c2a}"
            case .gradient:
                return base + "body{background:linear-gradient(135deg,#f0f4ff 0%,#faf0ff 100%);color:#2c2c44}.project{color:#1a1a33}.note{color:#6a6a88}.done{color:#aaaacc}.tag{color:#5050cc}"
            }
        }
    }

    // MARK: - Export

    static func export(_ document: TaskDocument, theme: Theme) -> String {
        let title = escapeHTML(document.fileURL.deletingPathExtension().lastPathComponent)
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <title>\(title)</title>
        <style>\(theme.css)</style>
        </head>
        <body>
        <div class="document">
        \(renderItems(document.items, depth: 0))\
        </div>
        </body>
        </html>
        """
    }

    // MARK: - Rendering

    private static func renderItems(_ items: [TaskItem], depth: Int) -> String {
        items.map { renderItem($0, depth: depth) }.joined()
    }

    private static func renderItem(_ item: TaskItem, depth: Int) -> String {
        let indent = depth * 20
        let highlighted = highlightTagsHTML(escapeHTML(item.content))

        var classes = "item"
        let inner: String

        switch item.type {
        case .project:
            classes += " project"
            inner = "\(highlighted):"
        case .task:
            classes += " task"
            if item.isDone { classes += " done" }
            inner = "- \(highlighted)"
        case .note:
            classes += " note"
            inner = highlighted
        }

        var result = "<div class=\"\(classes)\" style=\"margin-left:\(indent)px\">\(inner)</div>\n"
        if !item.children.isEmpty {
            result += renderItems(item.children, depth: depth + 1)
        }
        return result
    }

    // MARK: - Helpers

    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func highlightTagsHTML(_ escaped: String) -> String {
        guard escaped.contains("@"),
              let regex = try? NSRegularExpression(pattern: #"@[^\s\(\)<>&"]+(?:\([^\)]*\))?"#) else {
            return escaped
        }
        var result = ""
        var lastEnd = escaped.startIndex
        for match in regex.matches(in: escaped, range: NSRange(escaped.startIndex..., in: escaped)) {
            guard let range = Range(match.range, in: escaped) else { continue }
            result += escaped[lastEnd..<range.lowerBound]
            result += "<span class=\"tag\">\(escaped[range])</span>"
            lastEnd = range.upperBound
        }
        result += escaped[lastEnd...]
        return result
    }
}
