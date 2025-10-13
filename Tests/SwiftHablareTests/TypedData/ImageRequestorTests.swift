//
//  ImageRequestorTests.swift
//  SwiftHablareTests
//
//  Phase 6D: Tests for image requestors
//

import XCTest
@testable import SwiftHablare

@available(macOS 15.0, iOS 17.0, *)
final class ImageRequestorTests: XCTestCase {

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

    // MARK: - GeneratedImageData Tests

    func testGeneratedImageData_Initialization() {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header
        let data = GeneratedImageData(
            imageData: imageData,
            format: .png,
            width: 1024,
            height: 1024,
            model: "dall-e-3",
            revisedPrompt: "A revised prompt"
        )

        XCTAssertEqual(data.imageData, imageData)
        XCTAssertEqual(data.format, .png)
        XCTAssertEqual(data.width, 1024)
        XCTAssertEqual(data.height, 1024)
        XCTAssertEqual(data.model, "dall-e-3")
        XCTAssertEqual(data.revisedPrompt, "A revised prompt")
        XCTAssertEqual(data.fileSize, 4)
    }

    func testGeneratedImageData_NilImageData() {
        let data = GeneratedImageData(
            imageData: nil,
            format: .png,
            width: 1024,
            height: 1024,
            model: "dall-e-3"
        )

        XCTAssertNil(data.imageData)
        XCTAssertEqual(data.fileSize, 0)
    }

    func testGeneratedImageData_ImageFormatMimeTypes() {
        XCTAssertEqual(GeneratedImageData.ImageFormat.png.mimeType, "image/png")
        XCTAssertEqual(GeneratedImageData.ImageFormat.jpeg.mimeType, "image/jpeg")
        XCTAssertEqual(GeneratedImageData.ImageFormat.jpg.mimeType, "image/jpeg")
        XCTAssertEqual(GeneratedImageData.ImageFormat.webp.mimeType, "image/webp")
        XCTAssertEqual(GeneratedImageData.ImageFormat.heic.mimeType, "image/heic")
    }

    func testGeneratedImageData_ImageFormatExtensions() {
        XCTAssertEqual(GeneratedImageData.ImageFormat.png.fileExtension, "png")
        XCTAssertEqual(GeneratedImageData.ImageFormat.jpeg.fileExtension, "jpeg")
        XCTAssertEqual(GeneratedImageData.ImageFormat.jpg.fileExtension, "jpg")
        XCTAssertEqual(GeneratedImageData.ImageFormat.webp.fileExtension, "webp")
        XCTAssertEqual(GeneratedImageData.ImageFormat.heic.fileExtension, "heic")
    }

    func testGeneratedImageData_Codable() throws {
        let original = GeneratedImageData(
            imageData: Data([0x01, 0x02]),
            format: .png,
            width: 1024,
            height: 1024,
            model: "dall-e-3",
            revisedPrompt: "Test prompt"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GeneratedImageData.self, from: encoded)

        XCTAssertEqual(decoded.imageData, original.imageData)
        XCTAssertEqual(decoded.format, original.format)
        XCTAssertEqual(decoded.width, original.width)
        XCTAssertEqual(decoded.height, original.height)
        XCTAssertEqual(decoded.model, original.model)
        XCTAssertEqual(decoded.revisedPrompt, original.revisedPrompt)
    }

    func testGeneratedImageData_PreferredFormat() {
        let data = GeneratedImageData(
            imageData: nil,
            format: .png,
            width: 1024,
            height: 1024,
            model: "dall-e-3"
        )

        XCTAssertEqual(data.preferredFormat, .plist)
    }

    // MARK: - ImageGenerationConfig Tests

    func testImageGenerationConfig_DefaultInitialization() {
        let config = ImageGenerationConfig()

        XCTAssertEqual(config.size, .square1024)
        XCTAssertEqual(config.quality, .standard)
        XCTAssertEqual(config.style, .vivid)
        XCTAssertEqual(config.numberOfImages, 1)
    }

    func testImageGenerationConfig_CustomInitialization() {
        let config = ImageGenerationConfig(
            size: .wide16x9,
            quality: .hd,
            style: .natural,
            numberOfImages: 1
        )

        XCTAssertEqual(config.size, .wide16x9)
        XCTAssertEqual(config.quality, .hd)
        XCTAssertEqual(config.style, .natural)
        XCTAssertEqual(config.numberOfImages, 1)
    }

    func testImageGenerationConfig_DefaultPreset() {
        let config = ImageGenerationConfig.default

        XCTAssertEqual(config.size, .square1024)
        XCTAssertEqual(config.quality, .standard)
        XCTAssertEqual(config.style, .vivid)
        XCTAssertEqual(config.numberOfImages, 1)
    }

