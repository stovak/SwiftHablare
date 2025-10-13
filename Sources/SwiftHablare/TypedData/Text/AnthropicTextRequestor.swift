//
//  AnthropicTextRequestor.swift
//  SwiftHablare
//
//  Phase 6B: Anthropic text generation requestor
//

import Foundation
import SwiftUI

/// Anthropic text generation requestor.
///
/// Implements the AIRequestor protocol for Anthropic's Claude 3 models
/// (Opus, Sonnet, Haiku).
///
/// ## Usage
/// ```swift
/// let requestor = AnthropicTextRequestor(
///     provider: anthropicProvider,
///     model: .claude3Sonnet
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
public final class AnthropicTextRequestor: AIRequestor, @unchecked Sendable {

    // MARK: - Associated Types

    public typealias TypedData = GeneratedTextData
    public typealias ResponseModel = GeneratedTextRecord
    public typealias Configuration = TextGenerationConfig

    // MARK: - Claude Model Enum

    public enum ClaudeModel: String, Sendable {
        case claude3Opus = "claude-3-opus-20240229"
        case claude3Sonnet = "claude-3-sonnet-20240229"
        case claude3Haiku = "claude-3-haiku-20240307"

        public var displayName: String {
            switch self {
            case .claude3Opus: return "Claude 3 Opus"
            case .claude3Sonnet: return "Claude 3 Sonnet"
            case .claude3Haiku: return "Claude 3 Haiku"
            }
        }

        public var estimatedCostPerToken: Double {
            switch self {
            case .claude3Opus: return 0.000015 // $15 per 1M input tokens, $75 per 1M output
            case .claude3Sonnet: return 0.000003 // $3 per 1M input tokens, $15 per 1M output
            case .claude3Haiku: return 0.00000025 // $0.25 per 1M input tokens, $1.25 per 1M output
            }
        }
    }

    // MARK: - Properties

    /// Unique identifier for this requestor
    public let requestorID: String

    /// Human-readable display name
    public let displayName: String

    /// The provider that offers this requestor
    public let providerID: String = "anthropic"

    /// Category of content this requestor generates
    public let category: ProviderCategory = .text

    /// Output file type
    public let outputFileType: OutputFileType = .plainText()

    /// Optional schema for validation
    public let schema: TypedDataSchema? = nil

    /// Maximum expected response size (1MB for text)
    public let estimatedMaxSize: Int64? = 1_000_000

    // Private properties
    private let provider: AnthropicProvider
    private let model: ClaudeModel

    // MARK: - Initialization

    /// Creates an Anthropic text requestor
    ///
    /// - Parameters:
    ///   - provider: Anthropic provider instance
    ///   - model: Claude model to use
    public init(provider: AnthropicProvider, model: ClaudeModel) {
        self.provider = provider
        self.model = model
        self.requestorID = "anthropic.text.\(model.rawValue)"
        self.displayName = "Anthropic \(model.displayName)"
    }

    // MARK: - Configuration

    public func defaultConfiguration() -> TextGenerationConfig {
        return TextGenerationConfig()
    }

    public func validateConfiguration(_ config: TextGenerationConfig) throws {
        // Claude models have different constraints than OpenAI
        guard config.temperature >= 0 && config.temperature <= 1 else {
            throw AIServiceError.configurationError(
                "Temperature must be between 0 and 1 for Claude models, got \(config.temperature)"
            )
        }

        // Claude 3 models support up to 200K tokens context, but for generation we limit to reasonable amounts
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

        // Claude doesn't use frequency/presence penalty the same way as OpenAI
        // We'll silently ignore these for Claude
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
            "max_tokens": configuration.maxTokens,
            "temperature": configuration.temperature,
            "top_p": configuration.topP
        ]

        // Add system prompt if provided
        if let systemPrompt = configuration.systemPrompt {
            parameters["system"] = systemPrompt
        }

        // Add stop sequences if provided
        if let stopSequences = configuration.stopSequences, !stopSequences.isEmpty {
            parameters["stop_sequences"] = stopSequences
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
        return AnyView(TextConfigurationView(configuration: configuration))
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
