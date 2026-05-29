import SwiftUI

/// Single-column row used by the native List layout: name, tags, asset count.
struct ListRow: View {
    let item: ListWithAssetCount

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.list.name)
                    .font(.serif(20, relativeTo: .headline))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                if !item.list.tags.isEmpty {
                    Text(item.list.tags.prefix(3).map { "#\($0)" }.joined(separator: " "))
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if item.assetCount > 0 {
                Text("\(item.assetCount)")
                    .font(.mono(15, relativeTo: .subheadline))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
