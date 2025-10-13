import XCTest
import AVFoundation
@testable import SwiftHablare

/// Comprehensive tests for AppleVoiceProvider
final class AppleVoiceProviderTests: XCTestCase {

    var provider: AppleVoiceProvider!

    override func setUp() {
        super.setUp()
        provider = AppleVoiceProvider()
    }

    override func tearDown() {
        provider = nil
        super.tearDown()
    }

    // MARK: - Identity Tests

    func testProviderId() {
        XCTAssertEqual(provider.providerId, "apple")
    }

    func testDisplayName() {
        XCTAssertEqual(provider.displayName, "Apple Text-to-Speech")
    }

    // MARK: - Configuration Tests

    func testRequiresAPIKey() {
        XCTAssertFalse(provider.requiresAPIKey)
    }

    func testIsConfigured() {
        // Apple TTS is always configured on macOS
        XCTAssertTrue(provider.isConfigured())
    }

    // MARK: - Voice Fetching Tests

    func testFetchVoices_ReturnsNonEmptyArray() async throws {
        let voices = try await provider.fetchVoices()

        XCTAssertFalse(voices.isEmpty, "Should return at least some voices")
        XCTAssertGreaterThan(voices.count, 0)
    }

    func testFetchVoices_VoicesHaveValidProperties() async throws {
        let voices = try await provider.fetchVoices()

        for voice in voices {
            XCTAssertFalse(voice.id.isEmpty, "Voice ID should not be empty")
            XCTAssertFalse(voice.name.isEmpty, "Voice name should not be empty")
            XCTAssertEqual(voice.providerId, "apple", "Voice provider ID should be 'apple'")
            XCTAssertNotNil(voice.language, "Voice should have a language")
        }
    }

    func testFetchVoices_FiltersForSystemLanguage() async throws {
        let voices = try await provider.fetchVoices()

        // Get system language
        let systemLanguageCode = Locale.current.language.languageCode?.identifier ?? "en"
        let systemLangPrefix = String(systemLanguageCode.prefix(2))

        // Most voices should match system language (or at least some if system language has voices)
        let matchingVoices = voices.filter { voice in
            guard let voiceLanguage = voice.language else { return false }
            let voiceLangPrefix = String(voiceLanguage.prefix(2))
            return voiceLangPrefix == systemLangPrefix
        }

        // Either we have matching voices, or we get a fallback subset
        if matchingVoices.isEmpty {
            // Fallback: should return up to 10 voices
            XCTAssertLessThanOrEqual(voices.count, 10, "Fallback should return at most 10 voices")
        } else {
            // We have voices matching system language
            XCTAssertGreaterThan(matchingVoices.count, 0)
        }
    }

    func testFetchVoices_IncludesQualityDescription() async throws {
        let voices = try await provider.fetchVoices()

        // At least some voices should have quality descriptions
        let voicesWithQuality = voices.filter { !($0.description?.isEmpty ?? true) }
        XCTAssertGreaterThan(voicesWithQuality.count, 0)
    }

    // MARK: - Audio Generation Tests

    func testGenerateAudio_ProducesNonEmptyData() async throws {
        let text = "Hello, world!"
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            XCTFail("No voices available for testing")
            return
        }

        let audioData = try await provider.generateAudio(text: text, voiceId: firstVoice.id)

