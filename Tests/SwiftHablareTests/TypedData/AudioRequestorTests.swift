//
//  AudioRequestorTests.swift
//  SwiftHablareTests
//
//  Phase 6C: Tests for audio requestors
//

import XCTest
@testable import SwiftHablare

@available(macOS 15.0, iOS 17.0, *)
final class AudioRequestorTests: XCTestCase {

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

    // MARK: - GeneratedAudioData Tests

    func testGeneratedAudioData_Initialization() {
        let audioData = Data([0x01, 0x02, 0x03, 0x04])
        let data = GeneratedAudioData(
            audioData: audioData,
            format: .mp3,
            durationSeconds: 5.5,
            sampleRate: 44100,
            bitRate: 128000,
            channels: 2,
            voiceID: "21m00Tcm4TlvDq8ikWAM",
            voiceName: "Rachel",
            model: "eleven_monolingual_v1"
        )

        XCTAssertEqual(data.audioData, audioData)
        XCTAssertEqual(data.format, .mp3)
        XCTAssertEqual(data.durationSeconds, 5.5)
        XCTAssertEqual(data.sampleRate, 44100)
        XCTAssertEqual(data.bitRate, 128000)
        XCTAssertEqual(data.channels, 2)
        XCTAssertEqual(data.voiceID, "21m00Tcm4TlvDq8ikWAM")
        XCTAssertEqual(data.voiceName, "Rachel")
        XCTAssertEqual(data.model, "eleven_monolingual_v1")
        XCTAssertEqual(data.fileSize, 4)
    }

    func testGeneratedAudioData_NilAudioData() {
        let data = GeneratedAudioData(
            audioData: nil,
            format: .mp3,
            voiceID: "test-voice",
            voiceName: "Test Voice",
            model: "test-model"
        )

        XCTAssertNil(data.audioData)
        XCTAssertEqual(data.fileSize, 0)
    }

    func testGeneratedAudioData_AudioFormatMimeTypes() {
        XCTAssertEqual(GeneratedAudioData.AudioFormat.mp3.mimeType, "audio/mpeg")
        XCTAssertEqual(GeneratedAudioData.AudioFormat.wav.mimeType, "audio/wav")
        XCTAssertEqual(GeneratedAudioData.AudioFormat.m4a.mimeType, "audio/mp4")
        XCTAssertEqual(GeneratedAudioData.AudioFormat.flac.mimeType, "audio/flac")
        XCTAssertEqual(GeneratedAudioData.AudioFormat.ogg.mimeType, "audio/ogg")
    }

    func testGeneratedAudioData_AudioFormatExtensions() {
        XCTAssertEqual(GeneratedAudioData.AudioFormat.mp3.fileExtension, "mp3")
        XCTAssertEqual(GeneratedAudioData.AudioFormat.wav.fileExtension, "wav")
        XCTAssertEqual(GeneratedAudioData.AudioFormat.m4a.fileExtension, "m4a")
        XCTAssertEqual(GeneratedAudioData.AudioFormat.flac.fileExtension, "flac")
        XCTAssertEqual(GeneratedAudioData.AudioFormat.ogg.fileExtension, "ogg")
    }

    func testGeneratedAudioData_Codable() throws {
        let original = GeneratedAudioData(
            audioData: Data([0x01, 0x02]),
            format: .mp3,
            durationSeconds: 3.0,
            sampleRate: 44100,
            bitRate: 128000,
            channels: 2,
            voiceID: "test-voice",
            voiceName: "Test Voice",
            model: "test-model"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GeneratedAudioData.self, from: encoded)

        XCTAssertEqual(decoded.audioData, original.audioData)
        XCTAssertEqual(decoded.format, original.format)
        XCTAssertEqual(decoded.durationSeconds, original.durationSeconds)
        XCTAssertEqual(decoded.sampleRate, original.sampleRate)
        XCTAssertEqual(decoded.bitRate, original.bitRate)
        XCTAssertEqual(decoded.channels, original.channels)
        XCTAssertEqual(decoded.voiceID, original.voiceID)
        XCTAssertEqual(decoded.voiceName, original.voiceName)
        XCTAssertEqual(decoded.model, original.model)
    }

    func testGeneratedAudioData_PreferredFormat() {
        let data = GeneratedAudioData(
            audioData: nil,
            format: .mp3,
            voiceID: "test",
            voiceName: "Test",
            model: "test"
        )

        XCTAssertEqual(data.preferredFormat, .plist)
    }

