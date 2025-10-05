//
//  VoiceProviderTests.swift
//  SwiftHablareTests
//
//  Tests for VoiceProvider protocol and related types
//

import XCTest
@testable import SwiftHablare

final class VoiceProviderTests: XCTestCase {

    // MARK: - VoiceProviderType Tests

    func testVoiceProviderTypeRawValues() {
        XCTAssertEqual(VoiceProviderType.elevenlabs.rawValue, "elevenlabs")
        XCTAssertEqual(VoiceProviderType.apple.rawValue, "apple")
    }

    func testVoiceProviderTypeDisplayNames() {
        XCTAssertEqual(VoiceProviderType.elevenlabs.displayName, "ElevenLabs")
        XCTAssertEqual(VoiceProviderType.apple.displayName, "Apple Text-to-Speech")
    }

    func testVoiceProviderTypeAllCases() {
        let allCases = VoiceProviderType.allCases
        XCTAssertEqual(allCases.count, 2)
        XCTAssertTrue(allCases.contains(.elevenlabs))
        XCTAssertTrue(allCases.contains(.apple))
    }

    func testVoiceProviderTypeCodable() throws {
        let type = VoiceProviderType.elevenlabs

        let encoder = JSONEncoder()
        let data = try encoder.encode(type)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(VoiceProviderType.self, from: data)

        XCTAssertEqual(decoded, type)
    }

    // MARK: - VoiceProviderError Tests

    func testVoiceProviderErrorDescriptions() {
        let notConfiguredError = VoiceProviderError.notConfigured
        XCTAssertEqual(
            notConfiguredError.errorDescription,
            "Voice provider is not configured. Please check your settings."
        )

        let networkError = VoiceProviderError.networkError("Connection failed")
        XCTAssertEqual(
            networkError.errorDescription,
            "Network error: Connection failed"
        )

        let invalidResponseError = VoiceProviderError.invalidResponse
        XCTAssertEqual(
            invalidResponseError.errorDescription,
            "Invalid response from voice provider"
        )

        let unsupportedProviderError = VoiceProviderError.unsupportedProvider
        XCTAssertEqual(
            unsupportedProviderError.errorDescription,
            "Unsupported voice provider"
        )

        let notSupportedError = VoiceProviderError.notSupported
        XCTAssertEqual(
            notSupportedError.errorDescription,
            "Audio generation is not supported on this platform"
        )
    }

    // MARK: - MockVoiceProvider Tests

    func testMockVoiceProviderInitialization() {
        let provider = MockVoiceProvider(
            providerId: "test-id",
            displayName: "Test Provider",
            requiresAPIKey: true
        )

        XCTAssertEqual(provider.providerId, "test-id")
        XCTAssertEqual(provider.displayName, "Test Provider")
        XCTAssertTrue(provider.requiresAPIKey)
    }

    func testMockVoiceProviderIsConfigured() {
        let configuredProvider = MockVoiceProvider(isConfigured: true)
        XCTAssertTrue(configuredProvider.isConfigured())
        XCTAssertTrue(configuredProvider.isConfiguredCalled)

        let unconfiguredProvider = MockVoiceProvider(isConfigured: false)
        XCTAssertFalse(unconfiguredProvider.isConfigured())
    }

    func testMockVoiceProviderFetchVoices() async throws {
        let testVoices = [
            Voice(id: "voice-1", name: "Voice 1", description: nil, providerId: "mock"),
            Voice(id: "voice-2", name: "Voice 2", description: nil, providerId: "mock")
        ]

        let provider = MockVoiceProvider(voices: testVoices)
        let voices = try await provider.fetchVoices()

        XCTAssertTrue(provider.fetchVoicesCalled)
        XCTAssertEqual(voices.count, 2)
        XCTAssertEqual(voices[0].id, "voice-1")
        XCTAssertEqual(voices[1].id, "voice-2")
    }

    func testMockVoiceProviderFetchVoicesError() async {
        let provider = MockVoiceProvider(shouldThrowOnFetchVoices: true)

        do {
            _ = try await provider.fetchVoices()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(provider.fetchVoicesCalled)
            XCTAssertTrue(error is VoiceProviderError)
        }
    }

