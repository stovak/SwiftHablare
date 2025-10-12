//
//  MockOpenAIProviderTests.swift
//  SwiftHablare
//
//  Tests for Mock OpenAI Provider
//

import Testing
import Foundation
@testable import SwiftHablare

@Suite("MockOpenAIProvider Tests")
struct MockOpenAIProviderTests {

    // MARK: - Identity Tests

    @Test("Provider has correct identity")
    func testProviderIdentity() {
        let provider = MockOpenAIProvider.configured()

        #expect(provider.id == "openai-mock")
        #expect(provider.displayName == "OpenAI (Mock)")
    }

    @Test("Provider declares correct capabilities")
    func testProviderCapabilities() {
        let provider = MockOpenAIProvider.configured()

        #expect(provider.capabilities.contains(.textGeneration))
        #expect(provider.capabilities.contains(.embeddings))
        #expect(!provider.capabilities.contains(.imageGeneration))
    }

    @Test("Provider response type is text")
    func testProviderResponseType() {
        let provider = MockOpenAIProvider.configured()

        #expect(provider.responseType == .text)
    }

    // MARK: - Configuration Tests

    @Test("Provider requires API key")
    func testProviderRequiresAPIKey() {
        let provider = MockOpenAIProvider.configured()

        #expect(provider.requiresAPIKey == true)
    }

    @Test("Configured provider is configured")
    func testConfiguredProviderIsConfigured() {
        let provider = MockOpenAIProvider.configured()

        #expect(provider.isConfigured())
    }

    @Test("Unconfigured provider is not configured")
    func testUnconfiguredProviderIsNotConfigured() {
        let provider = MockOpenAIProvider.unconfigured()

        #expect(!provider.isConfigured())
    }

    @Test("Configured provider validates successfully")
    func testConfiguredProviderValidatesSuccessfully() {
        let provider = MockOpenAIProvider.configured()

        var didThrow = false
        do {
            try provider.validateConfiguration()
        } catch {
            didThrow = true
        }

        #expect(!didThrow, "Configured provider should validate successfully")
    }

