import Foundation
import Observation

@Observable
final class AppPreferences {
    var editorTheme: EditorTheme {
        didSet { saveTheme() }
    }
    var sortOrder: FileBrowserService.SortOrder {
        didSet { UserDefaults.standard.set(sortOrder.rawValue, forKey: "sortOrder") }
    }
    var autocorrectionEnabled: Bool {
        didSet { UserDefaults.standard.set(autocorrectionEnabled, forKey: "autocorrection") }
    }
    var addDateToDone: Bool {
        didSet { UserDefaults.standard.set(addDateToDone, forKey: "addDateToDone") }
    }
    var liveSearchEnabled: Bool {
        didSet { UserDefaults.standard.set(liveSearchEnabled, forKey: "liveSearch") }
    }
    var showFileExtensions: Bool {
        didSet { UserDefaults.standard.set(showFileExtensions, forKey: "showExtensions") }
    }
    var biometricLockEnabled: Bool {
        didSet { UserDefaults.standard.set(biometricLockEnabled, forKey: "biometricLock") }
    }
    var dynamicTypeEnabled: Bool {
        didSet { UserDefaults.standard.set(dynamicTypeEnabled, forKey: "dynamicType") }
    }
    var dueTintingEnabled: Bool {
        didSet { UserDefaults.standard.set(dueTintingEnabled, forKey: "dueTinting") }
    }
    var recentSearches: [String] {
        didSet { UserDefaults.standard.set(recentSearches, forKey: "recentSearches") }
    }

    init() {
        let defaults = UserDefaults.standard

        // Load theme
        if let data = defaults.data(forKey: "editorTheme"),
           let theme = try? JSONDecoder().decode(EditorTheme.self, from: data) {
            self.editorTheme = theme
        } else {
            self.editorTheme = .light
        }

        self.sortOrder = FileBrowserService.SortOrder(rawValue: defaults.string(forKey: "sortOrder") ?? "") ?? .nameAscending
        self.autocorrectionEnabled = defaults.object(forKey: "autocorrection") as? Bool ?? true
        self.addDateToDone = defaults.object(forKey: "addDateToDone") as? Bool ?? true
        self.liveSearchEnabled = defaults.object(forKey: "liveSearch") as? Bool ?? true
        self.showFileExtensions = defaults.object(forKey: "showExtensions") as? Bool ?? false
        self.biometricLockEnabled = defaults.object(forKey: "biometricLock") as? Bool ?? false
        self.dynamicTypeEnabled = defaults.object(forKey: "dynamicType") as? Bool ?? false
        self.dueTintingEnabled = defaults.object(forKey: "dueTinting") as? Bool ?? false
        self.recentSearches = defaults.stringArray(forKey: "recentSearches") ?? []
    }

    private func saveTheme() {
        if let data = try? JSONEncoder().encode(editorTheme) {
            UserDefaults.standard.set(data, forKey: "editorTheme")
        }
    }
}
