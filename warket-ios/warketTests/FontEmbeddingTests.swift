import XCTest
import UIKit

/// Verifies the brand fonts are actually bundled + registered (UIAppFonts).
/// `Font.custom` fails silently to a system font, so this catches a bad filename
/// or PostScript name that we otherwise couldn't see without running the UI.
final class FontEmbeddingTests: XCTestCase {
    func testBrandFontsAreRegistered() {
        let postScriptNames = [
            "InstrumentSerif-Regular",
            "InstrumentSerif-Italic",
            "JetBrainsMono-Regular",
            "JetBrainsMono-Medium",
            "JetBrainsMono-SemiBold",
        ]
        for name in postScriptNames {
            XCTAssertNotNil(UIFont(name: name, size: 17), "Font \"\(name)\" is not registered or bundled")
        }
    }
}
