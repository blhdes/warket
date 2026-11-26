import SwiftUI

/// Single-column row used by the native List layout: name, tags, asset count.
struct ListRow: View {
    let item: ListWithAssetCount

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.list.name)
                    .lineLimit(1)
                if !item.list.tags.isEmpty {
                    Text(item.list.tags.prefix(3).map { "#\($0)" }.joined(separator: " "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if item.assetCount > 0 {
                Text("\(item.assetCount)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: Double(item.assetCount)))
                    .animation(.snappy, value: item.assetCount)
                    .accessibilityLabel("\(item.assetCount) \(item.assetCount == 1 ? "asset" : "assets")")
            }
        }
        .padding(.vertical, 4)
    }
}
