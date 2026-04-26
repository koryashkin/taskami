import SwiftUI

struct FileBrowserView: View {
    @Environment(AppState.self) var appState
    @State private var searchText = ""
    @State private var showingNewFileDialog = false
    @State private var showingNewFolderDialog = false
    @State private var newItemName = ""
    @State private var showingSettings = false

    private var filteredItems: [FileItem] {
        if searchText.isEmpty {
            return appState.fileBrowser.items
        }
        return appState.fileBrowser.items.filter {
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
        .navigationTitle(appState.fileBrowser.currentDirectory.lastPathComponent)
        .searchable(text: $searchText, prompt: "Filter files")
        .navigationDestination(for: FileItem.self) { item in
            if item.isDirectory {
                FileBrowserView()
                    .onAppear { appState.fileBrowser.navigate(to: item.url) }
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
                            appState.fileBrowser.sortOrder = order
                            appState.fileBrowser.refresh()
                        } label: {
                            HStack {
                                Text(order.rawValue)
                                if appState.fileBrowser.sortOrder == order {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        }
        .refreshable {
            appState.fileBrowser.refresh()
        }
        .alert("New File", isPresented: $showingNewFileDialog) {
            TextField("File name", text: $newItemName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                guard !newItemName.isEmpty else { return }
                try? appState.fileBrowser.createFile(named: newItemName)
            }
        }
        .alert("New Folder", isPresented: $showingNewFolderDialog) {
            TextField("Folder name", text: $newItemName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                guard !newItemName.isEmpty else { return }
                try? appState.fileBrowser.createFolder(named: newItemName)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = filteredItems[index]
            try? appState.fileBrowser.deleteItem(at: item.url)
        }
    }
}
