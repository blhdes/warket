import SwiftUI

/// Provisional (purism plan S1): content no longer sits on glass (Apple keeps Liquid Glass for
/// bars and controls). Same signature, so no call site changes yet. S3 to S5 remove each call,
/// S5 deletes this file.
extension View {
    func glassSurface<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        background {
            shape.fill(Color(.secondarySystemGroupedBackground))
                .overlay { if let tint { shape.fill(tint.opacity(0.12)) } }
        }
    }
}
