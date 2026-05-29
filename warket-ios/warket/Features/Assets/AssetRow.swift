import SwiftUI

/// Compact asset row for the assets list: thumbnail, name + ticker, summary.
struct AssetRow: View {
    let asset: Asset

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(asset.name)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    if !asset.ticker.isEmpty {
                        Text(asset.ticker.uppercased())
                            .font(.mono(12, relativeTo: .caption))
                            .foregroundStyle(Theme.accent)
                    }
                }
                if !asset.summary.isEmpty {
                    Text(asset.summary)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
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
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.md)
            .fill(Theme.surface3)
            .overlay(
                Text(initials)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            )
    }

    private var initials: String {
        let base = asset.ticker.isEmpty ? asset.name : asset.ticker
        return String(base.prefix(2)).uppercased()
    }
}
