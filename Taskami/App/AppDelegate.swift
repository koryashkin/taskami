import UIKit

/// Minimal UIApplicationDelegate used solely to intercept home-screen quick-action shortcuts.
/// All other lifecycle management remains in TaskamiApp (SwiftUI @main).
@Observable
final class AppDelegate: NSObject, UIApplicationDelegate {

    /// Set when the user activates a home-screen shortcut. Consumed and cleared by the UI layer.
    var pendingShortcutType: String?

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        pendingShortcutType = shortcutItem.type
        completionHandler(true)
    }
}
