import XCTest
import SwiftData
@testable import SwiftHablare

/// Comprehensive tests for ElevenLabsProvider
@available(macOS 15.0, iOS 17.0, *)
final class ElevenLabsProviderTests: XCTestCase {

    // MARK: - Identity Tests

    func testIdentity() {
        let provider = ElevenLabsProvider()

        XCTAssertEqual(provider.id, "elevenlabs")
        XCTAssertEqual(provider.displayName, "ElevenLabs")
    }

    // MARK: - Capabilities Tests

    func testCapabilities() {
        let provider = ElevenLabsProvider()

        XCTAssertEqual(provider.capabilities.count, 1)
        XCTAssertTrue(provider.capabilities.contains(.audioGeneration))
        XCTAssertFalse(provider.capabilities.contains(.textGeneration))
    }

    func testSupportedDataStructures() {
        let provider = ElevenLabsProvider()

        XCTAssertTrue(provider.supportedDataStructures.isEmpty)
    }

    func testResponseType() {
        let provider = ElevenLabsProvider()

        XCTAssertEqual(provider.responseType, .audio)
    }

    // MARK: - Configuration Tests

    func testRequiresAPIKey() {
        let provider = ElevenLabsProvider()

        XCTAssertTrue(provider.requiresAPIKey)
    }

    func testIsConfigured_AlwaysReturnsTrue() {
        let provider = ElevenLabsProvider()

        // isConfigured() always returns true, actual validation happens in generate()
        XCTAssertTrue(provider.isConfigured())
    }

    func testValidateConfiguration_DoesNotThrow() throws {
        let provider = ElevenLabsProvider()

        // validateConfiguration() is a no-op in this provider
        XCTAssertNoThrow(try provider.validateConfiguration())
    }

    // MARK: - Initialization Tests

    func testInitialization_WithDefaultBaseURL() {
        let provider = ElevenLabsProvider()

        XCTAssertEqual(provider.baseURL, "https://api.elevenlabs.io")
        XCTAssertEqual(provider.timeout, 120.0)
    }

    func testInitialization_WithCustomBaseURL() {
        let provider = ElevenLabsProvider(
            baseURL: "https://custom.elevenlabs.io"
        )

        XCTAssertEqual(provider.baseURL, "https://custom.elevenlabs.io")
    }

    func testDefaultBaseURL() {
        XCTAssertEqual(ElevenLabsProvider.defaultBaseURL, "https://api.elevenlabs.io")
    }

    // MARK: - Generation Tests

    func testGenerate_FailsWithMissingCredentials() async {
        let provider = ElevenLabsProvider()
        

        let result = await provider.generate(prompt: "Hello world", parameters: [:])

        switch result {
        case .success:
            XCTFail("Expected failure due to missing credentials")
        case .failure(let error):
            if case .missingCredentials(let message) = error {
                XCTAssertTrue(message.contains("Failed to retrieve ElevenLabs API key"))
            } else {
                XCTFail("Expected missingCredentials error, got \(error)")
            }
        }
    }

    func testGenerate_FailsWithShortAPIKey() async {
        let provider = ElevenLabsProvider()
        

        let result = await provider.generate(prompt: "Hello world", parameters: [:])

        switch result {
        case .success:
            XCTFail("Expected failure due to invalid API key")
        case .failure(let error):
            if case .invalidAPIKey(let message) = error {
                XCTAssertTrue(message.contains("must be at least 32 characters"))
            } else {
                XCTFail("Expected invalidAPIKey error, got \(error)")
            }
        }
    }

    func testGenerate_AcceptsValidAPIKey() async {
        let provider = ElevenLabsProvider()
        // Valid 32-character API key
        

        // This will fail with network error since we don't have a real API, but it should pass validation
        let result = await provider.generate(prompt: "Hello world", parameters: [:])

        switch result {
        case .success:
            XCTFail("Not expected to succeed without real API")
        case .failure(let error):
            // Should fail with network error, not credential error
            if case .missingCredentials = error {
                XCTFail("Should not fail with missing credentials")
            } else if case .invalidAPIKey = error {
                XCTFail("Should not fail with invalid API key")
            }
            // Any other error (network, etc.) is expected
        }
    }

    func testGenerate_AcceptsTestAPIKey() async {
        let provider = ElevenLabsProvider()
        // Test keys with "test-" prefix are allowed
        

        // This will fail with network error, but should pass validation
        let result = await provider.generate(prompt: "Hello world", parameters: [:])

        switch result {
        case .success:
            XCTFail("Not expected to succeed without real API")
        case .failure(let error):
            // Should fail with network error, not credential error
            if case .missingCredentials = error {
                XCTFail("Should not fail with missing credentials")
            } else if case .invalidAPIKey = error {
                XCTFail("Should not fail with invalid API key")
            }
        }
    }

    func testGenerate_UsesDefaultParameters() async {
        let provider = ElevenLabsProvider()
        

        // Call without custom parameters - will use defaults
        // We're just testing that it doesn't crash
        let result = await provider.generate(prompt: "Test", parameters: [:])

        // We expect network error since we don't have a real API
        switch result {
        case .success:
            XCTFail("Not expected to succeed without real API")
        case .failure(let error):
            // Should fail with some error (network, etc.)
            XCTAssertNotNil(error)
        }
    }

