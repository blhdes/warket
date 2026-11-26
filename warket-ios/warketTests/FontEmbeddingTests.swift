import XCTest
import UIKit

/// Verifies the wordmark font is actually bundled + registered (UIAppFonts).
/// `Font.custom` fails silently to a system font, so this catches a bad filename
/// or PostScript name that we otherwise couldn't see without running the UI.
final class FontEmbeddingTests: XCTestCase {
    func testBrandFontsAreRegistered() {
        let postScriptNames = [
            "InstrumentSerif-Regular",
        ]
        for name in postScriptNames {
            XCTAssertNotNil(UIFont(name: name, size: 17), "Font \"\(name)\" is not registered or bundled")
        }
    }
}
