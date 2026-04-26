import Foundation
import Observation
import OSLog

private let log = Logger(subsystem: "com.taskami", category: "DocumentService")

private struct FoldStateFile: Codable {
    var version: Int = 1
    var collapsedPaths: [[Int]]
}

@Observable
final class DocumentService {
    var currentDocument: TaskDocument?
    var isLoading: Bool = false
    var error: Error?

    private let fileCoordinator = FileCoordinatorService()
    private var filePresenter: DocumentFilePresenter?
    private var autosaveTask: Task<Void, Never>?

    /// Open a .taskpaper file: read, parse, set up file presenter.
    func open(url: URL) async throws -> TaskDocument {
        isLoading = true
        defer { isLoading = false }

        // Close any existing document
        close()

        let (content, encoding) = try await fileCoordinator.read(at: url)

        // Detect line ending
        let lineEnding = content.contains("\r\n") ? "\r\n" : "\n"

        let items = TaskPaperParser.parse(content)

        let document = TaskDocument(
            fileURL: url,
            items: items,
            encoding: encoding,
            lineEnding: lineEnding
        )

        // Set up file presenter for change monitoring
        let presenter = DocumentFilePresenter(url: url)
        presenter.onFileChanged = { [weak self] in
            Task { @MainActor in
                do {
                    try await self?.reloadFromDisk()
                } catch {
                    log.error("Failed to reload from disk: \(error)")
                }
            }
        }
        presenter.onConflictDetected = { _ in
            // Conflict handling will be wired up in the UI layer
        }
        presenter.startMonitoring()
        self.filePresenter = presenter

        loadAndApplyFoldState(for: document)
        currentDocument = document
        return document
    }

    /// Save the current document to disk.
    func save() async throws {
        guard let document = currentDocument else { return }

        let content = TaskPaperSerializer.serialize(document.items, lineEnding: document.lineEnding)
        try await fileCoordinator.write(content, to: document.fileURL, encoding: document.encoding)
        document.hasUnsavedChanges = false
    }

    /// Close: remove file presenter, clear state.
    func close() {
        autosaveTask?.cancel()
        autosaveTask = nil

        filePresenter?.stopMonitoring()
        filePresenter = nil

        currentDocument = nil
        error = nil
    }

    /// Schedule autosave with 1-second debounce.
    func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            do {
                try await self?.save()
            } catch {
                log.error("Autosave failed: \(error)")
            }
        }
    }

    /// Reload from disk (called when file presenter detects external change).
    func reloadFromDisk() async throws {
        guard let document = currentDocument else { return }

        let (content, encoding) = try await fileCoordinator.read(at: document.fileURL)
        let items = TaskPaperParser.parse(content)

        document.items = items
        document.encoding = encoding
        document.hasUnsavedChanges = false
        loadAndApplyFoldState(for: document)
        log.debug("reloadFromDisk: \(document.fileURL.lastPathComponent)")
    }

    // MARK: - Fold state persistence

    /// Write the current fold state to a tiny JSON sidecar alongside the document file.
    func saveFoldState(for document: TaskDocument) {
        let paths = document.collapsedPaths
        let file = FoldStateFile(version: 1, collapsedPaths: paths)
        guard let data = try? JSONEncoder().encode(file) else { return }
        let url = foldStateURL(for: document.fileURL)
        try? data.write(to: url, options: .atomic)
        log.debug("saveFoldState: \(paths.count) collapsed paths → \(url.lastPathComponent)")
    }

    private func loadAndApplyFoldState(for document: TaskDocument) {
        let url = foldStateURL(for: document.fileURL)
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(FoldStateFile.self, from: data) else { return }
        document.applyCollapsedPaths(file.collapsedPaths)
        log.debug("loadFoldState: applied \(file.collapsedPaths.count) paths from \(url.lastPathComponent)")
    }

    private func foldStateURL(for documentURL: URL) -> URL {
        documentURL.appendingPathExtension("foldstate")
    }
}
