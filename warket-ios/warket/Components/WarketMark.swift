import SwiftUI

/// The warket dial. Two layers drawn by `design/build-mark.py` that share one crop,
/// so they stack exactly: the dial follows the text colour, the key notch keeps its teal.
struct WarketMark: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            Image("WarketMarkDial")
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(Theme.textPrimary)
            Image("WarketMarkKey")
                .resizable()
                .renderingMode(.original)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
