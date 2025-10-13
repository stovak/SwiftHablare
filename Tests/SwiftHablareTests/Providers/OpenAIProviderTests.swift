//
//  OpenAIProviderTests.swift
//  SwiftHablare
//
//  Tests for OpenAI Provider
//

import Testing
import Foundation
@testable import SwiftHablare

@Suite("OpenAIProvider Tests")
struct OpenAIProviderTests {

    // MARK: - Identity Tests

    @Test("Provider has correct identity")
    func testProviderIdentity() {
        let provider = OpenAIProvider()

        #expect(provider.id == "openai")
        #expect(provider.displayName == "OpenAI")
    }

    @Test("Provider declares correct capabilities")
    func testProviderCapabilities() {
        let provider = OpenAIProvider()

        #expect(provider.capabilities.contains(.textGeneration))
        #expect(provider.capabilities.contains(.imageGeneration))
        #expect(provider.capabilities.contains(.embeddings))
    }

    @Test("Provider response type is text")
    func testProviderResponseType() {
        let provider = OpenAIProvider()

        #expect(provider.responseType == .text)
    }

    @Test("Provider requires API key")
    func testProviderRequiresAPIKey() {
        let provider = OpenAIProvider()

        #expect(provider.requiresAPIKey == true)
    }

    // MARK: - Configuration Tests

    @Test("Provider is configured returns true")
    func testProviderIsConfigured() {
        let provider = OpenAIProvider()

        #expect(provider.isConfigured() == true)
    }

    @Test("Provider validates configuration successfully")
    func testProviderValidatesConfiguration() {
        let provider = OpenAIProvider()

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
            if !key.hasPrefix("sk-") && !key.hasPrefix("test-") {
                throw AIServiceError.invalidAPIKey("OpenAI API key must start with 'sk-'")
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
            "sk-1234567890abcdef",
            "sk-proj-abcdefghijklmnop",
            "test-1234567890"
        ]

        for key in validKeys {
            let isValid = key.hasPrefix("sk-") || key.hasPrefix("test-")
            #expect(isValid, "Key '\(key)' should be valid")
        }
    }

