import UIKit

struct EditorTheme: Equatable, Codable {
    var fontName: String
    var fontSize: CGFloat
    var backgroundColor: CodableColor
    var textColor: CodableColor
    var projectColor: CodableColor
    var taskColor: CodableColor
    var tagColor: CodableColor
    var doneColor: CodableColor
    var noteColor: CodableColor
    var cursorColor: CodableColor
    var indentWidth: CGFloat

    var font: UIFont {
        UIFont(name: fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
    }

    // MARK: - Presets

    static let light = EditorTheme(
        fontName: "Menlo",
        fontSize: 15,
        backgroundColor: CodableColor(.systemBackground),
        textColor: CodableColor(.label),
        projectColor: CodableColor(.label),
        taskColor: CodableColor(.label),
        tagColor: CodableColor(.systemBlue),
        doneColor: CodableColor(.systemGray),
        noteColor: CodableColor(.secondaryLabel),
        cursorColor: CodableColor(.tintColor),
        indentWidth: 20
    )

    static let dark = EditorTheme(
        fontName: "Menlo",
        fontSize: 15,
        backgroundColor: CodableColor(red: 0.1, green: 0.1, blue: 0.12),
        textColor: CodableColor(red: 0.9, green: 0.9, blue: 0.9),
        projectColor: CodableColor(red: 0.95, green: 0.95, blue: 0.95),
        taskColor: CodableColor(red: 0.85, green: 0.85, blue: 0.85),
        tagColor: CodableColor(red: 0.4, green: 0.7, blue: 1.0),
        doneColor: CodableColor(red: 0.5, green: 0.5, blue: 0.5),
        noteColor: CodableColor(red: 0.6, green: 0.6, blue: 0.6),
        cursorColor: CodableColor(red: 0.4, green: 0.7, blue: 1.0),
        indentWidth: 20
    )

    static let sepia = EditorTheme(
        fontName: "Georgia",
        fontSize: 15,
        backgroundColor: CodableColor(red: 0.96, green: 0.93, blue: 0.87),
        textColor: CodableColor(red: 0.27, green: 0.22, blue: 0.17),
        projectColor: CodableColor(red: 0.2, green: 0.15, blue: 0.1),
        taskColor: CodableColor(red: 0.27, green: 0.22, blue: 0.17),
        tagColor: CodableColor(red: 0.55, green: 0.35, blue: 0.15),
        doneColor: CodableColor(red: 0.6, green: 0.55, blue: 0.48),
        noteColor: CodableColor(red: 0.45, green: 0.38, blue: 0.3),
        cursorColor: CodableColor(red: 0.55, green: 0.35, blue: 0.15),
        indentWidth: 20
    )
}
