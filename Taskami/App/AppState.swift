import Foundation
import Observation

@Observable
final class AppState {
    var fileBrowser: FileBrowserService
    var documentService: DocumentService
    var preferences: AppPreferences
    var authService: AuthenticationService
    var isLocked: Bool = false
    /// Set by onOpenURL when the system routes a .taskpaper file to the app.
    var pendingOpenURL: URL?
    /// Set by onOpenURL when the system routes an .opml file to the app.
    var pendingImportURL: URL?
    /// Signals FileBrowserView to add a new task in the current document.
    var shortcutNewTask: Bool = false
    /// Signals DocumentView to activate the search bar.
    var shortcutActivateSearch: Bool = false

    init() {
        self.preferences = AppPreferences()
        self.fileBrowser = FileBrowserService(directory: FileBrowserService.defaultDirectory())
        self.documentService = DocumentService()
        self.authService = AuthenticationService()
    }

    func checkPasscode() {
        if preferences.biometricLockEnabled && !authService.isAuthenticated {
            isLocked = true
        }
    }

    func unlock() async {
        let success = await authService.authenticate()
        if success {
            isLocked = false
        }
    }

    /// Records a search query in the recent-searches list (max 10, deduped, newest first).
    func addRecentSearch(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        var recent = preferences.recentSearches
        recent.removeAll { $0 == q }
        recent.insert(q, at: 0)
        preferences.recentSearches = Array(recent.prefix(10))
    }

    /// Routes a file URL received from the system (Files app "Open In", share sheet, etc.)
    /// to the appropriate pending state consumed by the UI layer.
    func handleOpenURL(_ url: URL) {
        guard url.isFileURL else { return }
        let ext = url.pathExtension.lowercased()
        _ = url.startAccessingSecurityScopedResource()
        if ext == "taskpaper" {
            pendingOpenURL = url
        } else if ext == "opml" || ext == "xml" {
            pendingImportURL = url
        }
    }

    func handleScenePhaseChange(to phase: ScenePhase) {
        switch phase {
        case .background:
            authService.lastBackgroundDate = Date()
        case .active:
            if preferences.biometricLockEnabled && authService.shouldLock() {
                isLocked = true
            }
        default:
            break
        }
    }
}

import SwiftUI

// Needed for ScenePhase reference
extension AppState {
    enum ScenePhase {
        case active, inactive, background
    }
}
