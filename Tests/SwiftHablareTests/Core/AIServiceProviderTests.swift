import XCTest
import SwiftData
@testable import SwiftHablare

/// Comprehensive tests for AIServiceProvider protocol and default implementations
final class AIServiceProviderTests: XCTestCase {

    // MARK: - Test Helpers

    /// Simple test provider using only default implementations
    final class MinimalProvider: AIServiceProvider, @unchecked Sendable {
        let id: String
        let displayName: String
        let capabilities: [AICapability]
        let supportedDataStructures: [DataStructureCapability]
        let requiresAPIKey: Bool

        var configuredState: Bool = true

        init(
            id: String = "minimal",
            displayName: String = "Minimal Provider",
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
            configuredState
        }

        // Only implement legacy method
        func generate(
            prompt: String,
            parameters: [String: Any],
            context: ModelContext
        ) async throws -> Data {
            Data("minimal response".utf8)
        }

        func generateProperty<T: PersistentModel>(
            for model: T,
            property: PartialKeyPath<T>,
            prompt: String?,
            context: [String: Any]
        ) async throws -> Any {
            "minimal property"
        }
    }

    /// Provider that overrides default implementations
    final class CustomProvider: AIServiceProvider, @unchecked Sendable {
        let id: String = "custom"
        let displayName: String = "Custom Provider"
        let capabilities: [AICapability] = [.audioGeneration]
        let supportedDataStructures: [DataStructureCapability] = []
        let requiresAPIKey: Bool = true

        var configuredState: Bool = true
        var customValidationCalled: Bool = false
        var customGenerateCalled: Bool = false

        func isConfigured() -> Bool {
            configuredState
        }

        func validateConfiguration() throws {
            customValidationCalled = true
            if !configuredState {
                throw AIServiceError.configurationError("Custom validation failed")
            }
        }

        // Override new API
        func generate(
            prompt: String,
            parameters: [String: Any]
        ) async -> Result<ResponseContent, AIServiceError> {
            customGenerateCalled = true
            return .success(.audio(Data(repeating: 0, count: 100), format: .mp3))
        }

        // Override responseType
        var responseType: ResponseContent.ContentType {
            .audio
        }

        // Legacy methods
        func generate(
            prompt: String,
            parameters: [String: Any],
            context: ModelContext
        ) async throws -> Data {
            Data("custom response".utf8)
        }

        func generateProperty<T: PersistentModel>(
            for model: T,
            property: PartialKeyPath<T>,
            prompt: String?,
            context: [String: Any]
        ) async throws -> Any {
            "custom property"
        }
    }

    // MARK: - Protocol Conformance Tests

    func testProtocolConformance_RequiredProperties() {
        let provider = MinimalProvider()

        XCTAssertEqual(provider.id, "minimal")
        XCTAssertEqual(provider.displayName, "Minimal Provider")
        XCTAssertEqual(provider.capabilities, [.textGeneration])
        XCTAssertTrue(provider.supportedDataStructures.isEmpty)
        XCTAssertEqual(provider.requiresAPIKey, false)
        XCTAssertTrue(provider.isConfigured())
    }

    func testProtocolConformance_MultipleCapabilities() {
        let provider = MinimalProvider(
            capabilities: [.textGeneration, .audioGeneration, .imageGeneration]
        )

        XCTAssertEqual(provider.capabilities.count, 3)
        XCTAssertTrue(provider.capabilities.contains(.textGeneration))
        XCTAssertTrue(provider.capabilities.contains(.audioGeneration))
        XCTAssertTrue(provider.capabilities.contains(.imageGeneration))
    }

    func testProtocolConformance_WithDataStructures() {
        let provider = MinimalProvider(
            supportedDataStructures: [
                .protocol(protocolType: "AIGeneratable", typeConstraints: [.canGenerate(.string)])
            ]
        )

        XCTAssertEqual(provider.supportedDataStructures.count, 1)
    }

    // MARK: - Default Implementation Tests - validateConfiguration

    func testDefaultValidateConfiguration_Succeeds_WhenNoAPIKeyRequired() throws {
        let provider = MinimalProvider(requiresAPIKey: false)
        provider.configuredState = false

        // Should not throw because API key is not required
        try provider.validateConfiguration()
    }

    func testDefaultValidateConfiguration_Succeeds_WhenAPIKeyRequiredAndConfigured() throws {
        let provider = MinimalProvider(requiresAPIKey: true)
        provider.configuredState = true

        // Should not throw
        try provider.validateConfiguration()
    }

