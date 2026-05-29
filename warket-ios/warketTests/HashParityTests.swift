import XCTest
@testable import warket

/// M1 checkpoint: the Swift hash MUST match the JS hash byte-for-byte, or
/// existing vaults won't open. Reference vectors come from the implementation plan.
final class HashParityTests: XCTestCase {

    func testVaultHashReferenceVector() throws {
        let raw = "  Legal  Winner THANK year wave sausage worth useful legal winner thank yellow  "
        let hash = try SeedPhrase.hash(raw)
        XCTAssertEqual(hash, "ecb0e7ba498c5920991f0b3483e91f7abafa9ecc6bd82a9a51494589592b1a8f")
    }

    func testNormalizationIsCaseAndSpaceInsensitive() throws {
        let messy = try SeedPhrase.hash("  Legal  Winner THANK year wave sausage worth useful legal winner thank yellow  ")
        let clean = try SeedPhrase.hash("legal winner thank year wave sausage worth useful legal winner thank yellow")
        XCTAssertEqual(messy, clean)
    }

    func testShareHashReferenceVector() {
        let share = SeedPhrase.deriveShareHash("ecb0e7ba498c5920991f0b3483e91f7abafa9ecc6bd82a9a51494589592b1a8f")
        XCTAssertEqual(share, "4aedbd98322b258ec221d52e62bed851cd76131c7e9452e125eaeecd169c8e7f")
    }

    func testRejectsWrongWordCount() {
        XCTAssertThrowsError(try SeedPhrase.hash("only three words")) { error in
            XCTAssertEqual(error as? SeedPhraseError, .invalidWordCount(3))
        }
    }

    func testGenerateProducesTwelveWords() {
        let phrase = SeedPhrase.generate()
        XCTAssertEqual(phrase.split(separator: " ").count, 12)
    }
}
