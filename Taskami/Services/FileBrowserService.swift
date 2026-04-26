import Foundation
import Observation

@Observable
final class FileBrowserService {

    enum SortOrder: String, CaseIterable {
        case nameAscending = "Name (A-Z)"
        case nameDescending = "Name (Z-A)"
        case modifiedNewest = "Modified (Newest)"
        case modifiedOldest = "Modified (Oldest)"
    }

    var currentDirectory: URL
    var items: [FileItem] = []
    var sortOrder: SortOrder = .nameAscending
    var isLoading: Bool = false

    private let fileManager = FileManager.default

    init(directory: URL) {
        self.currentDirectory = directory
        refresh()
    }

    func navigate(to directory: URL) {
        currentDirectory = directory
        refresh()
    }

    func refresh() {
        isLoading = true
        defer { isLoading = false }

        let resourceKeys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .contentModificationDateKey,
            .nameKey
        ]

        guard let urls = try? fileManager.contentsOfDirectory(
            at: currentDirectory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            items = []
            return
        }

        var fileItems: [FileItem] = urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: resourceKeys) else { return nil }

            let isDir = values.isDirectory ?? false
            let ext = url.pathExtension.lowercased()

            // Only show directories and text/taskpaper files
            guard isDir || ext == "taskpaper" || ext == "txt" else { return nil }

            return FileItem(
                name: url.lastPathComponent,
                url: url,
                isDirectory: isDir,
                modificationDate: values.contentModificationDate
            )
        }

        // Sort: directories first, then by sort order
        fileItems.sort { a, b in
            if a.isDirectory != b.isDirectory {
                return a.isDirectory
            }
            return compareBySortOrder(a, b)
        }

        items = fileItems
    }

    func createFile(named name: String) throws -> URL {
        var fileName = name
        if !fileName.hasSuffix(".taskpaper") {
            fileName += ".taskpaper"
        }
        let url = currentDirectory.appendingPathComponent(fileName)
        let defaultContent = Bundle.main.url(forResource: "DefaultTaskList", withExtension: "taskpaper")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        try defaultContent.write(to: url, atomically: true, encoding: .utf8)
        refresh()
        return url
    }

    func createFolder(named name: String) throws -> URL {
        let url = currentDirectory.appendingPathComponent(name)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: false)
        refresh()
        return url
    }

    func deleteItem(at url: URL) throws {
        try fileManager.removeItem(at: url)
        refresh()
    }

    func renameItem(at url: URL, to newName: String) throws -> URL {
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        try fileManager.moveItem(at: url, to: newURL)
        refresh()
        return newURL
    }

    // MARK: - Private

    private func compareBySortOrder(_ a: FileItem, _ b: FileItem) -> Bool {
        switch sortOrder {
        case .nameAscending:
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        case .nameDescending:
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedDescending
        case .modifiedNewest:
            return (a.modificationDate ?? .distantPast) > (b.modificationDate ?? .distantPast)
        case .modifiedOldest:
            return (a.modificationDate ?? .distantPast) < (b.modificationDate ?? .distantPast)
        }
    }

    // MARK: - iCloud Container

    /// Returns the iCloud container URL, or falls back to local Documents.
    static func defaultDirectory() -> URL {
        if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents") {
            // Ensure directory exists
            try? FileManager.default.createDirectory(at: iCloudURL, withIntermediateDirectories: true)
            return iCloudURL
        }

        // Fallback to local Documents
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}
