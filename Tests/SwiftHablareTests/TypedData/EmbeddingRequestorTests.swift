//
//  EmbeddingRequestorTests.swift
//  SwiftHablareTests
//
//  Phase 6E: Tests for embedding requestors
//

import XCTest
@testable import SwiftHablare

@available(macOS 15.0, iOS 17.0, *)
final class EmbeddingRequestorTests: XCTestCase {

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

    // MARK: - GeneratedEmbeddingData Tests

    func testGeneratedEmbeddingData_Initialization() {
        let embedding: [Float] = [0.1, 0.2, 0.3, 0.4]
        let data = GeneratedEmbeddingData(
            embedding: embedding,
            dimensions: 4,
            model: "text-embedding-3-small",
            inputText: "Test input",
            tokenCount: 10,
            index: 0
        )

        XCTAssertEqual(data.embedding, embedding)
        XCTAssertEqual(data.dimensions, 4)
        XCTAssertEqual(data.model, "text-embedding-3-small")
        XCTAssertEqual(data.inputText, "Test input")
        XCTAssertEqual(data.tokenCount, 10)
        XCTAssertEqual(data.index, 0)
        XCTAssertEqual(data.dataSize, 16) // 4 floats * 4 bytes
    }

    func testGeneratedEmbeddingData_NilEmbedding() {
        let data = GeneratedEmbeddingData(
            embedding: nil,
            dimensions: 1536,
            model: "text-embedding-3-small"
        )

        XCTAssertNil(data.embedding)
        XCTAssertEqual(data.dataSize, 0)
    }

    func testGeneratedEmbeddingData_InputTextTruncation() {
        let longText = String(repeating: "A", count: 1500)
        let data = GeneratedEmbeddingData(
            embedding: [0.1],
            dimensions: 1,
            model: "test",
            inputText: longText
        )

        XCTAssertNotNil(data.inputText)
        XCTAssertEqual(data.inputText?.count, 1003) // 1000 chars + "..."
        XCTAssertTrue(data.inputText!.hasSuffix("..."))
    }

    func testGeneratedEmbeddingData_PreferredFormat() {
        let data = GeneratedEmbeddingData(
            embedding: [0.1],
            dimensions: 1,
            model: "test"
        )

        XCTAssertEqual(data.preferredFormat, .binary)
    }

    func testGeneratedEmbeddingData_BinarySerialization() throws {
        let embedding: [Float] = [0.1, 0.2, 0.3, 0.4]
        let data = GeneratedEmbeddingData(
            embedding: embedding,
            dimensions: 4,
            model: "test-model",
            inputText: "Test",
            tokenCount: 5
        )

        let serialized = try data.serialize()
        XCTAssertGreaterThan(serialized.count, 0)

        let deserialized = try GeneratedEmbeddingData.deserialize(
            from: serialized,
            format: .binary
        )

        XCTAssertEqual(deserialized.embedding?.count, embedding.count)
        XCTAssertEqual(deserialized.dimensions, 4)
        XCTAssertEqual(deserialized.model, "test-model")
        XCTAssertEqual(deserialized.inputText, "Test")
        XCTAssertEqual(deserialized.tokenCount, 5)
    }

    func testGeneratedEmbeddingData_SerializationWithoutOptionals() throws {
        let embedding: [Float] = [1.0, 2.0]
        let data = GeneratedEmbeddingData(
            embedding: embedding,
            dimensions: 2,
            model: "test"
        )

        let serialized = try data.serialize()
        let deserialized = try GeneratedEmbeddingData.deserialize(
            from: serialized,
            format: .binary
        )

        XCTAssertEqual(deserialized.embedding?.count, 2)
        XCTAssertNil(deserialized.inputText)
        XCTAssertNil(deserialized.tokenCount)
    }

