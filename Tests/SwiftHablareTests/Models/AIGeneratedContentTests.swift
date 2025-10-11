import Testing
import SwiftData
import Foundation
@testable import SwiftHablare

struct AIGeneratedContentTests {

    @Test("AIGeneratedContent initializes with default values")
    func testInitialization() {
        let content = AIGeneratedContent(
            providerId: "test-provider",
            prompt: "Test prompt"
        )

        #expect(content.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        #expect(content.providerId == "test-provider")
        #expect(content.prompt == "Test prompt")
        #expect(content.generatedAt.timeIntervalSinceNow < 1)
        #expect(content.modifiedAt == content.generatedAt)
        #expect(content.modelIdentifier == nil)
        #expect(content.tokenCount == nil)
        #expect(content.estimatedCost == nil)
    }

    @Test("AIGeneratedContent can store optional metadata")
    func testOptionalMetadata() {
        let content = AIGeneratedContent(
            providerId: "openai",
            prompt: "Test",
            modelIdentifier: "gpt-4",
            tokenCount: 150,
            estimatedCost: 0.003
        )

        #expect(content.modelIdentifier == "gpt-4")
        #expect(content.tokenCount == 150)
        #expect(content.estimatedCost == 0.003)
    }

    @Test("AIGeneratedContent touch() updates modifiedAt")
    func testTouch() async {
        let content = AIGeneratedContent(
            providerId: "test",
            prompt: "Test"
        )

        let originalModified = content.modifiedAt

        // Wait a tiny bit to ensure timestamp difference
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

        content.touch()

        #expect(content.modifiedAt > originalModified)
    }

    @Test("GeneratedText initializes correctly")
    func testGeneratedTextInitialization() {
        let text = GeneratedText(
            providerId: "openai",
            prompt: "Write a story",
            content: "Once upon a time in a digital realm",
            languageCode: "en",
            modelIdentifier: "gpt-4"
        )

        #expect(text.content == "Once upon a time in a digital realm")
        #expect(text.characterCount == 35)
        #expect(text.wordCount == 8)
        #expect(text.languageCode == "en")
        #expect(text.modelIdentifier == "gpt-4")
    }

    @Test("GeneratedText counts are accurate")
    func testGeneratedTextCounts() {
        let content = "Hello world this is a test"
        let text = GeneratedText(
            providerId: "test",
            prompt: "Test",
            content: content
        )

        #expect(text.characterCount == content.count)
        #expect(text.wordCount == 6)
    }

    @Test("GeneratedAudio initializes correctly")
    func testGeneratedAudioInitialization() {
        let audioData = Data(repeating: 0, count: 1024)
        let audio = GeneratedAudio(
            providerId: "elevenlabs",
            prompt: "Say hello",
            audioData: audioData,
            audioFormat: "mp3",
            duration: 2.5,
            sampleRate: 44100,
            voiceId: "voice-123"
        )

        #expect(audio.audioData.count == 1024)
        #expect(audio.audioFormat == "mp3")
        #expect(audio.duration == 2.5)
        #expect(audio.sampleRate == 44100)
        #expect(audio.voiceId == "voice-123")
    }

    @Test("GeneratedImage initializes correctly")
    func testGeneratedImageInitialization() {
        let imageData = Data(repeating: 0, count: 2048)
        let image = GeneratedImage(
            providerId: "dall-e",
            prompt: "A beautiful sunset",
            imageData: imageData,
            imageFormat: "png",
            width: 1024,
            height: 1024
        )

        #expect(image.imageData.count == 2048)
        #expect(image.imageFormat == "png")
        #expect(image.width == 1024)
        #expect(image.height == 1024)
        #expect(image.fileSize == 2048)
    }

    @Test("GeneratedVideo initializes correctly")
    func testGeneratedVideoInitialization() {
        let videoURL = URL(fileURLWithPath: "/tmp/test.mp4")
        let video = GeneratedVideo(
            providerId: "runway",
            prompt: "A flying bird",
            videoURL: videoURL,
            videoFormat: "mp4",
            duration: 5.0
        )

        #expect(video.videoURL == videoURL)
        #expect(video.videoFormat == "mp4")
        #expect(video.duration == 5.0)
    }

    @Test("GeneratedStructuredData initializes correctly")
    func testGeneratedStructuredDataInitialization() {
        let jsonData = Data("{\"key\": \"value\"}".utf8)
        let structured = GeneratedStructuredData(
            providerId: "openai",
            prompt: "Generate JSON",
            data: jsonData,
            dataFormat: "json",
            schemaVersion: "1.0"
        )

        #expect(structured.data == jsonData)
        #expect(structured.dataFormat == "json")
        #expect(structured.schemaVersion == "1.0")
    }

    @Test("All models have unique IDs by default")
    func testUniqueIDs() {
        let content1 = AIGeneratedContent(providerId: "test", prompt: "test")
        let content2 = AIGeneratedContent(providerId: "test", prompt: "test")

        #expect(content1.id != content2.id)

        let text1 = GeneratedText(providerId: "test", prompt: "test", content: "test")
        let text2 = GeneratedText(providerId: "test", prompt: "test", content: "test")

        #expect(text1.id != text2.id)
    }

    @Test("Models store timestamps correctly")
    func testTimestamps() {
        let before = Date()
        let content = AIGeneratedContent(providerId: "test", prompt: "test")
        let after = Date()

        #expect(content.generatedAt >= before)
        #expect(content.generatedAt <= after)
        #expect(content.modifiedAt == content.generatedAt)
    }

    @Test("GeneratedText with empty content")
    func testGeneratedTextEmptyContent() {
        let text = GeneratedText(
            providerId: "test",
            prompt: "test",
            content: ""
        )

        #expect(text.content == "")
        #expect(text.characterCount == 0)
        #expect(text.wordCount == 0)
    }

    @Test("GeneratedAudio with minimal data")
    func testGeneratedAudioMinimal() {
        let audio = GeneratedAudio(
            providerId: "test",
            prompt: "test",
            audioData: Data(),
            audioFormat: "mp3"
        )

        #expect(audio.audioData.isEmpty)
        #expect(audio.duration == nil)
        #expect(audio.sampleRate == nil)
        #expect(audio.voiceId == nil)
    }

    @Test("GeneratedImage file size matches data")
    func testGeneratedImageFileSize() {
        let imageData = Data(repeating: 0, count: 12345)
        let image = GeneratedImage(
            providerId: "test",
            prompt: "test",
            imageData: imageData,
            imageFormat: "png"
        )

        #expect(image.fileSize == 12345)
        #expect(image.fileSize == imageData.count)
    }

    @Test("Models can store cost information")
    func testCostInformation() {
        let text = GeneratedText(
            providerId: "openai",
            prompt: "test",
            content: "test"
        )
        text.estimatedCost = 0.0025

        #expect(text.estimatedCost == 0.0025)
    }
}