    // MARK: - AudioGenerationConfig Tests

    func testAudioGenerationConfig_DefaultInitialization() {
        let config = AudioGenerationConfig(
            voiceID: "test-voice",
            voiceName: "Test Voice"
        )

        XCTAssertEqual(config.voiceID, "test-voice")
        XCTAssertEqual(config.voiceName, "Test Voice")
        XCTAssertEqual(config.modelID, "eleven_monolingual_v1")
        XCTAssertEqual(config.stability, 0.5)
        XCTAssertEqual(config.similarityBoost, 0.75)
        XCTAssertEqual(config.outputFormat, .mp3)
    }

    func testAudioGenerationConfig_CustomInitialization() {
        let config = AudioGenerationConfig(
            voiceID: "custom-voice",
            voiceName: "Custom Voice",
            modelID: "custom-model",
            stability: 0.8,
            similarityBoost: 0.6,
            outputFormat: .wav
        )

        XCTAssertEqual(config.voiceID, "custom-voice")
        XCTAssertEqual(config.voiceName, "Custom Voice")
        XCTAssertEqual(config.modelID, "custom-model")
        XCTAssertEqual(config.stability, 0.8)
        XCTAssertEqual(config.similarityBoost, 0.6)
        XCTAssertEqual(config.outputFormat, .wav)
    }

    func testAudioGenerationConfig_DefaultPreset() {
        let config = AudioGenerationConfig.default

        XCTAssertEqual(config.voiceID, "21m00Tcm4TlvDq8ikWAM")
        XCTAssertEqual(config.voiceName, "Rachel")
        XCTAssertEqual(config.stability, 0.5)
        XCTAssertEqual(config.similarityBoost, 0.75)
    }

    func testAudioGenerationConfig_StablePreset() {
        let config = AudioGenerationConfig.stable(
            voiceID: "test-voice",
            voiceName: "Test Voice"
        )

        XCTAssertEqual(config.voiceID, "test-voice")
        XCTAssertEqual(config.voiceName, "Test Voice")
        XCTAssertEqual(config.stability, 0.75)
        XCTAssertEqual(config.similarityBoost, 0.5)
    }

    func testAudioGenerationConfig_ExpressivePreset() {
        let config = AudioGenerationConfig.expressive(
            voiceID: "test-voice",
            voiceName: "Test Voice"
        )

        XCTAssertEqual(config.voiceID, "test-voice")
        XCTAssertEqual(config.voiceName, "Test Voice")
        XCTAssertEqual(config.stability, 0.25)
        XCTAssertEqual(config.similarityBoost, 0.9)
    }

    func testAudioGenerationConfig_Codable() throws {
        let original = AudioGenerationConfig(
            voiceID: "test-voice",
            voiceName: "Test Voice",
            modelID: "test-model",
            stability: 0.7,
            similarityBoost: 0.8
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AudioGenerationConfig.self, from: encoded)

        XCTAssertEqual(decoded.voiceID, original.voiceID)
        XCTAssertEqual(decoded.voiceName, original.voiceName)
        XCTAssertEqual(decoded.modelID, original.modelID)
        XCTAssertEqual(decoded.stability, original.stability)
        XCTAssertEqual(decoded.similarityBoost, original.similarityBoost)
    }

    // MARK: - GeneratedAudioRecord Tests

    func testGeneratedAudioRecord_Initialization() {
        let audioData = Data([0x01, 0x02, 0x03, 0x04])
        let record = GeneratedAudioRecord(
            providerId: "elevenlabs",
            requestorID: "elevenlabs.audio.tts",
            audioData: audioData,
            format: "mp3",
            durationSeconds: 5.0,
            sampleRate: 44100,
            bitRate: 128000,
            channels: 2,
            voiceID: "21m00Tcm4TlvDq8ikWAM",
            voiceName: "Rachel",
            prompt: "Hello, world!",
            modelIdentifier: "eleven_monolingual_v1"
        )

        XCTAssertNotNil(record.id)
        XCTAssertEqual(record.providerId, "elevenlabs")
        XCTAssertEqual(record.requestorID, "elevenlabs.audio.tts")
        XCTAssertEqual(record.audioData, audioData)
        XCTAssertEqual(record.format, "mp3")
        XCTAssertEqual(record.durationSeconds, 5.0)
        XCTAssertEqual(record.sampleRate, 44100)
        XCTAssertEqual(record.bitRate, 128000)
        XCTAssertEqual(record.channels, 2)
        XCTAssertEqual(record.voiceID, "21m00Tcm4TlvDq8ikWAM")
        XCTAssertEqual(record.voiceName, "Rachel")
        XCTAssertEqual(record.prompt, "Hello, world!")
        XCTAssertEqual(record.modelIdentifier, "eleven_monolingual_v1")
    }

