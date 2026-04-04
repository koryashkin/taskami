import Foundation

actor FileCoordinatorService {

    /// Read a file's contents with coordinated access.
    func read(at url: URL) async throws -> (String, String.Encoding) {
        try await withCheckedThrowingContinuation { continuation in
            let coordinator = NSFileCoordinator()
            var error: NSError?

            coordinator.coordinate(readingItemAt: url, options: [], error: &error) { readURL in
                do {
                    var encoding: String.Encoding = .utf8
                    let content = try String(contentsOf: readURL, usedEncoding: &encoding)
                    continuation.resume(returning: (content, encoding))
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            if let error {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Write string content to a file with coordinated access.
    func write(_ content: String, to url: URL, encoding: String.Encoding = .utf8) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let coordinator = NSFileCoordinator()
            var error: NSError?

            coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &error) { writeURL in
                do {
                    try content.write(to: writeURL, atomically: true, encoding: encoding)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            if let error {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Move a file with coordinated access.
    func move(from source: URL, to destination: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let coordinator = NSFileCoordinator()
            var error: NSError?

            coordinator.coordinate(
                writingItemAt: source, options: .forMoving,
                writingItemAt: destination, options: .forReplacing,
                error: &error
            ) { srcURL, dstURL in
                do {
                    try FileManager.default.moveItem(at: srcURL, to: dstURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            if let error {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Delete a file with coordinated access.
    func delete(at url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let coordinator = NSFileCoordinator()
            var error: NSError?

            coordinator.coordinate(writingItemAt: url, options: .forDeleting, error: &error) { deleteURL in
                do {
                    try FileManager.default.removeItem(at: deleteURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            if let error {
                continuation.resume(throwing: error)
            }
        }
    }
}
