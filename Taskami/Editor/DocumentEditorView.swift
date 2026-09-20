import SwiftUI
import UIKit

struct DocumentEditorView: UIViewControllerRepresentable {
    let document: TaskDocument
    /// Plain search text — equatable, so updateUIViewController only calls applySnapshot when it actually changes.
    var searchText: String
    var theme: EditorTheme
    var addDateToDone: Bool = true
    var autocorrectionEnabled: Bool = true
    var dueTintingEnabled: Bool = false
    var onDocumentChanged: (() -> Void)?
    var onFoldStateChanged: (() -> Void)?
    var onActivateSearch: (() -> Void)?
    /// Called once after the view controller is created, providing a reference for calling actions.
    var onViewControllerCreated: ((DocumentEditorViewController) -> Void)?

    func makeUIViewController(context: Context) -> DocumentEditorViewController {
        let vc = DocumentEditorViewController()
        vc.theme = theme
        vc.searchText = searchText
        vc.addDateToDone = addDateToDone
        vc.autocorrectionEnabled = autocorrectionEnabled
        vc.dueTintingEnabled = dueTintingEnabled
        vc.setDocument(document)
        vc.onDocumentChanged = onDocumentChanged
        vc.onFoldStateChanged = onFoldStateChanged
        vc.onActivateSearch = onActivateSearch
        // Defer to avoid "modifying state during view update" warning —
        // makeUIViewController is called during the SwiftUI update pass.
        DispatchQueue.main.async { onViewControllerCreated?(vc) }
        return vc
    }

    func updateUIViewController(_ vc: DocumentEditorViewController, context: Context) {
        vc.theme = theme
        vc.searchText = searchText
        vc.addDateToDone = addDateToDone
        vc.autocorrectionEnabled = autocorrectionEnabled
        vc.dueTintingEnabled = dueTintingEnabled
        vc.onActivateSearch = onActivateSearch

        if vc.document?.id != document.id {
            vc.setDocument(document)
        }
    }
}
