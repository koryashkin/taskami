import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        Group {
            if appState.isLocked {
                LockScreenView()
            } else {
                NavigationStack {
                    FileBrowserView()
                }
            }
        }
    }
}
