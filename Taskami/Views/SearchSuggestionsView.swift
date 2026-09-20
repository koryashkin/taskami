import SwiftUI

struct SearchSuggestionsView: View {
    let document: TaskDocument
    @Binding var searchText: String
    var recentSearches: [String] = []
    var onClearRecent: (() -> Void)?
    var onSelect: ((String) -> Void)?

    private var uniqueTags: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for item in document.allItems {
            for tag in item.tags {
                if seen.insert(tag.name.lowercased()).inserted {
                    result.append(tag.name)
                }
            }
        }
        return result.sorted()
    }

    private var projects: [TaskItem] {
        document.allItems.filter { $0.type == .project }
    }

    var body: some View {
        if !recentSearches.isEmpty {
            Section {
                ForEach(recentSearches, id: \.self) { query in
                    Button {
                        select(query)
                    } label: {
                        Label(query, systemImage: "clock")
                    }
                }
            } header: {
                HStack {
                    Text("Recent")
                    Spacer()
                    Button("Clear") { onClearRecent?() }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }

        if !uniqueTags.isEmpty {
            Section("Tags") {
                ForEach(uniqueTags, id: \.self) { tag in
                    Button {
                        select("@\(tag)")
                    } label: {
                        Label("@\(tag)", systemImage: "tag")
                    }
                }
            }
        }

        if !projects.isEmpty {
            Section("Projects") {
                ForEach(projects) { project in
                    Button {
                        select("project = \"\(project.content)\"")
                    } label: {
                        Label(project.content, systemImage: "folder")
                    }
                }
            }
        }

        Section("Queries") {
            Button { select("not @done") } label: {
                Label("Not Done", systemImage: "circle")
            }
            Button { select("@done") } label: {
                Label("Done", systemImage: "checkmark.circle")
            }
            Button { select("type = task") } label: {
                Label("All Tasks", systemImage: "list.bullet")
            }
        }
    }

    private func select(_ query: String) {
        searchText = query
        onSelect?(query)
    }
}
