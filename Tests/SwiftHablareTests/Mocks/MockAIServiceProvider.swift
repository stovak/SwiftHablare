import Foundation
import SwiftData
@testable import SwiftHablare

/// Mock AI service provider for testing.
///
/// Supports configurable behavior including success, failure, and delay scenarios.

final class MockAIServiceProvider: AIServiceProvider, @unchecked Sendable {
    let id: String
    let displayName: String
    let capabilities: [AICapability]
    let supportedDataStructures: [DataStructureCapability]
    let requiresAPIKey: Bool

    // Test configuration
    var configured: Bool = true
    var shouldThrowError: AIServiceError?
    var generationDelay: TimeInterval = 0
    var generatedDataResponse: Data = Data("mock response".utf8)
    var generatedPropertyResponse: Any = "mock property value"
    var generatedContentResponse: ResponseContent = .text("mock response")

    // Call tracking
    private(set) var generateCallCount = 0
    private(set) var generatePropertyCallCount = 0
    private(set) var lastPrompt: String?
    private(set) var lastParameters: [String: Any]?

    init(
        id: String = "mock-provider",
        displayName: String = "Mock Provider",
        capabilities: [AICapability] = [.textGeneration],
        supportedDataStructures: [DataStructureCapability] = [],
        requiresAPIKey: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.capabilities = capabilities
        self.supportedDataStructures = supportedDataStructures
        self.requiresAPIKey = requiresAPIKey
    }

    func isConfigured() -> Bool {
        configured
    }

    // MARK: - New API Implementation

    func generate(
        prompt: String,
        parameters: [String: Any]
    ) async -> Result<ResponseContent, AIServiceError> {
        generateCallCount += 1
        lastPrompt = prompt
        lastParameters = parameters

        // Check if provider is configured
        if !configured {
            return .failure(.configurationError("Provider is not configured"))
        }

        if let error = shouldThrowError {
            return .failure(error)
        }

        if generationDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(generationDelay * 1_000_000_000))
        }

        return .success(generatedContentResponse)
    }

    // MARK: - Legacy API Implementation

    func generate(
        prompt: String,
        parameters: [String: Any],
        context: ModelContext
    ) async throws -> Data {
        generateCallCount += 1
        lastPrompt = prompt
        lastParameters = parameters

        // Check if provider is configured
        if !configured {
            throw AIServiceError.configurationError("Provider is not configured")
        }

        if let error = shouldThrowError {
            throw error
        }

        if generationDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(generationDelay * 1_000_000_000))
        }

        return generatedDataResponse
    }

    func generateProperty<T: PersistentModel>(
        for model: T,
        property: PartialKeyPath<T>,
        prompt: String?,
        context: [String: Any]
    ) async throws -> Any {
        generatePropertyCallCount += 1
        lastPrompt = prompt

        if let error = shouldThrowError {
            throw error
        }

        if generationDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(generationDelay * 1_000_000_000))
        }

        return generatedPropertyResponse
    }

    // Test helpers
    func reset() {
        generateCallCount = 0
        generatePropertyCallCount = 0
        lastPrompt = nil
        lastParameters = nil
        shouldThrowError = nil
        generationDelay = 0
        configured = true
    }
}

// MARK: - Factory Methods


extension MockAIServiceProvider {
    /// Creates a mock text generation provider.
    static func textProvider(id: String = "mock-text") -> MockAIServiceProvider {
        MockAIServiceProvider(
            id: id,
            displayName: "Mock Text Provider",
            capabilities: [.textGeneration],
            supportedDataStructures: [
                .protocol(protocolType: "AIGeneratable", typeConstraints: [
                    .canGenerate(.string)
                ])
            ]
        )
    }

    /// Creates a mock audio generation provider.
    static func audioProvider(id: String = "mock-audio") -> MockAIServiceProvider {
        let provider = MockAIServiceProvider(
            id: id,
            displayName: "Mock Audio Provider",
            capabilities: [.audioGeneration],
            supportedDataStructures: [
                .protocol(protocolType: "AIGeneratable", typeConstraints: [
                    .canGenerate(.data)
                ])
            ]
        )
        let mockAudioData = Data(repeating: 0, count: 1024)
        provider.generatedDataResponse = mockAudioData
        provider.generatedContentResponse = .audio(mockAudioData, format: .mp3)
        return provider
    }

    /// Creates a mock image generation provider.
    static func imageProvider(id: String = "mock-image") -> MockAIServiceProvider {
        let provider = MockAIServiceProvider(
            id: id,
            displayName: "Mock Image Provider",
            capabilities: [.imageGeneration],
            supportedDataStructures: [
                .protocol(protocolType: "AIGeneratable", typeConstraints: [
                    .canGenerate(.data)
                ])
            ]
        )
        let mockImageData = Data(repeating: 0, count: 2048)
        provider.generatedDataResponse = mockImageData
        provider.generatedContentResponse = .image(mockImageData, format: .png)
        return provider
    }

    /// Creates a mock provider that always fails.
    static func failingProvider(
        id: String = "mock-failing",
        error: AIServiceError = .providerError("Mock provider error")
    ) -> MockAIServiceProvider {
        let provider = MockAIServiceProvider(id: id, displayName: "Mock Failing Provider")
        provider.shouldThrowError = error
        return provider
    }

    /// Creates a mock provider that is not configured.
    static func unconfiguredProvider(id: String = "mock-unconfigured") -> MockAIServiceProvider {
        let provider = MockAIServiceProvider(
            id: id,
            displayName: "Mock Unconfigured Provider",
            requiresAPIKey: true
        )
        provider.configured = false
        return provider
    }

    /// Creates a mock provider with custom delay.
    static func delayedProvider(
        id: String = "mock-delayed",
        delay: TimeInterval = 0.1
    ) -> MockAIServiceProvider {
        let provider = MockAIServiceProvider(id: id, displayName: "Mock Delayed Provider")
        provider.generationDelay = delay
        return provider
    }
}
