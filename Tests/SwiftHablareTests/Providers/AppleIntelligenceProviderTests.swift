//
//  AppleIntelligenceProviderTests.swift
//  SwiftHablare
//
//  Tests for Apple Intelligence Provider
//

import Testing
import Foundation
@testable import SwiftHablare

@Suite("AppleIntelligenceProvider Tests")
struct AppleIntelligenceProviderTests {

    // MARK: - Identity Tests

    @Test("Provider has correct identity")
    func testProviderIdentity() {
        let provider = AppleIntelligenceProvider()

        #expect(provider.id == "apple-intelligence")
        #expect(provider.displayName == "Apple Intelligence")
    }

    @Test("Provider declares correct capabilities")
    func testProviderCapabilities() {
        let provider = AppleIntelligenceProvider()

        #expect(provider.capabilities.contains(.textGeneration))
        #expect(!provider.capabilities.contains(.imageGeneration))
        #expect(!provider.capabilities.contains(.embeddings))
    }

    @Test("Provider response type is text")
    func testProviderResponseType() {
        let provider = AppleIntelligenceProvider()

        #expect(provider.responseType == .text)
    }

    @Test("Provider does not require API key")
    func testProviderDoesNotRequireAPIKey() {
        let provider = AppleIntelligenceProvider()

        #expect(provider.requiresAPIKey == false)
    }

    // MARK: - Configuration Tests

    @Test("Provider is always configured")
    func testProviderIsConfigured() {
        let provider = AppleIntelligenceProvider()

        #expect(provider.isConfigured() == true)
    }

    @Test("Provider validates configuration successfully")
    func testProviderValidatesConfiguration() {
        let provider = AppleIntelligenceProvider()

        var threwError = false
        do {
            try provider.validateConfiguration()
        } catch {
            threwError = true
        }

        #expect(!threwError, "Validation should not throw")
    }

    // MARK: - Generation Tests

    @Test("Provider generates text successfully")
    func testProviderGeneratesText() async {
        let provider = AppleIntelligenceProvider()

        let result = await provider.generate(
            prompt: "Write a short story",
            parameters: [:]
        )

        switch result {
        case .success(let content):
            guard let text = content.text else {
                Issue.record("Expected text content")
                return
            }
            #expect(!text.isEmpty)
            #expect(text.contains("Apple Intelligence"))
        case .failure(let error):
            Issue.record("Expected success, got error: \(error)")
        }
    }

    @Test("Provider respects temperature parameter")
    func testProviderRespectsTemperature() async {
        let provider = AppleIntelligenceProvider()

        let result = await provider.generate(
            prompt: "Test",
            parameters: ["temperature": 0.5]
        )

        switch result {
        case .success(let content):
            guard let text = content.text else {
                Issue.record("Expected text content")
                return
            }
            #expect(text.contains("Temperature: 0.5"))
        case .failure(let error):
            Issue.record("Expected success, got error: \(error)")
        }
    }

    @Test("Provider respects max length parameter")
    func testProviderRespectsMaxLength() async {
        let provider = AppleIntelligenceProvider()

        let result = await provider.generate(
            prompt: "Test",
            parameters: ["max_length": 1000]
        )

        switch result {
        case .success(let content):
            guard let text = content.text else {
                Issue.record("Expected text content")
                return
            }
            #expect(text.contains("Max Length: 1000"))
        case .failure(let error):
            Issue.record("Expected success, got error: \(error)")
        }
    }

    @Test("Provider uses default parameters when not specified")
    func testProviderUsesDefaultParameters() async {
        let provider = AppleIntelligenceProvider()

        let result = await provider.generate(
            prompt: "Test",
            parameters: [:]
        )

        switch result {
        case .success(let content):
            guard let text = content.text else {
                Issue.record("Expected text content")
                return
            }
            #expect(text.contains("Temperature: 0.7"))
            #expect(text.contains("Max Length: 500"))
        case .failure(let error):
            Issue.record("Expected success, got error: \(error)")
        }
    }

