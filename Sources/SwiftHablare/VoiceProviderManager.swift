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
    /// Current provider ID (string-based for extensibility)
    @Published public var currentProviderId: String {
        didSet {
            UserDefaults.standard.set(currentProviderId, forKey: "selectedVoiceProvider")
        }
    }

    /// Legacy enum-based provider type (deprecated)
    @available(*, deprecated, message: "Use currentProviderId instead")
    @Published public var currentProviderType: VoiceProviderType {
        didSet {
            currentProviderId = currentProviderType.rawValue
        }
    }

    @Published public var lastError: String?

    private var providers: [String: VoiceProvider] = [:]
    private let modelContext: ModelContext

    /// Initialize with ModelContext and optionally register default providers
    /// - Parameters:
    ///   - modelContext: SwiftData model context for caching
    ///   - registerDefaults: Whether to register built-in providers (ElevenLabs, Apple). Default: true
    public init(modelContext: ModelContext, registerDefaults: Bool = true) {
        self.modelContext = modelContext

        // Load saved provider or default to ElevenLabs
        let savedProviderId = UserDefaults.standard.string(forKey: "selectedVoiceProvider") ?? "elevenlabs"
        self.currentProviderId = savedProviderId

        // Set deprecated property for backward compatibility
        if let providerType = VoiceProviderType(rawValue: savedProviderId) {
            self.currentProviderType = providerType
        } else {
            self.currentProviderType = .elevenlabs
        }

        // Register default providers if requested
        if registerDefaults {
            registerProvider(ElevenLabsVoiceProvider())
            registerProvider(AppleVoiceProvider())
        }
    }

    /// Register a voice provider
    public func registerProvider(_ provider: VoiceProvider) {
        providers[provider.providerId] = provider
    }

    /// Get the current active provider
    public func getCurrentProvider() -> VoiceProvider? {
        return providers[currentProviderId]
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

    /// Get all registered provider IDs
    public func getRegisteredProviderIds() -> [String] {
        return Array(providers.keys).sorted()
    }

    /// Get all registered providers as VoiceProviderInfo
    public func getRegisteredProviders() -> [VoiceProviderInfo] {
        return providers.values
            .map { VoiceProviderInfo(from: $0) }
            .sorted { $0.displayName < $1.displayName }
    }

    /// Check if a provider with the given ID is registered
    public func isProviderRegistered(_ providerId: String) -> Bool {
        return providers[providerId] != nil
    }

    /// Unregister a provider by ID
    public func unregisterProvider(_ providerId: String) {
        providers.removeValue(forKey: providerId)
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

    /// Get all available provider types (deprecated)
    @available(*, deprecated, message: "Use getRegisteredProviders() instead")
    public func getAvailableProviders() -> [VoiceProviderType] {
        return VoiceProviderType.allCases
    }

    /// Switch to a different provider by ID
    /// - Parameter providerId: The provider ID to switch to
    /// - Returns: True if switch was successful, false if provider not found
    @discardableResult
    public func switchProvider(to providerId: String) -> Bool {
        guard isProviderRegistered(providerId) else {
            lastError = "Provider '\(providerId)' is not registered"
            return false
        }
        currentProviderId = providerId

        // Update deprecated property if it matches
        if let providerType = VoiceProviderType(rawValue: providerId) {
            currentProviderType = providerType
        }

        lastError = nil
        return true
    }

    /// Switch to a different provider (deprecated enum-based version)
    @available(*, deprecated, message: "Use switchProvider(to: String) instead")
    public func switchProvider(to providerType: VoiceProviderType) {
        switchProvider(to: providerType.rawValue)
    }
}
