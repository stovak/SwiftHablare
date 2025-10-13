import XCTest
@testable import SwiftHablare

/// Comprehensive tests for AICapability enum
final class AICapabilityTests: XCTestCase {

    // MARK: - Raw Value Tests

    func testRawValues() {
        XCTAssertEqual(AICapability.textGeneration.rawValue, "text_generation")
        XCTAssertEqual(AICapability.audioGeneration.rawValue, "audio_generation")
        XCTAssertEqual(AICapability.imageGeneration.rawValue, "image_generation")
        XCTAssertEqual(AICapability.videoGeneration.rawValue, "video_generation")
        XCTAssertEqual(AICapability.structuredData.rawValue, "structured_data")
        XCTAssertEqual(AICapability.embeddings.rawValue, "embeddings")
        XCTAssertEqual(AICapability.transcription.rawValue, "transcription")
        XCTAssertEqual(AICapability.imageAnalysis.rawValue, "image_analysis")
        XCTAssertEqual(AICapability.codeGeneration.rawValue, "code_generation")
        XCTAssertEqual(AICapability.custom("custom_value").rawValue, "custom_value")
    }

    // MARK: - Display Name Tests

    func testDisplayNames() {
        XCTAssertEqual(AICapability.textGeneration.displayName, "Text Generation")
        XCTAssertEqual(AICapability.audioGeneration.displayName, "Audio Generation")
        XCTAssertEqual(AICapability.imageGeneration.displayName, "Image Generation")
        XCTAssertEqual(AICapability.videoGeneration.displayName, "Video Generation")
        XCTAssertEqual(AICapability.structuredData.displayName, "Structured Data")
        XCTAssertEqual(AICapability.embeddings.displayName, "Embeddings")
        XCTAssertEqual(AICapability.transcription.displayName, "Transcription")
        XCTAssertEqual(AICapability.imageAnalysis.displayName, "Image Analysis")
        XCTAssertEqual(AICapability.codeGeneration.displayName, "Code Generation")
        XCTAssertEqual(AICapability.custom("Custom Name").displayName, "Custom Name")
    }

    // MARK: - All Standard Cases Tests

    func testAllStandardCases() {
        let allCases = AICapability.allStandardCases

        XCTAssertEqual(allCases.count, 9)
        XCTAssertTrue(allCases.contains(.textGeneration))
        XCTAssertTrue(allCases.contains(.audioGeneration))
        XCTAssertTrue(allCases.contains(.imageGeneration))
        XCTAssertTrue(allCases.contains(.videoGeneration))
        XCTAssertTrue(allCases.contains(.structuredData))
        XCTAssertTrue(allCases.contains(.embeddings))
        XCTAssertTrue(allCases.contains(.transcription))
        XCTAssertTrue(allCases.contains(.imageAnalysis))
        XCTAssertTrue(allCases.contains(.codeGeneration))
    }

    // MARK: - Equatable Tests

    func testEquality_StandardCases() {
        XCTAssertEqual(AICapability.textGeneration, AICapability.textGeneration)
        XCTAssertEqual(AICapability.audioGeneration, AICapability.audioGeneration)
        XCTAssertEqual(AICapability.imageGeneration, AICapability.imageGeneration)
        XCTAssertEqual(AICapability.videoGeneration, AICapability.videoGeneration)
        XCTAssertEqual(AICapability.structuredData, AICapability.structuredData)
        XCTAssertEqual(AICapability.embeddings, AICapability.embeddings)
        XCTAssertEqual(AICapability.transcription, AICapability.transcription)
        XCTAssertEqual(AICapability.imageAnalysis, AICapability.imageAnalysis)
        XCTAssertEqual(AICapability.codeGeneration, AICapability.codeGeneration)
    }

    func testEquality_CustomCases() {
        XCTAssertEqual(AICapability.custom("test"), AICapability.custom("test"))
        XCTAssertNotEqual(AICapability.custom("test1"), AICapability.custom("test2"))
    }

