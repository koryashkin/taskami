import Foundation

struct FileItem: Identifiable, Hashable {
    var id: URL { url }
    var name: String
    var url: URL
    var isDirectory: Bool
    var modificationDate: Date?

    var isTaskPaperFile: Bool {
        url.pathExtension.lowercased() == "taskpaper"
    }

    var displayName: String {
        if isTaskPaperFile {
            return url.deletingPathExtension().lastPathComponent
        }
        return name
    }

    var icon: String {
        if isDirectory { return "folder.fill" }
        if isTaskPaperFile { return "doc.text.fill" }
        return "doc.fill"
    }
}
