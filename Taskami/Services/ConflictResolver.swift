import Foundation
import Observation

struct ConflictVersion: Identifiable {
    let id: UUID
    let fileVersion: NSFileVersion
    var modificationDate: Date?
    var localizedName: String?
    var isCurrentVersion: Bool

    init(fileVersion: NSFileVersion, isCurrentVersion: Bool = false) {
        self.id = UUID()
        self.fileVersion = fileVersion
        self.modificationDate = fileVersion.modificationDate
        self.localizedName = fileVersion.localizedName
        self.isCurrentVersion = isCurrentVersion
    }
}

@Observable
final class ConflictResolver {
    var conflicts: [ConflictVersion] = []
    var hasConflicts: Bool { !conflicts.isEmpty }

    /// Check for unresolved conflicts on a file.
    func checkConflicts(for url: URL) {
        let unresolvedVersions = NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []

        var versions: [ConflictVersion] = []

        // Add current version
        if let current = NSFileVersion.currentVersionOfItem(at: url) {
            versions.append(ConflictVersion(fileVersion: current, isCurrentVersion: true))
        }

        // Add conflict versions
        for version in unresolvedVersions {
            versions.append(ConflictVersion(fileVersion: version))
        }

        self.conflicts = versions
    }

    /// Resolve by keeping one version and removing the rest.
    func resolve(keeping version: ConflictVersion, for url: URL) throws {
        let unresolvedVersions = NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []

        if !version.isCurrentVersion {
            // Replace current with chosen version
            try version.fileVersion.replaceItem(at: url)
        }

        // Mark all conflict versions as resolved
        for conflictVersion in unresolvedVersions {
            conflictVersion.isResolved = true
        }

        // Remove old conflict versions
        try NSFileVersion.removeOtherVersionsOfItem(at: url)

        conflicts = []
    }

    /// Resolve by keeping the current version and discarding conflicts.
    func resolveKeepingCurrent(for url: URL) throws {
        let unresolvedVersions = NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []

        for version in unresolvedVersions {
            version.isResolved = true
        }

        try NSFileVersion.removeOtherVersionsOfItem(at: url)
        conflicts = []
    }
}
