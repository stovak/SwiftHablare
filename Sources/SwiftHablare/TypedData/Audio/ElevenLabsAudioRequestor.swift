//
//  ElevenLabsAudioRequestor.swift
//  SwiftHablare
//
//  Phase 6C: ElevenLabs text-to-speech requestor
//

import Foundation
import SwiftUI

/// ElevenLabs text-to-speech requestor.
///
/// Implements the AIRequestor protocol for ElevenLabs' TTS API.
/// Generates audio from text using various voices and models.
///
/// ## Usage
/// ```swift
/// let requestor = ElevenLabsAudioRequestor(provider: elevenLabsProvider)
///
/// let config = AudioGenerationConfig(
///     voiceID: "21m00Tcm4TlvDq8ikWAM",
///     voiceName: "Rachel",
///     stability: 0.5,
///     similarityBoost: 0.75
/// )
///
/// let result = await requestor.request(
///     prompt: "Hello, world!",
///     configuration: config,
///     storageArea: storageArea
/// )
/// ```
@available(macOS 15.0, iOS 17.0, *)
public final class ElevenLabsAudioRequestor: AIRequestor, @unchecked Sendable {

    // MARK: - Associated Types

    public typealias TypedData = GeneratedAudioData
    public typealias ResponseModel = GeneratedAudioRecord
    public typealias Configuration = AudioGenerationConfig

    // MARK: - Properties

    /// Unique identifier for this requestor
    public let requestorID: String = "elevenlabs.audio.tts"

    /// Human-readable display name
    public let displayName: String = "ElevenLabs Text-to-Speech"

    /// The provider that offers this requestor
    public let providerID: String = "elevenlabs"

    /// Category of content this requestor generates
    public let category: ProviderCategory = .audio

    /// Output file type
    public let outputFileType: OutputFileType = .mp3()

    /// Optional schema for validation
    public let schema: TypedDataSchema? = nil

    /// Maximum expected response size (10MB for audio)
    public let estimatedMaxSize: Int64? = 10_000_000

    // Private properties
    private let provider: ElevenLabsProvider

    // MARK: - Cost Estimation

    /// Estimated cost per character (ElevenLabs pricing)
    /// Based on typical pricing of ~$0.30 per 1000 characters
    private static let estimatedCostPerCharacter: Double = 0.0003

    // MARK: - Initialization

    /// Creates an ElevenLabs audio requestor
    ///
    /// - Parameter provider: ElevenLabs provider instance
    public init(provider: ElevenLabsProvider) {
        self.provider = provider
    }

    // MARK: - Configuration

    public func defaultConfiguration() -> AudioGenerationConfig {
        return AudioGenerationConfig.default
    }

    public func validateConfiguration(_ config: AudioGenerationConfig) throws {
        // Validate voice ID is not empty
        guard !config.voiceID.isEmpty else {
            throw AIServiceError.configurationError(
                "Voice ID cannot be empty"
            )
        }

        // Validate stability range (0.0 to 1.0)
        guard config.stability >= 0.0 && config.stability <= 1.0 else {
            throw AIServiceError.configurationError(
                "Stability must be between 0.0 and 1.0, got \(config.stability)"
            )
        }

        // Validate similarity boost range (0.0 to 1.0)
        guard config.similarityBoost >= 0.0 && config.similarityBoost <= 1.0 else {
            throw AIServiceError.configurationError(
                "Similarity boost must be between 0.0 and 1.0, got \(config.similarityBoost)"
            )
        }

        // Validate model ID is not empty
        guard !config.modelID.isEmpty else {
            throw AIServiceError.configurationError(
                "Model ID cannot be empty"
            )
        }
    }

    // MARK: - Request Execution

    public func request(
        prompt: String,
        configuration: Configuration,
        storageArea: StorageAreaReference
    ) async -> Result<GeneratedAudioData, AIServiceError> {
        // Validate configuration first
        do {
            try validateConfiguration(configuration)
        } catch let error as AIServiceError {
            return .failure(error)
        } catch {
            return .failure(.configurationError(error.localizedDescription))
        }

        // Validate prompt is not empty
        guard !prompt.isEmpty else {
            return .failure(.configurationError("Prompt cannot be empty"))
        }

        // Build parameters for provider
        let parameters: [String: Any] = [
            "voice_id": configuration.voiceID,
            "model_id": configuration.modelID,
            "stability": configuration.stability,
            "clarity_boost": configuration.similarityBoost
        ]

        // Make API call through provider
        let result = await provider.generate(prompt: prompt, parameters: parameters)

        switch result {
        case .success(let content):
            // Extract audio data and format
            guard let audioContent = content.audioContent else {
                return .failure(.unexpectedResponseFormat("Response does not contain audio data"))
            }

            // Convert AudioFormat to GeneratedAudioData.AudioFormat
            guard let audioFormat = GeneratedAudioData.AudioFormat(rawValue: audioContent.format.rawValue) else {
                return .failure(.unexpectedResponseFormat("Unknown audio format: \(audioContent.format.rawValue)"))
            }

            // Create typed data
            let typedData = GeneratedAudioData(
                audioData: audioContent.data,
                format: audioFormat,
                durationSeconds: nil, // ElevenLabs doesn't provide this in response
                sampleRate: nil,
                bitRate: nil,
                channels: nil,
                voiceID: configuration.voiceID,
                voiceName: configuration.voiceName,
                model: configuration.modelID
            )

            return .success(typedData)

        case .failure(let error):
            return .failure(error)
        }
    }

    // MARK: - Response Processing

    @MainActor
    public func makeResponseModel(
        from data: GeneratedAudioData,
        fileReference: TypedDataFileReference?,
        requestID: UUID
    ) -> GeneratedAudioRecord {
        // Calculate estimated cost based on character count
        // This is an approximation since we don't have exact character count here
        let estimatedCost: Double?
        if let audioData = data.audioData {
            // Rough estimate: 1 second of audio ≈ 150 characters
            // Average speaking rate: ~150 words per minute, ~5 characters per word
            let estimatedCharacters = Double(audioData.count) / 1000.0 * 10.0
            estimatedCost = estimatedCharacters * Self.estimatedCostPerCharacter
        } else {
            estimatedCost = nil
        }

        return GeneratedAudioRecord(
            id: requestID,
            providerId: providerID,
            requestorID: requestorID,
            data: data,
            prompt: "", // Prompt will be set by caller
            fileReference: fileReference,
            estimatedCost: estimatedCost
        )
    }

    // MARK: - UI Components (Phase 7 - Placeholder)

    @MainActor
    public func makeConfigurationView(
        configuration: Binding<AudioGenerationConfig>
    ) -> AnyView {
        // Phase 7: Implement configuration UI
        return AnyView(Text("Audio Configuration (Coming in Phase 7)"))
    }

    @MainActor
    public func makeListItemView(model: GeneratedAudioRecord) -> AnyView {
        // Phase 7: Implement list item view
        return AnyView(Text("Audio List Item (Coming in Phase 7)"))
    }

    @MainActor
    public func makeDetailView(model: GeneratedAudioRecord) -> AnyView {
        // Phase 7: Implement detail view
        return AnyView(Text("Audio Detail View (Coming in Phase 7)"))
    }
}
