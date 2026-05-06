import SwiftUI

private struct PresentedExternalDocument: Identifiable {
    let id = UUID()
    let url: URL
    let stopAccessing: () -> Void
}

struct ContentView: View {
    @Environment(AppState.self) var appState
    @State private var presentedExternalDocument: PresentedExternalDocument?

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
        .onChange(of: appState.pendingOpenURL) { _, url in
            guard let url else { return }
            appState.pendingOpenURL = nil

            let didStartAccessing = url.startAccessingSecurityScopedResource()
            presentedExternalDocument = PresentedExternalDocument(
                url: url,
                stopAccessing: {
                    if didStartAccessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            )
        }
        .sheet(item: $presentedExternalDocument, onDismiss: {
            presentedExternalDocument = nil
        }) { presented in
            NavigationStack {
                DocumentView(fileURL: presented.url)
            }
            .onDisappear {
                presented.stopAccessing()
            }
        }
    }
}
