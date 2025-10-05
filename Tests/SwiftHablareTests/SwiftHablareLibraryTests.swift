//
//  SwiftHablareLibraryTests.swift
//  SwiftHablareTests
//
//  Tests for the main SwiftHablare library interface
//

import XCTest
@testable import SwiftHablare

final class SwiftHablareLibraryTests: XCTestCase {

    func testSwiftHablareVersion() {
        XCTAssertEqual(SwiftHablare.version, "1.0.0")
    }

    func testSwiftHablareVersionIsNotEmpty() {
        XCTAssertFalse(SwiftHablare.version.isEmpty)
    }

    func testSwiftHablareVersionFormat() {
        // Verify version follows semantic versioning format (x.y.z)
        let components = SwiftHablare.version.split(separator: ".")
        XCTAssertEqual(components.count, 3, "Version should follow semantic versioning (major.minor.patch)")
    }
}