    func testImageGenerationConfig_HDPreset() {
        let config = ImageGenerationConfig.hd

        XCTAssertEqual(config.size, .square1024)
        XCTAssertEqual(config.quality, .hd)
        XCTAssertEqual(config.style, .vivid)
    }

    func testImageGenerationConfig_NaturalPreset() {
        let config = ImageGenerationConfig.natural

        XCTAssertEqual(config.size, .square1024)
        XCTAssertEqual(config.quality, .standard)
        XCTAssertEqual(config.style, .natural)
    }

    func testImageGenerationConfig_WidescreenPreset() {
        let config = ImageGenerationConfig.widescreen

        XCTAssertEqual(config.size, .wide16x9)
        XCTAssertEqual(config.quality, .hd)
        XCTAssertEqual(config.style, .vivid)
    }

    func testImageGenerationConfig_PortraitPreset() {
        let config = ImageGenerationConfig.portrait

        XCTAssertEqual(config.size, .portrait9x16)
        XCTAssertEqual(config.quality, .hd)
        XCTAssertEqual(config.style, .vivid)
    }

    func testImageGenerationConfig_StoryboardPreset() {
        let config = ImageGenerationConfig.storyboard

        XCTAssertEqual(config.size, .wide16x9)
        XCTAssertEqual(config.quality, .hd)
        XCTAssertEqual(config.style, .natural)
    }

    func testImageGenerationConfig_ImageSizeDimensions() {
        // Square formats
        XCTAssertEqual(ImageGenerationConfig.ImageSize.square256.width, 256)
        XCTAssertEqual(ImageGenerationConfig.ImageSize.square256.height, 256)

        XCTAssertEqual(ImageGenerationConfig.ImageSize.square512.width, 512)
        XCTAssertEqual(ImageGenerationConfig.ImageSize.square512.height, 512)

        XCTAssertEqual(ImageGenerationConfig.ImageSize.square1024.width, 1024)
        XCTAssertEqual(ImageGenerationConfig.ImageSize.square1024.height, 1024)

        // Widescreen (16:9 approximation)
        XCTAssertEqual(ImageGenerationConfig.ImageSize.wide16x9.width, 1792)
        XCTAssertEqual(ImageGenerationConfig.ImageSize.wide16x9.height, 1024)

        // Portrait (9:16)
        XCTAssertEqual(ImageGenerationConfig.ImageSize.portrait9x16.width, 1024)
        XCTAssertEqual(ImageGenerationConfig.ImageSize.portrait9x16.height, 1792)
    }

    func testImageGenerationConfig_AspectRatios() {
        // Square aspect ratios
        XCTAssertEqual(ImageGenerationConfig.ImageSize.square256.aspectRatio, 1.0)
        XCTAssertEqual(ImageGenerationConfig.ImageSize.square512.aspectRatio, 1.0)
        XCTAssertEqual(ImageGenerationConfig.ImageSize.square1024.aspectRatio, 1.0)

        // Widescreen (1.75:1 ≈ 16:9 which is 1.778:1)
        XCTAssertEqual(ImageGenerationConfig.ImageSize.wide16x9.aspectRatio, 1.75, accuracy: 0.01)

        // Portrait (0.571:1 ≈ 9:16 which is 0.5625:1)
        XCTAssertEqual(ImageGenerationConfig.ImageSize.portrait9x16.aspectRatio, 0.571, accuracy: 0.01)
    }

    func testImageGenerationConfig_AspectRatioDescriptions() {
        XCTAssertEqual(ImageGenerationConfig.ImageSize.square1024.aspectRatioDescription, "1:1 (Square)")
        XCTAssertEqual(ImageGenerationConfig.ImageSize.wide16x9.aspectRatioDescription, "16:9 (Widescreen)")
        XCTAssertEqual(ImageGenerationConfig.ImageSize.portrait9x16.aspectRatioDescription, "9:16 (Portrait)")
    }

    func testImageGenerationConfig_Codable() throws {
        let original = ImageGenerationConfig(
            size: .wide16x9,
            quality: .hd,
            style: .natural,
            numberOfImages: 1
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ImageGenerationConfig.self, from: encoded)

        XCTAssertEqual(decoded.size, original.size)
        XCTAssertEqual(decoded.quality, original.quality)
        XCTAssertEqual(decoded.style, original.style)
        XCTAssertEqual(decoded.numberOfImages, original.numberOfImages)
    }

    // MARK: - GeneratedImageRecord Tests

