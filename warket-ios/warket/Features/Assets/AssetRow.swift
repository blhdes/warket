import SwiftUI

/// Compact asset row for the assets list: thumbnail, name + ticker, summary.
struct AssetRow: View {
    let asset: Asset
    @ScaledMetric(relativeTo: .body) private var thumbSize: CGFloat = 40

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(asset.name)
                        .font(.headline)
                        .lineLimit(1)
                    if !asset.ticker.isEmpty {
                        Text(asset.ticker.uppercased())
                            .font(.caption.weight(.semibold))
                            .monospaced()
                            .foregroundStyle(.secondary)
                    }
                }
                if !asset.summary.isEmpty {
                    Text(asset.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        Group {
            if let raw = asset.imageUrl, !raw.isEmpty, let url = URL(string: raw) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: thumbSize, height: thumbSize)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(.fill.tertiary)
            .overlay(
                Text(initials)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            )
    }

    private var initials: String {
        let base = asset.ticker.isEmpty ? asset.name : asset.ticker
        return String(base.prefix(2)).uppercased()
    }
}
