import SwiftUI

@main
struct TaskamiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .onAppear {
                    appState.checkPasscode()
                }
                .onOpenURL { url in
                    appState.handleOpenURL(url)
                }
                .onChange(of: appDelegate.pendingShortcutType) { _, type in
                    guard let type else { return }
                    appDelegate.pendingShortcutType = nil
                    switch type {
                    case "com.taskami.app.newTask":
                        appState.shortcutNewTask = true
                    case "com.taskami.app.search":
                        appState.shortcutActivateSearch = true
                    default: break
                    }
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                appState.handleScenePhaseChange(to: .background)
            case .active:
                appState.handleScenePhaseChange(to: .active)
            case .inactive:
                appState.handleScenePhaseChange(to: .inactive)
            @unknown default:
                break
            }
        }
    }
}
