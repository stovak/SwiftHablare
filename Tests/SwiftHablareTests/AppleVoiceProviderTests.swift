//
//  AppleVoiceProviderTests.swift
//  SwiftHablareTests
//
//  Tests for Apple Voice Provider using mock simulator
//

import XCTest
@testable import SwiftHablare

final class AppleVoiceProviderTests: XCTestCase {
    var provider: MockAppleVoiceProviderSimulator!

    override func setUp() {
        provider = MockAppleVoiceProviderSimulator()
    }

    override func tearDown() {
        provider = nil
    }

    // MARK: - Configuration Tests

    func testProviderProperties() {
        XCTAssertEqual(provider.providerId, "apple")
        XCTAssertEqual(provider.displayName, "Apple Text-to-Speech")
        XCTAssertFalse(provider.requiresAPIKey)
    }

    func testIsConfigured() {
        // Apple provider is always configured
        XCTAssertTrue(provider.isConfigured())
    }

    // MARK: - Fetch Voices Tests

    func testFetchVoices() async throws {
        let voices = try await provider.fetchVoices()

        XCTAssertTrue(provider.fetchVoicesCalled)
        XCTAssertFalse(voices.isEmpty)

        // Verify voice structure
        let firstVoice = voices[0]
        XCTAssertFalse(firstVoice.id.isEmpty)
        XCTAssertFalse(firstVoice.name.isEmpty)
        XCTAssertEqual(firstVoice.providerId, "apple")
        XCTAssertNotNil(firstVoice.language)
        XCTAssertNotNil(firstVoice.locality)
    }

    func testFetchVoicesReturnsExpectedVoices() async throws {
        let voices = try await provider.fetchVoices()

        // Check for common Apple voices
        let voiceNames = voices.map { $0.name }
        XCTAssertTrue(voiceNames.contains("Samantha"))
        XCTAssertTrue(voiceNames.contains("Alex"))

        // Verify all voices have the correct provider
        XCTAssertTrue(voices.allSatisfy { $0.providerId == "apple" })
    }

    func testFetchVoicesWithEnhancedQuality() async throws {
        let voices = try await provider.fetchVoices()

        // Check that voices include quality information in description
        let descriptions = voices.compactMap { $0.description }
        XCTAssertTrue(descriptions.contains { $0.contains("Enhanced Quality") || $0.contains("Premium Quality") })
    }

    func testFetchVoicesWithGenderInformation() async throws {
        let voices = try await provider.fetchVoices()

        // Check that some voices have gender information
        let voicesWithGender = voices.filter { $0.gender != nil }
        XCTAssertFalse(voicesWithGender.isEmpty)

        // Verify gender values are valid
        let genders = voicesWithGender.compactMap { $0.gender }
        XCTAssertTrue(genders.allSatisfy { ["male", "female"].contains($0) })
    }

    func testFetchVoicesWithLanguageAndLocality() async throws {
        let voices = try await provider.fetchVoices()

        // Check for English voices with different localities
        let englishVoices = voices.filter { $0.language == "en" }
        XCTAssertFalse(englishVoices.isEmpty)

        // Verify localities
        let localities = englishVoices.compactMap { $0.locality }
        XCTAssertTrue(localities.contains("US"))
    }

