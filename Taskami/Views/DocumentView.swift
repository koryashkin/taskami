import SwiftUI
import OSLog

private let log = Logger(subsystem: "com.taskami", category: "DocumentView")

struct DocumentView: View {
    let fileURL: URL
    @Environment(AppState.self) var appState
    @State private var document: TaskDocument?
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var error: Error?
    @State private var editorVC: DocumentEditorViewController?

    var body: some View {
        Group {
            if let document {
                DocumentEditorView(
                    document: document,
                    searchText: searchText,
                    theme: appState.preferences.editorTheme,
                    onDocumentChanged: {
                        appState.documentService.scheduleAutosave()
                    },
                    onFoldStateChanged: {
                        if let doc = appState.documentService.currentDocument {
                            appState.documentService.saveFoldState(for: doc)
                        }
                    },
                    onViewControllerCreated: { vc in
                        editorVC = vc
                    }
                )
            } else if appState.documentService.isLoading {
                ProgressView("Loading...")
            } else if let error {
                ContentUnavailableView(
                    "Unable to Open",
                    systemImage: "doc.questionmark",
                    description: Text(error.localizedDescription)
                )
            } else {
                ProgressView("Opening...")
            }
        }
        .navigationTitle(fileURL.deletingPathExtension().lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, isPresented: $isSearching, prompt: "Search tasks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Task", systemImage: "plus") {
                    editorVC?.addNewItem()
                }
                .disabled(editorVC == nil)
            }
        }
        .task {
            await loadDocument()
        }
        .onDisappear {
            Task {
                try? await appState.documentService.save()
                appState.documentService.close()
            }
        }
    }

    private func loadDocument() async {
        do {
            let doc = try await appState.documentService.open(url: fileURL)
            document = doc
        } catch {
            log.error("Failed to open \(fileURL.lastPathComponent): \(error)")
            self.error = error
        }
    }
}