    func testInequality_DifferentCases() {
        XCTAssertNotEqual(AICapability.textGeneration, AICapability.audioGeneration)
        XCTAssertNotEqual(AICapability.imageGeneration, AICapability.videoGeneration)
        XCTAssertNotEqual(AICapability.textGeneration, AICapability.custom("text_generation"))
    }

    // MARK: - Hashable Tests

    func testHashable_StandardCases() {
        var set = Set<AICapability>()
        set.insert(.textGeneration)
        set.insert(.textGeneration) // Duplicate

        XCTAssertEqual(set.count, 1)
        XCTAssertTrue(set.contains(.textGeneration))
    }

    func testHashable_CustomCases() {
        var set = Set<AICapability>()
        set.insert(.custom("test1"))
        set.insert(.custom("test1")) // Duplicate
        set.insert(.custom("test2"))

        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(.custom("test1")))
        XCTAssertTrue(set.contains(.custom("test2")))
    }

    func testHashable_MixedCases() {
        var set = Set<AICapability>()
        set.insert(.textGeneration)
        set.insert(.audioGeneration)
        set.insert(.custom("custom1"))
        set.insert(.custom("custom2"))

        XCTAssertEqual(set.count, 4)
    }

    // MARK: - Codable Tests - Encoding

    func testEncoding_StandardCases() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let textGen = AICapability.textGeneration
        let data = try encoder.encode(textGen)
        let string = String(data: data, encoding: .utf8)

        XCTAssertEqual(string, "\"text_generation\"")
    }

    func testEncoding_AllStandardCases() throws {
        let encoder = JSONEncoder()

        let capabilities: [AICapability] = [
            .textGeneration,
            .audioGeneration,
            .imageGeneration,
            .videoGeneration,
            .structuredData,
            .embeddings,
            .transcription,
            .imageAnalysis,
            .codeGeneration
        ]

        for capability in capabilities {
            let data = try encoder.encode(capability)
            let string = String(data: data, encoding: .utf8)
            XCTAssertEqual(string, "\"\(capability.rawValue)\"")
        }
    }

    func testEncoding_CustomCase() throws {
        let encoder = JSONEncoder()
        let custom = AICapability.custom("my_custom_capability")
        let data = try encoder.encode(custom)
        let string = String(data: data, encoding: .utf8)

        XCTAssertEqual(string, "\"my_custom_capability\"")
    }

    func testEncoding_Array() throws {
        let encoder = JSONEncoder()
        let capabilities: [AICapability] = [
            .textGeneration,
            .audioGeneration,
            .custom("custom1")
        ]

        let data = try encoder.encode(capabilities)
        let string = String(data: data, encoding: .utf8)

        XCTAssertTrue(string!.contains("text_generation"))
        XCTAssertTrue(string!.contains("audio_generation"))
        XCTAssertTrue(string!.contains("custom1"))
    }

    // MARK: - Codable Tests - Decoding

    func testDecoding_StandardCases() throws {
        let decoder = JSONDecoder()

        let json = "\"text_generation\""
        let data = json.data(using: .utf8)!
        let capability = try decoder.decode(AICapability.self, from: data)

        XCTAssertEqual(capability, .textGeneration)
    }

    func testDecoding_AllStandardCases() throws {
        let decoder = JSONDecoder()

        let testCases: [(String, AICapability)] = [
            ("text_generation", .textGeneration),
            ("audio_generation", .audioGeneration),
            ("image_generation", .imageGeneration),
            ("video_generation", .videoGeneration),
            ("structured_data", .structuredData),
            ("embeddings", .embeddings),
            ("transcription", .transcription),
            ("image_analysis", .imageAnalysis),
            ("code_generation", .codeGeneration)
        ]

        for (rawValue, expectedCapability) in testCases {
            let json = "\"\(rawValue)\""
            let data = json.data(using: .utf8)!
            let capability = try decoder.decode(AICapability.self, from: data)
            XCTAssertEqual(capability, expectedCapability)
        }
    }

    func testDecoding_CustomCase() throws {
        let decoder = JSONDecoder()

        let json = "\"unknown_capability\""
        let data = json.data(using: .utf8)!
        let capability = try decoder.decode(AICapability.self, from: data)

        XCTAssertEqual(capability, .custom("unknown_capability"))
    }

    func testDecoding_Array() throws {
        let decoder = JSONDecoder()

        let json = "[\"text_generation\",\"audio_generation\",\"custom_one\"]"
        let data = json.data(using: .utf8)!
        let capabilities = try decoder.decode([AICapability].self, from: data)

        XCTAssertEqual(capabilities.count, 3)
        XCTAssertEqual(capabilities[0], .textGeneration)
        XCTAssertEqual(capabilities[1], .audioGeneration)
        XCTAssertEqual(capabilities[2], .custom("custom_one"))
    }

    // MARK: - Round-Trip Tests

    func testRoundTrip_StandardCases() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for capability in AICapability.allStandardCases {
            let encoded = try encoder.encode(capability)
            let decoded = try decoder.decode(AICapability.self, from: encoded)
            XCTAssertEqual(decoded, capability)
        }
    }

    func testRoundTrip_CustomCase() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = AICapability.custom("my_special_capability")
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(AICapability.self, from: encoded)

        XCTAssertEqual(decoded, original)
    }

    func testRoundTrip_MixedArray() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original: [AICapability] = [
            .textGeneration,
            .custom("custom1"),
            .imageGeneration,
            .custom("custom2"),
            .embeddings
        ]

        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode([AICapability].self, from: encoded)

        XCTAssertEqual(decoded, original)
    }

    // MARK: - Sendable Tests

    func testSendable() async {
        // Test that AICapability can be safely used across concurrency boundaries
        let capability = AICapability.textGeneration

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Task {
                // Can safely capture capability in a Task
                XCTAssertEqual(capability, .textGeneration)
                continuation.resume()
            }
        }
    }

    func testSendable_CustomCase() async {
        let capability = AICapability.custom("async_test")

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Task {
                XCTAssertEqual(capability, .custom("async_test"))
                continuation.resume()
            }
        }
    }

    // MARK: - Edge Cases

    func testCustom_EmptyString() {
        let capability = AICapability.custom("")
        XCTAssertEqual(capability.rawValue, "")
        XCTAssertEqual(capability.displayName, "")
    }

    func testCustom_SpecialCharacters() {
        let capability = AICapability.custom("test-capability_123")
        XCTAssertEqual(capability.rawValue, "test-capability_123")
        XCTAssertEqual(capability.displayName, "test-capability_123")
    }

    func testCustom_Whitespace() {
        let capability = AICapability.custom("test capability with spaces")
        XCTAssertEqual(capability.rawValue, "test capability with spaces")
        XCTAssertEqual(capability.displayName, "test capability with spaces")
    }

    // MARK: - Collection Operations

    func testArrayContains() {
        let capabilities: [AICapability] = [
            .textGeneration,
            .audioGeneration,
            .custom("custom1")
        ]

        XCTAssertTrue(capabilities.contains(.textGeneration))
        XCTAssertTrue(capabilities.contains(.audioGeneration))
        XCTAssertTrue(capabilities.contains(.custom("custom1")))
        XCTAssertFalse(capabilities.contains(.imageGeneration))
        XCTAssertFalse(capabilities.contains(.custom("custom2")))
    }

    func testSetOperations() {
        let set1: Set<AICapability> = [.textGeneration, .audioGeneration, .imageGeneration]
        let set2: Set<AICapability> = [.audioGeneration, .imageGeneration, .videoGeneration]

        let union = set1.union(set2)
        XCTAssertEqual(union.count, 4)

        let intersection = set1.intersection(set2)
        XCTAssertEqual(intersection.count, 2)
        XCTAssertTrue(intersection.contains(.audioGeneration))
        XCTAssertTrue(intersection.contains(.imageGeneration))

        let difference = set1.subtracting(set2)
        XCTAssertEqual(difference.count, 1)
        XCTAssertTrue(difference.contains(.textGeneration))
    }
}
