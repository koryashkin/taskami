import Foundation
import Observation

@Observable
final class AppState {
    var fileBrowser: FileBrowserService
    var documentService: DocumentService
    var preferences: AppPreferences
    var authService: AuthenticationService
    var isLocked: Bool = false

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
