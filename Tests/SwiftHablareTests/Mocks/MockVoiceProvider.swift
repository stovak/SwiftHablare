//
//  MockVoiceProvider.swift
//  SwiftHablareTests
//
//  Mock VoiceProvider for testing
//

import Foundation
@testable import SwiftHablare

/// Mock VoiceProvider for testing purposes
final class MockVoiceProvider: VoiceProvider, @unchecked Sendable {
    var providerId: String
    var displayName: String
    var requiresAPIKey: Bool

    // Configuration
    private var _isConfigured: Bool
    private var _voices: [Voice]
    private var _audioData: Data
    private var _shouldThrowOnFetchVoices: Bool
    private var _shouldThrowOnGenerateAudio: Bool
    private var _estimatedDuration: TimeInterval

    // Call tracking
    private(set) var fetchVoicesCalled = false
    private(set) var generateAudioCalled = false
    private(set) var isConfiguredCalled = false
    private(set) var estimateDurationCalled = false
    private(set) var isVoiceAvailableCalled = false

    private(set) var lastGenerateAudioText: String?
    private(set) var lastGenerateAudioVoiceId: String?
    private(set) var lastEstimateDurationText: String?
    private(set) var lastEstimateDurationVoiceId: String?
    private(set) var lastIsVoiceAvailableVoiceId: String?

    init(
        providerId: String = "mock-provider",
        displayName: String = "Mock Provider",
        requiresAPIKey: Bool = false,
        isConfigured: Bool = true,
        voices: [Voice] = [],
        audioData: Data = Data([0x01, 0x02, 0x03]),
        shouldThrowOnFetchVoices: Bool = false,
        shouldThrowOnGenerateAudio: Bool = false,
        estimatedDuration: TimeInterval = 1.0
    ) {
        self.providerId = providerId
        self.displayName = displayName
        self.requiresAPIKey = requiresAPIKey
        self._isConfigured = isConfigured
        self._voices = voices
        self._audioData = audioData
        self._shouldThrowOnFetchVoices = shouldThrowOnFetchVoices
        self._shouldThrowOnGenerateAudio = shouldThrowOnGenerateAudio
        self._estimatedDuration = estimatedDuration
    }

    func isConfigured() -> Bool {
        isConfiguredCalled = true
        return _isConfigured
    }

    func fetchVoices() async throws -> [Voice] {
        fetchVoicesCalled = true

        if _shouldThrowOnFetchVoices {
            throw VoiceProviderError.networkError("Mock fetch voices error")
        }

        return _voices
    }

    func generateAudio(text: String, voiceId: String) async throws -> Data {
        generateAudioCalled = true
        lastGenerateAudioText = text
        lastGenerateAudioVoiceId = voiceId

        if _shouldThrowOnGenerateAudio {
            throw VoiceProviderError.networkError("Mock generate audio error")
        }

        return _audioData
    }

    func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        estimateDurationCalled = true
        lastEstimateDurationText = text
        lastEstimateDurationVoiceId = voiceId
        return _estimatedDuration
    }

    func isVoiceAvailable(voiceId: String) async -> Bool {
        isVoiceAvailableCalled = true
        lastIsVoiceAvailableVoiceId = voiceId
        return _voices.contains { $0.id == voiceId }
    }

    // Helper methods for test configuration
    func setConfigured(_ configured: Bool) {
        _isConfigured = configured
    }

    func setVoices(_ voices: [Voice]) {
        _voices = voices
    }

    func setAudioData(_ data: Data) {
        _audioData = data
    }

    func setShouldThrowOnFetchVoices(_ shouldThrow: Bool) {
        _shouldThrowOnFetchVoices = shouldThrow
    }

    func setShouldThrowOnGenerateAudio(_ shouldThrow: Bool) {
        _shouldThrowOnGenerateAudio = shouldThrow
    }

    func setEstimatedDuration(_ duration: TimeInterval) {
        _estimatedDuration = duration
    }

    func reset() {
        fetchVoicesCalled = false
        generateAudioCalled = false
        isConfiguredCalled = false
        estimateDurationCalled = false
        isVoiceAvailableCalled = false
        lastGenerateAudioText = nil
        lastGenerateAudioVoiceId = nil
        lastEstimateDurationText = nil
        lastEstimateDurationVoiceId = nil
        lastIsVoiceAvailableVoiceId = nil
    }
}
