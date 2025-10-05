//
//  VoiceProviderManager.swift
//  SwiftHablare
//
//  Manages voice providers and handles switching between them
//

import Combine
import Foundation
import SwiftData

/// Manages voice providers and handles switching between them
@MainActor
public final class VoiceProviderManager: ObservableObject {
    @Published public var currentProviderType: VoiceProviderType {
        didSet {
            UserDefaults.standard.set(currentProviderType.rawValue, forKey: "selectedVoiceProvider")
        }
    }

    @Published public var lastError: String?

    private var providers: [String: VoiceProvider] = [:]
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext

        // Load saved provider or default to ElevenLabs
        if let savedProvider = UserDefaults.standard.string(forKey: "selectedVoiceProvider"),
           let providerType = VoiceProviderType(rawValue: savedProvider) {
            currentProviderType = providerType
        } else {
            currentProviderType = .elevenlabs
        }

        // Register providers
        registerProvider(ElevenLabsVoiceProvider())
        registerProvider(AppleVoiceProvider())
    }

    /// Register a voice provider
    public func registerProvider(_ provider: VoiceProvider) {
        providers[provider.providerId] = provider
    }

    /// Get the current active provider
    public func getCurrentProvider() -> VoiceProvider? {
        return providers[currentProviderType.rawValue]
    }

    /// Get a provider by ID
    public func getProvider(for providerId: String) -> VoiceProvider? {
        return providers[providerId]
    }

    /// Check if current provider is configured
    public func isCurrentProviderConfigured() -> Bool {
        guard let provider = getCurrentProvider() else { return false }
        return provider.isConfigured()
    }

    /// Get voices from current provider (with caching)
    public func getVoices(forceRefresh: Bool = false) async throws -> [Voice] {
        guard let provider = getCurrentProvider() else {
            lastError = "No voice provider available"
            throw VoiceProviderError.unsupportedProvider
        }

        let providerId = provider.providerId

        // Try to get cached voices if not forcing refresh
        if !forceRefresh {
            do {
                let descriptor = FetchDescriptor<VoiceModel>(
                    predicate: #Predicate<VoiceModel> { voice in
                        voice.providerId == providerId
                    },
                    sortBy: [SortDescriptor(\.name)]
                )
                let cachedVoices = try modelContext.fetch(descriptor)

                if !cachedVoices.isEmpty {
                    return cachedVoices.map { $0.toVoice() }
                }
            } catch {
                // Continue to fetch from provider
            }
        }

        // Fetch from provider
        do {
            let voices = try await provider.fetchVoices()

            // Cache the voices
            try await cacheVoices(voices, providerId: providerId)

            lastError = nil
            return voices
        } catch {
            let errorMessage = "Failed to fetch voices from \(provider.displayName): \(error.localizedDescription)"
            lastError = errorMessage
            throw error
        }
    }

    /// Generate audio using current provider
    public func generateAudio(text: String, voiceId: String) async throws -> Data {
        guard let provider = getCurrentProvider() else {
            throw VoiceProviderError.unsupportedProvider
        }

        return try await provider.generateAudio(text: text, voiceId: voiceId)
    }

    /// Generate audio using a specific provider and voice, with caching in SwiftData
    public func generateAndCacheAudio(
        text: String,
        voiceId: String,
        providerId: String,
        audioFormat: String = "mp3"
    ) async throws -> AudioFile {
        // Check if we already have this audio cached
        let descriptor = FetchDescriptor<AudioFile>(
            predicate: #Predicate<AudioFile> { audio in
                audio.text == text && audio.voiceId == voiceId && audio.providerId == providerId
            }
        )

        if let cachedAudio = try modelContext.fetch(descriptor).first {
            return cachedAudio
        }

        // Generate new audio
        guard let provider = getProvider(for: providerId) else {
            throw VoiceProviderError.unsupportedProvider
        }

        let audioData = try await provider.generateAudio(text: text, voiceId: voiceId)
        let duration = await provider.estimateDuration(text: text, voiceId: voiceId)

        // Create and save AudioFile model
        let audioFile = AudioFile(
            text: text,
            voiceId: voiceId,
            providerId: providerId,
            audioData: audioData,
            audioFormat: audioFormat,
            duration: duration
        )

        modelContext.insert(audioFile)
        try modelContext.save()

        return audioFile
    }

    /// Write audio file from SwiftData to a writable URL
    public func writeAudioFile(_ audioFile: AudioFile, to url: URL) throws {
        try audioFile.audioData.write(to: url)
    }

    /// Cache voices in SwiftData
    private func cacheVoices(_ voices: [Voice], providerId: String) async throws {
        // Clear existing cached voices for this provider
        let existingVoicesDescriptor = FetchDescriptor<VoiceModel>(
            predicate: #Predicate<VoiceModel> { voice in
                voice.providerId == providerId
            }
        )
        let existingVoices = try modelContext.fetch(existingVoicesDescriptor)
        for voice in existingVoices {
            modelContext.delete(voice)
        }

        // Save new voices
        for voice in voices {
            let voiceModel = VoiceModel.from(voice)
            modelContext.insert(voiceModel)
        }

        try modelContext.save()
    }

    /// Get all available provider types
    public func getAvailableProviders() -> [VoiceProviderType] {
        return VoiceProviderType.allCases
    }

    /// Switch to a different provider
    public func switchProvider(to providerType: VoiceProviderType) {
        currentProviderType = providerType
        lastError = nil
    }
}
