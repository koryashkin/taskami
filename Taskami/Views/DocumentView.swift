import SwiftUI
import UIKit
import OSLog

private let log = Logger(subsystem: "com.taskami", category: "DocumentView")

struct DocumentView: View {
    let fileURL: URL
    @Environment(AppState.self) var appState
    @State private var documentService = DocumentService()
    @State private var document: TaskDocument?
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var error: Error?
    @State private var editorVC: DocumentEditorViewController?
    @State private var showExportDialog = false
    @State private var showRemindersBanner = false
    @State private var remindersBannerMessage = ""
    private let remindersService = RemindersService()

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
                        documentService.scheduleAutosave()
                        WidgetDataStore.update(from: document)
                    },
                    onFoldStateChanged: {
                        if let doc = documentService.currentDocument {
                            documentService.saveFoldState(for: doc)
                        }
                    },
                    onActivateSearch: { isSearching = true },
                    onViewControllerCreated: { vc in
                        editorVC = vc
                        if let restore = documentService.consumePendingCursorRestore() {
                            vc.restoreCursor(itemPath: restore.itemPath, offset: restore.offset)
                        }
                    }
                )
            } else if documentService.isLoading {
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
        .searchSuggestions {
            if let document {
                SearchSuggestionsView(
                    document: document,
                    searchText: $searchText,
                    recentSearches: appState.preferences.recentSearches,
                    onClearRecent: { appState.preferences.recentSearches = [] }
                )
            }
        }
        .onChange(of: isSearching) { _, searching in
            if !searching && !searchText.isEmpty {
                appState.addRecentSearch(searchText)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Task", systemImage: "plus") {
                    editorVC?.addNewItemAfterCurrentEdit()
                }
                .disabled(editorVC == nil)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Export HTML", systemImage: "square.and.arrow.up") {
                    showExportDialog = true
                }
                .disabled(editorVC == nil)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Sync Reminders", systemImage: "bell.badge") {
                    syncReminders()
                }
                .disabled(document == nil)
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
        .overlay(alignment: .top) {
            if showRemindersBanner {
                Text(remindersBannerMessage)
                    .font(.footnote)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showRemindersBanner)
        .onChange(of: appState.shortcutActivateSearch) { _, active in
            if active { isSearching = true; appState.shortcutActivateSearch = false }
        }
        .alert("Document Changed on Disk", isPresented: externalChangeAlertBinding) {
            Button("Reload From Disk", role: .destructive) {
                Task {
                    do {
                        try await documentService.reloadDiscardingLocalChanges()
                    } catch {
                        self.error = error
                    }
                }
            }
            Button("Keep My Changes") {
                documentService.keepLocalChangesAfterExternalChange()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This file changed outside the editor while you had unsaved edits. Reload to take the disk version, or keep your local changes and overwrite on the next save.")
        }
        .task {
            await loadDocument()
        }
        .onDisappear {
            if let doc = documentService.currentDocument {
                let cursor = editorVC?.cursorPosition
                documentService.saveEditorState(
                    for: doc,
                    cursorItemPath: cursor?.itemPath,
                    cursorOffset: cursor?.offset
                )
            }
            Task {
                try? await documentService.save()
                documentService.close()
            }
        }
    }

    private var externalChangeAlertBinding: Binding<Bool> {
        Binding(
            get: { documentService.externalChangeResolutionState == .pending },
            set: { _ in }
        )
    }

    private func loadDocument() async {
        do {
            let doc = try await documentService.open(url: fileURL)
            document = doc
        } catch {
            log.error("Failed to open \(fileURL.lastPathComponent): \(error)")
            self.error = error
        }
    }

    private func syncReminders() {
        guard let document else { return }
        Task {
            let result = await remindersService.sync(document: document)
            remindersBannerMessage = result.message
            withAnimation { showRemindersBanner = true }
            try? await Task.sleep(for: .seconds(3))
            withAnimation { showRemindersBanner = false }
        }
    }
}