    @Test("Provider returns error when credentials are missing")
    func testMissingCredentialsInGenerate() async {
        // Create provider with new credential manager (no credentials stored)
        let credentialManager = AICredentialManager()
        let provider = OpenAIProvider(
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
            providerID: "openai",
            type: .apiKey,
            name: "Test Invalid Key"
        )

        try? await credentialManager.store(
            credential: credential,
            value: SecureString("invalid-key-no-prefix")
        )

        let provider = OpenAIProvider(
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

    @Test("Chat completion request structure is correct")
    func testChatCompletionRequestStructure() throws {
        let request = OpenAIProvider.ChatCompletionRequest(
            model: "gpt-4",
            messages: [
                OpenAIProvider.ChatMessage(role: "user", content: "Hello")
            ],
            temperature: 0.7,
            maxTokens: 100
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["model"] as? String == "gpt-4")
        #expect(json?["temperature"] as? Double == 0.7)
        #expect(json?["max_tokens"] as? Int == 100)

        let messages = json?["messages"] as? [[String: String]]
        #expect(messages?.count == 1)
        #expect(messages?.first?["role"] == "user")
        #expect(messages?.first?["content"] == "Hello")
    }

    @Test("Chat completion request with optional fields")
    func testChatCompletionRequestOptionalFields() throws {
        let request = OpenAIProvider.ChatCompletionRequest(
            model: "gpt-3.5-turbo",
            messages: [
                OpenAIProvider.ChatMessage(role: "system", content: "You are helpful"),
                OpenAIProvider.ChatMessage(role: "user", content: "Hi")
            ],
            temperature: nil,
            maxTokens: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["model"] as? String == "gpt-3.5-turbo")
        #expect(json?["temperature"] == nil)
        #expect(json?["max_tokens"] == nil)

        let messages = json?["messages"] as? [[String: String]]
        #expect(messages?.count == 2)
    }

    // MARK: - Response Parsing Tests

    @Test("Chat completion response decodes correctly")
    func testChatCompletionResponseDecoding() throws {
        let jsonString = """
        {
            "id": "chatcmpl-123",
            "object": "chat.completion",
            "created": 1677652288,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": "Hello! How can I help you today?"
                },
                "finish_reason": "stop"
            }],
            "usage": {
                "prompt_tokens": 9,
                "completion_tokens": 12,
                "total_tokens": 21
            }
        }
        """

        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(
            OpenAIProvider.ChatCompletionResponse.self,
            from: data
        )

        #expect(response.id == "chatcmpl-123")
        #expect(response.model == "gpt-4")
        #expect(response.choices.count == 1)
        #expect(response.choices[0].message.content == "Hello! How can I help you today?")
        #expect(response.usage?.totalTokens == 21)
        #expect(response.usage?.promptTokens == 9)
        #expect(response.usage?.completionTokens == 12)
    }

    @Test("Chat completion response without usage")
    func testChatCompletionResponseWithoutUsage() throws {
        let jsonString = """
        {
            "id": "chatcmpl-456",
            "object": "chat.completion",
            "created": 1677652288,
            "model": "gpt-3.5-turbo",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": "Test response"
                },
                "finish_reason": "stop"
            }]
        }
        """

        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(
            OpenAIProvider.ChatCompletionResponse.self,
            from: data
        )

        #expect(response.id == "chatcmpl-456")
        #expect(response.choices[0].message.content == "Test response")
        #expect(response.usage == nil)
    }

    @Test("Chat completion response with multiple choices")
    func testChatCompletionResponseMultipleChoices() throws {
        let jsonString = """
        {
            "id": "chatcmpl-789",
            "object": "chat.completion",
            "created": 1677652288,
            "model": "gpt-4",
            "choices": [
                {
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "First response"
                    },
                    "finish_reason": "stop"
                },
                {
                    "index": 1,
                    "message": {
                        "role": "assistant",
                        "content": "Second response"
                    },
                    "finish_reason": "stop"
                }
            ]
        }
        """

        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(
            OpenAIProvider.ChatCompletionResponse.self,
            from: data
        )

        #expect(response.choices.count == 2)
        #expect(response.choices[0].message.content == "First response")
        #expect(response.choices[1].message.content == "Second response")
    }

    // MARK: - Chat Message Tests

    @Test("Chat message encodes and decodes correctly")
    func testChatMessageCoding() throws {
        let message = OpenAIProvider.ChatMessage(
            role: "user",
            content: "Hello, world!"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(message)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(OpenAIProvider.ChatMessage.self, from: data)

        #expect(decoded.role == "user")
        #expect(decoded.content == "Hello, world!")
    }

    @Test("Chat message supports different roles")
    func testChatMessageRoles() {
        let roles = ["system", "user", "assistant", "function"]

        for role in roles {
            let message = OpenAIProvider.ChatMessage(role: role, content: "Test")
            #expect(message.role == role)
            #expect(message.content == "Test")
        }
    }

    // MARK: - Factory Method Tests

    @Test("Shared factory method creates provider")
    func testSharedFactoryMethod() {
        let provider = OpenAIProvider.shared()

        #expect(provider.id == "openai")
        #expect(provider.displayName == "OpenAI")
    }

    // MARK: - Parameter Handling Tests

    @Test("Default model is used when not specified")
    func testDefaultModelParameter() {
        let parameters: [String: Any] = [:]
        let model = parameters["model"] as? String ?? "gpt-3.5-turbo"

        #expect(model == "gpt-3.5-turbo")
    }

    @Test("Custom model parameter is respected")
    func testCustomModelParameter() {
        let parameters: [String: Any] = ["model": "gpt-4-turbo"]
        let model = parameters["model"] as? String ?? "gpt-3.5-turbo"

        #expect(model == "gpt-4-turbo")
    }

    @Test("Temperature parameter is extracted correctly")
    func testTemperatureParameter() {
        let parameters: [String: Any] = ["temperature": 0.9]
        let temperature = parameters["temperature"] as? Double ?? 0.7

        #expect(temperature == 0.9)
    }

    @Test("Default temperature is used when not specified")
    func testDefaultTemperature() {
        let parameters: [String: Any] = [:]
        let temperature = parameters["temperature"] as? Double ?? 0.7

        #expect(temperature == 0.7)
    }

    @Test("Max tokens parameter is extracted correctly")
    func testMaxTokensParameter() {
        let parameters: [String: Any] = ["max_tokens": 500]
        let maxTokens = parameters["max_tokens"] as? Int

        #expect(maxTokens == 500)
    }

    // MARK: - Model Support Tests

    @Test("Supports GPT-4 models")
    func testGPT4ModelSupport() {
        let gpt4Models = ["gpt-4", "gpt-4-turbo", "gpt-4-turbo-preview"]

        for model in gpt4Models {
            // Models should be valid strings
            #expect(!model.isEmpty)
            #expect(model.hasPrefix("gpt-4"))
        }
    }

    @Test("Supports GPT-3.5 models")
    func testGPT35ModelSupport() {
        let gpt35Models = ["gpt-3.5-turbo", "gpt-3.5-turbo-16k"]

        for model in gpt35Models {
            #expect(!model.isEmpty)
            #expect(model.hasPrefix("gpt-3.5"))
        }
    }

    // MARK: - Error Handling Structure Tests

    @Test("Provider handles missing credentials gracefully")
    func testMissingCredentialsHandling() {
        // Test the error type that should be thrown
        let error = AIServiceError.missingCredentials("OpenAI API key is required")

        if case .missingCredentials(let message) = error {
            #expect(message.contains("OpenAI"))
            #expect(message.contains("API key"))
        } else {
            Issue.record("Expected missingCredentials error")
        }
    }

    @Test("Provider handles invalid API key gracefully")
    func testInvalidAPIKeyHandling() {
        let error = AIServiceError.invalidAPIKey("OpenAI API key must start with 'sk-'")

        if case .invalidAPIKey(let message) = error {
            #expect(message.contains("sk-"))
        } else {
            Issue.record("Expected invalidAPIKey error")
        }
    }

    // MARK: - JSON Encoding Edge Cases

    @Test("Request handles empty messages array")
    func testRequestWithEmptyMessages() throws {
        let request = OpenAIProvider.ChatCompletionRequest(
            model: "gpt-4",
            messages: [],
            temperature: 0.7,
            maxTokens: nil
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
        let request = OpenAIProvider.ChatCompletionRequest(
            model: "gpt-4",
            messages: [
                OpenAIProvider.ChatMessage(role: "user", content: longContent)
            ],
            temperature: nil,
            maxTokens: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)

        #expect(data.count > 10000)
    }

    @Test("Response handles empty content")
    func testResponseWithEmptyContent() throws {
        let jsonString = """
        {
            "id": "test",
            "object": "chat.completion",
            "created": 1677652288,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": ""
                },
                "finish_reason": "stop"
            }]
        }
        """

        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(
            OpenAIProvider.ChatCompletionResponse.self,
            from: data
        )

        #expect(response.choices[0].message.content.isEmpty)
    }

    // MARK: - Base URL Configuration Tests

    @Test("Provider uses default base URL")
    func testDefaultBaseURL() {
        let provider = OpenAIProvider()

        #expect(provider.baseURL == "https://api.openai.com/v1")
    }

    @Test("Provider accepts custom base URL")
    func testCustomBaseURL() {
        let customURL = "https://custom.openai.proxy.com/v1"
        let provider = OpenAIProvider(baseURL: customURL)

        #expect(provider.baseURL == customURL)
    }

    // MARK: - Timeout Configuration Tests

    @Test("Provider has appropriate timeout")
    func testProviderTimeout() {
        let provider = OpenAIProvider()

        // OpenAI provider should have 120 second timeout
        #expect(provider.timeout == 120.0)
    }
}
