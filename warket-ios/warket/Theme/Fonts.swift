import SwiftUI

extension Font {
    /// Instrument Serif (display). Scales with Dynamic Type via `relativeTo`.
    static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("InstrumentSerif-Regular", size: size, relativeTo: style)
    }

    /// JetBrains Mono. Its static weights register as separate faces, so we map
    /// each weight to its exact PostScript name rather than relying on `.weight`.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        let name: String
        switch weight {
        case .medium:
            name = "JetBrainsMono-Medium"
        case .semibold, .bold, .heavy, .black:
            name = "JetBrainsMono-SemiBold"
        default:
            name = "JetBrainsMono-Regular"
        }
        return .custom(name, size: size, relativeTo: style)
    }
}
