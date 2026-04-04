import SwiftUI

struct FolderRowView: View {
    let item: FileItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.blue)
                .frame(width: 24)

            Text(item.name)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}
