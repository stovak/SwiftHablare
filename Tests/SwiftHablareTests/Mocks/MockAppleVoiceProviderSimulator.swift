//
//  MockAppleVoiceProviderSimulator.swift
//  SwiftHablareTests
//
//  Simulates Apple VoiceProvider responses without actual speech generation
//

import Foundation
import AVFoundation
import SwiftFijos
@testable import SwiftHablare

/// Simulates Apple VoiceProvider with realistic test data
final class MockAppleVoiceProviderSimulator: VoiceProvider, @unchecked Sendable {
    let providerId = "apple"
    let displayName = "Apple Text-to-Speech"
    let requiresAPIKey = false

    private var _shouldThrowOnFetchVoices = false
    private var _shouldThrowOnGenerateAudio = false
    private var _customVoices: [Voice]?
    private var _simulateNoVoices = false

    // Call tracking
    private(set) var fetchVoicesCalled = false
    private(set) var generateAudioCalled = false
    private(set) var estimateDurationCalled = false
    private(set) var isVoiceAvailableCalled = false
    private(set) var lastGenerateAudioText: String?
    private(set) var lastGenerateAudioVoiceId: String?

    init() {}

    func isConfigured() -> Bool {
        return true // Apple TTS is always available
    }

    func fetchVoices() async throws -> [Voice] {
        fetchVoicesCalled = true

        if _shouldThrowOnFetchVoices {
            throw VoiceProviderError.invalidResponse
        }

        if _simulateNoVoices {
            throw VoiceProviderError.invalidResponse
        }

        if let customVoices = _customVoices {
            return customVoices
        }

        // Load voices from fixture using Fijos
        let fixturesDirectory = try Fijos.getFixturesDirectory()
        let fixtureURL = fixturesDirectory.appendingPathComponent("voices/apple_voices.json")
        let jsonData = try Data(contentsOf: fixtureURL)

        struct AppleVoiceResponse: Codable {
            struct VoiceData: Codable {
                let identifier: String
                let name: String
                let language: String
                let quality: String
                let gender: String
            }
            let voices: [VoiceData]
        }

        let decoder = JSONDecoder()
        let response = try decoder.decode(AppleVoiceResponse.self, from: jsonData)

        return response.voices.map { voiceData in
            let components = voiceData.language.split(separator: "-")
            let language = String(components.first ?? "en")
            let locality = String(components.last ?? "US")

            return Voice(
                id: voiceData.identifier,
                name: voiceData.name,
                description: "English (\(locality)) - \(voiceData.quality.capitalized) Quality",
                providerId: providerId,
                language: language,
                locality: locality,
                gender: voiceData.gender
            )
        }
    }

    func generateAudio(text: String, voiceId: String) async throws -> Data {
        generateAudioCalled = true
        lastGenerateAudioText = text
        lastGenerateAudioVoiceId = voiceId

        if _shouldThrowOnGenerateAudio {
            throw VoiceProviderError.networkError("Audio generation failed")
        }

        // Generate simulated CAF audio file data (minimal valid CAF header)
        // This is a valid but silent audio file that mimics Apple's output
        return generateMockCAFData(duration: await estimateDuration(text: text, voiceId: voiceId))
    }

    func estimateDuration(text: String, voiceId: String) async -> TimeInterval {
        estimateDurationCalled = true

        // Simulate Apple's duration estimation algorithm
        // Average speech rate at default (0.5) is approximately 14-16 characters per second
        let characterCount = Double(text.count)
        let baseCharsPerSecond = 14.5
        let estimatedSeconds = characterCount / baseCharsPerSecond

        // Add small buffer for pauses and punctuation
        return max(1.0, estimatedSeconds * 1.1)
    }

    func isVoiceAvailable(voiceId: String) async -> Bool {
        isVoiceAvailableCalled = true

        // Check against our simulated voices
        let voices = (try? await fetchVoices()) ?? []
        return voices.contains { $0.id == voiceId }
    }

    // MARK: - Test Configuration

    func setShouldThrowOnFetchVoices(_ shouldThrow: Bool) {
        _shouldThrowOnFetchVoices = shouldThrow
    }

    func setShouldThrowOnGenerateAudio(_ shouldThrow: Bool) {
        _shouldThrowOnGenerateAudio = shouldThrow
    }

    func setCustomVoices(_ voices: [Voice]) {
        _customVoices = voices
    }

    func setSimulateNoVoices(_ simulate: Bool) {
        _simulateNoVoices = simulate
    }

    func reset() {
        fetchVoicesCalled = false
        generateAudioCalled = false
        estimateDurationCalled = false
        isVoiceAvailableCalled = false
        lastGenerateAudioText = nil
        lastGenerateAudioVoiceId = nil
        _shouldThrowOnFetchVoices = false
        _shouldThrowOnGenerateAudio = false
        _customVoices = nil
        _simulateNoVoices = false
    }

    // MARK: - Private Helpers

    private func generateMockCAFData(duration: TimeInterval) -> Data {
        // Load CAF fixture data using Fijos
        if let fixturesDirectory = try? Fijos.getFixturesDirectory() {
            let fixtureURL = fixturesDirectory.appendingPathComponent("audio/sample_caf.fixture")
            if let cafData = try? Data(contentsOf: fixtureURL) {
                return cafData
            }
        }

        // Fallback: generate minimal CAF data
        var data = Data()
        data.append(contentsOf: [0x63, 0x61, 0x66, 0x66]) // "caff"
        data.append(contentsOf: [0x00, 0x01]) // Version 1
        data.append(contentsOf: [0x00, 0x00]) // Flags
        return data
    }
}
