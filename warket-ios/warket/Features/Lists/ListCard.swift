import SwiftUI

/// One tile in the lists grid: name, asset count, and up to three tags. It grows with Dynamic Type.
struct ListCard: View {
    let item: ListWithAssetCount
    @ScaledMetric(relativeTo: .headline) private var minHeight: CGFloat = 104

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.list.name)
                .font(.headline)
                .lineLimit(2)
            Spacer(minLength: 0)
            if item.assetCount > 0 {
                Text("\(item.assetCount) \(item.assetCount == 1 ? "asset" : "assets")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: Double(item.assetCount)))
                    .animation(.snappy, value: item.assetCount)
            }
            if !item.list.tags.isEmpty {
                Text(item.list.tags.prefix(3).map { "#\($0)" }.joined(separator: " "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: .rect(cornerRadius: 16, style: .continuous))
        .contentShape(.rect(cornerRadius: 16, style: .continuous))
    }
}