    @Test("Provider indicates on-device processing")
    func testProviderIndicatesOnDeviceProcessing() async {
        let provider = AppleIntelligenceProvider()

        let result = await provider.generate(
            prompt: "Test",
            parameters: [:]
        )

        switch result {
        case .success(let content):
            guard let text = content.text else {
                Issue.record("Expected text content")
                return
            }
            #expect(text.contains("On-Device Processing"))
        case .failure(let error):
            Issue.record("Expected success, got error: \(error)")
        }
    }

    @Test("Provider includes prompt in response")
    func testProviderIncludesPromptInResponse() async {
        let provider = AppleIntelligenceProvider()
        let testPrompt = "This is a unique test prompt"

        let result = await provider.generate(
            prompt: testPrompt,
            parameters: [:]
        )

        switch result {
        case .success(let content):
            guard let text = content.text else {
                Issue.record("Expected text content")
                return
            }
            #expect(text.contains(testPrompt))
        case .failure(let error):
            Issue.record("Expected success, got error: \(error)")
        }
    }

    // MARK: - Factory Method Tests

    @Test("Shared factory method creates provider")
    func testSharedFactoryMethod() {
        let provider = AppleIntelligenceProvider.shared()

        #expect(provider.id == "apple-intelligence")
        #expect(provider.displayName == "Apple Intelligence")
    }

    // MARK: - Platform Support Tests

    @Test("Platform support check returns true on supported platforms")
    func testPlatformSupportCheck() {
        #if os(macOS) || os(iOS)
        #expect(AppleIntelligenceProvider.isSupported() == true)
        #else
        #expect(AppleIntelligenceProvider.isSupported() == false)
        #endif
    }

    @Test("Device info includes platform information")
    func testDeviceInfoIncludesPlatform() {
        let provider = AppleIntelligenceProvider()
        let deviceInfo = provider.getDeviceInfo()

        #expect(deviceInfo["platform"] != nil)
        #expect(deviceInfo["provider"] == "Apple Intelligence")
        #expect(deviceInfo["mode"] == "on-device")
        #expect(deviceInfo["requires_network"] == "false")
        #expect(deviceInfo["privacy"] == "all data stays on device")
    }

    @Test("Device info indicates correct platform on macOS")
    func testDeviceInfoPlatformMacOS() {
        let provider = AppleIntelligenceProvider()
        let deviceInfo = provider.getDeviceInfo()

        #if os(macOS)
        #expect(deviceInfo["platform"] == "macOS")
        #elseif os(iOS)
        #expect(deviceInfo["platform"] == "iOS")
        #else
        #expect(deviceInfo["platform"] == "unknown")
        #endif
    }

    // MARK: - Parameter Handling Tests

    @Test("Default temperature is used when not specified")
    func testDefaultTemperature() {
        let parameters: [String: Any] = [:]
        let temperature = parameters["temperature"] as? Double ?? 0.7

        #expect(temperature == 0.7)
    }

    @Test("Custom temperature parameter is respected")
    func testCustomTemperatureParameter() {
        let parameters: [String: Any] = ["temperature": 0.9]
        let temperature = parameters["temperature"] as? Double ?? 0.7

        #expect(temperature == 0.9)
    }

    @Test("Default max length is used when not specified")
    func testDefaultMaxLength() {
        let parameters: [String: Any] = [:]
        let maxLength = parameters["max_length"] as? Int ?? 500

        #expect(maxLength == 500)
    }

    @Test("Custom max length parameter is respected")
    func testCustomMaxLengthParameter() {
        let parameters: [String: Any] = ["max_length": 1000]
        let maxLength = parameters["max_length"] as? Int ?? 500

        #expect(maxLength == 1000)
    }

    // MARK: - Concurrent Access Tests

    @Test("Provider handles concurrent requests")
    func testProviderHandlesConcurrentRequests() async {
        let provider = AppleIntelligenceProvider()

        async let result1 = provider.generate(prompt: "Request 1", parameters: [:])
        async let result2 = provider.generate(prompt: "Request 2", parameters: [:])
        async let result3 = provider.generate(prompt: "Request 3", parameters: [:])

        let results = await [result1, result2, result3]

        for result in results {
            switch result {
            case .success:
                // Expected
                break
            case .failure(let error):
                Issue.record("Expected success, got error: \(error)")
            }
        }
    }

