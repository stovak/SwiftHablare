//
//  VoiceModelsTests.swift
//  SwiftHablareTests
//
//  Phase 3: Tests for Voice, VoiceModel, and AudioFile models
//

import XCTest
import SwiftData
@testable import SwiftHablare

final class VoiceModelsTests: XCTestCase {

    // MARK: - Voice Tests

    func testVoiceInitialization() {
        // WHEN
        let voice = Voice(
            id: "voice-123",
            name: "Test Voice",
            description: "A test voice",
            providerId: "elevenlabs",
            language: "en-US",
            locality: "US",
            gender: "female"
        )

        // THEN
        XCTAssertEqual(voice.id, "voice-123")
        XCTAssertEqual(voice.name, "Test Voice")
        XCTAssertEqual(voice.description, "A test voice")
        XCTAssertEqual(voice.providerId, "elevenlabs")
        XCTAssertEqual(voice.language, "en-US")
        XCTAssertEqual(voice.locality, "US")
        XCTAssertEqual(voice.gender, "female")
    }

    func testVoiceInitializationWithDefaults() {
        // WHEN
        let voice = Voice(
            id: "voice-123",
            name: "Test Voice",
            description: nil
        )

        // THEN
        XCTAssertEqual(voice.id, "voice-123")
        XCTAssertEqual(voice.name, "Test Voice")
        XCTAssertNil(voice.description)
        XCTAssertEqual(voice.providerId, "elevenlabs", "Should default to elevenlabs")
        XCTAssertNil(voice.language)
        XCTAssertNil(voice.locality)
        XCTAssertNil(voice.gender)
    }

    func testVoiceCodable() throws {
        // GIVEN
        let voice = Voice(
            id: "voice-123",
            name: "Test Voice",
            description: "Test description",
            providerId: "elevenlabs",
            language: "en-US",
            locality: "US",
            gender: "female"
        )

        // WHEN - Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(voice)

        // THEN - Decode
        let decoder = JSONDecoder()
        let decodedVoice = try decoder.decode(Voice.self, from: data)

        XCTAssertEqual(decodedVoice.id, voice.id)
        XCTAssertEqual(decodedVoice.name, voice.name)
        XCTAssertEqual(decodedVoice.description, voice.description)
        XCTAssertEqual(decodedVoice.language, voice.language)
        XCTAssertEqual(decodedVoice.locality, voice.locality)
        XCTAssertEqual(decodedVoice.gender, voice.gender)
    }

    func testVoiceDecodingWithCustomKeys() throws {
        // GIVEN - JSON with voice_id instead of id
        let json = """
        {
            "voice_id": "voice-123",
            "name": "Test Voice",
            "description": "Test description",
            "language": "en-US",
            "gender": "female"
        }
        """
        let data = json.data(using: .utf8)!

        // WHEN
        let decoder = JSONDecoder()
        let voice = try decoder.decode(Voice.self, from: data)

        // THEN
        XCTAssertEqual(voice.id, "voice-123")
        XCTAssertEqual(voice.name, "Test Voice")
        XCTAssertEqual(voice.description, "Test description")
        XCTAssertEqual(voice.providerId, "elevenlabs", "Should default to elevenlabs when decoding")
        XCTAssertEqual(voice.language, "en-US")
        XCTAssertEqual(voice.gender, "female")
    }

    func testVoiceIdentifiable() {
        // GIVEN
        let voice = Voice(
            id: "voice-123",
            name: "Test Voice",
            description: nil
        )

        // THEN
        XCTAssertEqual(voice.id, "voice-123", "Identifiable.id should match voice id")
    }

    // MARK: - VoiceModel Tests

