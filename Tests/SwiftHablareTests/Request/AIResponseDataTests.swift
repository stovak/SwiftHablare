import Testing
import Foundation
@testable import SwiftHablare

@Suite(.serialized)
struct AIResponseDataTests {

    // MARK: - AIResponseData Initialization Tests

    @Test("AIResponseData initializes with full parameters")
    func testFullInitialization() {
        let requestID = UUID()
        let providerID = "test-provider"
        let metadata = ["model": "gpt-4", "version": "1.0"]
        let receivedAt = Date()
        let usage = UsageStats(promptTokens: 10, completionTokens: 20, totalTokens: 30)
        let content = ResponseContent.text("Test response")

        let response = AIResponseData(
            requestID: requestID,
            providerID: providerID,
            result: .success(content),
            metadata: metadata,
            receivedAt: receivedAt,
            usage: usage
        )

        #expect(response.requestID == requestID)
        #expect(response.providerID == providerID)
        #expect(response.metadata == metadata)
        #expect(response.receivedAt == receivedAt)
        #expect(response.usage?.totalTokens == 30)
        #expect(response.isSuccess == true)
        #expect(response.isFailure == false)
    }

    @Test("AIResponseData success convenience initializer")
    func testSuccessConvenienceInitializer() {
        let requestID = UUID()
        let content = ResponseContent.text("Success")
        let metadata = ["key": "value"]
        let usage = UsageStats(totalTokens: 100)

        let response = AIResponseData(
            requestID: requestID,
            providerID: "provider",
            content: content,
            metadata: metadata,
            usage: usage
        )

        #expect(response.requestID == requestID)
        #expect(response.isSuccess == true)
        #expect(response.content?.text == "Success")
        #expect(response.metadata == metadata)
        #expect(response.usage?.totalTokens == 100)
    }

    @Test("AIResponseData failure convenience initializer")
    func testFailureConvenienceInitializer() {
        let requestID = UUID()
        let error = AIServiceError.networkError("Connection failed")
        let metadata = ["attempt": "1"]

        let response = AIResponseData(
            requestID: requestID,
            providerID: "provider",
            error: error,
            metadata: metadata
        )

        #expect(response.requestID == requestID)
        #expect(response.isFailure == true)
        #expect(response.isSuccess == false)
        #expect(response.error != nil)
        #expect(response.content == nil)
        #expect(response.usage == nil)
    }

    @Test("AIResponseData id property matches requestID")
    func testIDProperty() {
        let requestID = UUID()
        let response = AIResponseData(
            requestID: requestID,
            providerID: "provider",
            content: .text("Test")
        )

        #expect(response.id == requestID)
        #expect(response.id == response.requestID)
    }

    @Test("AIResponseData default values")
    func testDefaultValues() {
        let response = AIResponseData(
            requestID: UUID(),
            providerID: "provider",
            content: .text("Test")
        )

        #expect(response.metadata.isEmpty)
        #expect(response.usage == nil)
        // receivedAt should be approximately now (within 1 second)
        #expect(abs(response.receivedAt.timeIntervalSinceNow) < 1.0)
    }

    // MARK: - Convenience Properties Tests

    @Test("AIResponseData isSuccess for successful response")
    func testIsSuccessTrue() {
        let response = AIResponseData(
            requestID: UUID(),
            providerID: "provider",
            content: .text("Success")
        )

        #expect(response.isSuccess == true)
        #expect(response.isFailure == false)
    }

    @Test("AIResponseData isSuccess for failed response")
    func testIsSuccessFalse() {
        let response = AIResponseData(
            requestID: UUID(),
            providerID: "provider",
            error: .networkError("Failed")
        )

        #expect(response.isSuccess == false)
        #expect(response.isFailure == true)
    }

    @Test("AIResponseData content property for success")
    func testContentPropertySuccess() {
        let expectedContent = ResponseContent.text("Test content")
        let response = AIResponseData(
            requestID: UUID(),
            providerID: "provider",
            content: expectedContent
        )

        #expect(response.content != nil)
        #expect(response.content?.text == "Test content")
    }

    @Test("AIResponseData content property for failure")
    func testContentPropertyFailure() {
        let response = AIResponseData(
            requestID: UUID(),
            providerID: "provider",
            error: .networkError("Failed")
        )

        #expect(response.content == nil)
    }

