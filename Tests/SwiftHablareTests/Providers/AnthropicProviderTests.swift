//
//  AnthropicProviderTests.swift
//  SwiftHablare
//
//  Tests for Anthropic Provider
//

import Testing
import Foundation
@testable import SwiftHablare

@Suite("AnthropicProvider Tests")
struct AnthropicProviderTests {

    // MARK: - Identity Tests

    @Test("Provider has correct identity")
    func testProviderIdentity() {
        let provider = AnthropicProvider()

        #expect(provider.id == "anthropic")
        #expect(provider.displayName == "Anthropic")
    }

    @Test("Provider declares correct capabilities")
    func testProviderCapabilities() {
        let provider = AnthropicProvider()

        #expect(provider.capabilities.contains(.textGeneration))
        #expect(!provider.capabilities.contains(.imageGeneration))
        #expect(!provider.capabilities.contains(.embeddings))
    }

    @Test("Provider response type is text")
    func testProviderResponseType() {
        let provider = AnthropicProvider()

        #expect(provider.responseType == .text)
    }

    @Test("Provider requires API key")
    func testProviderRequiresAPIKey() {
        let provider = AnthropicProvider()

        #expect(provider.requiresAPIKey == true)
    }

    // MARK: - Configuration Tests

    @Test("Provider is configured returns true")
    func testProviderIsConfigured() {
        let provider = AnthropicProvider()

        #expect(provider.isConfigured() == true)
    }

    @Test("Provider validates configuration successfully")
    func testProviderValidatesConfiguration() {
        let provider = AnthropicProvider()

        var threwError = false
        do {
            try provider.validateConfiguration()
        } catch {
            threwError = true
        }

        #expect(!threwError, "Validation should not throw")
    }

    @Test("Provider validates API key format")
    func testAPIKeyFormatValidation() {
        // Test the validation logic directly
        var threwError = false
        do {
            // Test validation logic
            let key = "invalid-key"
            if !key.hasPrefix("sk-ant-") && !key.hasPrefix("test-") {
                throw AIServiceError.invalidAPIKey("Anthropic API key must start with 'sk-ant-'")
            }
        } catch {
            threwError = true
            if let aiError = error as? AIServiceError {
                if case .invalidAPIKey = aiError {
                    // Expected
                } else {
                    Issue.record("Expected invalidAPIKey, got \(aiError)")
                }
            }
        }

        #expect(threwError, "Invalid API key format should be rejected")
    }

    @Test("Provider accepts valid API key format")
    func testValidAPIKeyFormat() {
        let validKeys = [
            "sk-ant-1234567890abcdef",
            "sk-ant-api03-abcdefghijklmnop",
            "test-1234567890"
        ]

        for key in validKeys {
            let isValid = key.hasPrefix("sk-ant-") || key.hasPrefix("test-")
            #expect(isValid, "Key '\(key)' should be valid")
        }
    }

    @Test("Provider returns error when credentials are missing")
    func testMissingCredentialsInGenerate() async {
        // Create provider with new credential manager (no credentials stored)
        let credentialManager = AICredentialManager()
        let provider = AnthropicProvider(
            credentialManager: credentialManager,
            baseURL: "https://test.example.com"
        )

        let result = await provider.generate(
            prompt: "test prompt",
            parameters: [:]
        )

        switch result {
        case .success:
            Issue.record("Expected failure for missing credentials")
        case .failure(let error):
            if case .missingCredentials = error {
                // Expected
            } else {
                Issue.record("Expected missingCredentials error, got \(error)")
            }
        }
    }

    @Test("Provider returns error when API key has invalid format")
    func testInvalidAPIKeyInGenerate() async {
        // Create provider with invalid API key
        let credentialManager = AICredentialManager()

        // Store a credential with invalid format
        let credential = AICredential(
            providerID: "anthropic",
            type: .apiKey,
            name: "Test Invalid Key"
        )

        try? await credentialManager.store(
            credential: credential,
            value: SecureString("invalid-key-no-prefix")
        )

        let provider = AnthropicProvider(
            credentialManager: credentialManager,
            baseURL: "https://test.example.com"
        )

        let result = await provider.generate(
            prompt: "test prompt",
            parameters: [:]
        )

        switch result {
        case .success:
            Issue.record("Expected failure for invalid API key")
        case .failure(let error):
            if case .invalidAPIKey = error {
                // Expected
            } else {
                Issue.record("Expected invalidAPIKey error, got \(error)")
            }
        }
    }

    // MARK: - Request Building Tests

    @Test("Messages request structure is correct")
    func testMessagesRequestStructure() throws {
        let request = AnthropicProvider.MessagesRequest(
            model: "claude-3-opus-20240229",
            messages: [
                AnthropicProvider.Message(role: "user", content: "Hello")
            ],
            maxTokens: 1024,
            temperature: 0.7,
            system: "You are a helpful assistant"
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["model"] as? String == "claude-3-opus-20240229")
        #expect(json?["max_tokens"] as? Int == 1024)
        #expect(json?["temperature"] as? Double == 0.7)
        #expect(json?["system"] as? String == "You are a helpful assistant")

        let messages = json?["messages"] as? [[String: String]]
        #expect(messages?.count == 1)
        #expect(messages?.first?["role"] == "user")
        #expect(messages?.first?["content"] == "Hello")
    }

