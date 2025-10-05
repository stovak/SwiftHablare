//
//  ElevenLabsVoiceProviderTests.swift
//  SwiftHablareTests
//
//  Tests for ElevenLabs Voice Provider using mock simulator
//

import XCTest
@testable import SwiftHablare

final class ElevenLabsVoiceProviderTests: XCTestCase {
    var provider: MockElevenLabsVoiceProviderSimulator!

    override func setUp() {
        provider = MockElevenLabsVoiceProviderSimulator(apiKey: "test-api-key-12345")
    }

    override func tearDown() {
        provider = nil
    }

    // MARK: - Configuration Tests

    func testProviderProperties() {
        XCTAssertEqual(provider.providerId, "elevenlabs")
        XCTAssertEqual(provider.displayName, "ElevenLabs")
        XCTAssertTrue(provider.requiresAPIKey)
    }

    func testIsConfiguredWithAPIKey() {
        XCTAssertTrue(provider.isConfigured())
    }

    func testIsConfiguredWithoutAPIKey() {
        let unconfiguredProvider = MockElevenLabsVoiceProviderSimulator(apiKey: nil)
        XCTAssertFalse(unconfiguredProvider.isConfigured())
    }

    func testSetAPIKey() {
        provider.setApiKey(nil)
        XCTAssertFalse(provider.isConfigured())

        provider.setApiKey("new-key")
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
        XCTAssertEqual(firstVoice.providerId, "elevenlabs")
        XCTAssertNotNil(firstVoice.description)
    }

    func testFetchVoicesReturnsElevenLabsVoices() async throws {
        let voices = try await provider.fetchVoices()

        // Check for known ElevenLabs voices
        let voiceNames = voices.map { $0.name }
        XCTAssertTrue(voiceNames.contains("Rachel"))
        XCTAssertTrue(voiceNames.contains("Antoni"))
        XCTAssertTrue(voiceNames.contains("Bella"))

        // Verify all voices have the correct provider
        XCTAssertTrue(voices.allSatisfy { $0.providerId == "elevenlabs" })
    }

    func testFetchVoicesWithDescriptions() async throws {
        let voices = try await provider.fetchVoices()

        // Verify voices have descriptions
        XCTAssertTrue(voices.allSatisfy { $0.description != nil && !$0.description!.isEmpty })

        // Check specific voice descriptions
        if let rachel = voices.first(where: { $0.name == "Rachel" }) {
            XCTAssertTrue(rachel.description?.contains("young") ?? false)
            XCTAssertTrue(rachel.description?.contains("calm") ?? false)
        }
    }

    func testFetchVoicesWithGenderInformation() async throws {
        let voices = try await provider.fetchVoices()

        // All simulated voices should have gender
        XCTAssertTrue(voices.allSatisfy { $0.gender != nil })

        // Verify gender values
        let genders = voices.compactMap { $0.gender }
        XCTAssertTrue(genders.allSatisfy { ["male", "female"].contains($0) })

        // Check specific voices
        if let rachel = voices.first(where: { $0.name == "Rachel" }) {
            XCTAssertEqual(rachel.gender, "female")
        }
        if let antoni = voices.first(where: { $0.name == "Antoni" }) {
            XCTAssertEqual(antoni.gender, "male")
        }
    }

    func testFetchVoicesWithLanguageAndLocality() async throws {
        let voices = try await provider.fetchVoices()

        // Verify all voices have language information
        XCTAssertTrue(voices.allSatisfy { $0.language != nil })

        // Check for English US voices
        let englishUSVoices = voices.filter { $0.language == "en" && $0.locality == "US" }
        XCTAssertFalse(englishUSVoices.isEmpty)
    }