    func testGeneratedAudioRecord_ConvenienceInitializer() {
        let audioData = GeneratedAudioData(
            audioData: Data([0x01, 0x02]),
            format: .mp3,
            durationSeconds: 3.0,
            sampleRate: 44100,
            bitRate: 128000,
            channels: 2,
            voiceID: "21m00Tcm4TlvDq8ikWAM",
            voiceName: "Rachel",
            model: "eleven_monolingual_v1"
        )

        let record = GeneratedAudioRecord(
            providerId: "elevenlabs",
            requestorID: "elevenlabs.audio.tts",
            data: audioData,
            prompt: "Test prompt"
        )

        XCTAssertEqual(record.audioData, audioData.audioData)
        XCTAssertEqual(record.format, "mp3")
        XCTAssertEqual(record.durationSeconds, 3.0)
        XCTAssertEqual(record.sampleRate, 44100)
        XCTAssertEqual(record.bitRate, 128000)
        XCTAssertEqual(record.channels, 2)
        XCTAssertEqual(record.voiceID, "21m00Tcm4TlvDq8ikWAM")
        XCTAssertEqual(record.voiceName, "Rachel")
        XCTAssertEqual(record.prompt, "Test prompt")
        XCTAssertEqual(record.modelIdentifier, "eleven_monolingual_v1")
    }

    func testGeneratedAudioRecord_ConvenienceInitializerWithFileReference() {
        let audioData = GeneratedAudioData(
            audioData: Data([0x01, 0x02]),
            format: .mp3,
            voiceID: "test-voice",
            voiceName: "Test Voice",
            model: "test-model"
        )

        let fileRef = TypedDataFileReference(
            requestID: UUID(),
            fileName: "audio.mp3",
            fileSize: 1000,
            mimeType: "audio/mpeg"
        )

        let record = GeneratedAudioRecord(
            providerId: "elevenlabs",
            requestorID: "elevenlabs.audio.tts",
            data: audioData,
            prompt: "Test prompt",
            fileReference: fileRef
        )

        // When file reference exists, audio data should not be stored in-memory
        XCTAssertNil(record.audioData)
        XCTAssertNotNil(record.fileReference)
        XCTAssertTrue(record.isFileStored)
    }

    func testGeneratedAudioRecord_IsFileStored() {
        let recordInMemory = GeneratedAudioRecord(
            providerId: "elevenlabs",
            requestorID: "elevenlabs.audio.tts",
            audioData: Data([0x01]),
            format: "mp3",
            voiceID: "test",
            voiceName: "Test",
            prompt: ""
        )

        XCTAssertFalse(recordInMemory.isFileStored)

        let fileRef = TypedDataFileReference(
            requestID: UUID(),
            fileName: "audio.mp3",
            fileSize: 1000,
            mimeType: "audio/mpeg"
        )

        let recordInFile = GeneratedAudioRecord(
            providerId: "elevenlabs",
            requestorID: "elevenlabs.audio.tts",
            audioData: nil,
            format: "mp3",
            voiceID: "test",
            voiceName: "Test",
            prompt: "",
            fileReference: fileRef
        )

        XCTAssertTrue(recordInFile.isFileStored)
    }

    func testGeneratedAudioRecord_Touch() async throws {
        let record = GeneratedAudioRecord(
            providerId: "elevenlabs",
            requestorID: "elevenlabs.audio.tts",
            audioData: Data([0x01]),
            format: "mp3",
            voiceID: "test",
            voiceName: "Test",
            prompt: ""
        )

        let originalModifiedAt = record.modifiedAt

        // Wait a moment
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds

        record.touch()

        XCTAssertGreaterThan(record.modifiedAt, originalModifiedAt)
    }

