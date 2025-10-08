//
//  MockElevenLabsVoiceProviderSimulator.swift
//  SwiftHablareTests
//
//  Simulates ElevenLabs VoiceProvider responses with documented API format
//

import Foundation
import SwiftFixtureManager
@testable import SwiftHablare

/// Simulates ElevenLabs VoiceProvider with realistic API responses
final class MockElevenLabsVoiceProviderSimulator: VoiceProvider, @unchecked Sendable {
    let providerId = "elevenlabs"
    let displayName = "ElevenLabs"
    let requiresAPIKey = true

    private var _apiKey: String?
    private var _shouldThrowOnFetchVoices = false
    private var _shouldThrowOnGenerateAudio = false
    private var _customVoices: [Voice]?
    private var _httpErrorCode: Int?

    // Call tracking
    private(set) var fetchVoicesCalled = false
    private(set) var generateAudioCalled = false
    private(set) var estimateDurationCalled = false
    private(set) var isVoiceAvailableCalled = false
    private(set) var lastGenerateAudioText: String?
    private(set) var lastGenerateAudioVoiceId: String?
    private(set) var lastIsVoiceAvailableVoiceId: String?

    init(apiKey: String? = "mock-api-key-12345") {
        _apiKey = apiKey
    }

    func isConfigured() -> Bool {
        return _apiKey != nil
    }

    func fetchVoices() async throws -> [Voice] {
        fetchVoicesCalled = true

        guard _apiKey != nil else {
            throw VoiceProviderError.notConfigured
        }

        if _shouldThrowOnFetchVoices {
            throw VoiceProviderError.networkError("HTTP error")
        }

        if let errorCode = _httpErrorCode {
            throw VoiceProviderError.networkError("HTTP \(errorCode)")
        }

        if let customVoices = _customVoices {
            return customVoices
        }

        // Load voices from fixture
        let testFileURL = URL(fileURLWithPath: #filePath)
        let fixturesDir = try FixtureManager.getFixturesDirectory(from: testFileURL)
        let fixtureURL = fixturesDir.appendingPathComponent("voices/elevenlabs_voices.json")
        let jsonData = try Data(contentsOf: fixtureURL)

        struct ElevenLabsVoiceResponse: Codable {
            struct VoiceData: Codable {
                let voice_id: String
                let name: String
                let description: String
                let labels: Labels

                struct Labels: Codable {
                    let gender: String
                }
            }
            let voices: [VoiceData]
        }

        let decoder = JSONDecoder()
        let response = try decoder.decode(ElevenLabsVoiceResponse.self, from: jsonData)

        return response.voices.map { voiceData in
            Voice(
                id: voiceData.voice_id,
                name: voiceData.name,
                description: voiceData.description,
                providerId: providerId,
                language: "en",
                locality: "US",
                gender: voiceData.labels.gender
            )
        }
    }

    func generateAudio(text: String, voiceId: String) async throws -> Data {
        generateAudioCalled = true
        lastGenerateAudioText = text
        lastGenerateAudioVoiceId = voiceId

        guard _apiKey != nil else {
            throw VoiceProviderError.notConfigured
        }

        if _shouldThrowOnGenerateAudio {
            throw VoiceProviderError.networkError("HTTP 400: Invalid request")
        }

        if let errorCode = _httpErrorCode {
            var errorMessage = "HTTP \(errorCode)"
            switch errorCode {
            case 401:
                errorMessage += ": Invalid API key"
            case 404:
                errorMessage += ": Voice not found"
            case 429:
                errorMessage += ": Rate limit exceeded"
            case 500:
                errorMessage += ": Internal server error"
            default:
                break
            }
            throw VoiceProviderError.networkError(errorMessage)
        }

        // Generate simulated MP3 audio data
        // This is a minimal valid MP3 header that represents silent audio
        return generateMockMP3Data(duration: await estimateDuration(text: text, voiceId: voiceId))
    }

    func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        estimateDurationCalled = true

        // Simulate ElevenLabs duration estimation
        // Average professional narration: ~150-160 words per minute
        // Average word length: ~5 characters
        // So approximately 750-800 characters per minute, or ~13 characters per second
        let characterCount = Double(text.count)
        let baseCharsPerSecond = 13.0
        let estimatedSeconds = characterCount / baseCharsPerSecond

        // Add buffer for punctuation pauses and natural speech rhythm
        return max(1.0, estimatedSeconds * 1.15)
    }

