import Foundation

actor FileCoordinatorService {

    /// Read a file's contents with coordinated access.
    func read(at url: URL) async throws -> (String, String.Encoding) {
        // NSFileCoordinator.coordinate is synchronous: either the block runs (no error) or
        // the error pointer is set (block never runs). Run it off the actor to avoid blocking.
        try await Task.detached {
            var result: Result<(String, String.Encoding), Error>?
            let coordinator = NSFileCoordinator()
            var coordinatorError: NSError?

            coordinator.coordinate(readingItemAt: url, options: [], error: &coordinatorError) { readURL in
                do {
                    var encoding: String.Encoding = .utf8
                    let content = try String(contentsOf: readURL, usedEncoding: &encoding)
                    result = .success((content, encoding))
                } catch {
                    result = .failure(error)
                }
            }

            if let coordinatorError {
                throw coordinatorError
            }
            return try result!.get()
        }.value
    }

    /// Write string content to a file with coordinated access.
    func write(_ content: String, to url: URL, encoding: String.Encoding = .utf8) async throws {
        try await Task.detached {
            let coordinator = NSFileCoordinator()
            var coordinatorError: NSError?
            var writeError: Error?

            coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { writeURL in
                do {
                    try content.write(to: writeURL, atomically: true, encoding: encoding)
                } catch {
                    writeError = error
                }
            }

            if let coordinatorError { throw coordinatorError }
            if let writeError { throw writeError }
        }.value
    }

    /// Move a file with coordinated access.
    func move(from source: URL, to destination: URL) async throws {
        try await Task.detached {
            let coordinator = NSFileCoordinator()
            var coordinatorError: NSError?
            var moveError: Error?

            coordinator.coordinate(
                writingItemAt: source, options: .forMoving,
                writingItemAt: destination, options: .forReplacing,
                error: &coordinatorError
            ) { srcURL, dstURL in
                do {
                    try FileManager.default.moveItem(at: srcURL, to: dstURL)
                } catch {
                    moveError = error
                }
            }

            if let coordinatorError { throw coordinatorError }
            if let moveError { throw moveError }
        }.value
    }

    /// Delete a file with coordinated access.
    func delete(at url: URL) async throws {
        try await Task.detached {
            let coordinator = NSFileCoordinator()
            var coordinatorError: NSError?
            var deleteError: Error?

            coordinator.coordinate(writingItemAt: url, options: .forDeleting, error: &coordinatorError) { deleteURL in
                do {
                    try FileManager.default.removeItem(at: deleteURL)
                } catch {
                    deleteError = error
                }
            }

            if let coordinatorError { throw coordinatorError }
            if let deleteError { throw deleteError }
        }.value
    }
}