    func testGeneratedAudioRecord_GetAudioData_InMemory() throws {
        let audioData = Data([0x01, 0x02, 0x03])
        let record = GeneratedAudioRecord(
            providerId: "elevenlabs",
            requestorID: "elevenlabs.audio.tts",
            audioData: audioData,
            format: "mp3",
            voiceID: "test",
            voiceName: "Test",
            prompt: ""
        )

        let retrievedData = try record.getAudioData()
        XCTAssertEqual(retrievedData, audioData)
    }

    func testGeneratedAudioRecord_GetAudioData_NoDataAndNoFile() {
        let record = GeneratedAudioRecord(
            providerId: "elevenlabs",
            requestorID: "elevenlabs.audio.tts",
            audioData: nil,
            format: "mp3",
            voiceID: "test",
            voiceName: "Test",
            prompt: ""
        )

        XCTAssertThrowsError(try record.getAudioData()) { error in
            guard let typedError = error as? TypedDataError,
                  case .fileOperationFailed = typedError else {
                XCTFail("Expected fileOperationFailed error")
                return
            }
        }
    }

    func testGeneratedAudioRecord_FileSize() {
        let audioData = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let record = GeneratedAudioRecord(
            providerId: "elevenlabs",
            requestorID: "elevenlabs.audio.tts",
            audioData: audioData,
            format: "mp3",
            voiceID: "test",
            voiceName: "Test",
            prompt: ""
        )

        XCTAssertEqual(record.fileSize, 5)
    }

    func testGeneratedAudioRecord_Description() {
        let record = GeneratedAudioRecord(
            providerId: "elevenlabs",
            requestorID: "elevenlabs.audio.tts",
            audioData: Data([0x01]),
            format: "mp3",
            durationSeconds: 5.5,
            voiceID: "test",
            voiceName: "Rachel",
            prompt: ""
        )

        let description = record.description
        XCTAssertTrue(description.contains("GeneratedAudioRecord"))
        XCTAssertTrue(description.contains("Rachel"))
        XCTAssertTrue(description.contains("5.5s"))
        XCTAssertTrue(description.contains("memory"))
    }

    // MARK: - ElevenLabsAudioRequestor Tests

    func testElevenLabsAudioRequestor_Initialization() {
        let provider = ElevenLabsProvider.shared()
        let requestor = ElevenLabsAudioRequestor(provider: provider)

        XCTAssertEqual(requestor.requestorID, "elevenlabs.audio.tts")
        XCTAssertEqual(requestor.displayName, "ElevenLabs Text-to-Speech")
        XCTAssertEqual(requestor.providerID, "elevenlabs")
        XCTAssertEqual(requestor.category, .audio)
        XCTAssertEqual(requestor.outputFileType.mimeType, "audio/mpeg")
    }

    func testElevenLabsAudioRequestor_DefaultConfiguration() {
        let provider = ElevenLabsProvider.shared()
        let requestor = ElevenLabsAudioRequestor(provider: provider)

        let config = requestor.defaultConfiguration()

        XCTAssertEqual(config.voiceID, "21m00Tcm4TlvDq8ikWAM")
        XCTAssertEqual(config.voiceName, "Rachel")
        XCTAssertEqual(config.stability, 0.5)
        XCTAssertEqual(config.similarityBoost, 0.75)
    }

    func testElevenLabsAudioRequestor_ValidateConfiguration_Valid() {
        let provider = ElevenLabsProvider.shared()
        let requestor = ElevenLabsAudioRequestor(provider: provider)

        let config = AudioGenerationConfig(
            voiceID: "test-voice",
            voiceName: "Test Voice",
            stability: 0.5,
            similarityBoost: 0.75
        )

        XCTAssertNoThrow(try requestor.validateConfiguration(config))
    }

    func testElevenLabsAudioRequestor_ValidateConfiguration_EmptyVoiceID() {
        let provider = ElevenLabsProvider.shared()
        let requestor = ElevenLabsAudioRequestor(provider: provider)

        let config = AudioGenerationConfig(
            voiceID: "",
            voiceName: "Test Voice"
        )

        XCTAssertThrowsError(try requestor.validateConfiguration(config)) { error in
            guard let serviceError = error as? AIServiceError,
                  case .configurationError = serviceError else {
                XCTFail("Expected configurationError")
                return
            }
        }
    }

