//
//  MockElevenLabsVoiceProviderSimulator.swift
//  SwiftHablareTests
//
//  Simulates ElevenLabs VoiceProvider responses with documented API format
//

import Foundation
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

        // Return simulated ElevenLabs voices based on their API documentation
        return [
            Voice(
                id: "21m00Tcm4TlvDq8ikWAM",
                name: "Rachel",
                description: "A young, calm female voice with an American accent",
                providerId: providerId,
                language: "en",
                locality: "US",
                gender: "female"
            ),
            Voice(
                id: "AZnzlk1XvdvUeBnXmlld",
                name: "Domi",
                description: "A confident, strong female voice with an American accent",
                providerId: providerId,
                language: "en",
                locality: "US",
                gender: "female"
            ),
            Voice(
                id: "EXAVITQu4vr4xnSDxMaL",
                name: "Bella",
                description: "A soft, gentle female voice with an American accent",
                providerId: providerId,
                language: "en",
                locality: "US",
                gender: "female"
            ),
            Voice(
                id: "ErXwobaYiN019PkySvjV",
                name: "Antoni",
                description: "A well-rounded male voice with an American accent",
                providerId: providerId,
                language: "en",
                locality: "US",
                gender: "male"
            ),
            Voice(
                id: "MF3mGyEYCl7XYWbV9V6O",
                name: "Elli",
                description: "An emotional, young female voice with an American accent",
                providerId: providerId,
                language: "en",
                locality: "US",
                gender: "female"
            ),
            Voice(
                id: "TxGEqnHWrfWFTfGW9XjX",
                name: "Josh",
                description: "A deep, young male voice with an American accent",
                providerId: providerId,
                language: "en",
                locality: "US",
                gender: "male"
            ),
            Voice(
                id: "VR6AewLTigWG4xSOukaG",
                name: "Arnold",
                description: "A crisp, mature male voice with an American accent",
                providerId: providerId,
                language: "en",
                locality: "US",
                gender: "male"
            ),
            Voice(
                id: "pNInz6obpgDQGcFmaJgB",
                name: "Adam",
                description: "A deep, mature male voice with an American accent",
                providerId: providerId,
                language: "en",
                locality: "US",
                gender: "male"
            ),
            Voice(
                id: "yoZ06aMxZJJ28mfd3POQ",
                name: "Sam",
                description: "A raspy, dynamic male voice with an American accent",
                providerId: providerId,
                language: "en",
                locality: "US",
                gender: "male"
            )
        ]
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
        // Minimal valid MP3 frame header
        // This creates a valid but silent MP3 file
        var data = Data()

        // ID3v2 header (optional but common)
        data.append(contentsOf: [0x49, 0x44, 0x33]) // "ID3"
        data.append(contentsOf: [0x03, 0x00]) // Version 2.3
        data.append(contentsOf: [0x00]) // Flags
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Size (0 for minimal header)

        // MP3 frame header
        // Frame sync: 11 bits of 1 (0xFFE)
        // MPEG Audio version ID: MPEG-1 (11)
        // Layer: Layer III (01)
        // Bitrate: 128 kbps
        // Sample rate: 44.1 kHz
        // Padding: 0
        // Mode: Stereo

        // Simplified MP3 frame header (MPEG-1 Layer III, 128kbps, 44.1kHz, Stereo)
        data.append(contentsOf: [0xFF, 0xFB]) // Frame sync + version + layer
        data.append(contentsOf: [0x90, 0x00]) // Bitrate + sample rate + padding + mode

        // Add some zero bytes as frame data (silent audio)
        let frameCount = max(1, Int(duration)) // At least 1 frame
        for _ in 0..<min(frameCount, 10) { // Limit to 10 frames for test efficiency
            data.append(Data(count: 32)) // 32 bytes per frame (simplified)
        }

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
