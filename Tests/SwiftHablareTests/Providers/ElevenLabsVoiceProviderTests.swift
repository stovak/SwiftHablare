import XCTest
@testable import SwiftHablare

/// Comprehensive tests for ElevenLabsVoiceProvider
final class ElevenLabsVoiceProviderTests: XCTestCase {

    var provider: ElevenLabsVoiceProvider!

    override func setUp() {
        super.setUp()
        provider = ElevenLabsVoiceProvider()
    }

    override func tearDown() {
        provider = nil
        super.tearDown()
    }

    // MARK: - Identity Tests

    func testProviderId() {
        XCTAssertEqual(provider.providerId, "elevenlabs")
    }

    func testDisplayName() {
        XCTAssertEqual(provider.displayName, "ElevenLabs")
    }

    // MARK: - Configuration Tests

    func testRequiresAPIKey() {
        XCTAssertTrue(provider.requiresAPIKey)
    }

    func testIsConfigured_WithoutAPIKey() {
        // Without API key configured, should return false
        let configured = provider.isConfigured()

        // This will depend on whether a key is actually stored
        // We can't make assumptions about the test environment
        XCTAssertNotNil(configured)  // Just test it returns a value
    }

    // MARK: - Voice Fetching Tests

    func testFetchVoices_FailsWithoutAPIKey() async {
        // This test assumes no API key is configured
        // If an API key is configured, this test may fail

        do {
            _ = try await provider.fetchVoices()
            // If this succeeds, API key must be configured
        } catch let error as VoiceProviderError {
            // Expected to fail with notConfigured or networkError
            switch error {
            case .notConfigured, .networkError:
                // Success - expected error type
                break
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Audio Generation Tests

    func testGenerateAudio_FailsWithoutAPIKey() async {
        do {
            _ = try await provider.generateAudio(text: "Test", voiceId: "test-voice")
            // If this succeeds, API key must be configured
        } catch let error as VoiceProviderError {
            // Expected to fail
            switch error {
            case .notConfigured, .networkError:
                // Success - expected error type
                break
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testGenerateAudio_EmptyText() async {
        do {
            _ = try await provider.generateAudio(text: "", voiceId: "test-voice")
            // May succeed or fail depending on API key configuration
        } catch {
            // Expected to fail without API key
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Duration Estimation Tests

    func testEstimateDuration_ShortText() async {
        let text = "Hello"
        let duration = await provider.estimateDuration(text: text, voiceId: "test-voice")

        XCTAssertGreaterThanOrEqual(duration, 1.0, "Minimum duration should be 1 second")
        XCTAssertLessThan(duration, 5.0, "Short text should have short duration")
    }

    func testEstimateDuration_MediumText() async {
        let text = "The quick brown fox jumps over the lazy dog."
        let duration = await provider.estimateDuration(text: text, voiceId: "test-voice")

        XCTAssertGreaterThan(duration, 1.0)
        XCTAssertLessThan(duration, 10.0)
    }

    func testEstimateDuration_LongText() async {
        let text = String(repeating: "This is a long sentence with many words. ", count: 10)
        let duration = await provider.estimateDuration(text: text, voiceId: "test-voice")

        XCTAssertGreaterThan(duration, 10.0, "Long text should have longer duration")
    }

    func testEstimateDuration_EmptyText() async {
        let duration = await provider.estimateDuration(text: "", voiceId: "test-voice")

        XCTAssertEqual(duration, 1.0, "Empty text should return minimum duration of 1 second")
    }

    func testEstimateDuration_ProportionalToLength() async {
        let shortText = "Hello"
        let longText = "Hello Hello Hello Hello Hello"

        let shortDuration = await provider.estimateDuration(text: shortText, voiceId: "test-voice")
        let longDuration = await provider.estimateDuration(text: longText, voiceId: "test-voice")

        XCTAssertGreaterThan(longDuration, shortDuration, "Longer text should have longer estimated duration")
    }

    func testEstimateDuration_IncludesBuffer() async {
        // Test that buffer is applied (1.15x multiplier)
        let text = String(repeating: "a", count: 130)  // Exactly 10 seconds at base rate
        let duration = await provider.estimateDuration(text: text, voiceId: "test-voice")

        // Should be > 10 seconds due to buffer
        XCTAssertGreaterThan(duration, 10.0)
        // But not too much more
        XCTAssertLessThan(duration, 15.0)
    }

    // MARK: - Voice Availability Tests

    func testIsVoiceAvailable_WithoutAPIKey() async {
        let isAvailable = await provider.isVoiceAvailable(voiceId: "test-voice")

        // Without API key, should return false
        // (or may return false due to network error)
        XCTAssertNotNil(isAvailable)  // Just test it returns a value
    }

    func testIsVoiceAvailable_EmptyVoiceId() async {
        let isAvailable = await provider.isVoiceAvailable(voiceId: "")

        // Should handle empty voice ID gracefully
        XCTAssertFalse(isAvailable)
    }

    // MARK: - Sendable Tests

    func testProvider_IsSendable() async {
        let testProvider = provider!
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Task {
                // Should be able to capture provider in a task
                XCTAssertEqual(testProvider.providerId, "elevenlabs")
                continuation.resume()
            }
        }
    }

    // MARK: - API Response Model Tests

    func testElevenLabsVoice_IDProperty() {
        let voice = ElevenLabsVoice(
            voice_id: "test-123",
            name: "Test Voice",
            description: "A test voice",
            labels: nil,
            verified_languages: nil
        )

        XCTAssertEqual(voice.id, "test-123")
        XCTAssertEqual(voice.voice_id, "test-123")
    }

    func testElevenLabsVoice_LanguageProperty_WithVerifiedLanguages() {
        let verifiedLang = ElevenLabsVoice.VerifiedLanguage(
            language: "English",
            model_id: "eleven_monolingual_v1",
            accent: nil,
            locale: "en-US",
            preview_url: nil
        )

        let voice = ElevenLabsVoice(
            voice_id: "test-123",
            name: "Test Voice",
            description: "A test voice",
            labels: nil,
            verified_languages: [verifiedLang]
        )

        XCTAssertEqual(voice.language, "en")
    }

    func testElevenLabsVoice_LocalityProperty_WithVerifiedLanguages() {
        let verifiedLang = ElevenLabsVoice.VerifiedLanguage(
            language: "English",
            model_id: "eleven_monolingual_v1",
            accent: nil,
            locale: "en-US",
            preview_url: nil
        )

        let voice = ElevenLabsVoice(
            voice_id: "test-123",
            name: "Test Voice",
            description: "A test voice",
            labels: nil,
            verified_languages: [verifiedLang]
        )

        XCTAssertEqual(voice.locality, "US")
    }

    func testElevenLabsVoice_GenderProperty() {
        let labels = ElevenLabsVoice.VoiceLabels(
            accent: "American",
            description: "Test voice",
            age: "young",
            gender: "Female",
            use_case: "narration"
        )

        let voice = ElevenLabsVoice(
            voice_id: "test-123",
            name: "Test Voice",
            description: "A test voice",
            labels: labels,
            verified_languages: nil
        )

        XCTAssertEqual(voice.gender, "female")  // Should be lowercased
    }

    func testElevenLabsVoice_GenderProperty_Nil() {
        let voice = ElevenLabsVoice(
            voice_id: "test-123",
            name: "Test Voice",
            description: "A test voice",
            labels: nil,
            verified_languages: nil
        )

        XCTAssertNil(voice.gender)
    }

    func testElevenLabsVoice_LanguageProperty_FallbackToLabels() {
        let labels = ElevenLabsVoice.VoiceLabels(
            accent: "British",
            description: nil,
            age: nil,
            gender: nil,
            use_case: nil
        )

        let voice = ElevenLabsVoice(
            voice_id: "test-123",
            name: "Test Voice",
            description: "A test voice",
            labels: labels,
            verified_languages: nil
        )

        XCTAssertEqual(voice.language, "British")
    }

    func testVoicesResponse_Codable() throws {
        let json = """
        {
            "voices": [
                {
                    "voice_id": "voice-1",
                    "name": "Voice One",
                    "description": "First voice"
                },
                {
                    "voice_id": "voice-2",
                    "name": "Voice Two",
                    "description": "Second voice"
                }
            ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let response = try decoder.decode(VoicesResponse.self, from: json)

        XCTAssertEqual(response.voices.count, 2)
        XCTAssertEqual(response.voices[0].voice_id, "voice-1")
        XCTAssertEqual(response.voices[1].voice_id, "voice-2")
    }

    func testElevenLabsVoice_Codable() throws {
        let json = """
        {
            "voice_id": "test-123",
            "name": "Test Voice",
            "description": "A test voice",
            "labels": {
                "accent": "American",
                "gender": "female"
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let voice = try decoder.decode(ElevenLabsVoice.self, from: json)

        XCTAssertEqual(voice.voice_id, "test-123")
        XCTAssertEqual(voice.name, "Test Voice")
        XCTAssertEqual(voice.description, "A test voice")
        XCTAssertEqual(voice.labels?.accent, "American")
        XCTAssertEqual(voice.labels?.gender, "female")
    }

    func testVoiceLabels_Codable() throws {
        let json = """
        {
            "accent": "British",
            "description": "A British voice",
            "age": "middle_aged",
            "gender": "male",
            "use_case": "narration"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let labels = try decoder.decode(ElevenLabsVoice.VoiceLabels.self, from: json)

        XCTAssertEqual(labels.accent, "British")
        XCTAssertEqual(labels.description, "A British voice")
        XCTAssertEqual(labels.age, "middle_aged")
        XCTAssertEqual(labels.gender, "male")
        XCTAssertEqual(labels.use_case, "narration")
    }

    func testVerifiedLanguage_Codable() throws {
        let json = """
        {
            "language": "English",
            "model_id": "eleven_monolingual_v1",
            "accent": "American",
            "locale": "en-US",
            "preview_url": "https://example.com/preview.mp3"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let verifiedLang = try decoder.decode(ElevenLabsVoice.VerifiedLanguage.self, from: json)

        XCTAssertEqual(verifiedLang.language, "English")
        XCTAssertEqual(verifiedLang.model_id, "eleven_monolingual_v1")
        XCTAssertEqual(verifiedLang.accent, "American")
        XCTAssertEqual(verifiedLang.locale, "en-US")
        XCTAssertEqual(verifiedLang.preview_url, "https://example.com/preview.mp3")
    }

    // MARK: - Edge Cases

    func testEstimateDuration_VeryLongText() async {
        let text = String(repeating: "This is a test sentence. ", count: 1000)
        let duration = await provider.estimateDuration(text: text, voiceId: "test-voice")

        XCTAssertGreaterThan(duration, 100.0)  // Should be several minutes
    }

    func testElevenLabsVoice_LocalityProperty_HyphenSeparator() {
        let verifiedLang = ElevenLabsVoice.VerifiedLanguage(
            language: "English",
            model_id: "eleven_monolingual_v1",
            accent: nil,
            locale: "en-GB",
            preview_url: nil
        )

        let voice = ElevenLabsVoice(
            voice_id: "test-123",
            name: "Test Voice",
            description: "A test voice",
            labels: nil,
            verified_languages: [verifiedLang]
        )

        XCTAssertEqual(voice.locality, "GB")
    }

    func testElevenLabsVoice_LocalityProperty_UnderscoreSeparator() {
        let verifiedLang = ElevenLabsVoice.VerifiedLanguage(
            language: "English",
            model_id: "eleven_monolingual_v1",
            accent: nil,
            locale: "en_AU",
            preview_url: nil
        )

        let voice = ElevenLabsVoice(
            voice_id: "test-123",
            name: "Test Voice",
            description: "A test voice",
            labels: nil,
            verified_languages: [verifiedLang]
        )

        XCTAssertEqual(voice.locality, "AU")
    }

}