    func testGenerate_UsesCustomParameters() async {
        let provider = ElevenLabsProvider()
        

        let parameters: [String: Any] = [
            "voice_id": "custom-voice-123",
            "model_id": "eleven_multilingual_v2",
            "stability": 0.8,
            "clarity_boost": 0.9
        ]

        // Call with custom parameters
        let result = await provider.generate(prompt: "Test", parameters: parameters)

        // We expect network error since we don't have a real API
        switch result {
        case .success:
            XCTFail("Not expected to succeed without real API")
        case .failure(let error):
            // Should fail with some error (network, etc.)
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Available Requestors Tests

    func testAvailableRequestors() {
        let provider = ElevenLabsProvider()

        let requestors = provider.availableRequestors()

        XCTAssertEqual(requestors.count, 1)
        XCTAssertTrue(requestors[0] is ElevenLabsAudioRequestor)
    }

    // MARK: - Legacy API Tests

    func testLegacyGenerate_ConvertsResultToData() async throws {
        let provider = ElevenLabsProvider()
        

        let container = try TestHelpers.testContainer(for: GeneratedText.self)
        let context = ModelContext(container)

        // This will fail with network error
        do {
            _ = try await provider.generate(
                prompt: "Test",
                parameters: [:],
                context: context
            )
            XCTFail("Expected to throw error")
        } catch {
            // Expected to fail with network error
            XCTAssertNotNil(error)
        }
    }

    // Note: testLegacyGenerateProperty removed due to SwiftData @Model scope limitations in test functions

    // MARK: - Factory Method Tests

    func testSharedFactory() {
        let provider = ElevenLabsProvider.shared()

        XCTAssertEqual(provider.id, "elevenlabs")
        XCTAssertEqual(provider.displayName, "ElevenLabs")
        XCTAssertEqual(provider.baseURL, ElevenLabsProvider.defaultBaseURL)
    }

    // MARK: - Sendable Tests

    func testProvider_IsSendable() async {
        let provider = ElevenLabsProvider()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Task {
                // Should be able to capture provider in a task
                XCTAssertEqual(provider.id, "elevenlabs")
                continuation.resume()
            }
        }
    }

    // MARK: - Request Model Tests

    func testTextToSpeechRequest_Encoding() throws {
        let request = ElevenLabsProvider.TextToSpeechRequest(
            text: "Hello world",
            modelId: "eleven_monolingual_v1",
            voiceSettings: ElevenLabsProvider.VoiceSettings(
                stability: 0.5,
                similarityBoost: 0.75
            )
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["text"] as? String, "Hello world")
        XCTAssertEqual(json?["model_id"] as? String, "eleven_monolingual_v1")

        let voiceSettings = json?["voice_settings"] as? [String: Any]
        XCTAssertNotNil(voiceSettings)
        XCTAssertEqual(voiceSettings?["stability"] as? Double, 0.5)
        XCTAssertEqual(voiceSettings?["similarity_boost"] as? Double, 0.75)
    }

    func testVoiceSettings_Codable() throws {
        let settings = ElevenLabsProvider.VoiceSettings(
            stability: 0.8,
            similarityBoost: 0.9
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ElevenLabsProvider.VoiceSettings.self, from: data)

        XCTAssertEqual(decoded.stability, 0.8)
        XCTAssertEqual(decoded.similarityBoost, 0.9)
    }

    // MARK: - Edge Cases

    func testGenerate_EmptyPrompt() async {
        let provider = ElevenLabsProvider()
        

        let result = await provider.generate(prompt: "", parameters: [:])

        // Should still attempt to make the request
        switch result {
        case .success:
            XCTFail("Not expected to succeed")
        case .failure:
            // Expected to fail with some error
            break
        }
    }

    func testGenerate_VeryLongPrompt() async {
        let provider = ElevenLabsProvider()
        

        let longPrompt = String(repeating: "Hello world. ", count: 1000)
        let result = await provider.generate(prompt: longPrompt, parameters: [:])

        switch result {
        case .success:
            XCTFail("Not expected to succeed")
        case .failure:
            // Expected to fail
            break
        }
    }

    func testGenerate_InvalidVoiceIDType() async {
        let provider = ElevenLabsProvider()
        

        // Pass wrong type for voice_id - should handle gracefully
        let parameters: [String: Any] = [
            "voice_id": 123  // Should be String, not Int
        ]

        let result = await provider.generate(prompt: "Test", parameters: parameters)

        switch result {
        case .success:
            XCTFail("Not expected to succeed")
        case .failure:
            // Should handle type mismatch gracefully
            break
        }
    }

    // Note: testGenerate_CredentialManagerError removed - can't mock actor-based credential manager

    // MARK: - Integration with BaseHTTPProvider

    func testInheritsFromBaseHTTPProvider() {
        let provider = ElevenLabsProvider()

        // Verify that it's a BaseHTTPProvider
        XCTAssertTrue(provider is BaseHTTPProvider)
    }

    func testBaseURL_IsAccessible() {
        let provider = ElevenLabsProvider(
            baseURL: "https://test.api.com"
        )

        XCTAssertEqual(provider.baseURL, "https://test.api.com")
    }

    func testTimeout_IsAccessible() {
        let provider = ElevenLabsProvider()

        XCTAssertEqual(provider.timeout, 120.0)
    }
}
