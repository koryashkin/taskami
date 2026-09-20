import Foundation
import Observation

enum FileBrowserServiceError: LocalizedError {
    case invalidName
    case outsideCurrentDirectory

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Choose a non-empty file or folder name without path separators."
        case .outsideCurrentDirectory:
            return "This operation is limited to the current folder."
        }
    }
}

@Observable
final class FileBrowserService {
    private enum UITestEnvironment {
        static let directory = "TASKAMI_UI_TEST_DIRECTORY"
        static let seedFileName = "Test"
    }

    enum SortOrder: String, CaseIterable {
        case nameAscending = "Name (A-Z)"
        case nameDescending = "Name (Z-A)"
        case modifiedNewest = "Modified (Newest)"
        case modifiedOldest = "Modified (Oldest)"
    }

    var currentDirectory: URL
    var items: [FileItem] = []
    var sortOrder: SortOrder {
        didSet {
            guard oldValue != sortOrder else { return }
            refresh()
        }
    }
    var isLoading: Bool = false

    private let fileManager = FileManager.default

    init(directory: URL, sortOrder: SortOrder = .nameAscending) {
        self.currentDirectory = directory
        self.sortOrder = sortOrder
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
        var fileName = try validatedName(name)
        if !fileName.hasSuffix(".taskpaper") {
            fileName += ".taskpaper"
        }
        let url = currentDirectory.appendingPathComponent(fileName)
        try validateCurrentDirectoryChild(url)
        guard !fileManager.fileExists(atPath: url.path) else {
            throw CocoaError(.fileWriteFileExists, userInfo: [NSFilePathErrorKey: url.path])
        }
        let defaultContent = Bundle.main.url(forResource: "DefaultTaskList", withExtension: "taskpaper")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        try defaultContent.write(to: url, atomically: true, encoding: .utf8)
        refresh()
        return url
    }

    func createFolder(named name: String) throws -> URL {
        let url = currentDirectory.appendingPathComponent(try validatedName(name))
        try validateCurrentDirectoryChild(url)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: false)
        refresh()
        return url
    }

    func deleteItem(at url: URL) throws {
        try validateCurrentDirectoryChild(url)
        try fileManager.removeItem(at: url)
        refresh()
    }

    func renameItem(at url: URL, to newName: String) throws -> URL {
        try validateCurrentDirectoryChild(url)
        let newURL = currentDirectory.appendingPathComponent(try validatedName(newName))
        try validateCurrentDirectoryChild(newURL)
        try fileManager.moveItem(at: url, to: newURL)
        refresh()
        return newURL
    }

    // MARK: - Private

    private func validatedName(_ rawName: String) throws -> String {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              name != ".",
              name != "..",
              !name.contains("/"),
              !name.contains("\\") else {
            throw FileBrowserServiceError.invalidName
        }
        return name
    }

    private func validateCurrentDirectoryChild(_ url: URL) throws {
        let expectedParent = currentDirectory.standardizedFileURL
        let actualParent = url.deletingLastPathComponent().standardizedFileURL
        guard actualParent == expectedParent else {
            throw FileBrowserServiceError.outsideCurrentDirectory
        }
    }

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
        if let uiTestDirectory = uiTestDirectoryOverride() {
            ensureUITestSeedDocument(in: uiTestDirectory)
            return uiTestDirectory
        }

        if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents") {
            // Ensure directory exists
            try? FileManager.default.createDirectory(at: iCloudURL, withIntermediateDirectories: true)
            return iCloudURL
        }

        // Fallback to local Documents
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private static func uiTestDirectoryOverride() -> URL? {
        let env = ProcessInfo.processInfo.environment
        guard let rawPath = env[UITestEnvironment.directory], !rawPath.isEmpty else { return nil }

        let url = URL(fileURLWithPath: rawPath, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func ensureUITestSeedDocument(in directory: URL) {
        let fileManager = FileManager.default
        let visibleDocumentExtensions = Set(["taskpaper", "txt"])

        if let existing = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ),
           existing.contains(where: { visibleDocumentExtensions.contains($0.pathExtension.lowercased()) }) {
            return
        }

        let defaultContent = Bundle.main.url(forResource: "DefaultTaskList", withExtension: "taskpaper")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        let fileURL = directory.appendingPathComponent(UITestEnvironment.seedFileName).appendingPathExtension("taskpaper")
        try? defaultContent.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
