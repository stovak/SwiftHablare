//
//  TextRequestorTests.swift
//  SwiftHablareTests
//
//  Phase 6B: Tests for text requestors
//

import XCTest
@testable import SwiftHablare

@available(macOS 15.0, iOS 17.0, *)
final class TextRequestorTests: XCTestCase {

    var tempDirectory: URL!
    var storageArea: StorageAreaReference!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        storageArea = StorageAreaReference.temporary()
    }

    override func tearDown() {
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        super.tearDown()
    }

    // MARK: - GeneratedTextData Tests

    func testGeneratedTextData_Initialization() {
        let textData = GeneratedTextData(
            text: "Hello, world! This is a test.",
            model: "gpt-4",
            languageCode: "en",
            tokenCount: 10
        )

        XCTAssertEqual(textData.text, "Hello, world! This is a test.")
        XCTAssertEqual(textData.model, "gpt-4")
        XCTAssertEqual(textData.languageCode, "en")
        XCTAssertEqual(textData.tokenCount, 10)
        XCTAssertEqual(textData.wordCount, 6)
        XCTAssertEqual(textData.characterCount, 29)
    }

    func testGeneratedTextData_WordCount() {
        let textData = GeneratedTextData(
            text: "One two three four five",
            model: "gpt-4"
        )

        XCTAssertEqual(textData.wordCount, 5)
    }

    func testGeneratedTextData_CharacterCount() {
        let textData = GeneratedTextData(
            text: "12345",
            model: "gpt-4"
        )

        XCTAssertEqual(textData.characterCount, 5)
    }

    func testGeneratedTextData_EmptyText() {
        let textData = GeneratedTextData(
            text: "",
            model: "gpt-4"
        )

        XCTAssertEqual(textData.wordCount, 0)
        XCTAssertEqual(textData.characterCount, 0)
    }

    func testGeneratedTextData_Codable() throws {
        let original = GeneratedTextData(
            text: "Test content",
            model: "gpt-4",
            languageCode: "en",
            tokenCount: 5
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GeneratedTextData.self, from: encoded)

        XCTAssertEqual(decoded.text, original.text)
        XCTAssertEqual(decoded.model, original.model)
        XCTAssertEqual(decoded.languageCode, original.languageCode)
        XCTAssertEqual(decoded.tokenCount, original.tokenCount)
        XCTAssertEqual(decoded.wordCount, original.wordCount)
        XCTAssertEqual(decoded.characterCount, original.characterCount)
    }

    func testGeneratedTextData_PreferredFormat() {
        let textData = GeneratedTextData(
            text: "Test",
            model: "gpt-4"
        )

        XCTAssertEqual(textData.preferredFormat, .json)
    }

    // MARK: - TextGenerationConfig Tests

    func testTextGenerationConfig_DefaultInitialization() {
        let config = TextGenerationConfig()

        XCTAssertEqual(config.temperature, 0.7)
        XCTAssertEqual(config.maxTokens, 2048)
        XCTAssertEqual(config.topP, 1.0)
        XCTAssertEqual(config.frequencyPenalty, 0.0)
        XCTAssertEqual(config.presencePenalty, 0.0)
        XCTAssertNil(config.systemPrompt)
        XCTAssertNil(config.stopSequences)
    }

    func testTextGenerationConfig_CustomInitialization() {
        let config = TextGenerationConfig(
            temperature: 0.5,
            maxTokens: 1000,
            topP: 0.9,
            frequencyPenalty: 0.5,
            presencePenalty: 0.5,
            systemPrompt: "You are a helpful assistant",
            stopSequences: ["STOP"]
        )

        XCTAssertEqual(config.temperature, 0.5)
        XCTAssertEqual(config.maxTokens, 1000)
        XCTAssertEqual(config.topP, 0.9)
        XCTAssertEqual(config.frequencyPenalty, 0.5)
        XCTAssertEqual(config.presencePenalty, 0.5)
        XCTAssertEqual(config.systemPrompt, "You are a helpful assistant")
        XCTAssertEqual(config.stopSequences, ["STOP"])
    }

    func testTextGenerationConfig_DefaultPreset() {
        let config = TextGenerationConfig.default

        XCTAssertEqual(config.temperature, 0.7)
        XCTAssertEqual(config.maxTokens, 2048)
    }

    func testTextGenerationConfig_ConservativePreset() {
        let config = TextGenerationConfig.conservative

        XCTAssertEqual(config.temperature, 0.3)
        XCTAssertEqual(config.maxTokens, 1024)
    }

    func testTextGenerationConfig_CreativePreset() {
        let config = TextGenerationConfig.creative

        XCTAssertEqual(config.temperature, 1.2)
        XCTAssertEqual(config.maxTokens, 4096)
    }

    func testTextGenerationConfig_Codable() throws {
        let original = TextGenerationConfig(
            temperature: 0.8,
            maxTokens: 500,
            systemPrompt: "Test"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TextGenerationConfig.self, from: encoded)

        XCTAssertEqual(decoded.temperature, original.temperature)
        XCTAssertEqual(decoded.maxTokens, original.maxTokens)
        XCTAssertEqual(decoded.systemPrompt, original.systemPrompt)
    }

    // MARK: - GeneratedTextRecord Tests

    func testGeneratedTextRecord_Initialization() {
        let record = GeneratedTextRecord(
            providerId: "openai",
            requestorID: "openai.text.gpt4",
            text: "Test content",
            wordCount: 2,
            characterCount: 12,
            languageCode: "en",
            modelIdentifier: "gpt-4"
        )

        XCTAssertNotNil(record.id)
        XCTAssertEqual(record.providerId, "openai")
        XCTAssertEqual(record.requestorID, "openai.text.gpt4")
        XCTAssertEqual(record.text, "Test content")
        XCTAssertEqual(record.wordCount, 2)
        XCTAssertEqual(record.characterCount, 12)
        XCTAssertEqual(record.languageCode, "en")
        XCTAssertEqual(record.modelIdentifier, "gpt-4")
    }

    func testGeneratedTextRecord_ConvenienceInitializer() {
        let textData = GeneratedTextData(
            text: "Test content",
            model: "gpt-4",
            languageCode: "en",
            tokenCount: 5
        )

        let record = GeneratedTextRecord(
            providerId: "openai",
            requestorID: "openai.text.gpt4",
            data: textData,
            prompt: "Generate text"
        )

        XCTAssertEqual(record.text, "Test content")
        XCTAssertEqual(record.wordCount, textData.wordCount)
        XCTAssertEqual(record.characterCount, textData.characterCount)
        XCTAssertEqual(record.modelIdentifier, "gpt-4")
        XCTAssertEqual(record.prompt, "Generate text")
    }

    func testGeneratedTextRecord_ConvenienceInitializerWithFileReference() {
        let textData = GeneratedTextData(
            text: "Large text content",
            model: "gpt-4"
        )

        let fileRef = TypedDataFileReference(
            requestID: UUID(),
            fileName: "text.txt",
            fileSize: 1000,
            mimeType: "text/plain"
        )

        let record = GeneratedTextRecord(
            providerId: "openai",
            requestorID: "openai.text.gpt4",
            data: textData,
            prompt: "Generate text",
            fileReference: fileRef
        )

        // When file reference exists, text should not be stored in-memory
        XCTAssertNil(record.text)
        XCTAssertNotNil(record.fileReference)
        XCTAssertTrue(record.isFileStored)
    }

    func testGeneratedTextRecord_IsFileStored() {
        let recordInMemory = GeneratedTextRecord(
            providerId: "openai",
            requestorID: "openai.text.gpt4",
            text: "Test",
            wordCount: 1,
            characterCount: 4
        )

        XCTAssertFalse(recordInMemory.isFileStored)

        let fileRef = TypedDataFileReference(
            requestID: UUID(),
            fileName: "text.txt",
            fileSize: 100,
            mimeType: "text/plain"
        )

        let recordInFile = GeneratedTextRecord(
            providerId: "openai",
            requestorID: "openai.text.gpt4",
            text: nil,
            wordCount: 1,
            characterCount: 4,
            fileReference: fileRef
        )

        XCTAssertTrue(recordInFile.isFileStored)
    }

    func testGeneratedTextRecord_Touch() async throws {
        let record = GeneratedTextRecord(
            providerId: "openai",
            requestorID: "openai.text.gpt4",
            text: "Test",
            wordCount: 1,
            characterCount: 4
        )

        let originalModifiedAt = record.modifiedAt

        // Wait a moment
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds

        record.touch()

        XCTAssertGreaterThan(record.modifiedAt, originalModifiedAt)
    }

    func testGeneratedTextRecord_GetText_InMemory() throws {
        let record = GeneratedTextRecord(
            providerId: "openai",
            requestorID: "openai.text.gpt4",
            text: "Test content",
            wordCount: 2,
            characterCount: 12
        )

        let text = try record.getText()
        XCTAssertEqual(text, "Test content")
    }

    func testGeneratedTextRecord_GetText_NoTextAndNoFile() {
        let record = GeneratedTextRecord(
            providerId: "openai",
            requestorID: "openai.text.gpt4",
            text: nil,
            wordCount: 0,
            characterCount: 0
        )

        XCTAssertThrowsError(try record.getText()) { error in
            guard let typedError = error as? TypedDataError,
                  case .fileOperationFailed = typedError else {
                XCTFail("Expected fileOperationFailed error")
                return
            }
        }
    }

    func testGeneratedTextRecord_Description() {
        let record = GeneratedTextRecord(
            providerId: "openai",
            requestorID: "openai.text.gpt4",
            text: "Test",
            wordCount: 10,
            characterCount: 50
        )

        let description = record.description
        XCTAssertTrue(description.contains("GeneratedTextRecord"))
        XCTAssertTrue(description.contains("openai"))
        XCTAssertTrue(description.contains("10 words"))
        XCTAssertTrue(description.contains("memory"))
    }

    // MARK: - OpenAITextRequestor Tests

    func testOpenAITextRequestor_Initialization() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAITextRequestor(provider: provider, model: .gpt4)

        XCTAssertEqual(requestor.requestorID, "openai.text.gpt-4")
        XCTAssertEqual(requestor.displayName, "OpenAI GPT-4")
        XCTAssertEqual(requestor.providerID, "openai")
        XCTAssertEqual(requestor.category, .text)
        XCTAssertEqual(requestor.outputFileType.mimeType, "text/plain")
    }

    func testOpenAITextRequestor_DefaultConfiguration() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAITextRequestor(provider: provider, model: .gpt4)

        let config = requestor.defaultConfiguration()

        XCTAssertEqual(config.temperature, 0.7)
        XCTAssertEqual(config.maxTokens, 2048)
    }

    func testOpenAITextRequestor_ValidateConfiguration_Valid() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAITextRequestor(provider: provider, model: .gpt4)

        let config = TextGenerationConfig(
            temperature: 0.7,
            maxTokens: 1000
        )

        XCTAssertNoThrow(try requestor.validateConfiguration(config))
    }

    func testOpenAITextRequestor_ValidateConfiguration_InvalidTemperature() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAITextRequestor(provider: provider, model: .gpt4)

        let config = TextGenerationConfig(
            temperature: 3.0, // Invalid: > 2
            maxTokens: 1000
        )

        XCTAssertThrowsError(try requestor.validateConfiguration(config)) { error in
            guard let serviceError = error as? AIServiceError,
                  case .configurationError = serviceError else {
                XCTFail("Expected configurationError")
                return
            }
        }
    }

    func testOpenAITextRequestor_ValidateConfiguration_InvalidMaxTokens() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAITextRequestor(provider: provider, model: .gpt4)

        let config = TextGenerationConfig(
            temperature: 0.7,
            maxTokens: 10000 // Invalid: > 4096
        )

        XCTAssertThrowsError(try requestor.validateConfiguration(config)) { error in
            guard let serviceError = error as? AIServiceError,
                  case .configurationError = serviceError else {
                XCTFail("Expected configurationError")
                return
            }
        }
    }

    func testOpenAITextRequestor_GPTModelDisplayNames() {
        XCTAssertEqual(OpenAITextRequestor.GPTModel.gpt4.displayName, "GPT-4")
        XCTAssertEqual(OpenAITextRequestor.GPTModel.gpt4Turbo.displayName, "GPT-4 Turbo")
        XCTAssertEqual(OpenAITextRequestor.GPTModel.gpt35Turbo.displayName, "GPT-3.5 Turbo")
    }

    // MARK: - AnthropicTextRequestor Tests

    func testAnthropicTextRequestor_Initialization() {
        let provider = AnthropicProvider.shared()
        let requestor = AnthropicTextRequestor(provider: provider, model: .claude3Sonnet)

        XCTAssertEqual(requestor.requestorID, "anthropic.text.claude-3-sonnet-20240229")
        XCTAssertEqual(requestor.displayName, "Anthropic Claude 3 Sonnet")
        XCTAssertEqual(requestor.providerID, "anthropic")
        XCTAssertEqual(requestor.category, .text)
    }

    func testAnthropicTextRequestor_DefaultConfiguration() {
        let provider = AnthropicProvider.shared()
        let requestor = AnthropicTextRequestor(provider: provider, model: .claude3Sonnet)

        let config = requestor.defaultConfiguration()

        XCTAssertEqual(config.temperature, 0.7)
        XCTAssertEqual(config.maxTokens, 2048)
    }

    func testAnthropicTextRequestor_ValidateConfiguration_InvalidTemperature() {
        let provider = AnthropicProvider.shared()
        let requestor = AnthropicTextRequestor(provider: provider, model: .claude3Sonnet)

        let config = TextGenerationConfig(
            temperature: 2.0, // Invalid for Claude: > 1
            maxTokens: 1000
        )

        XCTAssertThrowsError(try requestor.validateConfiguration(config)) { error in
            guard let serviceError = error as? AIServiceError,
                  case .configurationError = serviceError else {
                XCTFail("Expected configurationError")
                return
            }
        }
    }

    func testAnthropicTextRequestor_ClaudeModelDisplayNames() {
        XCTAssertEqual(AnthropicTextRequestor.ClaudeModel.claude3Opus.displayName, "Claude 3 Opus")
        XCTAssertEqual(AnthropicTextRequestor.ClaudeModel.claude3Sonnet.displayName, "Claude 3 Sonnet")
        XCTAssertEqual(AnthropicTextRequestor.ClaudeModel.claude3Haiku.displayName, "Claude 3 Haiku")
    }

    // MARK: - Provider Integration Tests

    func testOpenAIProvider_AvailableRequestors() {
        let provider = OpenAIProvider.shared()
        let requestors = provider.availableRequestors()

        // OpenAI now provides 3 text + 2 image + 3 embedding requestors = 8 total
        XCTAssertEqual(requestors.count, 8)

        // Count by category
        let textRequestors = requestors.filter { $0.category == .text }
        let imageRequestors = requestors.filter { $0.category == .image }
        let embeddingRequestors = requestors.filter { $0.category == .embedding }

        XCTAssertEqual(textRequestors.count, 3)
        XCTAssertEqual(imageRequestors.count, 2)
        XCTAssertEqual(embeddingRequestors.count, 3)

        XCTAssertTrue(requestors.allSatisfy { $0.providerID == "openai" })
    }

    func testAnthropicProvider_AvailableRequestors() {
        let provider = AnthropicProvider.shared()
        let requestors = provider.availableRequestors()

        XCTAssertEqual(requestors.count, 3)
        XCTAssertTrue(requestors.allSatisfy { $0.category == .text })
        XCTAssertTrue(requestors.allSatisfy { $0.providerID == "anthropic" })
    }
}
