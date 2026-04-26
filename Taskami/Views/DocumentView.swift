import SwiftUI
import UIKit
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
    @State private var showExportDialog = false

    /// EditorTheme with font scaled to the system Dynamic Type body size when enabled.
    private var effectiveTheme: EditorTheme {
        var theme = appState.preferences.editorTheme
        if appState.preferences.dynamicTypeEnabled {
            let scaled = UIFontMetrics(forTextStyle: .body).scaledValue(for: theme.fontSize)
            theme.fontSize = scaled
        }
        return theme
    }

    var body: some View {
        Group {
            if let document {
                DocumentEditorView(
                    document: document,
                    searchText: searchText,
                    theme: effectiveTheme,
                    addDateToDone: appState.preferences.addDateToDone,
                    dueTintingEnabled: appState.preferences.dueTintingEnabled,
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
                        if let restore = appState.documentService.pendingCursorRestore {
                            appState.documentService.pendingCursorRestore = nil
                            vc.restoreCursor(itemPath: restore.itemPath, offset: restore.offset)
                        }
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
            ToolbarItem(placement: .secondaryAction) {
                Button("Export HTML", systemImage: "square.and.arrow.up") {
                    showExportDialog = true
                }
                .disabled(editorVC == nil)
            }
        }
        .confirmationDialog("Export as HTML", isPresented: $showExportDialog) {
            ForEach(HTMLExporter.Theme.allCases) { theme in
                Button(theme.rawValue) {
                    editorVC?.presentHTMLExport(theme: theme)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose a color theme for the exported HTML file.")
        }
        .task {
            await loadDocument()
        }
        .onDisappear {
            if let doc = appState.documentService.currentDocument {
                let cursor = editorVC?.cursorPosition
                appState.documentService.saveEditorState(
                    for: doc,
                    cursorItemPath: cursor?.itemPath,
                    cursorOffset: cursor?.offset
                )
            }
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