    func testGeneratedEmbeddingData_Codable() throws {
        let original = GeneratedEmbeddingData(
            embedding: [0.1, 0.2],
            dimensions: 2,
            model: "test",
            inputText: "Test",
            tokenCount: 5
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GeneratedEmbeddingData.self, from: encoded)

        XCTAssertEqual(decoded.embedding?.count, original.embedding?.count)
        XCTAssertEqual(decoded.dimensions, original.dimensions)
        XCTAssertEqual(decoded.model, original.model)
    }

    // MARK: - EmbeddingConfig Tests

    func testEmbeddingConfig_DefaultInitialization() {
        let config = EmbeddingConfig()

        XCTAssertEqual(config.model, .textEmbedding3Small)
        XCTAssertNil(config.dimensions)
        XCTAssertEqual(config.encodingFormat, .float)
        XCTAssertNil(config.user)
    }

    func testEmbeddingConfig_CustomInitialization() {
        let config = EmbeddingConfig(
            model: .textEmbedding3Large,
            dimensions: 1024,
            encodingFormat: .base64,
            user: "user123"
        )

        XCTAssertEqual(config.model, .textEmbedding3Large)
        XCTAssertEqual(config.dimensions, 1024)
        XCTAssertEqual(config.encodingFormat, .base64)
        XCTAssertEqual(config.user, "user123")
    }

    func testEmbeddingConfig_Presets() {
        XCTAssertEqual(EmbeddingConfig.default.model, .textEmbedding3Small)
        XCTAssertEqual(EmbeddingConfig.highQuality.model, .textEmbedding3Large)
        XCTAssertEqual(EmbeddingConfig.performance.model, .textEmbedding3Small)
        XCTAssertEqual(EmbeddingConfig.performance.dimensions, 512)
        XCTAssertEqual(EmbeddingConfig.legacy.model, .textEmbeddingAda002)
    }

    func testEmbeddingConfig_ModelProperties() {
        XCTAssertEqual(
            EmbeddingConfig.Model.textEmbedding3Small.displayName,
            "Text Embedding 3 Small"
        )
        XCTAssertEqual(
            EmbeddingConfig.Model.textEmbedding3Large.displayName,
            "Text Embedding 3 Large"
        )
        XCTAssertEqual(
            EmbeddingConfig.Model.textEmbeddingAda002.displayName,
            "Ada 002 (Legacy)"
        )

        XCTAssertEqual(EmbeddingConfig.Model.textEmbedding3Small.defaultDimensions, 1536)
        XCTAssertEqual(EmbeddingConfig.Model.textEmbedding3Large.defaultDimensions, 3072)
        XCTAssertEqual(EmbeddingConfig.Model.textEmbeddingAda002.defaultDimensions, 1536)
    }

    func testEmbeddingConfig_ModelCosts() {
        XCTAssertEqual(EmbeddingConfig.Model.textEmbedding3Small.costPer1MTokens, 0.02)
        XCTAssertEqual(EmbeddingConfig.Model.textEmbedding3Large.costPer1MTokens, 0.13)
        XCTAssertEqual(EmbeddingConfig.Model.textEmbeddingAda002.costPer1MTokens, 0.10)
    }

    func testEmbeddingConfig_Codable() throws {
        let original = EmbeddingConfig(
            model: .textEmbedding3Large,
            dimensions: 1024
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EmbeddingConfig.self, from: encoded)

        XCTAssertEqual(decoded.model, original.model)
        XCTAssertEqual(decoded.dimensions, original.dimensions)
    }

    // MARK: - GeneratedEmbeddingRecord Tests

    func testGeneratedEmbeddingRecord_Initialization() {
        let embeddingData = Data([0x00, 0x00, 0x80, 0x3F]) // Float: 1.0 in little-endian
        let record = GeneratedEmbeddingRecord(
            providerId: "openai",
            requestorID: "openai.embedding.text-embedding-3-small",
            embeddingData: embeddingData,
            dimensions: 1536,
            inputText: "Test input",
            tokenCount: 10,
            modelIdentifier: "text-embedding-3-small"
        )

        XCTAssertNotNil(record.id)
        XCTAssertEqual(record.providerId, "openai")
        XCTAssertEqual(record.requestorID, "openai.embedding.text-embedding-3-small")
        XCTAssertEqual(record.embeddingData, embeddingData)
        XCTAssertEqual(record.dimensions, 1536)
        XCTAssertEqual(record.inputText, "Test input")
        XCTAssertEqual(record.tokenCount, 10)
        XCTAssertEqual(record.modelIdentifier, "text-embedding-3-small")
    }