    @Test("Unconfigured provider validation fails")
    func testUnconfiguredProviderValidationFails() {
        let provider = MockOpenAIProvider.unconfigured()

        var threwError = false
        do {
            try provider.validateConfiguration()
        } catch let error as AIServiceError {
            threwError = true
            if case .missingCredentials = error {
                // Expected
            } else {
                Issue.record("Expected missingCredentials error, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }

        #expect(threwError, "Unconfigured provider should throw error")
    }

    @Test("Provider with short API key validation fails")
    func testShortAPIKeyValidationFails() {
        let provider = MockOpenAIProvider(apiKey: "short")

        var threwError = false
        do {
            try provider.validateConfiguration()
        } catch let error as AIServiceError {
            threwError = true
            if case .invalidAPIKey = error {
                // Expected
            } else {
                Issue.record("Expected invalidAPIKey error, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }

        #expect(threwError, "Short API key should fail validation")
    }

    // MARK: - Generation Tests

    @Test("Provider generates text successfully")
    func testProviderGeneratesText() async {
        let provider = MockOpenAIProvider.configured()

        let result = await provider.generate(
            prompt: "Write a story",
            parameters: ["model": "gpt-4"]
        )

        switch result {
        case .success(let content):
            guard let text = content.text else {
                Issue.record("Expected text content")
                return
            }
            #expect(!text.isEmpty)
            #expect(text.contains("Mock"))
        case .failure(let error):
            Issue.record("Expected success, got error: \(error)")
        }
    }

    @Test("Provider returns mock response when set")
    func testProviderReturnsMockResponse() async {
        let provider = MockOpenAIProvider.configured()
        let expectedResponse = "This is a custom mock response"

        provider.setMockResponse(expectedResponse, for: "test prompt")

        let result = await provider.generate(
            prompt: "test prompt",
            parameters: [:]
        )

        switch result {
        case .success(let content):
            #expect(content.text == expectedResponse)
        case .failure(let error):
            Issue.record("Expected success, got error: \(error)")
        }
    }

    @Test("Provider respects parameters in response")
    func testProviderRespectsParameters() async {
        let provider = MockOpenAIProvider.configured()

        let result = await provider.generate(
            prompt: "Test",
            parameters: [
                "model": "gpt-4-turbo",
                "max_tokens": 500
            ]
        )

        switch result {
        case .success(let content):
            guard let text = content.text else {
                Issue.record("Expected text content")
                return
            }
            #expect(text.contains("gpt-4-turbo"))
            #expect(text.contains("500"))
        case .failure(let error):
            Issue.record("Expected success, got error: \(error)")
        }
    }

    @Test("Provider generates different responses for different prompts")
    func testProviderGeneratesDifferentResponses() async {
        let provider = MockOpenAIProvider.configured()

        let result1 = await provider.generate(prompt: "First prompt", parameters: [:])
        let result2 = await provider.generate(prompt: "Second prompt", parameters: [:])

        guard case .success(let content1) = result1,
              case .success(let content2) = result2,
              let text1 = content1.text,
              let text2 = content2.text else {
            Issue.record("Expected successful text responses")
            return
        }

        #expect(text1.contains("First prompt"))
        #expect(text2.contains("Second prompt"))
        #expect(text1 != text2)
    }

    // MARK: - Error Simulation Tests

    @Test("Provider can simulate authentication failure")
    func testProviderSimulatesAuthenticationFailure() async {
        let provider = MockOpenAIProvider.configured()

        provider.simulateFailure(.authenticationFailed("Invalid API key"))

        let result = await provider.generate(prompt: "test", parameters: [:])

        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            if case .authenticationFailed = error {
                // Expected
            } else {
                Issue.record("Expected authenticationFailed, got \(error)")
            }
        }
    }

    @Test("Provider can simulate rate limit error")
    func testProviderSimulatesRateLimitError() async {
        let provider = MockOpenAIProvider.configured()

        provider.simulateFailure(.rateLimitExceeded("Too many requests", retryAfter: 60))

        let result = await provider.generate(prompt: "test", parameters: [:])

        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            if case .rateLimitExceeded(_, let retryAfter) = error {
                #expect(retryAfter == 60)
            } else {
                Issue.record("Expected rateLimitExceeded, got \(error)")
            }
        }
    }

    @Test("Provider can reset failure simulation")
    func testProviderResetsFailureSimulation() async {
        let provider = MockOpenAIProvider.configured()

        provider.simulateFailure(.networkError("Connection failed"))

        // First call should fail
        let result1 = await provider.generate(prompt: "test", parameters: [:])
        #expect(result1.isFailure)

        // Reset and try again
        provider.resetFailure()
        let result2 = await provider.generate(prompt: "test", parameters: [:])
        #expect(result2.isSuccess)
    }

    // MARK: - Unconfigured Provider Tests

    @Test("Unconfigured provider returns configuration error")
    func testUnconfiguredProviderReturnsError() async {
        let provider = MockOpenAIProvider.unconfigured()

        let result = await provider.generate(prompt: "test", parameters: [:])

        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            if case .missingCredentials = error {
                // Expected
            } else {
                Issue.record("Expected missingCredentials, got \(error)")
            }
        }
    }

    // MARK: - Concurrent Access Tests

    @Test("Provider handles concurrent requests")
    func testProviderHandlesConcurrentRequests() async {
        let provider = MockOpenAIProvider.configured()

        async let result1 = provider.generate(prompt: "Request 1", parameters: [:])
        async let result2 = provider.generate(prompt: "Request 2", parameters: [:])
        async let result3 = provider.generate(prompt: "Request 3", parameters: [:])

        let results = await [result1, result2, result3]

        for result in results {
            #expect(result.isSuccess, "All concurrent requests should succeed")
        }
    }

    // MARK: - Response Content Tests

    @Test("Response content is extractable as text")
    func testResponseContentExtractableAsText() async {
        let provider = MockOpenAIProvider.configured()

        let result = await provider.generate(prompt: "test", parameters: [:])

        switch result {
        case .success(let content):
            #expect(content.text != nil)
            #expect(content.contentType == .text)
        case .failure(let error):
            Issue.record("Expected success, got error: \(error)")
        }
    }

    @Test("Response content is extractable as data")
    func testResponseContentExtractableAsData() async {
        let provider = MockOpenAIProvider.configured()

        let result = await provider.generate(prompt: "test", parameters: [:])

        switch result {
        case .success(let content):
            #expect(content.dataContent != nil)
        case .failure(let error):
            Issue.record("Expected success, got error: \(error)")
        }
    }

    // MARK: - Factory Method Tests

    @Test("Configured factory method creates configured provider")
    func testConfiguredFactoryMethod() {
        let provider = MockOpenAIProvider.configured()

        #expect(provider.isConfigured())
    }

    @Test("Unconfigured factory method creates unconfigured provider")
    func testUnconfiguredFactoryMethod() {
        let provider = MockOpenAIProvider.unconfigured()

        #expect(!provider.isConfigured())
    }

    // MARK: - Performance Tests

    @Test("Provider generates responses quickly")
    func testProviderPerformance() async {
        let provider = MockOpenAIProvider.configured()

        let start = Date()

        _ = await provider.generate(prompt: "test", parameters: [:])

        let duration = Date().timeIntervalSince(start)

        // Mock provider should respond in under 200ms (includes 100ms simulated delay)
        #expect(duration < 0.2, "Provider took \(duration)s, expected < 0.2s")
    }

    // MARK: - Integration with Result Type

    @Test("Result type provides success/failure checks")
    func testResultTypeProvidesSuccessFailureChecks() async {
        let provider = MockOpenAIProvider.configured()

        let successResult = await provider.generate(prompt: "test", parameters: [:])
        #expect(successResult.isSuccess)
        #expect(!successResult.isFailure)

        provider.simulateFailure(.networkError("Test error"))
        let failureResult = await provider.generate(prompt: "test", parameters: [:])
        #expect(failureResult.isFailure)
        #expect(!failureResult.isSuccess)
    }
}

// MARK: - Result Extension for Testing

extension Result {
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    var isFailure: Bool {
        if case .failure = self {
            return true
        }
        return false
    }
}
