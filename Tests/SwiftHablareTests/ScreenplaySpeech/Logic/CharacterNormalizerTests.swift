import XCTest
@testable import SwiftHablare

final class CharacterNormalizerTests: XCTestCase {
    var normalizer: CharacterNormalizer!

    override func setUp() async throws {
        normalizer = CharacterNormalizer()
    }

    func testBasicNormalization() {
        XCTAssertEqual(normalizer.normalize("JOHN"), "john")
        XCTAssertEqual(normalizer.normalize("Sarah"), "sarah")
        XCTAssertEqual(normalizer.normalize("THE MAYOR"), "the mayor")
    }

    func testVoiceOverModifier() {
        XCTAssertEqual(normalizer.normalize("JOHN (V.O.)"), "john")
        XCTAssertEqual(normalizer.normalize("SARAH (V.O.)"), "sarah")
    }

    func testOffScreenModifier() {
        XCTAssertEqual(normalizer.normalize("JOHN (O.S.)"), "john")
        XCTAssertEqual(normalizer.normalize("SARAH (O.S.)"), "sarah")
    }

    func testContinuedModifier() {
        XCTAssertEqual(normalizer.normalize("JOHN (CONT'D)"), "john")
        XCTAssertEqual(normalizer.normalize("SARAH (CONT'D)"), "sarah")
    }

    func testMultipleModifiers() {
        XCTAssertEqual(normalizer.normalize("JOHN (V.O.) (CONT'D)"), "john")
    }

    func testWhitespaceHandling() {
        XCTAssertEqual(normalizer.normalize("  JOHN  "), "john")
        XCTAssertEqual(normalizer.normalize("JOHN (V.O.) "), "john")
    }

    func testUserDefinedAliases() {
        // GIVEN
        normalizer.userDefinedAliases["JOHN (V.O.)"] = "john"
        normalizer.userDefinedAliases["YOUNG JOHN"] = "john"

        // THEN
        XCTAssertEqual(normalizer.normalize("JOHN (V.O.)"), "john")
        XCTAssertEqual(normalizer.normalize("YOUNG JOHN"), "john")
    }

    func testConsistency() {
        // Same character different representations should normalize to same
        let variations = ["JOHN", "JOHN (V.O.)", "JOHN (O.S.)", "john", "John"]
        let normalized = variations.map { normalizer.normalize($0) }

        XCTAssertEqual(Set(normalized).count, 1)
        XCTAssertEqual(normalized.first, "john")
    }
}
