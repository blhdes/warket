import SwiftUI

/// A wrapping layout (like CSS flex-wrap) for chips/tags that flow onto multiple
/// lines when they run out of horizontal room.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    /// Subview sizes, measured once and reused across the sizing + placement
    /// passes (and across passes until SwiftUI invalidates via updateCache).
    struct Cache {
        var sizes: [CGSize]
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache(sizes: subviews.map { $0.sizeThatFits(.unspecified) })
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(maxWidth: maxWidth, sizes: cache.sizes)
        let width = maxWidth.isFinite ? maxWidth : (rows.map(\.width).max() ?? 0)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let rows = computeRows(maxWidth: bounds.width, sizes: cache.sizes)
        for row in rows {
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
            }
        }
    }

    private struct RowItem { let index: Int; let size: CGSize; let x: CGFloat }
    private struct Row { var items: [RowItem]; var y: CGFloat; var height: CGFloat; var width: CGFloat }

    private func computeRows(maxWidth: CGFloat, sizes: [CGSize]) -> [Row] {
        var rows: [Row] = []
        var items: [RowItem] = []
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0
        var y: CGFloat = 0

        func endRow() {
            rows.append(Row(items: items, y: y, height: rowHeight, width: max(0, x - spacing)))
            y += rowHeight + spacing
            items = []; x = 0; rowHeight = 0
        }

        for (i, size) in sizes.enumerated() {
            if x + size.width > maxWidth, !items.isEmpty { endRow() }
            items.append(RowItem(index: i, size: size, x: x))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        if !items.isEmpty { endRow() }
        return rows
    }
}