    @Test("AIResponseData error property for success")
    func testErrorPropertySuccess() {
        let response = AIResponseData(
            requestID: UUID(),
            providerID: "provider",
            content: .text("Success")
        )

        #expect(response.error == nil)
    }

    @Test("AIResponseData error property for failure")
    func testErrorPropertyFailure() {
        let response = AIResponseData(
            requestID: UUID(),
            providerID: "provider",
            error: .rateLimitExceeded("Rate limit")
        )

        #expect(response.error != nil)
        // Check that it's the correct error type
        if case .rateLimitExceeded = response.error! {
            // Expected
        } else {
            Issue.record("Expected rateLimitExceeded error")
        }
    }

    // MARK: - ResponseContent Tests

    @Test("ResponseContent text case")
    func testResponseContentText() {
        let content = ResponseContent.text("Hello, world!")

        #expect(content.text == "Hello, world!")
        #expect(content.contentType == .text)
        #expect(content.audioContent == nil)
        #expect(content.imageContent == nil)
        #expect(content.structuredContent == nil)
    }

    @Test("ResponseContent data case")
    func testResponseContentData() {
        let testData = "Test data".data(using: .utf8)!
        let content = ResponseContent.data(testData)

        #expect(content.contentType == .data)
        #expect(content.dataContent == testData)
        #expect(content.text == nil)
    }

    @Test("ResponseContent audio case")
    func testResponseContentAudio() {
        let audioData = Data([0x01, 0x02, 0x03])
        let content = ResponseContent.audio(audioData, format: .mp3)

        #expect(content.contentType == .audio)
        #expect(content.audioContent?.data == audioData)
        #expect(content.audioContent?.format == .mp3)
        #expect(content.text == nil)
        #expect(content.imageContent == nil)
    }

    @Test("ResponseContent image case")
    func testResponseContentImage() {
        let imageData = Data([0xFF, 0xD8, 0xFF]) // JPEG header
        let content = ResponseContent.image(imageData, format: .jpeg)

        #expect(content.contentType == .image)
        #expect(content.imageContent?.data == imageData)
        #expect(content.imageContent?.format == .jpeg)
        #expect(content.text == nil)
        #expect(content.audioContent == nil)
    }

    @Test("ResponseContent structured case")
    func testResponseContentStructured() {
        let dict: [String: SendableValue] = [
            "name": .string("John"),
            "age": .int(30),
            "active": .bool(true)
        ]
        let content = ResponseContent.structured(dict)

        #expect(content.contentType == .structured)
        #expect(content.structuredContent?["name"]?.stringValue == "John")
        #expect(content.structuredContent?["age"]?.intValue == 30)
        #expect(content.structuredContent?["active"]?.boolValue == true)
        #expect(content.text == nil)
    }

    @Test("ResponseContent dataContent from text")
    func testDataContentFromText() {
        let content = ResponseContent.text("Hello")
        let data = content.dataContent

        #expect(data != nil)
        #expect(String(data: data!, encoding: .utf8) == "Hello")
    }

    @Test("ResponseContent dataContent from data")
    func testDataContentFromData() {
        let originalData = "Test".data(using: .utf8)!
        let content = ResponseContent.data(originalData)

        #expect(content.dataContent == originalData)
    }

    @Test("ResponseContent dataContent from audio")
    func testDataContentFromAudio() {
        let audioData = Data([0x01, 0x02])
        let content = ResponseContent.audio(audioData, format: .wav)

        #expect(content.dataContent == audioData)
    }

    @Test("ResponseContent dataContent from image")
    func testDataContentFromImage() {
        let imageData = Data([0xFF, 0xD8])
        let content = ResponseContent.image(imageData, format: .png)

        #expect(content.dataContent == imageData)
    }

    @Test("ResponseContent dataContent from structured")
    func testDataContentFromStructured() {
        let dict: [String: SendableValue] = ["key": .string("value")]
        let content = ResponseContent.structured(dict)

        let data = content.dataContent
        #expect(data != nil)
        // Should be valid JSON
        let decoded = try? JSONDecoder().decode([String: String].self, from: data!)
        #expect(decoded?["key"] == "value")
    }

    // MARK: - AudioFormat Tests

