import Foundation

/// Converts OPML outlines to TaskPaper format.
/// Outline nodes with children become projects; leaf nodes become tasks.
struct OPMLImporter {

    struct ImportResult {
        let suggestedTitle: String
        let taskPaperContent: String
    }

    enum ImportError: LocalizedError {
        case notOPML
        case xmlParseError(String)

        var errorDescription: String? {
            switch self {
            case .notOPML: return "The file does not appear to be a valid OPML document."
            case .xmlParseError(let msg): return "XML parse error: \(msg)"
            }
        }
    }

    static func importFrom(url: URL) throws -> ImportResult {
        let data = try Data(contentsOf: url)
        let parser = _OPMLXMLParser()
        let doc = try parser.parse(data)
        let title = doc.title.isEmpty
            ? url.deletingPathExtension().lastPathComponent
            : doc.title
        let content = renderTaskPaper(outlines: doc.body, level: 0)
        return ImportResult(suggestedTitle: title, taskPaperContent: content)
    }

    private static func renderTaskPaper(outlines: [_OPMLOutline], level: Int) -> String {
        let indent = String(repeating: "\t", count: level)
        var lines: [String] = []
        for outline in outlines {
            let text = outline.text
            if outline.children.isEmpty {
                lines.append("\(indent)- \(text)")
            } else {
                lines.append("\(indent)\(text):")
                let children = renderTaskPaper(outlines: outline.children, level: level + 1)
                if !children.isEmpty { lines.append(children) }
            }
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Internal XML model

private struct _OPMLDocument {
    var title: String = ""
    var body: [_OPMLOutline] = []
}

private struct _OPMLOutline {
    var text: String
    var children: [_OPMLOutline] = []
}

// MARK: - XMLParserDelegate

private final class _OPMLXMLParser: NSObject, XMLParserDelegate {

    private var doc = _OPMLDocument()
    private var stack: [_OPMLOutline] = []
    private var inHead = false
    private var inTitle = false
    private var inBody = false
    private var titleBuffer = ""
    private var parseError: Error?
    private var foundBody = false

    func parse(_ data: Data) throws -> _OPMLDocument {
        let p = XMLParser(data: data)
        p.delegate = self
        p.parse()
        if let err = parseError { throw OPMLImporter.ImportError.xmlParseError(err.localizedDescription) }
        guard foundBody else { throw OPMLImporter.ImportError.notOPML }
        return doc
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        switch name.lowercased() {
        case "head":  inHead = true
        case "title": if inHead { inTitle = true; titleBuffer = "" }
        case "body":  inBody = true; foundBody = true
        case "outline":
            guard inBody else { return }
            let text = attributes["text"] ?? attributes["_text"] ?? ""
            stack.append(_OPMLOutline(text: text))
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inTitle { titleBuffer += string }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
                qualifiedName: String?) {
        switch name.lowercased() {
        case "head": inHead = false
        case "title":
            if inTitle { doc.title = titleBuffer.trimmingCharacters(in: .whitespacesAndNewlines) }
            inTitle = false
        case "body": inBody = false
        case "outline":
            guard inBody, let finished = stack.popLast() else { return }
            if stack.isEmpty {
                doc.body.append(finished)
            } else {
                stack[stack.count - 1].children.append(finished)
            }
        default: break
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred error: Error) {
        parseError = error
    }
}