    func testDefaultValidateConfiguration_Fails_WhenAPIKeyRequiredButNotConfigured() {
        let provider = MinimalProvider(requiresAPIKey: true)
        provider.configuredState = false

        XCTAssertThrowsError(try provider.validateConfiguration()) { error in
            guard let serviceError = error as? AIServiceError else {
                XCTFail("Expected AIServiceError, got \(type(of: error))")
                return
            }

            if case .configurationError(let message) = serviceError {
                XCTAssertTrue(message.contains("API key required"))
                XCTAssertTrue(message.contains("minimal"))
            } else {
                XCTFail("Expected configurationError, got \(serviceError)")
            }
        }
    }

    func testCustomValidateConfiguration_IsCalledInsteadOfDefault() throws {
        let provider = CustomProvider()
        provider.configuredState = true

        XCTAssertFalse(provider.customValidationCalled)
        try provider.validateConfiguration()
        XCTAssertTrue(provider.customValidationCalled)
    }

    func testCustomValidateConfiguration_CanThrowCustomError() {
        let provider = CustomProvider()
        provider.configuredState = false

        XCTAssertThrowsError(try provider.validateConfiguration()) { error in
            guard let serviceError = error as? AIServiceError else {
                XCTFail("Expected AIServiceError")
                return
            }

            if case .configurationError(let message) = serviceError {
                XCTAssertEqual(message, "Custom validation failed")
            } else {
                XCTFail("Expected configurationError")
            }
        }
    }

    // MARK: - Default Implementation Tests - availableRequestors

    @available(macOS 15.0, iOS 17.0, *)
    func testDefaultAvailableRequestors_ReturnsEmptyArray() {
        let provider = MinimalProvider()
        let requestors = provider.availableRequestors()

        XCTAssertTrue(requestors.isEmpty)
    }

    // MARK: - Default Implementation Tests - generate (new API)

    func testDefaultGenerateNewAPI_ReturnsUnsupportedOperationError() async {
        let provider = MinimalProvider()

        let result = await provider.generate(prompt: "test", parameters: [:])

        switch result {
        case .success:
            XCTFail("Expected failure, got success")
        case .failure(let error):
            if case .unsupportedOperation(let message) = error {
                XCTAssertTrue(message.contains("minimal"))
                XCTAssertTrue(message.contains("has not implemented"))
                XCTAssertTrue(message.contains("new generate"))
            } else {
                XCTFail("Expected unsupportedOperation error, got \(error)")
            }
        }
    }

    func testCustomGenerateNewAPI_IsCalledInsteadOfDefault() async {
        let provider = CustomProvider()

        XCTAssertFalse(provider.customGenerateCalled)
        let result = await provider.generate(prompt: "test", parameters: [:])
        XCTAssertTrue(provider.customGenerateCalled)

        switch result {
        case .success(let content):
            XCTAssertEqual(content.contentType, .audio)
        case .failure:
            XCTFail("Expected success")
        }
    }

    // MARK: - Default Implementation Tests - responseType

    func testDefaultResponseType_TextGeneration() {
        let provider = MinimalProvider(capabilities: [.textGeneration])
        XCTAssertEqual(provider.responseType, .text)
    }

    func testDefaultResponseType_AudioGeneration() {
        let provider = MinimalProvider(capabilities: [.audioGeneration])
        XCTAssertEqual(provider.responseType, .audio)
    }

    func testDefaultResponseType_ImageGeneration() {
        let provider = MinimalProvider(capabilities: [.imageGeneration])
        XCTAssertEqual(provider.responseType, .image)
    }

    func testDefaultResponseType_MultipleCapabilities_PrefersText() {
        // When multiple capabilities exist, text takes precedence
        let provider = MinimalProvider(
            capabilities: [.textGeneration, .audioGeneration, .imageGeneration]
        )
        XCTAssertEqual(provider.responseType, .text)
    }

    func testDefaultResponseType_MultipleCapabilities_PrefersAudioOverImage() {
        let provider = MinimalProvider(
            capabilities: [.audioGeneration, .imageGeneration]
        )
        XCTAssertEqual(provider.responseType, .audio)
    }

    func testDefaultResponseType_OtherCapabilities_ReturnsData() {
        let provider = MinimalProvider(
            capabilities: [.embeddings, .structuredData]
        )
        XCTAssertEqual(provider.responseType, .data)
    }

    func testCustomResponseType_OverridesDefault() {
        let provider = CustomProvider()
        XCTAssertEqual(provider.responseType, .audio)
    }

    // MARK: - Sendable Tests