    @Test("AudioFormat cases")
    func testAudioFormats() {
        #expect(AudioFormat.mp3.rawValue == "mp3")
        #expect(AudioFormat.wav.rawValue == "wav")
        #expect(AudioFormat.aac.rawValue == "aac")
        #expect(AudioFormat.flac.rawValue == "flac")
        #expect(AudioFormat.ogg.rawValue == "ogg")
        #expect(AudioFormat.opus.rawValue == "opus")
        #expect(AudioFormat.pcm.rawValue == "pcm")
        #expect(AudioFormat.unknown.rawValue == "unknown")
    }

    // MARK: - ImageFormat Tests

    @Test("ImageFormat cases")
    func testImageFormats() {
        #expect(ImageFormat.jpeg.rawValue == "jpeg")
        #expect(ImageFormat.png.rawValue == "png")
        #expect(ImageFormat.gif.rawValue == "gif")
        #expect(ImageFormat.webp.rawValue == "webp")
        #expect(ImageFormat.heic.rawValue == "heic")
        #expect(ImageFormat.tiff.rawValue == "tiff")
        #expect(ImageFormat.bmp.rawValue == "bmp")
        #expect(ImageFormat.unknown.rawValue == "unknown")
    }

    // MARK: - SendableValue Tests

    @Test("SendableValue string case")
    func testSendableValueString() {
        let value = SendableValue.string("test")

        #expect(value.stringValue == "test")
        #expect(value.intValue == nil)
        #expect(value.doubleValue == nil)
        #expect(value.boolValue == nil)
        #expect(value.arrayValue == nil)
        #expect(value.dictionaryValue == nil)
        #expect(value.isNull == false)
    }

    @Test("SendableValue int case")
    func testSendableValueInt() {
        let value = SendableValue.int(42)

        #expect(value.intValue == 42)
        #expect(value.stringValue == nil)
        #expect(value.doubleValue == nil)
        #expect(value.boolValue == nil)
        #expect(value.isNull == false)
    }

    @Test("SendableValue double case")
    func testSendableValueDouble() {
        let value = SendableValue.double(3.14)

        #expect(value.doubleValue == 3.14)
        #expect(value.intValue == nil)
        #expect(value.stringValue == nil)
        #expect(value.isNull == false)
    }

    @Test("SendableValue bool case")
    func testSendableValueBool() {
        let value = SendableValue.bool(true)

        #expect(value.boolValue == true)
        #expect(value.intValue == nil)
        #expect(value.stringValue == nil)
        #expect(value.isNull == false)
    }

    @Test("SendableValue null case")
    func testSendableValueNull() {
        let value = SendableValue.null

        #expect(value.isNull == true)
        #expect(value.stringValue == nil)
        #expect(value.intValue == nil)
        #expect(value.doubleValue == nil)
        #expect(value.boolValue == nil)
    }

    @Test("SendableValue array case")
    func testSendableValueArray() {
        let array: [SendableValue] = [.string("a"), .int(1), .bool(true)]
        let value = SendableValue.array(array)

        #expect(value.arrayValue?.count == 3)
        #expect(value.arrayValue?[0].stringValue == "a")
        #expect(value.arrayValue?[1].intValue == 1)
        #expect(value.arrayValue?[2].boolValue == true)
        #expect(value.dictionaryValue == nil)
        #expect(value.isNull == false)
    }

    @Test("SendableValue dictionary case")
    func testSendableValueDictionary() {
        let dict: [String: SendableValue] = [
            "name": .string("Alice"),
            "age": .int(25)
        ]
        let value = SendableValue.dictionary(dict)

        #expect(value.dictionaryValue?["name"]?.stringValue == "Alice")
        #expect(value.dictionaryValue?["age"]?.intValue == 25)
        #expect(value.arrayValue == nil)
        #expect(value.isNull == false)
    }

    @Test("SendableValue nested structures")
    func testSendableValueNested() {
        let nested: [String: SendableValue] = [
            "users": .array([
                .dictionary([
                    "name": .string("Alice"),
                    "active": .bool(true)
                ]),
                .dictionary([
                    "name": .string("Bob"),
                    "active": .bool(false)
                ])
            ])
        ]

        let value = SendableValue.dictionary(nested)
        let users = value.dictionaryValue?["users"]?.arrayValue
        #expect(users?.count == 2)
        #expect(users?[0].dictionaryValue?["name"]?.stringValue == "Alice")
        #expect(users?[1].dictionaryValue?["active"]?.boolValue == false)
    }

    // MARK: - UsageStats Tests