    func testGeneratedEmbeddingRecord_ConvenienceInitializer() {
        let embedding: [Float] = [0.1, 0.2, 0.3]
        let embeddingData = GeneratedEmbeddingData(
            embedding: embedding,
            dimensions: 3,
            model: "text-embedding-3-small",
            inputText: "Test"
        )

        let record = GeneratedEmbeddingRecord(
            providerId: "openai",
            requestorID: "openai.embedding.text-embedding-3-small",
            data: embeddingData,
            prompt: "Test prompt"
        )

        XCTAssertNotNil(record.embeddingData)
        XCTAssertEqual(record.dimensions, 3)
        XCTAssertEqual(record.inputText, "Test")
        XCTAssertEqual(record.prompt, "Test prompt")
    }

    func testGeneratedEmbeddingRecord_ConvenienceInitializerWithFileReference() {
        let embeddingData = GeneratedEmbeddingData(
            embedding: [0.1, 0.2],
            dimensions: 2,
            model: "text-embedding-3-small"
        )

        let fileRef = TypedDataFileReference(
            requestID: UUID(),
            fileName: "embedding.bin",
            fileSize: 8,
            mimeType: "application/octet-stream"
        )

        let record = GeneratedEmbeddingRecord(
            providerId: "openai",
            requestorID: "openai.embedding.text-embedding-3-small",
            data: embeddingData,
            prompt: "Test",
            fileReference: fileRef
        )

        // When file reference exists, embedding data should not be stored in-memory
        XCTAssertNil(record.embeddingData)
        XCTAssertNotNil(record.fileReference)
        XCTAssertTrue(record.isFileStored)
    }

    func testGeneratedEmbeddingRecord_IsFileStored() {
        let recordInMemory = GeneratedEmbeddingRecord(
            providerId: "openai",
            requestorID: "openai.embedding.test",
            embeddingData: Data([0x01]),
            dimensions: 1,
            inputText: nil,
            tokenCount: nil,
            modelIdentifier: "test"
        )

        XCTAssertFalse(recordInMemory.isFileStored)

        let fileRef = TypedDataFileReference(
            requestID: UUID(),
            fileName: "embedding.bin",
            fileSize: 100,
            mimeType: "application/octet-stream"
        )

        let recordInFile = GeneratedEmbeddingRecord(
            providerId: "openai",
            requestorID: "openai.embedding.test",
            embeddingData: nil,
            dimensions: 1,
            inputText: nil,
            tokenCount: nil,
            modelIdentifier: "test",
            fileReference: fileRef
        )

        XCTAssertTrue(recordInFile.isFileStored)
    }

    func testGeneratedEmbeddingRecord_DataSize() {
        let embeddingData = Data(repeating: 0, count: 100)
        let record = GeneratedEmbeddingRecord(
            providerId: "openai",
            requestorID: "openai.embedding.test",
            embeddingData: embeddingData,
            dimensions: 25,
            inputText: nil,
            tokenCount: nil,
            modelIdentifier: "test"
        )

        XCTAssertEqual(record.dataSize, 100)
    }

    func testGeneratedEmbeddingRecord_Touch() async throws {
        let record = GeneratedEmbeddingRecord(
            providerId: "openai",
            requestorID: "openai.embedding.test",
            embeddingData: Data([0x01]),
            dimensions: 1,
            inputText: nil,
            tokenCount: nil,
            modelIdentifier: "test"
        )

        let originalModifiedAt = record.modifiedAt

        // Wait a moment
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds

        record.touch()

        XCTAssertGreaterThan(record.modifiedAt, originalModifiedAt)
    }

