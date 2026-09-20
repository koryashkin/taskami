import Foundation
import Testing
@testable import Taskami

@Suite("DocumentService Tests")
struct DocumentServiceTests {

    private func makeTempFile(named name: String, content: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @MainActor
    @Test("External file changes do not overwrite dirty in-memory edits")
    func externalChangeWhileDirtyDefersReload() async throws {
        let url = try makeTempFile(named: "Dirty.taskpaper", content: "- Original\n")
        let service = DocumentService()
        let document = try await service.open(url: url)

        document.items[0].content = "Local edit"
        document.items[0].tags = TagParser.parseTags(in: document.items[0].content)
        document.hasUnsavedChanges = true

        try "- Remote edit\n".write(to: url, atomically: true, encoding: .utf8)

        await service.handlePresentedItemDidChange()

        #expect(service.externalChangeResolutionState == .pending)
        #expect(service.currentDocument?.items[0].content == "Local edit")
        #expect(service.currentDocument?.hasUnsavedChanges == true)
    }

    @MainActor
    @Test("Reloading after external change applies disk version")
    func reloadAfterExternalChangeAppliesDiskVersion() async throws {
        let url = try makeTempFile(named: "Reload.taskpaper", content: "- Original\n")
        let service = DocumentService()
        let document = try await service.open(url: url)

        document.items[0].content = "Local edit"
        document.items[0].tags = TagParser.parseTags(in: document.items[0].content)
        document.hasUnsavedChanges = true

        try "- Remote edit\n".write(to: url, atomically: true, encoding: .utf8)
        await service.handlePresentedItemDidChange()

        try await service.reloadDiscardingLocalChanges()

        #expect(service.externalChangeResolutionState == .none)
        #expect(service.currentDocument?.items[0].content == "Remote edit")
        #expect(service.currentDocument?.hasUnsavedChanges == false)
    }
}
