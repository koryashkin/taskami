import Foundation
import Testing
@testable import Taskami

@Suite("FileBrowserService Tests")
struct FileBrowserServiceTests {

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test("Creating a file rejects a path traversal name")
    func createFileRejectsPathTraversal() throws {
        let directory = try makeTemporaryDirectory()
        let service = FileBrowserService(directory: directory)
        let outsideName = "outside-\(UUID().uuidString)"

        var didThrow = false
        do {
            _ = try service.createFile(named: "../\(outsideName)")
        } catch {
            didThrow = true
        }

        #expect(didThrow)
        #expect(!FileManager.default.fileExists(atPath: directory.deletingLastPathComponent().appendingPathComponent("\(outsideName).taskpaper").path))
    }

    @Test("Creating a folder rejects a path traversal name")
    func createFolderRejectsPathTraversal() throws {
        let directory = try makeTemporaryDirectory()
        let service = FileBrowserService(directory: directory)

        var didThrow = false
        do {
            _ = try service.createFolder(named: "../outside")
        } catch {
            didThrow = true
        }

        #expect(didThrow)
    }

    @Test("Deleting a URL outside the current directory is rejected")
    func deleteRejectsURLOutsideCurrentDirectory() throws {
        let directory = try makeTemporaryDirectory()
        let outsideFile = directory.deletingLastPathComponent().appendingPathComponent("outside.txt")
        try "Keep me".write(to: outsideFile, atomically: true, encoding: .utf8)
        let service = FileBrowserService(directory: directory)

        var didThrow = false
        do {
            try service.deleteItem(at: outsideFile)
        } catch {
            didThrow = true
        }
        #expect(didThrow)
        #expect(FileManager.default.fileExists(atPath: outsideFile.path))
    }
}
