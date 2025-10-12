//
//  MockOpenAIProvider.swift
//  SwiftHablare
//
//  Mock OpenAI provider for Phase 5 testing and development
//

import Foundation
import SwiftData

/// Mock OpenAI provider implementation.
///
/// This provider simulates OpenAI's GPT models for testing and development.
/// It implements the full AIServiceProvider protocol without making real API calls.
///
/// ## Features
/// - Text generation with configurable responses
/// - Token usage tracking
/// - Parameter validation
/// - Error simulation
///
/// ## Example
/// ```swift
/// let provider = MockOpenAIProvider()
/// let result = await provider.generate(
///     prompt: "Write a story",
///     parameters: ["model": "gpt-4", "temperature": 0.7]
/// )
/// ```
@available(macOS 15.0, iOS 17.0, *)
public final class MockOpenAIProvider: AIServiceProvider, @unchecked Sendable {

    // MARK: - Identity

    public let id: String = "openai-mock"
    public let displayName: String = "OpenAI (Mock)"

    // MARK: - Capabilities

    public let capabilities: [AICapability] = [.textGeneration, .embeddings]

    public let supportedDataStructures: [DataStructureCapability] = []

    // MARK: - Configuration

    public let requiresAPIKey: Bool = true

    private var apiKey: String?
    private var mockResponses: [String: String] = [:]
    private var shouldFail: Bool = false
    private var failureError: AIServiceError?

    // MARK: - Response Type

    public let responseType: ResponseContent.ContentType = .text

    // MARK: - Initialization

    /// Create a new mock OpenAI provider.
    ///
    /// - Parameters:
    ///   - apiKey: Mock API key (default: "mock-key")
    ///   - mockResponses: Predefined responses for testing
    public init(apiKey: String? = "mock-key", mockResponses: [String: String] = [:]) {
        self.apiKey = apiKey
        self.mockResponses = mockResponses
    }

    // MARK: - Configuration

    public func isConfigured() -> Bool {
        return apiKey != nil
    }

    public func validateConfiguration() throws {
        guard let key = apiKey, !key.isEmpty else {
            throw AIServiceError.missingCredentials("OpenAI API key is required")
        }

        if key.count < 10 {
            throw AIServiceError.invalidAPIKey("API key format is invalid")
        }
    }

    // MARK: - Generation (New API)

    public func generate(
        prompt: String,
        parameters: [String: Any]
    ) async -> Result<ResponseContent, AIServiceError> {
        // Simulate API delay
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Check if we should simulate failure
        if shouldFail, let error = failureError {
            return .failure(error)
        }

        // Validate configuration
        do {
            try validateConfiguration()
        } catch {
            return .failure(error as? AIServiceError ?? .configurationError(error.localizedDescription))
        }

        // Check for mock response
        if let mockResponse = mockResponses[prompt] {
            return .success(.text(mockResponse))
        }

        // Generate mock response based on prompt
        let response = generateMockResponse(for: prompt, parameters: parameters)

        return .success(.text(response))
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

    // MARK: - Test Helpers

    /// Set a mock response for a specific prompt.
    ///
    /// - Parameters:
    ///   - response: The response to return
    ///   - prompt: The prompt that triggers this response
    public func setMockResponse(_ response: String, for prompt: String) {
        mockResponses[prompt] = response
    }

    /// Configure the provider to simulate a failure.
    ///
    /// - Parameter error: The error to return
    public func simulateFailure(_ error: AIServiceError) {
        shouldFail = true
        failureError = error
    }

    /// Reset failure simulation.
    public func resetFailure() {
        shouldFail = false
        failureError = nil
    }

    // MARK: - Private Helpers

    private func generateMockResponse(for prompt: String, parameters: [String: Any]) -> String {
        let model = parameters["model"] as? String ?? "gpt-3.5-turbo"
        let maxTokens = parameters["max_tokens"] as? Int ?? 100

        // Generate a simple mock response
        let promptPreview = String(prompt.prefix(50))
        return """
        [Mock \(model) Response]

        This is a generated response for the prompt: "\(promptPreview)..."

        The response is limited to approximately \(maxTokens) tokens.
        This is mock content generated by MockOpenAIProvider for testing purposes.
        """
    }
}

// MARK: - Factory Methods

@available(macOS 15.0, iOS 17.0, *)
extension MockOpenAIProvider {

    /// Create a configured mock provider for testing.
    public static func configured() -> MockOpenAIProvider {
        return MockOpenAIProvider(apiKey: "sk-test-mock-key-12345")
    }

    /// Create an unconfigured mock provider for testing error cases.
    public static func unconfigured() -> MockOpenAIProvider {
        return MockOpenAIProvider(apiKey: nil)
    }
}
