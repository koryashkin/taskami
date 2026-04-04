import Foundation

struct LegacyImportService {

    /// Find existing .taskpaper files in the local Documents directory
    /// that could be imported to the iCloud container.
    static func findLegacyFiles() -> [URL] {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: documentsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.filter { $0.pathExtension.lowercased() == "taskpaper" }
    }

    /// Import a file from the local Documents directory to the iCloud container.
    static func importFile(from source: URL, to destinationDirectory: URL) throws -> URL {
        let destination = destinationDirectory.appendingPathComponent(source.lastPathComponent)

        // If file already exists at destination, add a suffix
        if FileManager.default.fileExists(atPath: destination.path) {
            let baseName = source.deletingPathExtension().lastPathComponent
            let ext = source.pathExtension
            let newName = "\(baseName) (imported).\(ext)"
            let altDestination = destinationDirectory.appendingPathComponent(newName)
            try FileManager.default.copyItem(at: source, to: altDestination)
            return altDestination
        }

        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    /// Import all legacy files to the given directory.
    static func importAll(to destinationDirectory: URL) -> [URL] {
        let files = findLegacyFiles()
        var imported: [URL] = []
        for file in files {
            if let url = try? importFile(from: file, to: destinationDirectory) {
                imported.append(url)
            }
        }
        return imported
    }
}