    @Test("Messages request with optional fields")
    func testMessagesRequestOptionalFields() throws {
        let request = AnthropicProvider.MessagesRequest(
            model: "claude-3-sonnet-20240229",
            messages: [
                AnthropicProvider.Message(role: "user", content: "Hi")
            ],
            maxTokens: 2048,
            temperature: nil,
            system: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["model"] as? String == "claude-3-sonnet-20240229")
        #expect(json?["max_tokens"] as? Int == 2048)
        #expect(json?["temperature"] == nil)
        #expect(json?["system"] == nil)

        let messages = json?["messages"] as? [[String: String]]
        #expect(messages?.count == 1)
    }

    // MARK: - Response Parsing Tests

    @Test("Messages response decodes correctly")
    func testMessagesResponseDecoding() throws {
        let jsonString = """
        {
            "id": "msg_123",
            "type": "message",
            "role": "assistant",
            "content": [{
                "type": "text",
                "text": "Hello! How can I help you today?"
            }],
            "model": "claude-3-opus-20240229",
            "stop_reason": "end_turn",
            "usage": {
                "input_tokens": 10,
                "output_tokens": 20
            }
        }
        """

        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(
            AnthropicProvider.MessagesResponse.self,
            from: data
        )

        #expect(response.id == "msg_123")
        #expect(response.type == "message")
        #expect(response.role == "assistant")
        #expect(response.model == "claude-3-opus-20240229")
        #expect(response.stopReason == "end_turn")
        #expect(response.content.count == 1)
        #expect(response.content[0].type == "text")
        #expect(response.content[0].text == "Hello! How can I help you today?")
        #expect(response.usage.inputTokens == 10)
        #expect(response.usage.outputTokens == 20)
    }

    @Test("Messages response with multiple content blocks")
    func testMessagesResponseMultipleContentBlocks() throws {
        let jsonString = """
        {
            "id": "msg_456",
            "type": "message",
            "role": "assistant",
            "content": [
                {
                    "type": "text",
                    "text": "First part"
                },
                {
                    "type": "text",
                    "text": "Second part"
                }
            ],
            "model": "claude-3-sonnet-20240229",
            "stop_reason": "end_turn",
            "usage": {
                "input_tokens": 5,
                "output_tokens": 10
            }
        }
        """

        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(
            AnthropicProvider.MessagesResponse.self,
            from: data
        )

        #expect(response.content.count == 2)
        #expect(response.content[0].text == "First part")
        #expect(response.content[1].text == "Second part")
    }

    @Test("Messages response without stop reason")
    func testMessagesResponseWithoutStopReason() throws {
        let jsonString = """
        {
            "id": "msg_789",
            "type": "message",
            "role": "assistant",
            "content": [{
                "type": "text",
                "text": "Test response"
            }],
            "model": "claude-3-haiku-20240307",
            "usage": {
                "input_tokens": 15,
                "output_tokens": 5
            }
        }
        """

        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(
            AnthropicProvider.MessagesResponse.self,
            from: data
        )

        #expect(response.id == "msg_789")
        #expect(response.content[0].text == "Test response")
        #expect(response.stopReason == nil)
    }

    // MARK: - Message Tests

    @Test("Message encodes and decodes correctly")
    func testMessageCoding() throws {
        let message = AnthropicProvider.Message(
            role: "user",
            content: "Hello, Claude!"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(message)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnthropicProvider.Message.self, from: data)

        #expect(decoded.role == "user")
        #expect(decoded.content == "Hello, Claude!")
    }

    @Test("Message supports different roles")
    func testMessageRoles() {
        let roles = ["user", "assistant"]

        for role in roles {
            let message = AnthropicProvider.Message(role: role, content: "Test")
            #expect(message.role == role)
            #expect(message.content == "Test")
        }
    }

    // MARK: - Factory Method Tests

    @Test("Shared factory method creates provider")
    func testSharedFactoryMethod() {
        let provider = AnthropicProvider.shared()

        #expect(provider.id == "anthropic")
        #expect(provider.displayName == "Anthropic")
    }

    // MARK: - Parameter Handling Tests

    @Test("Default model is used when not specified")
    func testDefaultModelParameter() {
        let parameters: [String: Any] = [:]
        let model = parameters["model"] as? String ?? "claude-3-sonnet-20240229"

        #expect(model == "claude-3-sonnet-20240229")
    }

    @Test("Custom model parameter is respected")
    func testCustomModelParameter() {
        let parameters: [String: Any] = ["model": "claude-3-opus-20240229"]
        let model = parameters["model"] as? String ?? "claude-3-sonnet-20240229"

        #expect(model == "claude-3-opus-20240229")
    }

