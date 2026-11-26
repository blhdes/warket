import SwiftUI

extension Font {
    /// Instrument Serif, used only for the "warket" wordmark. Scales with Dynamic Type via `relativeTo`.
    static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("InstrumentSerif-Regular", size: size, relativeTo: style)
    }
}