    func testElevenLabsAudioRequestor_ValidateConfiguration_InvalidStability() {
        let provider = ElevenLabsProvider.shared()
        let requestor = ElevenLabsAudioRequestor(provider: provider)

        let config = AudioGenerationConfig(
            voiceID: "test-voice",
            voiceName: "Test Voice",
            stability: 1.5 // Invalid: > 1.0
        )

        XCTAssertThrowsError(try requestor.validateConfiguration(config)) { error in
            guard let serviceError = error as? AIServiceError,
                  case .configurationError = serviceError else {
                XCTFail("Expected configurationError")
                return
            }
        }
    }

    func testElevenLabsAudioRequestor_ValidateConfiguration_InvalidSimilarityBoost() {
        let provider = ElevenLabsProvider.shared()
        let requestor = ElevenLabsAudioRequestor(provider: provider)

        let config = AudioGenerationConfig(
            voiceID: "test-voice",
            voiceName: "Test Voice",
            similarityBoost: -0.1 // Invalid: < 0.0
        )

        XCTAssertThrowsError(try requestor.validateConfiguration(config)) { error in
            guard let serviceError = error as? AIServiceError,
                  case .configurationError = serviceError else {
                XCTFail("Expected configurationError")
                return
            }
        }
    }

    func testElevenLabsAudioRequestor_ValidateConfiguration_EmptyModelID() {
        let provider = ElevenLabsProvider.shared()
        let requestor = ElevenLabsAudioRequestor(provider: provider)

        let config = AudioGenerationConfig(
            voiceID: "test-voice",
            voiceName: "Test Voice",
            modelID: ""
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

    func testElevenLabsAudioRequestor_SmallAudioStoredInMemory() async {
        // Small audio (<100KB threshold) should be stored in-memory
        let provider = ElevenLabsProvider.shared()
        let requestor = ElevenLabsAudioRequestor(provider: provider)
        let config = AudioGenerationConfig.default

        // Create small audio data (10KB)
        let smallAudioData = Data(repeating: 0xFF, count: 10_000)

        // Note: This test would need a mock provider to inject the audio data
        // For now, we're testing the threshold logic conceptually
        let shouldStoreAsFile = requestor.outputFileType.shouldStoreAsFile(estimatedSize: Int64(smallAudioData.count))

        XCTAssertFalse(shouldStoreAsFile, "Small audio (<100KB) should be stored in-memory")
    }

    func testElevenLabsAudioRequestor_LargeAudioStoredAsFile() async {
        // Large audio (>=100KB threshold) should be written to file
        let provider = ElevenLabsProvider.shared()
        let requestor = ElevenLabsAudioRequestor(provider: provider)
        let config = AudioGenerationConfig.default

        // Create large audio data (1MB)
        let largeAudioData = Data(repeating: 0xFF, count: 1_000_000)

        let shouldStoreAsFile = requestor.outputFileType.shouldStoreAsFile(estimatedSize: Int64(largeAudioData.count))

        XCTAssertTrue(shouldStoreAsFile, "Large audio (>=100KB) should be stored as file")
    }

    func testElevenLabsAudioRequestor_ThresholdBoundary() async {
        let provider = ElevenLabsProvider.shared()
        let requestor = ElevenLabsAudioRequestor(provider: provider)

        // Test at threshold (100KB)
        let thresholdData = Data(repeating: 0xFF, count: 100_000)
        let atThreshold = requestor.outputFileType.shouldStoreAsFile(estimatedSize: Int64(thresholdData.count))
        XCTAssertTrue(atThreshold, "Audio at threshold (100KB) should be stored as file")

        // Test just below threshold
        let belowThresholdData = Data(repeating: 0xFF, count: 99_999)
        let belowThreshold = requestor.outputFileType.shouldStoreAsFile(estimatedSize: Int64(belowThresholdData.count))
        XCTAssertFalse(belowThreshold, "Audio below threshold should be in-memory")
    }

    // MARK: - Provider Integration Tests

    func testElevenLabsProvider_AvailableRequestors() {
        let provider = ElevenLabsProvider.shared()
        let requestors = provider.availableRequestors()

        XCTAssertEqual(requestors.count, 1)
        XCTAssertTrue(requestors.allSatisfy { $0.category == .audio })
        XCTAssertTrue(requestors.allSatisfy { $0.providerID == "elevenlabs" })
        XCTAssertEqual(requestors.first?.requestorID, "elevenlabs.audio.tts")
    }
}
