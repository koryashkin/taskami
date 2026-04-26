import UIKit

final class EditorDragDropHandler: NSObject, UICollectionViewDragDelegate, UICollectionViewDropDelegate {

    weak var editorVC: DocumentEditorViewController?

    // MARK: - UICollectionViewDragDelegate

    func collectionView(
        _ collectionView: UICollectionView,
        itemsForBeginning session: UIDragSession,
        at indexPath: IndexPath
    ) -> [UIDragItem] {
        guard let editorVC, let item = editorVC.item(at: indexPath) else { return [] }

        editorVC.commitCurrentEdit()

        let provider = NSItemProvider(object: item.id.uuidString as NSString)
        let dragItem = UIDragItem(itemProvider: provider)
        dragItem.localObject = item
        return [dragItem]
    }

    func collectionView(
        _ collectionView: UICollectionView,
        dragPreviewParametersForItemAt indexPath: IndexPath
    ) -> UIDragPreviewParameters? {
        let params = UIDragPreviewParameters()
        params.backgroundColor = .clear
        return params
    }

    // MARK: - UICollectionViewDropDelegate

    func collectionView(
        _ collectionView: UICollectionView,
        dropSessionDidUpdate session: UIDropSession,
        withDestinationIndexPath destinationIndexPath: IndexPath?
    ) -> UICollectionViewDropProposal {
        guard session.localDragSession != nil else {
            return UICollectionViewDropProposal(operation: .forbidden)
        }
        return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        performDropWith coordinator: UICollectionViewDropCoordinator
    ) {
        guard let editorVC,
              let document = editorVC.document else { return }

        var movedAny = false
        for dropItem in coordinator.items {
            guard let draggedItem = dropItem.dragItem.localObject as? TaskItem else { continue }

            let destinationIndexPath = coordinator.destinationIndexPath ?? IndexPath(item: document.allItems.count - 1, section: 0)
            let flatItems = document.allItems

            guard destinationIndexPath.item < flatItems.count else { continue }
            let targetItem = flatItems[destinationIndexPath.item]

            // Determine new parent and position
            let newParent = targetItem.parent
            let siblings: [TaskItem]
            if let newParent {
                siblings = newParent.children
            } else {
                siblings = document.items
            }

            let targetIndex = siblings.firstIndex(where: { $0.id == targetItem.id }) ?? siblings.count

            // Perform the move
            document.moveItem(draggedItem, toParent: newParent, atIndex: targetIndex)
            coordinator.drop(dropItem.dragItem, toItemAt: destinationIndexPath)
            movedAny = true
        }

        // Only refresh when something actually moved.
        // Use animated:false — animated apply is async on iOS 15+ and races with the
        // isApplyingSnapshot guard.
        if movedAny {
            editorVC.applySnapshot(animated: false)
            editorVC.onDocumentChanged?()
        }
    }
}