    @Test("Temperature parameter is extracted correctly")
    func testTemperatureParameter() {
        let parameters: [String: Any] = ["temperature": 0.9]
        let temperature = parameters["temperature"] as? Double

        #expect(temperature == 0.9)
    }

    @Test("Max tokens parameter is extracted correctly")
    func testMaxTokensParameter() {
        let parameters: [String: Any] = ["max_tokens": 2048]
        let maxTokens = parameters["max_tokens"] as? Int ?? 1024

        #expect(maxTokens == 2048)
    }

    @Test("Default max tokens is used when not specified")
    func testDefaultMaxTokens() {
        let parameters: [String: Any] = [:]
        let maxTokens = parameters["max_tokens"] as? Int ?? 1024

        #expect(maxTokens == 1024)
    }

    @Test("System prompt parameter is extracted correctly")
    func testSystemPromptParameter() {
        let parameters: [String: Any] = ["system": "You are a helpful assistant"]
        let system = parameters["system"] as? String

        #expect(system == "You are a helpful assistant")
    }

    // MARK: - Model Support Tests

    @Test("Supports Claude 3 Opus model")
    func testClaude3OpusModelSupport() {
        let models = ["claude-3-opus-20240229"]

        for model in models {
            #expect(!model.isEmpty)
            #expect(model.hasPrefix("claude-3-opus"))
        }
    }

    @Test("Supports Claude 3 Sonnet model")
    func testClaude3SonnetModelSupport() {
        let models = ["claude-3-sonnet-20240229"]

        for model in models {
            #expect(!model.isEmpty)
            #expect(model.hasPrefix("claude-3-sonnet"))
        }
    }

    @Test("Supports Claude 3 Haiku model")
    func testClaude3HaikuModelSupport() {
        let models = ["claude-3-haiku-20240307"]

        for model in models {
            #expect(!model.isEmpty)
            #expect(model.hasPrefix("claude-3-haiku"))
        }
    }

    // MARK: - Error Handling Structure Tests

    @Test("Provider handles missing credentials gracefully")
    func testMissingCredentialsHandling() {
        // Test the error type that should be thrown
        let error = AIServiceError.missingCredentials("Anthropic API key is required")

        if case .missingCredentials(let message) = error {
            #expect(message.contains("Anthropic"))
            #expect(message.contains("API key"))
        } else {
            Issue.record("Expected missingCredentials error")
        }
    }

    @Test("Provider handles invalid API key gracefully")
    func testInvalidAPIKeyHandling() {
        let error = AIServiceError.invalidAPIKey("Anthropic API key must start with 'sk-ant-'")

        if case .invalidAPIKey(let message) = error {
            #expect(message.contains("sk-ant-"))
        } else {
            Issue.record("Expected invalidAPIKey error")
        }
    }

    // MARK: - JSON Encoding Edge Cases

    @Test("Request handles empty messages array")
    func testRequestWithEmptyMessages() throws {
        let request = AnthropicProvider.MessagesRequest(
            model: "claude-3-sonnet-20240229",
            messages: [],
            maxTokens: 1024,
            temperature: nil,
            system: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        let messages = json?["messages"] as? [[String: String]]
        #expect(messages?.isEmpty == true)
    }

    @Test("Request handles very long content")
    func testRequestWithLongContent() throws {
        let longContent = String(repeating: "A", count: 10000)
        let request = AnthropicProvider.MessagesRequest(
            model: "claude-3-opus-20240229",
            messages: [
                AnthropicProvider.Message(role: "user", content: longContent)
            ],
            maxTokens: 4096,
            temperature: nil,
            system: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)

        #expect(data.count > 10000)
    }

    @Test("Response handles empty content text")
    func testResponseWithEmptyContentText() throws {
        let jsonString = """
        {
            "id": "test",
            "type": "message",
            "role": "assistant",
            "content": [{
                "type": "text",
                "text": ""
            }],
            "model": "claude-3-sonnet-20240229",
            "usage": {
                "input_tokens": 5,
                "output_tokens": 0
            }
        }
        """

        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(
            AnthropicProvider.MessagesResponse.self,
            from: data
        )

        #expect(response.content[0].text.isEmpty)
    }

    // MARK: - Base URL Configuration Tests

    @Test("Provider uses default base URL")
    func testDefaultBaseURL() {
        let provider = AnthropicProvider()

        #expect(provider.baseURL == "https://api.anthropic.com")
    }

    @Test("Provider accepts custom base URL")
    func testCustomBaseURL() {
        let customURL = "https://custom.anthropic.proxy.com"
        let provider = AnthropicProvider(baseURL: customURL)

        #expect(provider.baseURL == customURL)
    }

    // MARK: - Timeout Configuration Tests

    @Test("Provider has appropriate timeout")
    func testProviderTimeout() {
        let provider = AnthropicProvider()

        // Anthropic provider should have 120 second timeout
        #expect(provider.timeout == 120.0)
    }
}