    @MainActor
    func testVoiceModelInitialization() throws {
        // GIVEN
        let schema = Schema([VoiceModel.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        // WHEN
        let voiceModel = VoiceModel(
            voiceId: "voice-123",
            name: "Test Voice",
            voiceDescription: "A test voice",
            providerId: "elevenlabs",
            language: "en-US",
            locality: "US",
            gender: "female"
        )

        context.insert(voiceModel)
        try context.save()

        // THEN
        XCTAssertEqual(voiceModel.voiceId, "voice-123")
        XCTAssertEqual(voiceModel.name, "Test Voice")
        XCTAssertEqual(voiceModel.voiceDescription, "A test voice")
        XCTAssertEqual(voiceModel.providerId, "elevenlabs")
        XCTAssertEqual(voiceModel.language, "en-US")
        XCTAssertEqual(voiceModel.locality, "US")
        XCTAssertEqual(voiceModel.gender, "female")
        XCTAssertNotNil(voiceModel.lastFetched)
    }

    @MainActor
    func testVoiceModelFromVoice() throws {
        // GIVEN
        let voice = Voice(
            id: "voice-123",
            name: "Test Voice",
            description: "Test description",
            providerId: "elevenlabs",
            language: "en-US",
            locality: "US",
            gender: "female"
        )

        // WHEN
        let voiceModel = VoiceModel.from(voice)

        // THEN
        XCTAssertEqual(voiceModel.voiceId, voice.id)
        XCTAssertEqual(voiceModel.name, voice.name)
        XCTAssertEqual(voiceModel.voiceDescription, voice.description)
        XCTAssertEqual(voiceModel.providerId, voice.providerId)
        XCTAssertEqual(voiceModel.language, voice.language)
        XCTAssertEqual(voiceModel.locality, voice.locality)
        XCTAssertEqual(voiceModel.gender, voice.gender)
    }

    @MainActor
    func testVoiceModelToVoice() {
        // GIVEN
        let voiceModel = VoiceModel(
            voiceId: "voice-123",
            name: "Test Voice",
            voiceDescription: "Test description",
            providerId: "elevenlabs",
            language: "en-US",
            locality: "US",
            gender: "female"
        )

        // WHEN
        let voice = voiceModel.toVoice()

        // THEN
        XCTAssertEqual(voice.id, voiceModel.voiceId)
        XCTAssertEqual(voice.name, voiceModel.name)
        XCTAssertEqual(voice.description, voiceModel.voiceDescription)
        XCTAssertEqual(voice.providerId, voiceModel.providerId)
        XCTAssertEqual(voice.language, voiceModel.language)
        XCTAssertEqual(voice.locality, voiceModel.locality)
        XCTAssertEqual(voice.gender, voiceModel.gender)
    }

    @MainActor
    func testVoiceModelRoundTrip() {
        // GIVEN
        let originalVoice = Voice(
            id: "voice-123",
            name: "Test Voice",
            description: "Test description",
            providerId: "elevenlabs",
            language: "en-US",
            locality: "US",
            gender: "female"
        )

        // WHEN - Convert to model and back
        let voiceModel = VoiceModel.from(originalVoice)
        let convertedVoice = voiceModel.toVoice()

        // THEN
        XCTAssertEqual(convertedVoice.id, originalVoice.id)
        XCTAssertEqual(convertedVoice.name, originalVoice.name)
        XCTAssertEqual(convertedVoice.description, originalVoice.description)
        XCTAssertEqual(convertedVoice.providerId, originalVoice.providerId)
        XCTAssertEqual(convertedVoice.language, originalVoice.language)
        XCTAssertEqual(convertedVoice.locality, originalVoice.locality)
        XCTAssertEqual(convertedVoice.gender, originalVoice.gender)
    }

    // MARK: - AudioFile Tests

    @MainActor
    func testAudioFileInitialization() throws {
        // GIVEN
        let schema = Schema([AudioFile.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let audioData = Data("test audio data".utf8)

        // WHEN
        let audioFile = AudioFile(
            text: "Hello world",
            voiceId: "voice-123",
            providerId: "elevenlabs",
            audioData: audioData,
            audioFormat: "mp3",
            duration: 2.5,
            sampleRate: 44100,
            bitRate: 128,
            channels: 2
        )

        context.insert(audioFile)
        try context.save()

        // THEN
        XCTAssertNotNil(audioFile.id)
        XCTAssertEqual(audioFile.text, "Hello world")
        XCTAssertEqual(audioFile.voiceId, "voice-123")
        XCTAssertEqual(audioFile.providerId, "elevenlabs")
        XCTAssertEqual(audioFile.audioData, audioData)
        XCTAssertEqual(audioFile.audioFormat, "mp3")
        XCTAssertEqual(audioFile.duration, 2.5)
        XCTAssertEqual(audioFile.sampleRate, 44100)
        XCTAssertEqual(audioFile.bitRate, 128)
        XCTAssertEqual(audioFile.channels, 2)
        XCTAssertNotNil(audioFile.createdAt)
        XCTAssertNotNil(audioFile.modifiedAt)
    }

    @MainActor
    func testAudioFileWithDefaults() throws {
        // GIVEN
        let schema = Schema([AudioFile.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let audioData = Data("test".utf8)

        // WHEN - Initialize with minimal parameters
        let audioFile = AudioFile(
            text: "Test",
            voiceId: "voice-1",
            providerId: "test",
            audioData: audioData,
            audioFormat: "mp3"
        )

        context.insert(audioFile)
        try context.save()

        // THEN - Check defaults
        XCTAssertNil(audioFile.duration)
        XCTAssertNil(audioFile.sampleRate)
        XCTAssertNil(audioFile.bitRate)
        XCTAssertNil(audioFile.channels)
    }

    @MainActor
    func testAudioFileUniqueness() throws {
        // GIVEN
        let schema = Schema([AudioFile.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let audioData = Data("test".utf8)

        let audioFile1 = AudioFile(
            text: "Test",
            voiceId: "voice-1",
            providerId: "test",
            audioData: audioData,
            audioFormat: "mp3"
        )

        let audioFile2 = AudioFile(
            text: "Test",
            voiceId: "voice-1",
            providerId: "test",
            audioData: audioData,
            audioFormat: "mp3"
        )

        context.insert(audioFile1)
        context.insert(audioFile2)
        try context.save()

        // THEN - IDs should be unique even with same content
        XCTAssertNotEqual(audioFile1.id, audioFile2.id, "Each AudioFile should have unique ID")
    }

    @MainActor
    func testAudioFileQueryByText() throws {
        // GIVEN
        let schema = Schema([AudioFile.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let audioData = Data("test".utf8)

        let audioFile = AudioFile(
            text: "Hello world",
            voiceId: "voice-123",
            providerId: "elevenlabs",
            audioData: audioData,
            audioFormat: "mp3"
        )

        context.insert(audioFile)
        try context.save()

        // WHEN
        let descriptor = FetchDescriptor<AudioFile>(
            predicate: #Predicate<AudioFile> { audio in
                audio.text == "Hello world"
            }
        )
        let results = try context.fetch(descriptor)

        // THEN
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.text, "Hello world")
    }

    @MainActor
    func testAudioFileQueryByVoiceAndProvider() throws {
        // GIVEN
        let schema = Schema([AudioFile.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let audioData = Data("test".utf8)

        let audioFile1 = AudioFile(
            text: "Test 1",
            voiceId: "voice-123",
            providerId: "elevenlabs",
            audioData: audioData,
            audioFormat: "mp3"
        )

        let audioFile2 = AudioFile(
            text: "Test 2",
            voiceId: "voice-456",
            providerId: "elevenlabs",
            audioData: audioData,
            audioFormat: "mp3"
        )

        let audioFile3 = AudioFile(
            text: "Test 3",
            voiceId: "voice-123",
            providerId: "apple",
            audioData: audioData,
            audioFormat: "m4a"
        )

        context.insert(audioFile1)
        context.insert(audioFile2)
        context.insert(audioFile3)
        try context.save()

        // WHEN - Query for specific voice and provider
        let descriptor = FetchDescriptor<AudioFile>(
            predicate: #Predicate<AudioFile> { audio in
                audio.voiceId == "voice-123" && audio.providerId == "elevenlabs"
            }
        )
        let results = try context.fetch(descriptor)

        // THEN
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.text, "Test 1")
    }
}
