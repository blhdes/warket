import SwiftUI

/// Provisional (purism plan S1): the animated mesh is gone. This view now paints the system
/// background so every screen already looks native. S3 to S5 remove each call site, S5 deletes it.
struct MarketPulseBackground: View {
    var body: some View {
        Color(.systemGroupedBackground).ignoresSafeArea()
    }
}
