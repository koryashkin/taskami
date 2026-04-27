import Testing
import Foundation
@testable import Taskami

@Suite("HTMLExporter Tests")
struct HTMLExporterTests {

    private func doc(text: String, name: String = "MyDoc") -> TaskDocument {
        TaskDocument(
            fileURL: URL(fileURLWithPath: "/tmp/\(name).taskpaper"),
            items: TaskPaperParser.parse(text)
        )
    }

    private func export(_ text: String, theme: HTMLExporter.Theme = .white) -> String {
        HTMLExporter.export(doc(text: text), theme: theme)
    }

    // MARK: - Document structure

    @Test("Output starts with DOCTYPE")
    func hasDOCTYPE() {
        #expect(export("- Task").hasPrefix("<!DOCTYPE html>"))
    }

    @Test("Output contains closing html tag")
    func hasClosingHTML() {
        #expect(export("- Task").hasSuffix("</html>\n") || export("- Task").contains("</html>"))
    }

    @Test("Title uses file name without extension")
    func titleFromFileName() {
        let html = HTMLExporter.export(doc(text: "- Task", name: "Shopping List"), theme: .white)
        #expect(html.contains("<title>Shopping List</title>"))
    }

    @Test("Title escapes HTML characters")
    func titleEscaping() {
        let html = HTMLExporter.export(doc(text: "- Task", name: "A<B"), theme: .white)
        #expect(html.contains("A&lt;B"))
        #expect(!html.contains("<title>A<B</title>"))
    }

    // MARK: - Item types

    @Test("Projects get project class and colon suffix")
    func projectRendering() {
        let html = export("Project Alpha:\n\t- Task\n")
        #expect(html.contains("class=\"item project\""))
        #expect(html.contains("Project Alpha:"))
    }

    @Test("Tasks get task class and dash prefix")
    func taskRendering() {
        let html = export("- Buy milk\n")
        #expect(html.contains("class=\"item task\""))
        #expect(html.contains("- Buy milk"))
    }

    @Test("Done tasks get task and done classes")
    func doneTaskRendering() {
        let html = export("- Walk dog @done(2024-01-01)\n")
        #expect(html.contains("class=\"item task done\""))
        #expect(html.contains("- Walk dog"))
    }

    @Test("Notes get note class with no prefix")
    func noteRendering() {
        let html = export("A plain note\n")
        #expect(html.contains("class=\"item note\""))
        #expect(html.contains("A plain note"))
    }

    // MARK: - Nesting / indentation

    @Test("Child items have positive margin-left")
    func childIndent() {
        let html = export("Project:\n\t- Child task\n")
        #expect(html.contains("margin-left:20px"))
    }

    @Test("Deeply nested item has larger margin-left")
    func deepIndent() {
        let html = export("Project:\n\t- Task\n\t\t- Subtask\n")
        #expect(html.contains("margin-left:40px"))
    }

    @Test("Root items have zero margin-left")
    func rootIndent() {
        let html = export("- Root task\n")
        #expect(html.contains("margin-left:0px"))
    }

    // MARK: - Tag highlighting

    @Test("Tags wrapped in span.tag")
    func tagsHighlighted() {
        let html = export("- Task @done(2024-01-01)\n")
        #expect(html.contains("<span class=\"tag\">@done(2024-01-01)</span>"))
    }

    @Test("Multiple tags each wrapped")
    func multipleTagsHighlighted() {
        let html = export("- Task @priority(1) @today\n")
        #expect(html.contains("<span class=\"tag\">@priority(1)</span>"))
        #expect(html.contains("<span class=\"tag\">@today</span>"))
    }

    @Test("Content without tags has no span")
    func noTagsNoSpan() {
        let html = export("- Plain task\n")
        #expect(!html.contains("<span class=\"tag\">"))
    }

    // MARK: - HTML escaping

    @Test("Angle brackets in content are escaped")
    func angleBracketsEscaped() {
        let html = export("- Task <b>bold</b>\n")
        #expect(html.contains("&lt;b&gt;bold&lt;/b&gt;"))
        #expect(!html.contains("<b>bold</b>"))
    }

    @Test("Ampersand in content is escaped")
    func ampersandEscaped() {
        let html = export("- Salt & pepper\n")
        #expect(html.contains("Salt &amp; pepper"))
    }

    @Test("Quotes in content are escaped")
    func quotesEscaped() {
        let html = export("- Say \"hello\"\n")
        #expect(html.contains("&quot;hello&quot;"))
    }

    // MARK: - Themes

    @Test("All four themes produce valid HTML")
    func allThemesValid() {
        let document = doc(text: "Project:\n\t- Task @done\n\tNote\n")
        for theme in HTMLExporter.Theme.allCases {
            let html = HTMLExporter.export(document, theme: theme)
            #expect(html.hasPrefix("<!DOCTYPE html>"), "Theme \(theme.rawValue) missing DOCTYPE")
            #expect(html.contains("</html>"), "Theme \(theme.rawValue) missing </html>")
            #expect(html.contains("<style>"), "Theme \(theme.rawValue) missing <style>")
        }
    }

    @Test("White theme CSS contains white background")
    func whiteThemeBackground() {
        let html = HTMLExporter.export(doc(text: "- Task"), theme: .white)
        #expect(html.contains("#fff"))
    }

    @Test("Black theme CSS contains dark background")
    func blackThemeBackground() {
        let html = HTMLExporter.export(doc(text: "- Task"), theme: .black)
        #expect(html.contains("#111"))
    }

    @Test("Sepia theme CSS contains warm background color")
    func sepiaThemeBackground() {
        let html = HTMLExporter.export(doc(text: "- Task"), theme: .sepia)
        #expect(html.contains("#f5f0e8"))
    }

    @Test("Gradient theme CSS contains gradient")
    func gradientThemeCSS() {
        let html = HTMLExporter.export(doc(text: "- Task"), theme: .gradient)
        #expect(html.contains("linear-gradient"))
    }

    // MARK: - Edge cases

    @Test("Empty document produces valid HTML")
    func emptyDocument() {
        let html = HTMLExporter.export(doc(text: ""), theme: .white)
        #expect(html.hasPrefix("<!DOCTYPE html>"))
        #expect(html.contains("</html>"))
    }

    @Test("Project with no children renders correctly")
    func projectNoChildren() {
        let html = export("Empty Project:\n")
        #expect(html.contains("Empty Project:"))
        #expect(html.contains("class=\"item project\""))
    }

    @Test("All theme rawValues are non-empty")
    func themeRawValues() {
        for theme in HTMLExporter.Theme.allCases {
            #expect(!theme.rawValue.isEmpty)
            #expect(!theme.id.isEmpty)
        }
    }
}
