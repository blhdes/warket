import SwiftUI

/// A wrapping layout (like CSS flex-wrap) for chips/tags that flow onto multiple
/// lines when they run out of horizontal room.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(maxWidth: maxWidth, subviews: subviews)
        let width = maxWidth.isFinite ? maxWidth : (rows.map(\.width).max() ?? 0)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(maxWidth: bounds.width, subviews: subviews)
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

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
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

        for (i, sub) in subviews.enumerated() {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, !items.isEmpty { endRow() }
            items.append(RowItem(index: i, size: size, x: x))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        if !items.isEmpty { endRow() }
        return rows
    }
}