    func testFetchVoicesNotConfigured() async {
        provider.setApiKey(nil)

        do {
            _ = try await provider.fetchVoices()
            XCTFail("Expected error to be thrown")
        } catch {
            if case VoiceProviderError.notConfigured = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected notConfigured error")
            }
        }
    }

    func testFetchVoicesNetworkError() async {
        provider.setShouldThrowOnFetchVoices(true)

        do {
            _ = try await provider.fetchVoices()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is VoiceProviderError)
            XCTAssertTrue(provider.fetchVoicesCalled)
        }
    }

    func testFetchVoicesHTTPError() async {
        provider.setHTTPErrorCode(401)

        do {
            _ = try await provider.fetchVoices()
            XCTFail("Expected error to be thrown")
        } catch {
            if case let VoiceProviderError.networkError(message) = error {
                XCTAssertTrue(message.contains("401"))
            } else {
                XCTFail("Expected network error")
            }
        }
    }

    func testFetchVoicesWithCustomVoices() async throws {
        let customVoices = [
            Voice(
                id: "custom-voice-id",
                name: "Custom Voice",
                description: "A custom test voice",
                providerId: "elevenlabs",
                language: "en",
                locality: "GB",
                gender: "male"
            )
        ]

        provider.setCustomVoices(customVoices)
        let voices = try await provider.fetchVoices()

        XCTAssertEqual(voices.count, 1)
        XCTAssertEqual(voices[0].name, "Custom Voice")
        XCTAssertEqual(voices[0].locality, "GB")
    }

    // MARK: - Generate Audio Tests

    func testGenerateAudio() async throws {
        let text = "Hello, this is a test of ElevenLabs."
        let voiceId = "21m00Tcm4TlvDq8ikWAM"

        let audioData = try await provider.generateAudio(text: text, voiceId: voiceId)

        XCTAssertTrue(provider.generateAudioCalled)
        XCTAssertEqual(provider.lastGenerateAudioText, text)
        XCTAssertEqual(provider.lastGenerateAudioVoiceId, voiceId)
        XCTAssertFalse(audioData.isEmpty)
    }

    func testGenerateAudioReturnsMP3Format() async throws {
        let audioData = try await provider.generateAudio(
            text: "Test",
            voiceId: "21m00Tcm4TlvDq8ikWAM"
        )

        // Verify MP3/ID3 header (starts with "ID3")
        let headerBytes = [UInt8](audioData.prefix(3))
        let expectedHeader: [UInt8] = [0x49, 0x44, 0x33] // "ID3"
        XCTAssertEqual(headerBytes, expectedHeader)
    }

    func testGenerateAudioWithDifferentVoices() async throws {
        let voices = try await provider.fetchVoices()
        let text = "Testing different voices."

        for voice in voices.prefix(3) {
            let audioData = try await provider.generateAudio(text: text, voiceId: voice.id)
            XCTAssertFalse(audioData.isEmpty, "Failed for voice: \(voice.name)")
            XCTAssertEqual(provider.lastGenerateAudioVoiceId, voice.id)
        }
    }

    func testGenerateAudioNotConfigured() async {
        provider.setApiKey(nil)

        do {
            _ = try await provider.generateAudio(text: "Test", voiceId: "test-voice")
            XCTFail("Expected error to be thrown")
        } catch {
            if case VoiceProviderError.notConfigured = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected notConfigured error")
            }
        }
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

    func testGenerateAudioHTTPErrors() async {
        let errorCodes = [401, 404, 429, 500]

        for code in errorCodes {
            provider.reset()
            provider.setHTTPErrorCode(code)

            do {
                _ = try await provider.generateAudio(text: "Test", voiceId: "test-voice")
                XCTFail("Expected error for HTTP \(code)")
            } catch {
                if case let VoiceProviderError.networkError(message) = error {
                    XCTAssertTrue(message.contains("\(code)"))
                } else {
                    XCTFail("Expected network error for HTTP \(code)")
                }
            }
        }
    }

    func testGenerateAudioHTTPErrorMessages() async {
        // Test specific error messages
        provider.setHTTPErrorCode(401)
        do {
            _ = try await provider.generateAudio(text: "Test", voiceId: "test")
            XCTFail("Expected error")
        } catch let VoiceProviderError.networkError(message) {
            XCTAssertTrue(message.contains("Invalid API key"))
        } catch {
            XCTFail("Unexpected error type")
        }

        provider.reset()
        provider.setHTTPErrorCode(404)
        do {
            _ = try await provider.generateAudio(text: "Test", voiceId: "test")
            XCTFail("Expected error")
        } catch let VoiceProviderError.networkError(message) {
            XCTAssertTrue(message.contains("Voice not found"))
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testGenerateAudioWithLongText() async throws {
        let longText = String(repeating: "This is a longer test sentence. ", count: 50)
        let audioData = try await provider.generateAudio(text: longText, voiceId: "test-voice")

        XCTAssertFalse(audioData.isEmpty)
    }

    // MARK: - Estimate Duration Tests

    func testEstimateDuration() async {
        let text = "Hello, world!"
        let duration = await provider.estimateDuration(text: text, voiceId: "test-voice")

        XCTAssertTrue(provider.estimateDurationCalled)
        XCTAssertGreaterThan(duration, 0)
        XCTAssertGreaterThanOrEqual(duration, 1.0) // Minimum 1 second
    }

    func testEstimateDurationScalesWithText() async {
        let shortText = "Hi"
        let longText = String(repeating: "This is a test sentence. ", count: 20)

        let shortDuration = await provider.estimateDuration(text: shortText, voiceId: "test")
        let longDuration = await provider.estimateDuration(text: longText, voiceId: "test")

        XCTAssertGreaterThan(longDuration, shortDuration)
    }

    func testEstimateDurationFormula() async {
        // Test the specific estimation algorithm
        // ~13 characters per second, with 1.15x buffer
        let text = String(repeating: "a", count: 130) // Should be ~10 seconds base
        let duration = await provider.estimateDuration(text: text, voiceId: "test")

        // Expected: 130 / 13 * 1.15 = ~11.5 seconds
        XCTAssertGreaterThan(duration, 10.0)
        XCTAssertLessThan(duration, 13.0)
    }

    func testEstimateDurationMinimum() async {
        let emptyText = ""
        let duration = await provider.estimateDuration(text: emptyText, voiceId: "test")

        // Should always return at least 1 second
        XCTAssertGreaterThanOrEqual(duration, 1.0)
    }

    // MARK: - Voice Availability Tests

    func testIsVoiceAvailable() async {
        let availableVoiceId = "21m00Tcm4TlvDq8ikWAM" // Rachel
        let isAvailable = await provider.isVoiceAvailable(voiceId: availableVoiceId)

        XCTAssertTrue(provider.isVoiceAvailableCalled)
        XCTAssertEqual(provider.lastIsVoiceAvailableVoiceId, availableVoiceId)
        XCTAssertTrue(isAvailable)
    }

    func testIsVoiceNotAvailable() async {
        let unavailableVoiceId = "nonexistent-voice-id"
        let isAvailable = await provider.isVoiceAvailable(voiceId: unavailableVoiceId)

        XCTAssertFalse(isAvailable)
    }

    func testIsVoiceAvailableWithoutAPIKey() async {
        provider.setApiKey(nil)
        let isAvailable = await provider.isVoiceAvailable(voiceId: "any-voice")

        XCTAssertFalse(isAvailable)
    }

    func testIsVoiceAvailableForAllFetchedVoices() async throws {
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

        provider.setShouldThrowOnFetchVoices(true)
        provider.setHTTPErrorCode(500)

        // Verify state
        XCTAssertTrue(provider.fetchVoicesCalled)
        XCTAssertTrue(provider.generateAudioCalled)
        XCTAssertNotNil(provider.lastGenerateAudioText)

        // Reset
        provider.reset()

        // Verify reset
        XCTAssertFalse(provider.fetchVoicesCalled)
        XCTAssertFalse(provider.generateAudioCalled)
        XCTAssertFalse(provider.estimateDurationCalled)
        XCTAssertFalse(provider.isVoiceAvailableCalled)
        XCTAssertNil(provider.lastGenerateAudioText)
        XCTAssertNil(provider.lastGenerateAudioVoiceId)
        XCTAssertNil(provider.lastIsVoiceAvailableVoiceId)

        // Verify error flags are reset
        do {
            _ = try await provider.fetchVoices()
            // Should succeed now
            XCTAssertTrue(true)
        } catch {
            XCTFail("Should not throw after reset")
        }
    }

    // MARK: - API Response Simulation Tests

    func testSimulatedVoicesAPIResponse() {
        let data = MockElevenLabsVoiceProviderSimulator.simulateVoicesAPIResponse()
        XCTAssertFalse(data.isEmpty)

        // Verify it's valid JSON
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertNotNil(json)
            XCTAssertNotNil(json?["voices"])
        } catch {
            XCTFail("Invalid JSON")
        }
    }

    func testSimulatedErrorAPIResponse() {
        let data = MockElevenLabsVoiceProviderSimulator.simulateErrorAPIResponse(
            statusCode: 401,
            message: "Invalid API key"
        )

        XCTAssertFalse(data.isEmpty)

        // Verify it's valid JSON
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertNotNil(json)
            XCTAssertNotNil(json?["detail"])
        } catch {
            XCTFail("Invalid JSON")
        }
    }

    // MARK: - Integration Tests

    func testCompleteVoiceGenerationFlow() async throws {
        // 1. Verify configured
        XCTAssertTrue(provider.isConfigured())

        // 2. Fetch voices
        let voices = try await provider.fetchVoices()
        XCTAssertFalse(voices.isEmpty)

        // 3. Select a voice
        let selectedVoice = voices.first(where: { $0.name == "Rachel" })!

        // 4. Check if voice is available
        let isAvailable = await provider.isVoiceAvailable(voiceId: selectedVoice.id)
        XCTAssertTrue(isAvailable)

        // 5. Estimate duration
        let text = "This is a complete integration test for ElevenLabs."
        let estimatedDuration = await provider.estimateDuration(text: text, voiceId: selectedVoice.id)
        XCTAssertGreaterThan(estimatedDuration, 0)

        // 6. Generate audio
        let audioData = try await provider.generateAudio(text: text, voiceId: selectedVoice.id)
        XCTAssertFalse(audioData.isEmpty)

        // Verify the audio is in MP3 format
        let headerBytes = [UInt8](audioData.prefix(3))
        XCTAssertEqual(headerBytes, [0x49, 0x44, 0x33]) // "ID3"
    }

    func testMultipleConsecutiveGenerations() async throws {
        let text = "Testing multiple consecutive generations."
        let voiceId = "21m00Tcm4TlvDq8ikWAM"

        for i in 1...5 {
            let audioData = try await provider.generateAudio(text: "\(text) Iteration \(i)", voiceId: voiceId)
            XCTAssertFalse(audioData.isEmpty, "Failed on iteration \(i)")
        }
    }

    func testAllVoiceIDs() async throws {
        let voices = try await provider.fetchVoices()

        // Verify all voice IDs follow ElevenLabs format (alphanumeric, 20+ chars)
        for voice in voices {
            XCTAssertGreaterThanOrEqual(voice.id.count, 20, "Voice ID too short: \(voice.id)")
            XCTAssertTrue(voice.id.allSatisfy { $0.isLetter || $0.isNumber }, "Invalid voice ID format: \(voice.id)")
        }
    }
}