    func isVoiceAvailable(voiceId: String) async -> Bool {
        isVoiceAvailableCalled = true
        lastIsVoiceAvailableVoiceId = voiceId

        guard _apiKey != nil else {
            return false
        }

        // Check against our simulated voices
        let voices = (try? await fetchVoices()) ?? []
        return voices.contains { $0.id == voiceId }
    }

    // MARK: - Test Configuration

    func setApiKey(_ key: String?) {
        _apiKey = key
    }

    func setShouldThrowOnFetchVoices(_ shouldThrow: Bool) {
        _shouldThrowOnFetchVoices = shouldThrow
    }

    func setShouldThrowOnGenerateAudio(_ shouldThrow: Bool) {
        _shouldThrowOnGenerateAudio = shouldThrow
    }

    func setCustomVoices(_ voices: [Voice]) {
        _customVoices = voices
    }

    func setHTTPErrorCode(_ code: Int?) {
        _httpErrorCode = code
    }

    func reset() {
        fetchVoicesCalled = false
        generateAudioCalled = false
        estimateDurationCalled = false
        isVoiceAvailableCalled = false
        lastGenerateAudioText = nil
        lastGenerateAudioVoiceId = nil
        lastIsVoiceAvailableVoiceId = nil
        _shouldThrowOnFetchVoices = false
        _shouldThrowOnGenerateAudio = false
        _customVoices = nil
        _httpErrorCode = nil
    }

    // MARK: - Private Helpers

    private func generateMockMP3Data(duration: TimeInterval) -> Data {
        // Load MP3 fixture data
        let testFileURL = URL(fileURLWithPath: #filePath)
        if let fixturesDir = try? FixtureManager.getFixturesDirectory(from: testFileURL) {
            let fixtureURL = fixturesDir.appendingPathComponent("audio/sample_mp3.fixture")
            if let mp3Data = try? Data(contentsOf: fixtureURL) {
                return mp3Data
            }
        }

        // Fallback: generate minimal MP3 data
        var data = Data()
        data.append(contentsOf: [0x49, 0x44, 0x33]) // "ID3"
        data.append(contentsOf: [0x03, 0x00]) // Version 2.3
        data.append(contentsOf: [0x00]) // Flags
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Size
        return data
    }

    // MARK: - Simulated API Response Structures

    /// Simulates the ElevenLabs API /v1/voices response format
    static func simulateVoicesAPIResponse() -> Data {
        let json = """
        {
            "voices": [
                {
                    "voice_id": "21m00Tcm4TlvDq8ikWAM",
                    "name": "Rachel",
                    "description": "A young, calm female voice with an American accent",
                    "labels": {
                        "accent": "american",
                        "gender": "female",
                        "age": "young",
                        "use_case": "narration"
                    },
                    "verified_languages": [
                        {
                            "language": "English",
                            "locale": "en-US",
                            "model_id": "eleven_monolingual_v1"
                        }
                    ]
                },
                {
                    "voice_id": "ErXwobaYiN019PkySvjV",
                    "name": "Antoni",
                    "description": "A well-rounded male voice with an American accent",
                    "labels": {
                        "accent": "american",
                        "gender": "male",
                        "age": "middle_aged",
                        "use_case": "narration"
                    },
                    "verified_languages": [
                        {
                            "language": "English",
                            "locale": "en-US",
                            "model_id": "eleven_monolingual_v1"
                        }
                    ]
                }
            ]
        }
        """
        return json.data(using: .utf8)!
    }

    /// Simulates an error response from ElevenLabs API
    static func simulateErrorAPIResponse(statusCode: Int, message: String) -> Data {
        let json = """
        {
            "detail": {
                "status": "error",
                "message": "\(message)"
            }
        }
        """
        return json.data(using: .utf8)!
    }
}
