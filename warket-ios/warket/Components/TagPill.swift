import SwiftUI

/// A small rounded tag label. When `selected`, it uses the accent style — used
/// both for plain display and as a tappable filter chip.
struct TagPill: View {
    let text: String
    var selected: Bool = false

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(selected ? Theme.accent : Theme.surface2, in: Capsule())
            .foregroundStyle(selected ? .white : Theme.textSecondary)
    }
}