    func testProvider_CanBeSentAcrossActorBoundaries() async {
        let provider = MinimalProvider()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Task {
                // Should be able to capture provider in a task
                XCTAssertEqual(provider.id, "minimal")
                continuation.resume()
            }
        }
    }

    func testProvider_CanBePassedToAsyncFunction() async {
        let provider = MinimalProvider()

        // Helper that accepts a Sendable provider
        func processProvider(_ provider: some AIServiceProvider) async -> String {
            return provider.id
        }

        let id = await processProvider(provider)
        XCTAssertEqual(id, "minimal")
    }

    // MARK: - Configuration State Tests

    func testConfigurationState_CanBeModified() {
        let provider = MinimalProvider()

        XCTAssertTrue(provider.isConfigured())

        provider.configuredState = false
        XCTAssertFalse(provider.isConfigured())

        provider.configuredState = true
        XCTAssertTrue(provider.isConfigured())
    }

    func testValidateConfiguration_ReflectsCurrentState() throws {
        let provider = MinimalProvider(requiresAPIKey: true)
        provider.configuredState = true

        // Should succeed
        try provider.validateConfiguration()

        provider.configuredState = false

        // Should fail
        XCTAssertThrowsError(try provider.validateConfiguration())

        provider.configuredState = true

        // Should succeed again
        try provider.validateConfiguration()
    }

    // MARK: - Legacy API Tests

    func testLegacyGenerate_CanBeImplemented() async throws {
        let provider = MinimalProvider()
        let container = try TestHelpers.testContainer(for: GeneratedText.self)
        let context = ModelContext(container)

        let data = try await provider.generate(
            prompt: "test",
            parameters: [:],
            context: context
        )

        let string = String(data: data, encoding: .utf8)
        XCTAssertEqual(string, "minimal response")
    }

    // Note: testLegacyGenerateProperty_CanBeImplemented removed due to SwiftData @Model scope limitations in test functions

    // MARK: - Edge Cases

    func testProvider_EmptyDisplayName() {
        let provider = MinimalProvider(displayName: "")
        XCTAssertEqual(provider.displayName, "")
    }

    func testProvider_EmptyCapabilities() {
        let provider = MinimalProvider(capabilities: [])
        XCTAssertTrue(provider.capabilities.isEmpty)
        XCTAssertEqual(provider.responseType, .data)
    }

    func testProvider_CustomCapability() {
        let provider = MinimalProvider(capabilities: [.custom("my-custom")])
        XCTAssertEqual(provider.capabilities.count, 1)
        XCTAssertEqual(provider.capabilities.first, .custom("my-custom"))
    }

    func testProvider_SpecialCharactersInID() {
        let provider = MinimalProvider(id: "test-provider_123")
        XCTAssertEqual(provider.id, "test-provider_123")
    }

    // MARK: - Integration with MockAIServiceProvider

    func testMockProvider_UsesDefaultImplementations() throws {
        let mock = MockAIServiceProvider(requiresAPIKey: true)
        mock.configured = true

        // Should use default validateConfiguration
        try mock.validateConfiguration()

        mock.configured = false
        XCTAssertThrowsError(try mock.validateConfiguration())
    }

    @available(macOS 15.0, iOS 17.0, *)
    func testMockProvider_DefaultAvailableRequestors() {
        let mock = MockAIServiceProvider()
        let requestors = mock.availableRequestors()

        XCTAssertTrue(requestors.isEmpty)
    }

    func testMockProvider_ImplementsNewGenerateAPI() async {
        let mock = MockAIServiceProvider()
        mock.generatedContentResponse = .text("mock text")

        let result = await mock.generate(prompt: "test", parameters: [:])

        switch result {
        case .success(let content):
            XCTAssertEqual(content.text, "mock text")
        case .failure:
            XCTFail("Expected success")
        }
    }

    func testMockProvider_DefaultResponseType() {
        let textMock = MockAIServiceProvider(capabilities: [.textGeneration])
        XCTAssertEqual(textMock.responseType, .text)

        let audioMock = MockAIServiceProvider(capabilities: [.audioGeneration])
        XCTAssertEqual(audioMock.responseType, .audio)

        let imageMock = MockAIServiceProvider(capabilities: [.imageGeneration])
        XCTAssertEqual(imageMock.responseType, .image)
    }

    // MARK: - Capability Querying

    func testCapabilityQuerying_Single() {
        let provider = MinimalProvider(capabilities: [.textGeneration])

        XCTAssertTrue(provider.capabilities.contains(.textGeneration))
        XCTAssertFalse(provider.capabilities.contains(.audioGeneration))
    }

    func testCapabilityQuerying_Multiple() {
        let provider = MinimalProvider(
            capabilities: [.textGeneration, .imageGeneration, .embeddings]
        )

        XCTAssertTrue(provider.capabilities.contains(.textGeneration))
        XCTAssertTrue(provider.capabilities.contains(.imageGeneration))
        XCTAssertTrue(provider.capabilities.contains(.embeddings))
        XCTAssertFalse(provider.capabilities.contains(.audioGeneration))
    }

    func testCapabilityQuerying_Custom() {
        let provider = MinimalProvider(
            capabilities: [.textGeneration, .custom("special")]
        )

        XCTAssertTrue(provider.capabilities.contains(.custom("special")))
        XCTAssertFalse(provider.capabilities.contains(.custom("other")))
    }
}