    @Test("UsageStats full initialization")
    func testUsageStatsFullInit() {
        let stats = UsageStats(
            promptTokens: 100,
            completionTokens: 150,
            totalTokens: 250,
            costUSD: Decimal(string: "0.005"),
            durationSeconds: 2.5
        )

        #expect(stats.promptTokens == 100)
        #expect(stats.completionTokens == 150)
        #expect(stats.totalTokens == 250)
        #expect(stats.costUSD == Decimal(string: "0.005"))
        #expect(stats.durationSeconds == 2.5)
    }

    @Test("UsageStats default nil values")
    func testUsageStatsDefaults() {
        let stats = UsageStats()

        #expect(stats.promptTokens == nil)
        #expect(stats.completionTokens == nil)
        #expect(stats.totalTokens == nil)
        #expect(stats.costUSD == nil)
        #expect(stats.durationSeconds == nil)
    }

    @Test("UsageStats partial initialization")
    func testUsageStatsPartial() {
        let stats = UsageStats(
            promptTokens: 50,
            totalTokens: 75
        )

        #expect(stats.promptTokens == 50)
        #expect(stats.completionTokens == nil)
        #expect(stats.totalTokens == 75)
        #expect(stats.costUSD == nil)
    }

    // MARK: - ContentType Tests

    @Test("ContentType cases")
    func testContentTypeCases() {
        let allCases = ResponseContent.ContentType.allCases

        #expect(allCases.contains(.text))
        #expect(allCases.contains(.data))
        #expect(allCases.contains(.audio))
        #expect(allCases.contains(.image))
        #expect(allCases.contains(.structured))
        #expect(allCases.count == 5)
    }

    @Test("ContentType raw values")
    func testContentTypeRawValues() {
        #expect(ResponseContent.ContentType.text.rawValue == "text")
        #expect(ResponseContent.ContentType.data.rawValue == "data")
        #expect(ResponseContent.ContentType.audio.rawValue == "audio")
        #expect(ResponseContent.ContentType.image.rawValue == "image")
        #expect(ResponseContent.ContentType.structured.rawValue == "structured")
    }

    // MARK: - Sendable Conformance Tests

    @Test("AIResponseData is Sendable")
    func testAIResponseDataSendable() async {
        let response = AIResponseData(
            requestID: UUID(),
            providerID: "provider",
            content: .text("Test")
        )

        await Task {
            // Should compile without warnings
            _ = response.isSuccess
        }.value
    }

    @Test("ResponseContent is Sendable")
    func testResponseContentSendable() async {
        let content = ResponseContent.text("Test")

        await Task {
            // Should compile without warnings
            _ = content.text
        }.value
    }

    @Test("UsageStats is Sendable")
    func testUsageStatsSendable() async {
        let stats = UsageStats(totalTokens: 100)

        await Task {
            // Should compile without warnings
            _ = stats.totalTokens
        }.value
    }

    // MARK: - Edge Cases

    @Test("ResponseContent structured with empty dictionary")
    func testStructuredEmptyDictionary() {
        let content = ResponseContent.structured([:])

        #expect(content.structuredContent?.isEmpty == true)
        #expect(content.contentType == .structured)
    }

    @Test("SendableValue array with nested arrays")
    func testNestedArrays() {
        let value = SendableValue.array([
            .array([.int(1), .int(2)]),
            .array([.int(3), .int(4)])
        ])

        #expect(value.arrayValue?.count == 2)
        #expect(value.arrayValue?[0].arrayValue?.count == 2)
        #expect(value.arrayValue?[1].arrayValue?[0].intValue == 3)
    }

    @Test("SendableValue deeply nested structures")
    func testDeeplyNestedStructures() {
        let value = SendableValue.dictionary([
            "level1": .dictionary([
                "level2": .dictionary([
                    "level3": .array([
                        .int(1),
                        .string("deep")
                    ])
                ])
            ])
        ])

        let level3 = value.dictionaryValue?["level1"]?
            .dictionaryValue?["level2"]?
            .dictionaryValue?["level3"]?
            .arrayValue

        #expect(level3?.count == 2)
        #expect(level3?[1].stringValue == "deep")
    }

