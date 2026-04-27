import SwiftUI

@main
struct TaskamiApp: App {
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