    // MARK: - Privacy and Security Tests

    @Test("Provider emphasizes on-device privacy")
    func testProviderEmphasizesPrivacy() {
        let provider = AppleIntelligenceProvider()
        let deviceInfo = provider.getDeviceInfo()

        #expect(deviceInfo["privacy"]?.contains("device") == true)
        #expect(deviceInfo["requires_network"] == "false")
        #expect(deviceInfo["mode"] == "on-device")
    }

    @Test("Provider does not require network")
    func testProviderDoesNotRequireNetwork() {
        let provider = AppleIntelligenceProvider()
        let deviceInfo = provider.getDeviceInfo()

        #expect(deviceInfo["requires_network"] == "false")
    }

    // MARK: - Response Content Tests

    @Test("Response content is extractable as text")
    func testResponseContentExtractableAsText() async {
        let provider = AppleIntelligenceProvider()

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
        let provider = AppleIntelligenceProvider()

        let result = await provider.generate(prompt: "test", parameters: [:])

        switch result {
        case .success(let content):
            #expect(content.dataContent != nil)
        case .failure(let error):
            Issue.record("Expected success, got error: \(error)")
        }
    }

    // MARK: - Edge Cases

    @Test("Provider handles empty prompt")
    func testProviderHandlesEmptyPrompt() async {
        let provider = AppleIntelligenceProvider()

        let result = await provider.generate(prompt: "", parameters: [:])

        switch result {
        case .success(let content):
            #expect(content.text != nil)
        case .failure(let error):
            Issue.record("Expected success, got error: \(error)")
        }
    }

    @Test("Provider handles very long prompt")
    func testProviderHandlesVeryLongPrompt() async {
        let provider = AppleIntelligenceProvider()
        let longPrompt = String(repeating: "A", count: 10000)

        let result = await provider.generate(prompt: longPrompt, parameters: [:])

        switch result {
        case .success(let content):
            guard let text = content.text else {
                Issue.record("Expected text content")
                return
            }
            #expect(text.contains(longPrompt))
        case .failure(let error):
            Issue.record("Expected success, got error: \(error)")
        }
    }

    @Test("Provider handles special characters in prompt")
    func testProviderHandlesSpecialCharacters() async {
        let provider = AppleIntelligenceProvider()
        let specialPrompt = "Test: \"quotes\", 'apostrophes', & symbols!"

        let result = await provider.generate(prompt: specialPrompt, parameters: [:])

        switch result {
        case .success(let content):
            guard let text = content.text else {
                Issue.record("Expected text content")
                return
            }
            #expect(text.contains(specialPrompt))
        case .failure(let error):
            Issue.record("Expected success, got error: \(error)")
        }
    }

    // MARK: - Integration Tests

    @Test("Provider works without any parameters")
    func testProviderWorksWithoutParameters() async {
        let provider = AppleIntelligenceProvider()

        let result = await provider.generate(
            prompt: "Simple test",
            parameters: [:]
        )

        switch result {
        case .success(let content):
            #expect(content.text != nil)
        case .failure(let error):
            Issue.record("Expected success, got error: \(error)")
        }
    }

    @Test("Provider initialization requires no configuration")
    func testProviderInitializationRequiresNoConfiguration() {
        // Should not throw or require any setup
        let provider = AppleIntelligenceProvider()

        #expect(provider.isConfigured())
        #expect(provider.requiresAPIKey == false)
    }

    @Test("Multiple provider instances are independent")
    func testMultipleProviderInstancesAreIndependent() async {
        let provider1 = AppleIntelligenceProvider()
        let provider2 = AppleIntelligenceProvider()

        async let result1 = provider1.generate(prompt: "Test 1", parameters: [:])
        async let result2 = provider2.generate(prompt: "Test 2", parameters: [:])

        let results = await [result1, result2]

        #expect(results.count == 2)
        for result in results {
            #expect(result.isSuccess)
        }
    }
}
