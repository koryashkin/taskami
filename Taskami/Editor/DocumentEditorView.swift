import SwiftUI
import UIKit

struct DocumentEditorView: UIViewControllerRepresentable {
    let document: TaskDocument
    var searchFilter: ((TaskItem) -> Bool)?
    var theme: EditorTheme
    var onDocumentChanged: (() -> Void)?
    var onAddItem: (() -> Void)?

    func makeUIViewController(context: Context) -> DocumentEditorViewController {
        let vc = DocumentEditorViewController()
        vc.theme = theme
        vc.searchFilter = searchFilter
        vc.setDocument(document)
        vc.onDocumentChanged = onDocumentChanged
        return vc
    }

    func updateUIViewController(_ vc: DocumentEditorViewController, context: Context) {
        vc.theme = theme

        // Update search filter
        vc.searchFilter = searchFilter
        vc.applySnapshot(animated: true)
    }
}
