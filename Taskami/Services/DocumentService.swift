import Foundation
import Observation
import OSLog

private let log = Logger(subsystem: "com.taskami", category: "DocumentService")

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
        log.debug("reloadFromDisk: \(document.fileURL.lastPathComponent)")
    }
}
