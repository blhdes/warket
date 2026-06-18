import SwiftUI

/// A small rounded tag label. When `selected`, it uses the accent style — used
/// both for plain display and as a tappable filter chip.
struct TagPill: View {
    let text: String
    var selected: Bool = false

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(selected ? .white : Theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background {
                if selected { Capsule().fill(Theme.accent) }
            }
            .glassSurface(in: Capsule())
    }
}
