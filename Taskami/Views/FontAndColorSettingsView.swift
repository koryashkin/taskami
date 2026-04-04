import SwiftUI

struct FontAndColorSettingsView: View {
    @Environment(AppState.self) var appState

    private var theme: Binding<EditorTheme> {
        Binding(
            get: { appState.preferences.editorTheme },
            set: { appState.preferences.editorTheme = $0 }
        )
    }

    var body: some View {
        Form {
            Section("Font") {
                Picker("Font", selection: theme.fontName) {
                    Text("Menlo").tag("Menlo")
                    Text("Courier New").tag("Courier New")
                    Text("SF Mono").tag("SFMono-Regular")
                    Text("Georgia").tag("Georgia")
                    Text("Helvetica Neue").tag("HelveticaNeue")
                    Text("System").tag(".AppleSystemUIFont")
                }

                HStack {
                    Text("Size")
                    Spacer()
                    Text("\(Int(appState.preferences.editorTheme.fontSize))")
                        .foregroundStyle(.secondary)
                    Stepper("", value: theme.fontSize, in: 10...30, step: 1)
                        .labelsHidden()
                }
            }

            Section("Colors") {
                ColorRow(title: "Background", color: theme.backgroundColor)
                ColorRow(title: "Text", color: theme.textColor)
                ColorRow(title: "Projects", color: theme.projectColor)
                ColorRow(title: "Tasks", color: theme.taskColor)
                ColorRow(title: "Tags", color: theme.tagColor)
                ColorRow(title: "Done Items", color: theme.doneColor)
                ColorRow(title: "Notes", color: theme.noteColor)
            }

            Section("Presets") {
                Button("Light Theme") { appState.preferences.editorTheme = .light }
                Button("Dark Theme") { appState.preferences.editorTheme = .dark }
                Button("Sepia Theme") { appState.preferences.editorTheme = .sepia }
            }
        }
        .navigationTitle("Fonts & Colors")
    }
}

private struct ColorRow: View {
    let title: String
    @Binding var color: CodableColor

    var body: some View {
        ColorPicker(title, selection: Binding(
            get: { color.color },
            set: { newColor in
                if let components = UIColor(newColor).cgColor.components, components.count >= 3 {
                    color = CodableColor(
                        red: components[0],
                        green: components[1],
                        blue: components[2],
                        alpha: components.count >= 4 ? components[3] : 1.0
                    )
                }
            }
        ))
    }
}