    @Test("AIResponseData with all error types")
    func testAllErrorTypes() {
        let errors: [AIServiceError] = [
            .networkError("Network"),
            .rateLimitExceeded("Rate limit"),
            .invalidAPIKey("Invalid key"),
            .configurationError("Config"),
            .validationError("Validation"),
            .persistenceError("Persistence"),
            .unexpectedResponseFormat("Format"),
            .providerError("Server error", code: "500"),
            .unsupportedOperation("Unsupported"),
            .timeout("Timeout"),
            .dataBindingError("Binding"),
            .dataConversionError("Conversion"),
            .modelNotFound("Model"),
            .missingCredentials("Credentials"),
            .authenticationFailed("Auth"),
            .connectionFailed("Connection"),
            .invalidRequest("Request")
        ]

        for error in errors {
            let response = AIResponseData(
                requestID: UUID(),
                providerID: "provider",
                error: error
            )

            #expect(response.isFailure == true)
            #expect(response.error != nil)
        }
    }

    // MARK: - Codable Tests

    @Test("ResponseContent structured encodes and decodes")
    func testStructuredEncodeDecode() throws {
        let original: [String: SendableValue] = [
            "string": .string("hello"),
            "int": .int(42),
            "double": .double(3.14),
            "bool": .bool(true),
            "null": .null,
            "array": .array([.string("a"), .int(1)]),
            "nested": .dictionary(["key": .string("value")])
        ]

        let content = ResponseContent.structured(original)
        let data = content.dataContent

        #expect(data != nil)

        // Decode back to verify round-trip
        let decoded = try JSONDecoder().decode([String: TestCodableValue].self, from: data!)

        #expect(decoded["string"]?.stringValue == "hello")
        #expect(decoded["int"]?.intValue == 42)
        #expect(decoded["double"]?.doubleValue == 3.14)
        #expect(decoded["bool"]?.boolValue == true)
        #expect(decoded["null"]?.isNull == true)
    }

    @Test("ResponseContent structured with nested arrays")
    func testStructuredNestedArraysEncodeDecode() throws {
        let original: [String: SendableValue] = [
            "matrix": .array([
                .array([.int(1), .int(2)]),
                .array([.int(3), .int(4)])
            ])
        ]

        let content = ResponseContent.structured(original)
        let data = content.dataContent

        #expect(data != nil)

        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: data!, options: [])
        #expect(json is [String: Any])
    }

    @Test("ResponseContent structured handles all value types")
    func testStructuredAllValueTypes() throws {
        // Test simple value types that definitely work
        let simpleDict: [String: SendableValue] = [
            "string": .string("test"),
            "int": .int(123),
            "double": .double(45.67),
            "bool": .bool(true),
            "null": .null
        ]

        let content = ResponseContent.structured(simpleDict)
        let data = content.dataContent

        #expect(data != nil)

        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: data!, options: [])
        #expect(json is [String: Any])
    }

    @Test("ResponseContent structured with array")
    func testStructuredWithArray() throws {
        let dict: [String: SendableValue] = [
            "numbers": .array([.int(1), .int(2), .int(3)])
        ]

        let content = ResponseContent.structured(dict)
        let data = content.dataContent

        #expect(data != nil)

        // Verify it can be encoded
        if let data = data {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            #expect(json is [String: Any])
        }
    }

    @Test("ResponseContent structured with nested dictionary")
    func testStructuredWithNestedDictionary() throws {
        let dict: [String: SendableValue] = [
            "user": .dictionary([
                "name": .string("Alice"),
                "age": .int(30)
            ])
        ]

        let content = ResponseContent.structured(dict)
        let data = content.dataContent

        #expect(data != nil)

        // Verify it can be encoded
        if let data = data {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            #expect(json is [String: Any])
        }
    }

    @Test("ResponseContent structured complex structure")
    func testStructuredComplexStructure() throws {
        let dict: [String: SendableValue] = [
            "title": .string("Document"),
            "count": .int(42),
            "active": .bool(true),
            "tags": .array([.string("swift"), .string("testing")])
        ]

        let content = ResponseContent.structured(dict)
        let data = content.dataContent

        #expect(data != nil)

        // Just verify encoding succeeds
        if let data = data {
            _ = try JSONSerialization.jsonObject(with: data, options: [])
        }
    }
}

// MARK: - Test Helpers

/// Helper for testing Codable support
enum TestCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    var intValue: Int? {
        if case .int(let v) = self { return v }
        return nil
    }

    var doubleValue: Double? {
        if case .double(let v) = self { return v }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }

    var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .null: try container.encodeNil()
        }
    }
}
