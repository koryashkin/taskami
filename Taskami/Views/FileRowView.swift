import SwiftUI

struct FileRowView: View {
    let item: FileItem
    var showExtension: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(showExtension ? item.name : item.displayName)
                    .lineLimit(1)

                if let date = item.modificationDate {
                    Text(date, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
