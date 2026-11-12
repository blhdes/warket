import SwiftUI

/// Centered icon, title and detail for empty, no-match and error states.
/// Pass `actionTitle` and `action` to show a button under the text, such as "Try again".
struct StateMessage: View {
    let icon: String
    let title: String
    let detail: String
    let tint: Color
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(tint)
            Text(title).font(.headline).foregroundStyle(Theme.textPrimary)
            Text(detail).font(.subheadline).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .glassSurface(in: Capsule(), tint: Theme.accent)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