    func testGeneratedImageRecord_Initialization() {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        let record = GeneratedImageRecord(
            providerId: "openai",
            requestorID: "openai.image.dalle3",
            imageData: imageData,
            format: "png",
            width: 1024,
            height: 1024,
            prompt: "A sunset over mountains",
            revisedPrompt: "A beautiful sunset",
            modelIdentifier: "dall-e-3"
        )

        XCTAssertNotNil(record.id)
        XCTAssertEqual(record.providerId, "openai")
        XCTAssertEqual(record.requestorID, "openai.image.dalle3")
        XCTAssertEqual(record.imageData, imageData)
        XCTAssertEqual(record.format, "png")
        XCTAssertEqual(record.width, 1024)
        XCTAssertEqual(record.height, 1024)
        XCTAssertEqual(record.prompt, "A sunset over mountains")
        XCTAssertEqual(record.revisedPrompt, "A beautiful sunset")
        XCTAssertEqual(record.modelIdentifier, "dall-e-3")
    }

    func testGeneratedImageRecord_ConvenienceInitializer() {
        let imageData = GeneratedImageData(
            imageData: Data([0x01, 0x02]),
            format: .png,
            width: 1024,
            height: 1024,
            model: "dall-e-3",
            revisedPrompt: "Revised prompt"
        )

        let record = GeneratedImageRecord(
            providerId: "openai",
            requestorID: "openai.image.dalle3",
            data: imageData,
            prompt: "Test prompt"
        )

        XCTAssertEqual(record.imageData, imageData.imageData)
        XCTAssertEqual(record.format, "png")
        XCTAssertEqual(record.width, 1024)
        XCTAssertEqual(record.height, 1024)
        XCTAssertEqual(record.prompt, "Test prompt")
        XCTAssertEqual(record.revisedPrompt, "Revised prompt")
        XCTAssertEqual(record.modelIdentifier, "dall-e-3")
    }

    func testGeneratedImageRecord_ConvenienceInitializerWithFileReference() {
        let imageData = GeneratedImageData(
            imageData: Data([0x01, 0x02]),
            format: .png,
            width: 1024,
            height: 1024,
            model: "dall-e-3"
        )

        let fileRef = TypedDataFileReference(
            requestID: UUID(),
            fileName: "image.png",
            fileSize: 50000,
            mimeType: "image/png"
        )

        let record = GeneratedImageRecord(
            providerId: "openai",
            requestorID: "openai.image.dalle3",
            data: imageData,
            prompt: "Test prompt",
            fileReference: fileRef
        )

        // When file reference exists, image data should not be stored in-memory
        XCTAssertNil(record.imageData)
        XCTAssertNotNil(record.fileReference)
        XCTAssertTrue(record.isFileStored)
    }

    func testGeneratedImageRecord_IsFileStored() {
        let recordInMemory = GeneratedImageRecord(
            providerId: "openai",
            requestorID: "openai.image.dalle3",
            imageData: Data([0x01]),
            format: "png",
            width: 1024,
            height: 1024,
            prompt: ""
        )

        XCTAssertFalse(recordInMemory.isFileStored)

        let fileRef = TypedDataFileReference(
            requestID: UUID(),
            fileName: "image.png",
            fileSize: 50000,
            mimeType: "image/png"
        )

        let recordInFile = GeneratedImageRecord(
            providerId: "openai",
            requestorID: "openai.image.dalle3",
            imageData: nil,
            format: "png",
            width: 1024,
            height: 1024,
            prompt: "",
            fileReference: fileRef
        )

        XCTAssertTrue(recordInFile.isFileStored)
    }

    func testGeneratedImageRecord_Touch() async throws {
        let record = GeneratedImageRecord(
            providerId: "openai",
            requestorID: "openai.image.dalle3",
            imageData: Data([0x01]),
            format: "png",
            width: 1024,
            height: 1024,
            prompt: ""
        )

        let originalModifiedAt = record.modifiedAt

        // Wait a moment
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds

        record.touch()

        XCTAssertGreaterThan(record.modifiedAt, originalModifiedAt)
    }

    func testGeneratedImageRecord_GetImageData_InMemory() throws {
        let imageData = Data([0x89, 0x50, 0x4E])
        let record = GeneratedImageRecord(
            providerId: "openai",
            requestorID: "openai.image.dalle3",
            imageData: imageData,
            format: "png",
            width: 1024,
            height: 1024,
            prompt: ""
        )

        let retrievedData = try record.getImageData()
        XCTAssertEqual(retrievedData, imageData)
    }

