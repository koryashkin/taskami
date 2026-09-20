import SwiftUI
import UniformTypeIdentifiers

struct FileBrowserView: View {
    private enum CreateOperationKind {
        case file
        case folder

        var alertTitle: String {
            switch self {
            case .file: return "Unable to Create File"
            case .folder: return "Unable to Create Folder"
            }
        }
    }

    @Environment(AppState.self) var appState
    @State private var nestedFileBrowser: FileBrowserService?
    @State private var searchText = ""
    @State private var showingNewFileDialog = false
    @State private var showingNewFolderDialog = false
    @State private var newItemName = ""
    @State private var showingSettings = false
    @State private var showingOPMLPicker = false
    @State private var importError: String?
    @State private var showingImportError = false
    @State private var createOperationKind: CreateOperationKind?
    @State private var createError: String?
    @State private var showingCreateError = false

    init(
        directory: URL? = nil,
        sortOrder: FileBrowserService.SortOrder = .nameAscending
    ) {
        _nestedFileBrowser = State(
            initialValue: directory.map { FileBrowserService(directory: $0, sortOrder: sortOrder) }
        )
    }

    private var fileBrowser: FileBrowserService {
        nestedFileBrowser ?? appState.fileBrowser
    }

    private var filteredItems: [FileItem] {
        if searchText.isEmpty {
            return fileBrowser.items
        }
        return fileBrowser.items.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            ForEach(filteredItems) { item in
                if item.isDirectory {
                    NavigationLink(value: item) {
                        FolderRowView(item: item)
                    }
                } else {
                    NavigationLink(value: item) {
                        FileRowView(item: item, showExtension: appState.preferences.showFileExtensions)
                    }
                }
            }
            .onDelete(perform: deleteItems)
        }
        .navigationTitle(fileBrowser.currentDirectory.lastPathComponent)
        .searchable(text: $searchText, prompt: "Filter files")
        .navigationDestination(for: FileItem.self) { item in
            if item.isDirectory {
                FileBrowserView(
                    directory: item.url,
                    sortOrder: appState.preferences.sortOrder
                )
            } else {
                DocumentView(fileURL: item.url)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("New File", systemImage: "doc.badge.plus") {
                        newItemName = ""
                        showingNewFileDialog = true
                    }
                    Button("New Folder", systemImage: "folder.badge.plus") {
                        newItemName = ""
                        showingNewFolderDialog = true
                    }
                    Button("Import OPML…", systemImage: "arrow.down.doc") {
                        showingOPMLPicker = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gear")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu("Sort", systemImage: "arrow.up.arrow.down") {
                    ForEach(FileBrowserService.SortOrder.allCases, id: \.self) { order in
                        Button {
                            appState.preferences.sortOrder = order
                            fileBrowser.sortOrder = order
                        } label: {
                            HStack {
                                Text(order.rawValue)
                                if fileBrowser.sortOrder == order {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        }
        .refreshable {
            fileBrowser.refresh()
        }
        .onChange(of: appState.preferences.sortOrder) { _, order in
            fileBrowser.sortOrder = order
        }
        .alert("New File", isPresented: $showingNewFileDialog) {
            TextField("File name", text: $newItemName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                guard !newItemName.isEmpty else { return }
                do {
                    _ = try fileBrowser.createFile(named: newItemName)
                } catch {
                    presentCreateError(error, for: .file)
                }
            }
        }
        .alert("New Folder", isPresented: $showingNewFolderDialog) {
            TextField("Folder name", text: $newItemName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                guard !newItemName.isEmpty else { return }
                do {
                    _ = try fileBrowser.createFolder(named: newItemName)
                } catch {
                    presentCreateError(error, for: .folder)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .fileImporter(
            isPresented: $showingOPMLPicker,
            allowedContentTypes: [.xml, UTType("org.opml.opml") ?? .xml],
            onCompletion: { result in
                switch result {
                case .success(let url): importOPML(from: url)
                case .failure: break
                }
            }
        )
        .alert("Import Error", isPresented: $showingImportError, presenting: importError) { _ in
            Button("OK", role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
        .alert(createOperationKind?.alertTitle ?? "Unable to Create", isPresented: $showingCreateError, presenting: createError) { _ in
            Button("OK", role: .cancel) {
                createError = nil
                createOperationKind = nil
            }
        } message: { msg in
            Text(msg)
        }
        .onChange(of: appState.shortcutNewTask) { _, active in
            if active {
                appState.shortcutNewTask = false
                newItemName = ""
                showingNewFileDialog = true
            }
        }
        .onChange(of: appState.pendingImportURL) { _, url in
            guard let url else { return }
            appState.pendingImportURL = nil
            importOPML(from: url)
        }
    }

    private func importOPML(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let result = try OPMLImporter.importFrom(url: url)
            let dir = fileBrowser.currentDirectory
            var dest = dir.appendingPathComponent(result.suggestedTitle).appendingPathExtension("taskpaper")
            var counter = 1
            while FileManager.default.fileExists(atPath: dest.path) {
                dest = dir.appendingPathComponent("\(result.suggestedTitle) \(counter)").appendingPathExtension("taskpaper")
                counter += 1
            }
            try result.taskPaperContent.write(to: dest, atomically: true, encoding: .utf8)
            fileBrowser.refresh()
        } catch {
            importError = error.localizedDescription
            showingImportError = true
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = filteredItems[index]
            try? fileBrowser.deleteItem(at: item.url)
        }
    }

    private func presentCreateError(_ error: Error, for kind: CreateOperationKind) {
        createOperationKind = kind
        createError = error.localizedDescription
        showingCreateError = true
    }
}