        XCTAssertFalse(audioData.isEmpty, "Audio data should not be empty")
        XCTAssertGreaterThan(audioData.count, 0)
    }

    func testGenerateAudio_EmptyText() async throws {
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            XCTFail("No voices available for testing")
            return
        }

        let audioData = try await provider.generateAudio(text: "", voiceId: firstVoice.id)

        // Should still produce some data (silence or minimal audio)
        XCTAssertGreaterThan(audioData.count, 0)
    }

    func testGenerateAudio_LongText() async throws {
        let text = String(repeating: "This is a test sentence. ", count: 20)
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            XCTFail("No voices available for testing")
            return
        }

        let audioData = try await provider.generateAudio(text: text, voiceId: firstVoice.id)

        XCTAssertGreaterThan(audioData.count, 0)
    }

    // MARK: - Duration Estimation Tests

    func testEstimateDuration_ShortText() async {
        let text = "Hello"
        let duration = await provider.estimateDuration(text: text, voiceId: "com.apple.voice.compact.en-US.Samantha")

        XCTAssertGreaterThanOrEqual(duration, 1.0, "Minimum duration should be 1 second")
        XCTAssertLessThan(duration, 5.0, "Short text should have short duration")
    }

    func testEstimateDuration_MediumText() async {
        let text = "The quick brown fox jumps over the lazy dog."
        let duration = await provider.estimateDuration(text: text, voiceId: "com.apple.voice.compact.en-US.Samantha")

        XCTAssertGreaterThan(duration, 1.0)
        XCTAssertLessThan(duration, 10.0)
    }

    func testEstimateDuration_LongText() async {
        let text = String(repeating: "This is a long sentence with many words. ", count: 10)
        let duration = await provider.estimateDuration(text: text, voiceId: "com.apple.voice.compact.en-US.Samantha")

        XCTAssertGreaterThan(duration, 10.0, "Long text should have longer duration")
    }

    func testEstimateDuration_EmptyText() async {
        let duration = await provider.estimateDuration(text: "", voiceId: "com.apple.voice.compact.en-US.Samantha")

        XCTAssertEqual(duration, 1.0, "Empty text should return minimum duration of 1 second")
    }

    func testEstimateDuration_ProportionalToLength() async {
        let shortText = "Hello"
        let longText = "Hello Hello Hello Hello Hello"

        let shortDuration = await provider.estimateDuration(text: shortText, voiceId: "com.apple.voice.compact.en-US.Samantha")
        let longDuration = await provider.estimateDuration(text: longText, voiceId: "com.apple.voice.compact.en-US.Samantha")

        XCTAssertGreaterThan(longDuration, shortDuration, "Longer text should have longer estimated duration")
    }

    // MARK: - Voice Availability Tests

    func testIsVoiceAvailable_ValidVoice() async throws {
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            XCTFail("No voices available for testing")
            return
        }

        let isAvailable = await provider.isVoiceAvailable(voiceId: firstVoice.id)
        XCTAssertTrue(isAvailable, "Voice from fetchVoices should be available")
    }

    func testIsVoiceAvailable_InvalidVoice() async {
        let isAvailable = await provider.isVoiceAvailable(voiceId: "invalid-voice-id-12345")
        XCTAssertFalse(isAvailable, "Invalid voice ID should not be available")
    }

    func testIsVoiceAvailable_EmptyVoiceId() async {
        let isAvailable = await provider.isVoiceAvailable(voiceId: "")
        XCTAssertFalse(isAvailable, "Empty voice ID should not be available")
    }

    // MARK: - Sendable Tests

    func testProvider_IsSendable() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Task {
                // Should be able to capture provider in a task
                XCTAssertEqual(provider.providerId, "apple")
                continuation.resume()
            }
        }
    }

    // MARK: - Edge Cases

    // Note: testFetchVoices_Concurrent removed due to Sendable data race warnings

    func testGenerateAudio_SpecialCharacters() async throws {
        let text = "Hello! How are you? I'm fine, thanks."
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            XCTFail("No voices available for testing")
            return
        }

        let audioData = try await provider.generateAudio(text: text, voiceId: firstVoice.id)
        XCTAssertGreaterThan(audioData.count, 0)
    }

    func testGenerateAudio_Unicode() async throws {
        let text = "Hello 世界 🌍"
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            XCTFail("No voices available for testing")
            return
        }

        let audioData = try await provider.generateAudio(text: text, voiceId: firstVoice.id)
        XCTAssertGreaterThan(audioData.count, 0)
    }

    func testGenerateAudio_Newlines() async throws {
        let text = "Line one.\nLine two.\nLine three."
        let voices = try await provider.fetchVoices()

        guard let firstVoice = voices.first else {
            XCTFail("No voices available for testing")
            return
        }

        let audioData = try await provider.generateAudio(text: text, voiceId: firstVoice.id)
        XCTAssertGreaterThan(audioData.count, 0)
    }

    // MARK: - Voice Property Tests

    func testVoices_HaveCorrectProviderId() async throws {
        let voices = try await provider.fetchVoices()

        for voice in voices {
            XCTAssertEqual(voice.providerId, "apple")
        }
    }

    func testVoices_HaveValidIds() async throws {
        let voices = try await provider.fetchVoices()

        for voice in voices {
            XCTAssertFalse(voice.id.isEmpty)
            XCTAssertTrue(voice.id.contains("."))  // Apple voice IDs contain dots
        }
    }

    func testVoices_HaveValidNames() async throws {
        let voices = try await provider.fetchVoices()

        for voice in voices {
            XCTAssertFalse(voice.name.isEmpty)
        }
    }
}
