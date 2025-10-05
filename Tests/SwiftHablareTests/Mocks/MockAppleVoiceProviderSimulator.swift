//
//  MockAppleVoiceProviderSimulator.swift
//  SwiftHablareTests
//
//  Simulates Apple VoiceProvider responses without actual speech generation
//

import Foundation
import AVFoundation
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

        // Return simulated Apple voices (based on common macOS/iOS voices)
        return [
            Voice(
                id: "com.apple.voice.compact.en-US.Samantha",
                name: "Samantha",
                description: "English (United States) - Enhanced Quality",
                providerId: providerId,
                language: "en",
                locality: "US",
                gender: "female"
            ),
            Voice(
                id: "com.apple.voice.compact.en-US.Alex",
                name: "Alex",
                description: "English (United States) - Enhanced Quality",
                providerId: providerId,
                language: "en",
                locality: "US",
                gender: "male"
            ),
            Voice(
                id: "com.apple.voice.compact.en-GB.Daniel",
                name: "Daniel",
                description: "English (United Kingdom) - Enhanced Quality",
                providerId: providerId,
                language: "en",
                locality: "GB",
                gender: "male"
            ),
            Voice(
                id: "com.apple.voice.compact.en-AU.Karen",
                name: "Karen",
                description: "English (Australia) - Enhanced Quality",
                providerId: providerId,
                language: "en",
                locality: "AU",
                gender: "female"
            ),
            Voice(
                id: "com.apple.voice.premium.en-US.Ava",
                name: "Ava",
                description: "English (United States) - Premium Quality",
                providerId: providerId,
                language: "en",
                locality: "US",
                gender: "female"
            )
        ]
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
        // Minimal valid CAF file header
        // CAF = Core Audio Format (Apple's native format)
        var data = Data()

        // File header: "caff" magic
        data.append(contentsOf: [0x63, 0x61, 0x66, 0x66]) // "caff"
        data.append(contentsOf: [0x00, 0x01]) // Version 1
        data.append(contentsOf: [0x00, 0x00]) // Flags

        // Audio description chunk
        data.append(contentsOf: [0x64, 0x65, 0x73, 0x63]) // "desc"
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x20]) // Chunk size: 32 bytes

        // Sample rate: 44100 Hz (as Double)
        let sampleRate: Double = 44100.0
        var sampleRateBytes = sampleRate.bitPattern.bigEndian
        data.append(Data(bytes: &sampleRateBytes, count: 8))

        // Format ID: 'lpcm' (Linear PCM)
        data.append(contentsOf: [0x6C, 0x70, 0x63, 0x6D])

        // Format flags, bytes per packet, frames per packet, channels per frame, bits per channel
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Format flags
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x02]) // Bytes per packet: 2 (16-bit mono)
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x01]) // Frames per packet: 1
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x01]) // Channels per frame: 1 (mono)
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x10]) // Bits per channel: 16

        // Data chunk (silent audio)
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"

        // Calculate data size based on duration
        let frameCount = Int(duration * sampleRate)
        let dataSize = frameCount * 2 // 2 bytes per frame (16-bit)

        // Data chunk size (-1 for unknown/streaming)
        data.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])

        // Edit count
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])

        // Add minimal silent audio data (just a few zero bytes)
        data.append(Data(count: min(dataSize, 100))) // Limited to 100 bytes for test efficiency

        return data
    }
}
