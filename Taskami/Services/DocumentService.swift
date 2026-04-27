import Foundation
import Observation
import OSLog

private let log = Logger(subsystem: "com.taskami", category: "DocumentService")

private struct EditorStateFile: Codable {
    var version: Int = 1
    var collapsedPaths: [[Int]]
    /// Index path to the item holding the cursor, plus the character offset within it.
    var cursorItemPath: [Int]?
    var cursorOffset: Int?
}

@Observable
final class DocumentService {
    var currentDocument: TaskDocument?
    var isLoading: Bool = false
    var error: Error?
    /// Set after open(); the DocumentView should consume this once to scroll to the saved position.
    var pendingCursorRestore: (itemPath: [Int], offset: Int)?

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

        let savedCursor = loadAndApplyEditorState(for: document)
        currentDocument = document
        pendingCursorRestore = savedCursor
        return document
    }

    /// Save the current document to disk.
    func save() async throws {
        guard let document = currentDocument else { return }

        let content = TaskPaperSerializer.serialize(document.items, lineEnding: document.lineEnding)
        try await fileCoordinator.write(content, to: document.fileURL, encoding: document.encoding, initiator: filePresenter)
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
        loadAndApplyEditorState(for: document)
        log.debug("reloadFromDisk: \(document.fileURL.lastPathComponent)")
    }

    // MARK: - Editor state persistence (fold + cursor)

    /// Write fold state and cursor position to the sidecar file.
    func saveEditorState(for document: TaskDocument, cursorItemPath: [Int]? = nil, cursorOffset: Int? = nil) {
        let file = EditorStateFile(
            version: 1,
            collapsedPaths: document.collapsedPaths,
            cursorItemPath: cursorItemPath,
            cursorOffset: cursorOffset
        )
        guard let data = try? JSONEncoder().encode(file) else { return }
        let url = editorStateURL(for: document.fileURL)
        try? data.write(to: url, options: .atomic)
        log.debug("saveEditorState: \(file.collapsedPaths.count) folds, cursor=\(String(describing: cursorItemPath)):\(String(describing: cursorOffset))")
    }

    /// Load and apply fold state; return the saved cursor position if present.
    @discardableResult
    func loadAndApplyEditorState(for document: TaskDocument) -> (itemPath: [Int], offset: Int)? {
        let url = editorStateURL(for: document.fileURL)
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(EditorStateFile.self, from: data) else { return nil }
        document.applyCollapsedPaths(file.collapsedPaths)
        log.debug("loadEditorState: \(file.collapsedPaths.count) folds from \(url.lastPathComponent)")
        if let path = file.cursorItemPath, let offset = file.cursorOffset {
            return (path, offset)
        }
        return nil
    }

    private func editorStateURL(for documentURL: URL) -> URL {
        documentURL.appendingPathExtension("foldstate")
    }

    // Keep old name as a passthrough so existing callers compile without change.
    func saveFoldState(for document: TaskDocument) {
        saveEditorState(for: document)
    }
}
