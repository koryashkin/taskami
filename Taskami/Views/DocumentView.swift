import SwiftUI

struct DocumentView: View {
    let fileURL: URL
    @Environment(AppState.self) var appState
    @State private var document: TaskDocument?
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showConflicts = false
    @State private var error: Error?

    var body: some View {
        Group {
            if let document {
                DocumentEditorView(
                    document: document,
                    searchFilter: searchFilter,
                    theme: appState.preferences.editorTheme,
                    onDocumentChanged: {
                        appState.documentService.scheduleAutosave()
                    }
                )
            } else if appState.documentService.isLoading {
                ProgressView("Loading...")
            } else {
                ContentUnavailableView(
                    "Unable to Open",
                    systemImage: "doc.questionmark",
                    description: Text(error?.localizedDescription ?? "Unknown error")
                )
            }
        }
        .navigationTitle(fileURL.deletingPathExtension().lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, isPresented: $isSearching, prompt: "Search tasks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Task", systemImage: "plus") {
                    // Will be wired to the editor VC
                }
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

    private var searchFilter: ((TaskItem) -> Bool)? {
        guard !searchText.isEmpty else { return nil }
        return QueryEngine.compile(searchText)
    }

    private func loadDocument() async {
        do {
            let doc = try await appState.documentService.open(url: fileURL)
            document = doc
        } catch {
            self.error = error
        }
    }
}
