import SwiftUI

/// Brand design tokens ported from the web app's `src/index.css` (dark theme).
/// Light theme is deferred for the MVP, so only dark values live here.
enum Theme {
    // Accent
    static let accent      = Color(hex: 0x2A9D8F)
    static let accentHover = Color(hex: 0x228377)

    // Surfaces (darkest -> lightest)
    static let surface0 = Color(hex: 0x08090D)
    static let surface1 = Color(hex: 0x0E1018)
    static let surface2 = Color(hex: 0x161922)
    static let surface3 = Color(hex: 0x1E212D)

    // Borders
    static let borderDefault = Color(hex: 0x262A38)
    static let borderHover   = Color(hex: 0x353A4D)
    static let borderActive  = Color(hex: 0x464B62)

    // Text
    static let textPrimary   = Color(hex: 0xF0F0F2)
    static let textSecondary = Color(hex: 0xA0A3B1)
    static let textTertiary  = Color(hex: 0x636678)
    static let textMuted     = Color(hex: 0x464959)

    // Status
    static let success = Color(hex: 0x34D399)
    static let error   = Color(hex: 0xF87171)

    /// Corner radii (points), matching the web tokens.
    enum Radius {
        static let sm: CGFloat = 2
        static let md: CGFloat = 6
        static let lg: CGFloat = 8
        static let pill: CGFloat = 9999
    }
}

extension Color {
    /// Build a Color from a `0xRRGGBB` integer literal (sRGB).
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