    func testMockVoiceProviderGenerateAudio() async throws {
        let testData = Data([0x01, 0x02, 0x03, 0x04])
        let provider = MockVoiceProvider(audioData: testData)

        let audio = try await provider.generateAudio(text: "Hello", voiceId: "voice-1")

        XCTAssertTrue(provider.generateAudioCalled)
        XCTAssertEqual(provider.lastGenerateAudioText, "Hello")
        XCTAssertEqual(provider.lastGenerateAudioVoiceId, "voice-1")
        XCTAssertEqual(audio, testData)
    }

    func testMockVoiceProviderGenerateAudioError() async {
        let provider = MockVoiceProvider(shouldThrowOnGenerateAudio: true)

        do {
            _ = try await provider.generateAudio(text: "Test", voiceId: "voice-1")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(provider.generateAudioCalled)
            XCTAssertTrue(error is VoiceProviderError)
        }
    }

    func testMockVoiceProviderEstimateDuration() async {
        let provider = MockVoiceProvider(estimatedDuration: 5.5)

        let duration = await provider.estimateDuration(text: "Test text", voiceId: "voice-1")

        XCTAssertTrue(provider.estimateDurationCalled)
        XCTAssertEqual(provider.lastEstimateDurationText, "Test text")
        XCTAssertEqual(provider.lastEstimateDurationVoiceId, "voice-1")
        XCTAssertEqual(duration, 5.5)
    }

    func testMockVoiceProviderIsVoiceAvailable() async {
        let testVoices = [
            Voice(id: "available", name: "Available", description: nil, providerId: "mock")
        ]
        let provider = MockVoiceProvider(voices: testVoices)

        let available = await provider.isVoiceAvailable(voiceId: "available")
        let unavailable = await provider.isVoiceAvailable(voiceId: "unavailable")

        XCTAssertTrue(provider.isVoiceAvailableCalled)
        XCTAssertTrue(available)
        XCTAssertFalse(unavailable)
    }

    func testMockVoiceProviderReset() async throws {
        let provider = MockVoiceProvider()

        // Make some calls
        _ = provider.isConfigured()
        _ = try await provider.fetchVoices()
        _ = try await provider.generateAudio(text: "Test", voiceId: "voice")
        _ = await provider.estimateDuration(text: "Test", voiceId: "voice")
        _ = await provider.isVoiceAvailable(voiceId: "voice")

        // Verify calls were tracked
        XCTAssertTrue(provider.isConfiguredCalled)
        XCTAssertTrue(provider.fetchVoicesCalled)
        XCTAssertTrue(provider.generateAudioCalled)
        XCTAssertTrue(provider.estimateDurationCalled)
        XCTAssertTrue(provider.isVoiceAvailableCalled)

        // Reset
        provider.reset()

        // Verify reset worked
        XCTAssertFalse(provider.isConfiguredCalled)
        XCTAssertFalse(provider.fetchVoicesCalled)
        XCTAssertFalse(provider.generateAudioCalled)
        XCTAssertFalse(provider.estimateDurationCalled)
        XCTAssertFalse(provider.isVoiceAvailableCalled)
        XCTAssertNil(provider.lastGenerateAudioText)
        XCTAssertNil(provider.lastGenerateAudioVoiceId)
        XCTAssertNil(provider.lastEstimateDurationText)
        XCTAssertNil(provider.lastEstimateDurationVoiceId)
        XCTAssertNil(provider.lastIsVoiceAvailableVoiceId)
    }

    func testMockVoiceProviderConfiguration() {
        let provider = MockVoiceProvider()

        // Test setting voices
        let newVoices = [
            Voice(id: "new-1", name: "New 1", description: nil, providerId: "mock")
        ]
        provider.setVoices(newVoices)

        // Test setting audio data
        let newData = Data([0xFF, 0xFE])
        provider.setAudioData(newData)

        // Test setting configured state
        provider.setConfigured(false)
        XCTAssertFalse(provider.isConfigured())

        provider.setConfigured(true)
        XCTAssertTrue(provider.isConfigured())

        // Test setting error behavior
        provider.setShouldThrowOnFetchVoices(true)
        provider.setShouldThrowOnGenerateAudio(true)

        // Test setting duration
        provider.setEstimatedDuration(10.0)
    }

    func testMockVoiceProviderSendable() {
        // This test verifies that MockVoiceProvider can be used in async contexts
        let provider = MockVoiceProvider()

        Task {
            _ = provider.isConfigured()
        }

        // If this compiles and runs without warnings, Sendable conformance is working
        XCTAssertTrue(true)
    }
}
