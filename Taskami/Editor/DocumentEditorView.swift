import SwiftUI
import UIKit

struct DocumentEditorView: UIViewControllerRepresentable {
    let document: TaskDocument
    var searchFilter: ((TaskItem) -> Bool)?
    var theme: EditorTheme
    var onDocumentChanged: (() -> Void)?
    /// Called once after the view controller is created, providing a reference for calling actions.
    var onViewControllerCreated: ((DocumentEditorViewController) -> Void)?

    func makeUIViewController(context: Context) -> DocumentEditorViewController {
        let vc = DocumentEditorViewController()
        vc.theme = theme
        vc.searchFilter = searchFilter
        vc.setDocument(document)
        vc.onDocumentChanged = onDocumentChanged
        // Defer to avoid "modifying state during view update" warning —
        // makeUIViewController is called during the SwiftUI update pass.
        DispatchQueue.main.async { onViewControllerCreated?(vc) }
        return vc
    }

    func updateUIViewController(_ vc: DocumentEditorViewController, context: Context) {
        vc.theme = theme
        vc.searchFilter = searchFilter

        // If the document instance changed, update it; otherwise just refresh the snapshot
        if vc.document?.id != document.id {
            vc.setDocument(document)
        } else {
            vc.applySnapshot(animated: false)
        }
    }
}