    func testGeneratedImageRecord_GetImageData_NoDataAndNoFile() {
        let record = GeneratedImageRecord(
            providerId: "openai",
            requestorID: "openai.image.dalle3",
            imageData: nil,
            format: "png",
            width: 1024,
            height: 1024,
            prompt: ""
        )

        XCTAssertThrowsError(try record.getImageData()) { error in
            guard let typedError = error as? TypedDataError,
                  case .fileOperationFailed = typedError else {
                XCTFail("Expected fileOperationFailed error")
                return
            }
        }
    }

    func testGeneratedImageRecord_FileSize() {
        let imageData = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let record = GeneratedImageRecord(
            providerId: "openai",
            requestorID: "openai.image.dalle3",
            imageData: imageData,
            format: "png",
            width: 1024,
            height: 1024,
            prompt: ""
        )

        XCTAssertEqual(record.fileSize, 5)
    }

    func testGeneratedImageRecord_Description() {
        let record = GeneratedImageRecord(
            providerId: "openai",
            requestorID: "openai.image.dalle3",
            imageData: Data([0x01]),
            format: "png",
            width: 1024,
            height: 768,
            prompt: ""
        )

        let description = record.description
        XCTAssertTrue(description.contains("GeneratedImageRecord"))
        XCTAssertTrue(description.contains("1024x768"))
        XCTAssertTrue(description.contains("memory"))
    }

    // MARK: - OpenAIImageRequestor Tests

    func testOpenAIImageRequestor_Initialization_DALLE3() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAIImageRequestor(provider: provider, model: .dalle3)

