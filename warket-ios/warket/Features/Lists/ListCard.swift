import SwiftUI

/// One card in the lists grid: name, asset count, and up to three tags.
struct ListCard: View {
    let item: ListWithAssetCount

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.list.name)
                .font(.serif(22, relativeTo: .headline))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)

            Spacer(minLength: 0)

            if item.assetCount > 0 {
                Text("\(item.assetCount) \(item.assetCount == 1 ? "asset" : "assets")")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }

            if !item.list.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(item.list.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.surface3, in: Capsule())
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .padding(14)
        .frame(height: 124, alignment: .topLeading)
        .frame(maxWidth: .infinity)
        .background(Theme.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.borderDefault, lineWidth: 1)
        )
    }
}
