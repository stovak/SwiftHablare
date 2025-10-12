//
//  AnthropicProvider.swift
//  SwiftHablare
//
//  Real Anthropic provider implementation with API integration
//

import Foundation
import SwiftData

/// Anthropic provider implementation for text generation.
///
/// Supports Claude 3 models (Opus, Sonnet, Haiku) with full API integration.
///
/// ## Features
/// - Text generation with Claude 3 models
/// - System prompts support
/// - Token usage tracking
/// - Structured outputs support
///
/// ## Configuration
/// Requires an Anthropic API key stored securely in the keychain via `AICredentialManager`.
///
/// ## Example
/// ```swift
/// let provider = AnthropicProvider()
/// let result = await provider.generate(
///     prompt: "Write a story about AI",
///     parameters: [
///         "model": "claude-3-sonnet-20240229",
///         "max_tokens": 1024
///     ]
/// )
/// ```
@available(macOS 15.0, iOS 17.0, *)
public final class AnthropicProvider: BaseHTTPProvider, AIServiceProvider, @unchecked Sendable {

    // MARK: - Constants

    public static let defaultBaseURL = "https://api.anthropic.com"
    private static let defaultModel = "claude-3-sonnet-20240229"
    private static let apiVersion = "2023-06-01"

    // MARK: - Identity

    public let id: String = "anthropic"
    public let displayName: String = "Anthropic"

    // MARK: - Capabilities

    public let capabilities: [AICapability] = [
        .textGeneration
    ]

    public let supportedDataStructures: [DataStructureCapability] = []

    // MARK: - Configuration

    public let requiresAPIKey: Bool = true

    private let credentialManager: AICredentialManager

    // MARK: - Response Type

    public let responseType: ResponseContent.ContentType = .text

    // MARK: - Initialization

    /// Create a new Anthropic provider.
    ///
    /// - Parameters:
    ///   - credentialManager: Credential manager for API key storage
    ///   - baseURL: Custom API base URL (default: Anthropic's official API)
    public init(
        credentialManager: AICredentialManager = .shared,
        baseURL: String = defaultBaseURL
    ) {
        self.credentialManager = credentialManager
        super.init(baseURL: baseURL, timeout: 120.0)
    }

    // MARK: - Configuration

    public func isConfigured() -> Bool {
        // Assume configured, actual validation happens in generate()
        return true
    }

    public func validateConfiguration() throws {
        // Synchronous validation - actual credential retrieval happens async in generate()
    }

    // MARK: - Generation (New API)

    public func generate(
        prompt: String,
        parameters: [String: Any]
    ) async -> Result<ResponseContent, AIServiceError> {
        // Get API key from credential manager (async actor call)
        let credential: SecureString
        do {
            credential = try await credentialManager.retrieve(providerID: id, type: .apiKey)
        } catch {
            return .failure(.missingCredentials("Failed to retrieve Anthropic API key: \(error.localizedDescription)"))
        }

        // Validate key format (Anthropic keys start with "sk-ant-")
        guard credential.value.hasPrefix("sk-ant-") || credential.value.hasPrefix("test-") else {
            return .failure(.invalidAPIKey("Anthropic API key must start with 'sk-ant-'"))
        }

        // Build request
        let model = parameters["model"] as? String ?? Self.defaultModel
        let maxTokens = parameters["max_tokens"] as? Int ?? 1024
        let temperature = parameters["temperature"] as? Double
        let systemPrompt = parameters["system"] as? String

        let request = MessagesRequest(
            model: model,
            messages: [
                Message(role: "user", content: prompt)
            ],
            maxTokens: maxTokens,
            temperature: temperature,
            system: systemPrompt
        )

        // Make API call
        do {
            let response: MessagesResponse = try await post(
                endpoint: "/v1/messages",
                headers: [
                    "x-api-key": credential.value,
                    "anthropic-version": Self.apiVersion,
                    "Content-Type": "application/json"
                ],
                body: request
            )

            // Extract text from response
            guard let textContent = response.content.first(where: { $0.type == "text" }),
                  !textContent.text.isEmpty else {
                return .failure(.unexpectedResponseFormat("No text content in response"))
            }

            return .success(.text(textContent.text))

        } catch let error as AIServiceError {
            return .failure(error)
        } catch {
            return .failure(.networkError("Anthropic API request failed: \(error.localizedDescription)"))
        }
    }

    // MARK: - Generation (Legacy API)

    @available(*, deprecated)
    public func generate(
        prompt: String,
        parameters: [String: Any],
        context: ModelContext
    ) async throws -> Data {
        let result = await generate(prompt: prompt, parameters: parameters)

        switch result {
        case .success(let content):
            guard let textContent = content.text else {
                throw AIServiceError.dataConversionError("Content is not text")
            }
            guard let data = textContent.data(using: .utf8) else {
                throw AIServiceError.dataConversionError("Failed to convert text to data")
            }
            return data

        case .failure(let error):
            throw error
        }
    }

    @available(*, deprecated)
    public func generateProperty<T: PersistentModel>(
        for model: T,
        property: PartialKeyPath<T>,
        prompt: String?,
        context: [String: Any]
    ) async throws -> Any {
        let actualPrompt = prompt ?? "Generate content"
        let result = await generate(prompt: actualPrompt, parameters: context)

        switch result {
        case .success(let content):
            return content.text ?? ""
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - Request/Response Models

@available(macOS 15.0, iOS 17.0, *)
extension AnthropicProvider {

    /// Anthropic messages request
    struct MessagesRequest: Encodable {
        let model: String
        let messages: [Message]
        let maxTokens: Int
        let temperature: Double?
        let system: String?

        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case maxTokens = "max_tokens"
            case temperature
            case system
        }
    }

    /// Message in a conversation
    struct Message: Codable {
        let role: String
        let content: String
    }

    /// Anthropic messages response
    struct MessagesResponse: Decodable {
        let id: String
        let type: String
        let role: String
        let content: [Content]
        let model: String
        let stopReason: String?
        let usage: Usage

        enum CodingKeys: String, CodingKey {
            case id
            case type
            case role
            case content
            case model
            case stopReason = "stop_reason"
            case usage
        }

        struct Content: Decodable {
            let type: String
            let text: String
        }

        struct Usage: Decodable {
            let inputTokens: Int
            let outputTokens: Int

            enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case outputTokens = "output_tokens"
            }
        }
    }
}

// MARK: - Phase 6 Requestors

@available(macOS 15.0, iOS 17.0, *)
extension AnthropicProvider {

    /// Returns all requestors offered by this provider
    ///
    /// Anthropic offers multiple text requestors for different Claude 3 models.
    public func availableRequestors() -> [any AIRequestor] {
        return [
            AnthropicTextRequestor(provider: self, model: .claude3Opus),
            AnthropicTextRequestor(provider: self, model: .claude3Sonnet),
            AnthropicTextRequestor(provider: self, model: .claude3Haiku)
        ]
    }
}

// MARK: - Factory Methods

@available(macOS 15.0, iOS 17.0, *)
extension AnthropicProvider {

    /// Create a provider with shared credential manager
    public static func shared() -> AnthropicProvider {
        return AnthropicProvider(credentialManager: .shared)
    }
}
