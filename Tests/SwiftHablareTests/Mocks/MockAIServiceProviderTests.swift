import Testing
import SwiftData
import Foundation
@testable import SwiftHablare

// Test model for generateProperty tests
@Model
final class TestModelForGenerateProperty {
    var title: String = ""
    init() {}
}

struct MockAIServiceProviderTests {

    @Test("MockAIServiceProvider initializes with defaults")
    func testInitialization() {
        let provider = MockAIServiceProvider()

        #expect(provider.id == "mock-provider")
        #expect(provider.displayName == "Mock Provider")
        #expect(provider.capabilities == [.textGeneration])
        #expect(provider.requiresAPIKey == false)
        #expect(provider.isConfigured() == true)
    }

    @Test("MockAIServiceProvider can be configured")
    func testConfiguration() {
        let provider = MockAIServiceProvider(
            id: "custom-mock",
            displayName: "Custom Mock",
            capabilities: [.textGeneration, .audioGeneration],
            requiresAPIKey: true
        )

        #expect(provider.id == "custom-mock")
        #expect(provider.displayName == "Custom Mock")
        #expect(provider.capabilities.count == 2)
        #expect(provider.requiresAPIKey == true)
    }

    @Test("MockAIServiceProvider generate tracks calls")
    func testGenerateTracking() async throws {
        let provider = MockAIServiceProvider()
        let context = try ModelContext(ModelContainer(for: GeneratedText.self))

        #expect(provider.generateCallCount == 0)

        _ = try await provider.generate(
            prompt: "Test prompt",
            parameters: ["key": "value"],
            context: context
        )

        #expect(provider.generateCallCount == 1)
        #expect(provider.lastPrompt == "Test prompt")
        #expect(provider.lastParameters?["key"] as? String == "value")
    }

    @Test("MockAIServiceProvider returns configured response")
    func testConfiguredResponse() async throws {
        let provider = MockAIServiceProvider()
        provider.generatedDataResponse = Data("custom response".utf8)

        let context = try ModelContext(ModelContainer(for: GeneratedText.self))
        let result = try await provider.generate(
            prompt: "test",
            parameters: [:],
            context: context
        )

        #expect(result == Data("custom response".utf8))
    }

    @Test("MockAIServiceProvider can throw errors")
    func testErrorThrowing() async throws {
        let provider = MockAIServiceProvider()
        provider.shouldThrowError = .networkError("Test error")

        let context = try ModelContext(ModelContainer(for: GeneratedText.self))

        await #expect(throws: AIServiceError.self) {
            _ = try await provider.generate(
                prompt: "test",
                parameters: [:],
                context: context
            )
        }
    }

    @Test("MockAIServiceProvider respects delay")
    func testGenerationDelay() async throws {
        let provider = MockAIServiceProvider()
        provider.generationDelay = 0.05 // 50ms

        let context = try ModelContext(ModelContainer(for: GeneratedText.self))

        let start = Date()
        _ = try await provider.generate(prompt: "test", parameters: [:], context: context)
        let duration = Date().timeIntervalSince(start)

        #expect(duration >= 0.05)
        #expect(duration < 0.3) // Allow more time for CI environments
    }

    @Test("MockAIServiceProvider reset() clears state")
    func testReset() async throws {
        let provider = MockAIServiceProvider()
        let context = try ModelContext(ModelContainer(for: GeneratedText.self))

        _ = try await provider.generate(prompt: "test", parameters: [:], context: context)
        provider.shouldThrowError = .networkError("test")
        provider.configured = false

        #expect(provider.generateCallCount == 1)
        #expect(provider.shouldThrowError != nil)
        #expect(provider.configured == false)

        provider.reset()

        #expect(provider.generateCallCount == 0)
        #expect(provider.lastPrompt == nil)
        #expect(provider.shouldThrowError == nil)
        #expect(provider.configured == true)
    }

    @Test("Factory method textProvider creates correct provider")
    func testTextProviderFactory() {
        let provider = MockAIServiceProvider.textProvider()

        #expect(provider.id == "mock-text")
        #expect(provider.displayName == "Mock Text Provider")
        #expect(provider.capabilities == [.textGeneration])
        #expect(provider.supportedDataStructures.count == 1)
    }

    @Test("Factory method audioProvider creates correct provider")
    func testAudioProviderFactory() {
        let provider = MockAIServiceProvider.audioProvider()

        #expect(provider.id == "mock-audio")
        #expect(provider.capabilities == [.audioGeneration])
        #expect(provider.generatedDataResponse.count == 1024)
    }

    @Test("Factory method imageProvider creates correct provider")
    func testImageProviderFactory() {
        let provider = MockAIServiceProvider.imageProvider()

        #expect(provider.id == "mock-image")
        #expect(provider.capabilities == [.imageGeneration])
        #expect(provider.generatedDataResponse.count == 2048)
    }

    @Test("Factory method failingProvider creates failing provider")
    func testFailingProviderFactory() async throws {
        let provider = MockAIServiceProvider.failingProvider(
            error: .rateLimitExceeded("Too many requests")
        )

        let context = try ModelContext(ModelContainer(for: GeneratedText.self))

        await #expect(throws: AIServiceError.self) {
            _ = try await provider.generate(prompt: "test", parameters: [:], context: context)
        }
    }

    @Test("Factory method unconfiguredProvider creates unconfigured provider")
    func testUnconfiguredProviderFactory() {
        let provider = MockAIServiceProvider.unconfiguredProvider()

        #expect(provider.requiresAPIKey == true)
        #expect(provider.isConfigured() == false)
    }

    @Test("Factory method delayedProvider has delay configured")
    func testDelayedProviderFactory() async throws {
        let provider = MockAIServiceProvider.delayedProvider(delay: 0.05)

        #expect(provider.generationDelay == 0.05)

        let context = try ModelContext(ModelContainer(for: GeneratedText.self))
        let start = Date()
        _ = try await provider.generate(prompt: "test", parameters: [:], context: context)
        let duration = Date().timeIntervalSince(start)

        #expect(duration >= 0.05)
    }

    @Test("MockAIServiceProvider validateConfiguration works with default implementation")
    func testValidateConfiguration() throws {
        let provider = MockAIServiceProvider(requiresAPIKey: true)
        provider.configured = true

        // Should not throw
        try provider.validateConfiguration()

        provider.configured = false

        // Should throw
        #expect(throws: AIServiceError.self) {
            try provider.validateConfiguration()
        }
    }

    @Test("MockAIServiceProvider generateProperty tracks calls")
    func testGeneratePropertyTracking() async throws {
        let provider = MockAIServiceProvider()

        let model = TestModelForGenerateProperty()
        #expect(provider.generatePropertyCallCount == 0)

        _ = try await provider.generateProperty(
            for: model,
            property: \TestModelForGenerateProperty.title,
            prompt: "Generate title",
            context: [:]
        )

        #expect(provider.generatePropertyCallCount == 1)
        #expect(provider.lastPrompt == "Generate title")
    }

    @Test("MockAIServiceProvider is Sendable")
    func testSendable() async throws {
        let provider = MockAIServiceProvider()

        await Task {
            // Should compile without warnings
            let _ = provider.id
        }.value
    }
}
