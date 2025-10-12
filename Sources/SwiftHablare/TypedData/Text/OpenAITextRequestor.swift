//
//  OpenAITextRequestor.swift
//  SwiftHablare
//
//  Phase 6B: OpenAI text generation requestor
//

import Foundation
import SwiftUI

/// OpenAI text generation requestor.
///
/// Implements the AIRequestor protocol for OpenAI's text generation models
/// (GPT-4, GPT-4 Turbo, GPT-3.5 Turbo).
///
/// ## Usage
/// ```swift
/// let requestor = OpenAITextRequestor(
///     provider: openAIProvider,
///     model: .gpt4
/// )
///
/// let config = TextGenerationConfig(temperature: 0.7, maxTokens: 1000)
/// let result = await requestor.request(
///     prompt: "Write a story",
///     configuration: config,
///     storageArea: storageArea
/// )
/// ```
@available(macOS 15.0, iOS 17.0, *)
public final class OpenAITextRequestor: AIRequestor, @unchecked Sendable {

    // MARK: - Associated Types

    public typealias TypedData = GeneratedTextData
    public typealias ResponseModel = GeneratedTextRecord
    public typealias Configuration = TextGenerationConfig

    // MARK: - GPT Model Enum

    public enum GPTModel: String, Sendable {
        case gpt4 = "gpt-4"
        case gpt4Turbo = "gpt-4-turbo-preview"
        case gpt35Turbo = "gpt-3.5-turbo"

        public var displayName: String {
            switch self {
            case .gpt4: return "GPT-4"
            case .gpt4Turbo: return "GPT-4 Turbo"
            case .gpt35Turbo: return "GPT-3.5 Turbo"
            }
        }

        public var estimatedCostPerToken: Double {
            switch self {
            case .gpt4: return 0.00003 // $0.03 per 1K tokens
            case .gpt4Turbo: return 0.00001 // $0.01 per 1K tokens
            case .gpt35Turbo: return 0.000002 // $0.002 per 1K tokens
            }
        }
    }

    // MARK: - Properties

    /// Unique identifier for this requestor
    public let requestorID: String

    /// Human-readable display name
    public let displayName: String

    /// The provider that offers this requestor
    public let providerID: String = "openai"

    /// Category of content this requestor generates
    public let category: ProviderCategory = .text

    /// Output file type
    public let outputFileType: OutputFileType = .plainText()

    /// Optional schema for validation
    public let schema: TypedDataSchema? = nil

    /// Maximum expected response size (1MB for text)
    public let estimatedMaxSize: Int64? = 1_000_000

    // Private properties
    private let provider: OpenAIProvider
    private let model: GPTModel

    // MARK: - Initialization

    /// Creates an OpenAI text requestor
    ///
    /// - Parameters:
    ///   - provider: OpenAI provider instance
    ///   - model: GPT model to use
    public init(provider: OpenAIProvider, model: GPTModel) {
        self.provider = provider
        self.model = model
        self.requestorID = "openai.text.\(model.rawValue)"
        self.displayName = "OpenAI \(model.displayName)"
    }

    // MARK: - Configuration

    public func defaultConfiguration() -> TextGenerationConfig {
        return TextGenerationConfig()
    }

    public func validateConfiguration(_ config: TextGenerationConfig) throws {
        guard config.temperature >= 0 && config.temperature <= 2 else {
            throw AIServiceError.configurationError(
                "Temperature must be between 0 and 2, got \(config.temperature)"
            )
        }

        guard config.maxTokens > 0 && config.maxTokens <= 4096 else {
            throw AIServiceError.configurationError(
                "Max tokens must be between 1 and 4096, got \(config.maxTokens)"
            )
        }

        guard config.topP >= 0 && config.topP <= 1 else {
            throw AIServiceError.configurationError(
                "Top-p must be between 0 and 1, got \(config.topP)"
            )
        }

        guard config.frequencyPenalty >= -2 && config.frequencyPenalty <= 2 else {
            throw AIServiceError.configurationError(
                "Frequency penalty must be between -2 and 2, got \(config.frequencyPenalty)"
            )
        }

        guard config.presencePenalty >= -2 && config.presencePenalty <= 2 else {
            throw AIServiceError.configurationError(
                "Presence penalty must be between -2 and 2, got \(config.presencePenalty)"
            )
        }
    }

    // MARK: - Request Execution

    public func request(
        prompt: String,
        configuration: Configuration,
        storageArea: StorageAreaReference
    ) async -> Result<GeneratedTextData, AIServiceError> {
        // Validate configuration first
        do {
            try validateConfiguration(configuration)
        } catch let error as AIServiceError {
            return .failure(error)
        } catch {
            return .failure(.configurationError(error.localizedDescription))
        }

        // Build parameters for provider
        var parameters: [String: Any] = [
            "model": model.rawValue,
            "temperature": configuration.temperature,
            "max_tokens": configuration.maxTokens,
            "top_p": configuration.topP,
            "frequency_penalty": configuration.frequencyPenalty,
            "presence_penalty": configuration.presencePenalty
        ]

        if let stopSequences = configuration.stopSequences, !stopSequences.isEmpty {
            parameters["stop"] = stopSequences
        }

        // Make API call through provider
        let result = await provider.generate(prompt: prompt, parameters: parameters)

        switch result {
        case .success(let content):
            guard let text = content.text else {
                return .failure(.unexpectedResponseFormat("Response does not contain text"))
            }

            // Create typed data
            let typedData = GeneratedTextData(
                text: text,
                model: model.rawValue,
                languageCode: "en" // TODO: Detect language
            )

            return .success(typedData)

        case .failure(let error):
            return .failure(error)
        }
    }

    // MARK: - Response Processing

    @MainActor
    public func makeResponseModel(
        from data: GeneratedTextData,
        fileReference: TypedDataFileReference?,
        requestID: UUID
    ) -> GeneratedTextRecord {
        // Calculate estimated cost
        let estimatedCost: Double?
        if let tokenCount = data.tokenCount {
            estimatedCost = Double(tokenCount) * model.estimatedCostPerToken
        } else {
            estimatedCost = nil
        }

        return GeneratedTextRecord(
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
        configuration: Binding<TextGenerationConfig>
    ) -> AnyView {
        // Phase 7: Implement configuration UI
        return AnyView(Text("Text Configuration (Coming in Phase 7)"))
    }

    @MainActor
    public func makeListItemView(model: GeneratedTextRecord) -> AnyView {
        // Phase 7: Implement list item view
        return AnyView(Text("Text List Item (Coming in Phase 7)"))
    }

    @MainActor
    public func makeDetailView(model: GeneratedTextRecord) -> AnyView {
        // Phase 7: Implement detail view
        return AnyView(Text("Text Detail View (Coming in Phase 7)"))
    }
}
