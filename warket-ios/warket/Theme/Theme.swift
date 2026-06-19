import SwiftUI
import UIKit

/// Brand design tokens ported from the web app's `src/index.css`. Each color is
/// *adaptive*: it resolves to the dark or light value based on the active iOS
/// interface style, so every `Theme.xxx` call site follows the system setting
/// without change. Dark/light hex pairs mirror the `:root` and
/// `[data-theme="light"]` blocks in `index.css`.
enum Theme {
    // Accent
    static let accent      = Color.adaptive(dark: 0x2A9D8F, light: 0x1A8377)
    static let accentHover = Color.adaptive(dark: 0x228377, light: 0x146D63)

    // Surfaces (darkest -> lightest in dark mode; lightest base in light mode)
    static let surface0 = Color.adaptive(dark: 0x08090D, light: 0xF8F9FB)
    static let surface1 = Color.adaptive(dark: 0x0E1018, light: 0xFFFFFF)
    static let surface2 = Color.adaptive(dark: 0x161922, light: 0xF0F1F5)
    static let surface3 = Color.adaptive(dark: 0x1E212D, light: 0xE4E6ED)

    // Borders
    static let borderDefault = Color.adaptive(dark: 0x262A38, light: 0xDFE1E8)
    static let borderHover   = Color.adaptive(dark: 0x353A4D, light: 0xC8CBD6)
    static let borderActive  = Color.adaptive(dark: 0x464B62, light: 0xB0B4C3)

    // Text
    static let textPrimary   = Color.adaptive(dark: 0xF0F0F2, light: 0x1A1D27)
    static let textSecondary = Color.adaptive(dark: 0xA0A3B1, light: 0x4A4E5C)
    static let textTertiary  = Color.adaptive(dark: 0x636678, light: 0x7A7F91)
    static let textMuted     = Color.adaptive(dark: 0x464959, light: 0xA0A4B4)

    // Status
    static let success = Color.adaptive(dark: 0x34D399, light: 0x059669)
    static let error   = Color.adaptive(dark: 0xF87171, light: 0xDC2626)

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

    /// A color that resolves to `dark` or `light` (both `0xRRGGBB`) based on the
    /// active interface style — the foundation of the app's system-driven theme.
    static func adaptive(dark: UInt, light: UInt) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt) {
        self.init(
            red:   CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue:  CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
