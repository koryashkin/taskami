import Foundation

final class DocumentFilePresenter: NSObject, NSFilePresenter, @unchecked Sendable {
    let presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue

    var onFileChanged: (@Sendable () -> Void)?
    var onConflictDetected: (@Sendable ([NSFileVersion]) -> Void)?

    init(url: URL) {
        self.presentedItemURL = url
        self.presentedItemOperationQueue = OperationQueue()
        presentedItemOperationQueue.maxConcurrentOperationCount = 1
        presentedItemOperationQueue.qualityOfService = .userInitiated
        super.init()
    }

    /// Register this presenter to begin receiving notifications.
    func startMonitoring() {
        NSFileCoordinator.addFilePresenter(self)
    }

    /// Unregister this presenter.
    func stopMonitoring() {
        NSFileCoordinator.removeFilePresenter(self)
    }

    // MARK: - NSFilePresenter

    func presentedItemDidChange() {
        onFileChanged?()
    }

    func presentedItemDidGain(_ version: NSFileVersion) {
        checkForConflicts()
    }

    func presentedItemDidLose(_ version: NSFileVersion) {
        checkForConflicts()
    }

    func presentedItemDidResolveConflict(_ version: NSFileVersion) {
        // Conflict resolved externally
    }

    // MARK: - Private

    private func checkForConflicts() {
        guard let url = presentedItemURL else { return }
        let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []
        if !conflicts.isEmpty {
            onConflictDetected?(conflicts)
        }
    }
}