        XCTAssertEqual(requestor.requestorID, "openai.image.dall-e-3")
        XCTAssertEqual(requestor.displayName, "OpenAI DALL-E 3")
        XCTAssertEqual(requestor.providerID, "openai")
        XCTAssertEqual(requestor.category, .image)
        XCTAssertEqual(requestor.outputFileType.mimeType, "image/png")
    }

    func testOpenAIImageRequestor_Initialization_DALLE2() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAIImageRequestor(provider: provider, model: .dalle2)

        XCTAssertEqual(requestor.requestorID, "openai.image.dall-e-2")
        XCTAssertEqual(requestor.displayName, "OpenAI DALL-E 2")
        XCTAssertEqual(requestor.providerID, "openai")
        XCTAssertEqual(requestor.category, .image)
    }

    func testOpenAIImageRequestor_DefaultConfiguration() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAIImageRequestor(provider: provider)

        let config = requestor.defaultConfiguration()

        XCTAssertEqual(config.size, .square1024)
        XCTAssertEqual(config.quality, .standard)
        XCTAssertEqual(config.style, .vivid)
        XCTAssertEqual(config.numberOfImages, 1)
    }

    func testOpenAIImageRequestor_ValidateConfiguration_Valid() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAIImageRequestor(provider: provider, model: .dalle3)

        let config = ImageGenerationConfig(
            size: .square1024,
            quality: .hd,
            style: .vivid,
            numberOfImages: 1
        )

        XCTAssertNoThrow(try requestor.validateConfiguration(config))
    }

    func testOpenAIImageRequestor_ValidateConfiguration_MultipleImages() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAIImageRequestor(provider: provider, model: .dalle3)

        let config = ImageGenerationConfig(
            size: .square1024,
            quality: .standard,
            style: .vivid,
            numberOfImages: 2 // Invalid: only 1 supported
        )

        XCTAssertThrowsError(try requestor.validateConfiguration(config)) { error in
            guard let serviceError = error as? AIServiceError,
                  case .configurationError = serviceError else {
                XCTFail("Expected configurationError")
                return
            }
        }
    }

    func testOpenAIImageRequestor_ValidateConfiguration_DALLE2_MultipleImages() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAIImageRequestor(provider: provider, model: .dalle2)

        let config = ImageGenerationConfig(
            size: .square512,
            quality: .standard,
            style: .vivid,
            numberOfImages: 5 // Invalid: only 1 supported
        )

        XCTAssertThrowsError(try requestor.validateConfiguration(config)) { error in
            guard let serviceError = error as? AIServiceError,
                  case .configurationError = serviceError else {
                XCTFail("Expected configurationError")
                return
            }
        }
    }

    func testOpenAIImageRequestor_ValidateConfiguration_DALLE3_SmallSize() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAIImageRequestor(provider: provider, model: .dalle3)

        let config = ImageGenerationConfig(
            size: .square256, // Invalid for DALL-E 3
            quality: .standard,
            style: .vivid,
            numberOfImages: 1
        )

        XCTAssertThrowsError(try requestor.validateConfiguration(config)) { error in
            guard let serviceError = error as? AIServiceError,
                  case .configurationError = serviceError else {
                XCTFail("Expected configurationError")
                return
            }
        }
    }

    func testOpenAIImageRequestor_ValidateConfiguration_DALLE2_HD() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAIImageRequestor(provider: provider, model: .dalle2)

        let config = ImageGenerationConfig(
            size: .square1024,
            quality: .hd, // Invalid for DALL-E 2
            style: .vivid,
            numberOfImages: 1
        )

        XCTAssertThrowsError(try requestor.validateConfiguration(config)) { error in
            guard let serviceError = error as? AIServiceError,
                  case .configurationError = serviceError else {
                XCTFail("Expected configurationError")
                return
            }
        }
    }

    func testOpenAIImageRequestor_ValidateConfiguration_DALLE2_WidescreenFormat() {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAIImageRequestor(provider: provider, model: .dalle2)

        let config = ImageGenerationConfig(
            size: .wide16x9, // Invalid for DALL-E 2
            quality: .standard,
            style: .vivid,
            numberOfImages: 1
        )

        XCTAssertThrowsError(try requestor.validateConfiguration(config)) { error in
            guard let serviceError = error as? AIServiceError,
                  case .configurationError = serviceError else {
                XCTFail("Expected configurationError")
                return
            }
        }
    }

    // MARK: - Storage Area Integration Tests

    func testOpenAIImageRequestor_SmallImageStoredInMemory() async {
        // Small images (<100KB threshold) should be stored in-memory
        let provider = OpenAIProvider.shared()
        let requestor = OpenAIImageRequestor(provider: provider)

        // Create small image data (50KB)
        let smallImageData = Data(repeating: 0xFF, count: 50_000)

        let shouldStoreAsFile = requestor.outputFileType.shouldStoreAsFile(estimatedSize: Int64(smallImageData.count))

        XCTAssertFalse(shouldStoreAsFile, "Small images (<100KB) should be stored in-memory")
    }

    func testOpenAIImageRequestor_LargeImageStoredAsFile() async {
        // Large images (>=100KB threshold) should be written to file
        let provider = OpenAIProvider.shared()
        let requestor = OpenAIImageRequestor(provider: provider)

        // Create large image data (500KB - typical for 1024x1024 PNG)
        let largeImageData = Data(repeating: 0xFF, count: 500_000)

        let shouldStoreAsFile = requestor.outputFileType.shouldStoreAsFile(estimatedSize: Int64(largeImageData.count))

        XCTAssertTrue(shouldStoreAsFile, "Large images (>=100KB) should be stored as file")
    }

    func testOpenAIImageRequestor_ThresholdBoundary() async {
        let provider = OpenAIProvider.shared()
        let requestor = OpenAIImageRequestor(provider: provider)

        // Test at threshold (100KB)
        let thresholdData = Data(repeating: 0xFF, count: 100_000)
        let atThreshold = requestor.outputFileType.shouldStoreAsFile(estimatedSize: Int64(thresholdData.count))
        XCTAssertTrue(atThreshold, "Image at threshold (100KB) should be stored as file")

        // Test just below threshold
        let belowThresholdData = Data(repeating: 0xFF, count: 99_999)
        let belowThreshold = requestor.outputFileType.shouldStoreAsFile(estimatedSize: Int64(belowThresholdData.count))
        XCTAssertFalse(belowThreshold, "Image below threshold should be in-memory")
    }

    // MARK: - Provider Integration Tests

    func testOpenAIProvider_AvailableRequestors() {
        let provider = OpenAIProvider.shared()
        let requestors = provider.availableRequestors()

        // Should have 3 text + 2 image + 3 embedding requestors = 8 total
        XCTAssertEqual(requestors.count, 8)

        // Count by category
        let textRequestors = requestors.filter { $0.category == .text }
        let imageRequestors = requestors.filter { $0.category == .image }
        let embeddingRequestors = requestors.filter { $0.category == .embedding }

        XCTAssertEqual(textRequestors.count, 3)
        XCTAssertEqual(imageRequestors.count, 2)
        XCTAssertEqual(embeddingRequestors.count, 3)

        // Check image requestor IDs
        let imageRequestorIDs = imageRequestors.map { $0.requestorID }.sorted()
        XCTAssertTrue(imageRequestorIDs.contains("openai.image.dall-e-2"))
        XCTAssertTrue(imageRequestorIDs.contains("openai.image.dall-e-3"))

        // All should be from openai provider
        XCTAssertTrue(requestors.allSatisfy { $0.providerID == "openai" })
    }
}
