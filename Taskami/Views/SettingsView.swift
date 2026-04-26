import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        @Bindable var prefs = appState.preferences

        NavigationStack {
            Form {
                Section("Appearance") {
                    NavigationLink("Fonts & Colors") {
                        FontAndColorSettingsView()
                    }

                    HStack {
                        Text("Theme Preset")
                        Spacer()
                        Menu("Select") {
                            Button("Light") { appState.preferences.editorTheme = .light }
                            Button("Dark") { appState.preferences.editorTheme = .dark }
                            Button("Sepia") { appState.preferences.editorTheme = .sepia }
                        }
                    }

                    Toggle("Dynamic Type", isOn: $prefs.dynamicTypeEnabled)
                    Toggle("Highlight Overdue Tasks", isOn: $prefs.dueTintingEnabled)
                }

                Section("Editor") {
                    Toggle("Autocorrection", isOn: $prefs.autocorrectionEnabled)
                    Toggle("Add Date to @done", isOn: $prefs.addDateToDone)
                    Toggle("Live Search", isOn: $prefs.liveSearchEnabled)
                }

                Section("Files") {
                    Picker("Sort By", selection: $prefs.sortOrder) {
                        ForEach(FileBrowserService.SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    Toggle("Show File Extensions", isOn: $prefs.showFileExtensions)
                }

                Section("Security") {
                    Toggle(appState.authService.biometricName, isOn: $prefs.biometricLockEnabled)
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