    func testGeneratedEmbeddingRecord_GetEmbedding_InMemory() throws {
        let embedding: [Float] = [1.0, 2.0, 3.0]
        let embeddingData = embedding.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }

        let record = GeneratedEmbeddingRecord(
            providerId: "openai",
            requestorID: "openai.embedding.test",
            embeddingData: embeddingData,
            dimensions: 3,
            inputText: nil,
            tokenCount: nil,
            modelIdentifier: "test"
        )

        let retrieved = try record.getEmbedding()
        XCTAssertEqual(retrieved.count, 3)
        XCTAssertEqual(retrieved[0], 1.0, accuracy: 0.001)
        XCTAssertEqual(retrieved[1], 2.0, accuracy: 0.001)
        XCTAssertEqual(retrieved[2], 3.0, accuracy: 0.001)
    }

    func testGeneratedEmbeddingRecord_GetEmbedding_NoDataAndNoFile() {
        let record = GeneratedEmbeddingRecord(
            providerId: "openai",
            requestorID: "openai.embedding.test",
            embeddingData: nil,
            dimensions: 1,
            inputText: nil,
            tokenCount: nil,
            modelIdentifier: "test"
        )

        XCTAssertThrowsError(try record.getEmbedding()) { error in
            guard let typedError = error as? TypedDataError,
                  case .fileOperationFailed = typedError else {
                XCTFail("Expected fileOperationFailed error")
                return
            }
        }
    }

    func testGeneratedEmbeddingRecord_CustomDescription() {
        let record = GeneratedEmbeddingRecord(
            providerId: "openai",
            requestorID: "openai.embedding.test",
            embeddingData: Data([0x01]),
            dimensions: 1536,
            inputText: "Test input text",
            tokenCount: nil,
            modelIdentifier: "test"
        )

        let description = record.customDescription
        XCTAssertTrue(description.contains("GeneratedEmbeddingRecord"))
        XCTAssertTrue(description.contains("openai"))
        XCTAssertTrue(description.contains("1536"))
        XCTAssertTrue(description.contains("Test input"))
    }

    // MARK: - OpenAIEmbeddingRequestor Tests

    func testOpenAIEmbeddingRequestor_Initialization_Small() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAIEmbeddingRequestor(
            provider: provider,
            model: .textEmbedding3Small
        )

        XCTAssertEqual(requestor.requestorID, "openai.embedding.text-embedding-3-small")
        XCTAssertEqual(requestor.displayName, "OpenAI Text Embedding 3 Small")
        XCTAssertEqual(requestor.providerID, "openai")
        XCTAssertEqual(requestor.category, .embedding)
        XCTAssertEqual(requestor.outputFileType.fileExtension, "bin")
        XCTAssertEqual(requestor.outputFileType.mimeType, "application/octet-stream")
    }

    func testOpenAIEmbeddingRequestor_Initialization_Large() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAIEmbeddingRequestor(
            provider: provider,
            model: .textEmbedding3Large
        )

        XCTAssertEqual(requestor.requestorID, "openai.embedding.text-embedding-3-large")
        XCTAssertEqual(requestor.displayName, "OpenAI Text Embedding 3 Large")
    }

    func testOpenAIEmbeddingRequestor_Initialization_Ada() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAIEmbeddingRequestor(
            provider: provider,
            model: .textEmbeddingAda002
        )

        XCTAssertEqual(requestor.requestorID, "openai.embedding.text-embedding-ada-002")
        XCTAssertEqual(requestor.displayName, "OpenAI Ada 002 (Legacy)")
    }

    func testOpenAIEmbeddingRequestor_DefaultConfiguration() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAIEmbeddingRequestor(provider: provider)

        let config = requestor.defaultConfiguration()

        XCTAssertEqual(config.model, .textEmbedding3Small)
        XCTAssertNil(config.dimensions)
        XCTAssertEqual(config.encodingFormat, .float)
    }

    func testOpenAIEmbeddingRequestor_ValidateConfiguration_Valid() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAIEmbeddingRequestor(
            provider: provider,
            model: .textEmbedding3Small
        )

        let config = EmbeddingConfig(model: .textEmbedding3Small)

        XCTAssertNoThrow(try requestor.validateConfiguration(config))
    }

    func testOpenAIEmbeddingRequestor_ValidateConfiguration_ModelMismatch() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAIEmbeddingRequestor(
            provider: provider,
            model: .textEmbedding3Small
        )

        let config = EmbeddingConfig(model: .textEmbedding3Large)

        XCTAssertThrowsError(try requestor.validateConfiguration(config)) { error in
            guard let serviceError = error as? AIServiceError,
                  case .configurationError = serviceError else {
                XCTFail("Expected configurationError")
                return
            }
        }
    }

    func testOpenAIEmbeddingRequestor_ValidateConfiguration_CustomDimensions() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAIEmbeddingRequestor(
            provider: provider,
            model: .textEmbedding3Small
        )

        let config = EmbeddingConfig(
            model: .textEmbedding3Small,
            dimensions: 512
        )

        XCTAssertNoThrow(try requestor.validateConfiguration(config))
    }

    func testOpenAIEmbeddingRequestor_ValidateConfiguration_InvalidDimensions() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAIEmbeddingRequestor(
            provider: provider,
            model: .textEmbedding3Small
        )

        let config = EmbeddingConfig(
            model: .textEmbedding3Small,
            dimensions: 10000 // Too large
        )

        XCTAssertThrowsError(try requestor.validateConfiguration(config)) { error in
            guard let serviceError = error as? AIServiceError,
                  case .configurationError = serviceError else {
                XCTFail("Expected configurationError")
                return
            }
        }
    }

    func testOpenAIEmbeddingRequestor_ValidateConfiguration_DimensionsTooSmall() {
        let provider = OpenAIProvider.shared()

        // Test text-embedding-3-small (min: 512)
        let smallRequestor = OpenAIEmbeddingRequestor(
            provider: provider,
            model: .textEmbedding3Small
        )

        let configTooSmall = EmbeddingConfig(
            model: .textEmbedding3Small,
            dimensions: 256 // Below minimum of 512
        )

        XCTAssertThrowsError(try smallRequestor.validateConfiguration(configTooSmall)) { error in
            guard let serviceError = error as? AIServiceError,
                  case .configurationError(let message) = serviceError else {
                XCTFail("Expected configurationError")
                return
            }
            XCTAssertTrue(message.contains("512"), "Error should mention minimum of 512")
            XCTAssertTrue(message.contains("1536"), "Error should mention maximum of 1536")
        }

        // Test text-embedding-3-large (min: 256)
        let largeRequestor = OpenAIEmbeddingRequestor(
            provider: provider,
            model: .textEmbedding3Large
        )

        let configTooSmallForLarge = EmbeddingConfig(
            model: .textEmbedding3Large,
            dimensions: 100 // Below minimum of 256
        )

        XCTAssertThrowsError(try largeRequestor.validateConfiguration(configTooSmallForLarge)) { error in
            guard let serviceError = error as? AIServiceError,
                  case .configurationError(let message) = serviceError else {
                XCTFail("Expected configurationError")
                return
            }
            XCTAssertTrue(message.contains("256"), "Error should mention minimum of 256")
            XCTAssertTrue(message.contains("3072"), "Error should mention maximum of 3072")
        }
    }

    func testOpenAIEmbeddingRequestor_ValidateConfiguration_ValidMinimumDimensions() {
        let provider = OpenAIProvider.shared()

        // Test text-embedding-3-small at minimum (512)
        let smallRequestor = OpenAIEmbeddingRequestor(
            provider: provider,
            model: .textEmbedding3Small
        )

        let configAtMin = EmbeddingConfig(
            model: .textEmbedding3Small,
            dimensions: 512 // Exactly at minimum
        )

        XCTAssertNoThrow(try smallRequestor.validateConfiguration(configAtMin))

        // Test text-embedding-3-large at minimum (256)
        let largeRequestor = OpenAIEmbeddingRequestor(
            provider: provider,
            model: .textEmbedding3Large
        )

        let configAtMinLarge = EmbeddingConfig(
            model: .textEmbedding3Large,
            dimensions: 256 // Exactly at minimum
        )

        XCTAssertNoThrow(try largeRequestor.validateConfiguration(configAtMinLarge))
    }

    func testOpenAIEmbeddingRequestor_ValidateConfiguration_Ada002NoDimensions() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAIEmbeddingRequestor(
            provider: provider,
            model: .textEmbeddingAda002
        )

        let config = EmbeddingConfig(
            model: .textEmbeddingAda002,
            dimensions: 512 // Not allowed for Ada
        )

        XCTAssertThrowsError(try requestor.validateConfiguration(config)) { error in
            guard let serviceError = error as? AIServiceError,
                  case .configurationError = serviceError else {
                XCTFail("Expected configurationError")
                return
            }
        }
    }

    // MARK: - Storage Threshold Tests

    func testOpenAIEmbeddingRequestor_SmallEmbeddingStoredInMemory() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAIEmbeddingRequestor(provider: provider)

        // Small embedding (1536 dimensions = 6KB)
        let vectorSize = Int64(1536 * MemoryLayout<Float>.size)
        let shouldStoreAsFile = requestor.outputFileType.shouldStoreAsFile(estimatedSize: vectorSize)

        XCTAssertFalse(shouldStoreAsFile, "Small embeddings (<100KB) should be stored in-memory")
    }

    func testOpenAIEmbeddingRequestor_LargeEmbeddingStoredAsFile() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAIEmbeddingRequestor(provider: provider)

        // Large embedding (100KB threshold = 25,600 dimensions)
        let vectorSize = Int64(25_600 * MemoryLayout<Float>.size)
        let shouldStoreAsFile = requestor.outputFileType.shouldStoreAsFile(estimatedSize: vectorSize)

        XCTAssertTrue(shouldStoreAsFile, "Large embeddings (≥100KB) should be stored as file")
    }

    func testOpenAIEmbeddingRequestor_ThresholdBoundary() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAIEmbeddingRequestor(provider: provider)

        // At threshold (100KB)
        let atThreshold = Int64(100_000)
        let shouldStoreAtThreshold = requestor.outputFileType.shouldStoreAsFile(estimatedSize: atThreshold)
        XCTAssertTrue(shouldStoreAtThreshold, "Embedding at threshold (100KB) should be stored as file")

        // Just below threshold
        let belowThreshold = Int64(99_999)
        let shouldStoreBelowThreshold = requestor.outputFileType.shouldStoreAsFile(estimatedSize: belowThreshold)
        XCTAssertFalse(shouldStoreBelowThreshold, "Embedding below threshold should be in-memory")
    }

    // MARK: - Provider Integration Tests

    func testOpenAIProvider_AvailableRequestors() {
        let provider = OpenAIProvider.shared()
        let requestors = provider.availableRequestors()

        // Should have 3 text + 2 image + 3 embedding = 8 total
        XCTAssertEqual(requestors.count, 8)

        // Count by category
        let textRequestors = requestors.filter { $0.category == .text }
        let imageRequestors = requestors.filter { $0.category == .image }
        let embeddingRequestors = requestors.filter { $0.category == .embedding }

        XCTAssertEqual(textRequestors.count, 3)
        XCTAssertEqual(imageRequestors.count, 2)
        XCTAssertEqual(embeddingRequestors.count, 3)

        // Check embedding requestor IDs
        let embeddingIDs = embeddingRequestors.map { $0.requestorID }.sorted()
        XCTAssertTrue(embeddingIDs.contains("openai.embedding.text-embedding-3-small"))
        XCTAssertTrue(embeddingIDs.contains("openai.embedding.text-embedding-3-large"))
        XCTAssertTrue(embeddingIDs.contains("openai.embedding.text-embedding-ada-002"))

        // All should be from openai provider
        XCTAssertTrue(requestors.allSatisfy { $0.providerID == "openai" })
    }
}
