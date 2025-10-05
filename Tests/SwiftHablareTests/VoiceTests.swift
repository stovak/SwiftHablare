//
//  VoiceTests.swift
//  SwiftHablareTests
//
//  Tests for the Voice model
//

import XCTest
@testable import SwiftHablare

final class VoiceTests: XCTestCase {

    // MARK: - Initialization Tests

    func testVoiceInitialization() {
        let voice = Voice(
            id: "test-voice-id",
            name: "Test Voice",
            description: "A test voice",
            providerId: "test-provider",
            language: "en",
            locality: "US",
            gender: "female"
        )

        XCTAssertEqual(voice.id, "test-voice-id")
        XCTAssertEqual(voice.name, "Test Voice")
        XCTAssertEqual(voice.description, "A test voice")
        XCTAssertEqual(voice.providerId, "test-provider")
        XCTAssertEqual(voice.language, "en")
        XCTAssertEqual(voice.locality, "US")
        XCTAssertEqual(voice.gender, "female")
    }

    func testVoiceInitializationWithDefaults() {
        let voice = Voice(
            id: "test-id",
            name: "Test",
            description: nil
        )

        XCTAssertEqual(voice.id, "test-id")
        XCTAssertEqual(voice.name, "Test")
        XCTAssertNil(voice.description)
        XCTAssertEqual(voice.providerId, "elevenlabs") // Default
        XCTAssertNil(voice.language)
        XCTAssertNil(voice.locality)
        XCTAssertNil(voice.gender)
    }

    // MARK: - Codable Tests

    func testVoiceEncoding() throws {
        let voice = Voice(
            id: "encode-test",
            name: "Encode Test",
            description: "Test encoding",
            providerId: "provider",
            language: "es",
            locality: "MX",
            gender: "male"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(voice)

        XCTAssertFalse(data.isEmpty)
    }

    func testVoiceDecoding() throws {
        let json = """
        {
            "voice_id": "decoded-voice",
            "name": "Decoded Voice",
            "description": "Test decoding",
            "language": "fr",
            "locality": "FR",
            "gender": "female"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let voice = try decoder.decode(Voice.self, from: data)

        XCTAssertEqual(voice.id, "decoded-voice")
        XCTAssertEqual(voice.name, "Decoded Voice")
        XCTAssertEqual(voice.description, "Test decoding")
        XCTAssertEqual(voice.providerId, "elevenlabs") // Default for decoded
        XCTAssertEqual(voice.language, "fr")
        XCTAssertEqual(voice.locality, "FR")
        XCTAssertEqual(voice.gender, "female")
    }

    func testVoiceDecodingWithMissingOptionalFields() throws {
        let json = """
        {
            "voice_id": "minimal-voice",
            "name": "Minimal Voice"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let voice = try decoder.decode(Voice.self, from: data)

        XCTAssertEqual(voice.id, "minimal-voice")
        XCTAssertEqual(voice.name, "Minimal Voice")
        XCTAssertNil(voice.description)
        XCTAssertEqual(voice.providerId, "elevenlabs")
        XCTAssertNil(voice.language)
        XCTAssertNil(voice.locality)
        XCTAssertNil(voice.gender)
    }

    func testVoiceEncodingDecodingRoundTrip() throws {
        let originalVoice = Voice(
            id: "roundtrip-test",
            name: "Round Trip",
            description: "Testing round trip",
            providerId: "custom-provider",
            language: "de",
            locality: "DE",
            gender: "male"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalVoice)

        let decoder = JSONDecoder()
        let decodedVoice = try decoder.decode(Voice.self, from: data)

        XCTAssertEqual(decodedVoice.id, originalVoice.id)
        XCTAssertEqual(decodedVoice.name, originalVoice.name)
        XCTAssertEqual(decodedVoice.description, originalVoice.description)
        // Note: providerId defaults to "elevenlabs" when decoded
        XCTAssertEqual(decodedVoice.providerId, "elevenlabs")
        XCTAssertEqual(decodedVoice.language, originalVoice.language)
        XCTAssertEqual(decodedVoice.locality, originalVoice.locality)
        XCTAssertEqual(decodedVoice.gender, originalVoice.gender)
    }

    // MARK: - Identifiable Tests

    func testVoiceIdentifiable() {
        let voice1 = Voice(id: "id-1", name: "Voice 1", description: nil)
        let voice2 = Voice(id: "id-2", name: "Voice 2", description: nil)

        XCTAssertNotEqual(voice1.id, voice2.id)
    }

    // MARK: - Mutation Tests

    func testVoiceMutableProperties() {
        var voice = Voice(
            id: "mutable-test",
            name: "Original Name",
            description: "Original Description",
            providerId: "provider1"
        )

        voice.providerId = "provider2"
        voice.language = "ja"
        voice.locality = "JP"
        voice.gender = "female"

        XCTAssertEqual(voice.providerId, "provider2")
        XCTAssertEqual(voice.language, "ja")
        XCTAssertEqual(voice.locality, "JP")
        XCTAssertEqual(voice.gender, "female")
    }
}