    func testFetchVoicesError() async {
        provider.setShouldThrowOnFetchVoices(true)

        do {
            _ = try await provider.fetchVoices()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is VoiceProviderError)
            XCTAssertTrue(provider.fetchVoicesCalled)
        }
    }

    func testFetchVoicesNoVoicesAvailable() async {
        provider.setSimulateNoVoices(true)

        do {
            _ = try await provider.fetchVoices()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is VoiceProviderError)
        }
    }

    func testFetchVoicesWithCustomVoices() async throws {
        let customVoices = [
            Voice(
                id: "custom-1",
                name: "Custom Voice",
                description: "Test",
                providerId: "apple",
                language: "en",
                locality: "US",
                gender: "female"
            )
        ]

        provider.setCustomVoices(customVoices)
        let voices = try await provider.fetchVoices()

        XCTAssertEqual(voices.count, 1)
        XCTAssertEqual(voices[0].name, "Custom Voice")
    }

    // MARK: - Generate Audio Tests

    func testGenerateAudio() async throws {
        let text = "Hello, this is a test."
        let voiceId = "com.apple.voice.compact.en-US.Samantha"

        let audioData = try await provider.generateAudio(text: text, voiceId: voiceId)

        XCTAssertTrue(provider.generateAudioCalled)
        XCTAssertEqual(provider.lastGenerateAudioText, text)
        XCTAssertEqual(provider.lastGenerateAudioVoiceId, voiceId)
        XCTAssertFalse(audioData.isEmpty)
    }

    func testGenerateAudioReturnsCAFFormat() async throws {
        let audioData = try await provider.generateAudio(
            text: "Test",
            voiceId: "com.apple.voice.compact.en-US.Alex"
        )

        // Verify CAF file header (starts with "caff")
        let headerBytes = [UInt8](audioData.prefix(4))
        let expectedHeader: [UInt8] = [0x63, 0x61, 0x66, 0x66] // "caff"
        XCTAssertEqual(headerBytes, expectedHeader)
    }

    func testGenerateAudioWithDifferentTextLengths() async throws {
        let shortText = "Hi"
        let longText = String(repeating: "This is a longer test sentence. ", count: 10)

        let shortAudio = try await provider.generateAudio(text: shortText, voiceId: "test")
        let longAudio = try await provider.generateAudio(text: longText, voiceId: "test")

        // Both should generate valid audio
        XCTAssertFalse(shortAudio.isEmpty)
        XCTAssertFalse(longAudio.isEmpty)
    }

    func testGenerateAudioError() async {
        provider.setShouldThrowOnGenerateAudio(true)

        do {
            _ = try await provider.generateAudio(text: "Test", voiceId: "test-voice")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is VoiceProviderError)
            XCTAssertTrue(provider.generateAudioCalled)
        }
    }

    // MARK: - Estimate Duration Tests

    func testEstimateDuration() async {
        let shortText = "Hello"
        let duration = await provider.estimateDuration(text: shortText, voiceId: "test")

        XCTAssertTrue(provider.estimateDurationCalled)
        XCTAssertGreaterThan(duration, 0)
        XCTAssertGreaterThanOrEqual(duration, 1.0) // Minimum 1 second
    }

    func testEstimateDurationScalesWithText() async {
        let shortText = "Hello"
        let longText = String(repeating: "This is a test sentence. ", count: 20)

        let shortDuration = await provider.estimateDuration(text: shortText, voiceId: "test")
        let longDuration = await provider.estimateDuration(text: longText, voiceId: "test")

        // Longer text should have longer estimated duration
        XCTAssertGreaterThan(longDuration, shortDuration)
    }

    func testEstimateDurationFormula() async {
        // Test the specific estimation algorithm
        // ~14.5 characters per second at default rate, with 1.1x buffer
        let text = String(repeating: "a", count: 145) // Should be ~10 seconds base
        let duration = await provider.estimateDuration(text: text, voiceId: "test")

        // Expected: 145 / 14.5 * 1.1 = ~11 seconds
        XCTAssertGreaterThan(duration, 10.0)
        XCTAssertLessThan(duration, 12.0)
    }

    func testEstimateDurationMinimum() async {
        let emptyText = ""
        let duration = await provider.estimateDuration(text: emptyText, voiceId: "test")

        // Should always return at least 1 second
        XCTAssertGreaterThanOrEqual(duration, 1.0)
    }

    // MARK: - Voice Availability Tests

    func testIsVoiceAvailable() async {
        let availableVoiceId = "com.apple.voice.compact.en-US.Samantha"
        let isAvailable = await provider.isVoiceAvailable(voiceId: availableVoiceId)

        XCTAssertTrue(provider.isVoiceAvailableCalled)
        XCTAssertTrue(isAvailable)
    }

    func testIsVoiceNotAvailable() async {
        let unavailableVoiceId = "com.apple.voice.nonexistent"
        let isAvailable = await provider.isVoiceAvailable(voiceId: unavailableVoiceId)

        XCTAssertFalse(isAvailable)
    }

    func testIsVoiceAvailableChecksAllVoices() async throws {
        let voices = try await provider.fetchVoices()

        for voice in voices {
            let isAvailable = await provider.isVoiceAvailable(voiceId: voice.id)
            XCTAssertTrue(isAvailable, "Voice \(voice.name) should be available")
        }
    }

    // MARK: - Reset Tests

    func testReset() async throws {
        // Make some calls
        _ = try await provider.fetchVoices()
        _ = try await provider.generateAudio(text: "Test", voiceId: "test")
        _ = await provider.estimateDuration(text: "Test", voiceId: "test")
        _ = await provider.isVoiceAvailable(voiceId: "test")

        // Verify calls were tracked
        XCTAssertTrue(provider.fetchVoicesCalled)
        XCTAssertTrue(provider.generateAudioCalled)
        XCTAssertTrue(provider.estimateDurationCalled)
        XCTAssertTrue(provider.isVoiceAvailableCalled)

        // Reset
        provider.reset()

        // Verify reset
        XCTAssertFalse(provider.fetchVoicesCalled)
        XCTAssertFalse(provider.generateAudioCalled)
        XCTAssertFalse(provider.estimateDurationCalled)
        XCTAssertFalse(provider.isVoiceAvailableCalled)
        XCTAssertNil(provider.lastGenerateAudioText)
        XCTAssertNil(provider.lastGenerateAudioVoiceId)
    }

    // MARK: - Integration Tests

    func testCompleteVoiceGenerationFlow() async throws {
        // 1. Fetch voices
        let voices = try await provider.fetchVoices()
        XCTAssertFalse(voices.isEmpty)

        // 2. Select a voice
        let selectedVoice = voices[0]

        // 3. Check if voice is available
        let isAvailable = await provider.isVoiceAvailable(voiceId: selectedVoice.id)
        XCTAssertTrue(isAvailable)

        // 4. Estimate duration
        let text = "This is a complete integration test."
        let estimatedDuration = await provider.estimateDuration(text: text, voiceId: selectedVoice.id)
        XCTAssertGreaterThan(estimatedDuration, 0)

        // 5. Generate audio
        let audioData = try await provider.generateAudio(text: text, voiceId: selectedVoice.id)
        XCTAssertFalse(audioData.isEmpty)

        // Verify the audio is in CAF format
        let headerBytes = [UInt8](audioData.prefix(4))
        XCTAssertEqual(headerBytes, [0x63, 0x61, 0x66, 0x66]) // "caff"
    }

    func testMultipleVoiceGenerations() async throws {
        let voices = try await provider.fetchVoices()
        let testText = "Testing multiple voice generations."

        for voice in voices.prefix(3) { // Test first 3 voices
            let audioData = try await provider.generateAudio(text: testText, voiceId: voice.id)
            XCTAssertFalse(audioData.isEmpty, "Failed to generate audio for \(voice.name)")
        }
    }
}
