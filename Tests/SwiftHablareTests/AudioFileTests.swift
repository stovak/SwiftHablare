//
//  AudioFileTests.swift
//  SwiftHablareTests
//
//  Tests for the AudioFile model
//

import XCTest
import SwiftData
@testable import SwiftHablare

final class AudioFileTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        // Create an in-memory model container for testing
        let schema = Schema([AudioFile.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
    }

    // MARK: - Initialization Tests

    func testAudioFileInitialization() {
        let audioData = Data([0x01, 0x02, 0x03])
        let audioFile = AudioFile(
            text: "Hello, world!",
            voiceId: "test-voice",
            providerId: "test-provider",
            audioData: audioData,
            audioFormat: "mp3",
            duration: 2.5,
            sampleRate: 44100,
            bitRate: 128,
            channels: 2
        )

        XCTAssertNotNil(audioFile.id)
        XCTAssertEqual(audioFile.text, "Hello, world!")
        XCTAssertEqual(audioFile.voiceId, "test-voice")
        XCTAssertEqual(audioFile.providerId, "test-provider")
        XCTAssertEqual(audioFile.audioData, audioData)
        XCTAssertEqual(audioFile.audioFormat, "mp3")
        XCTAssertEqual(audioFile.duration, 2.5)
        XCTAssertEqual(audioFile.sampleRate, 44100)
        XCTAssertEqual(audioFile.bitRate, 128)
        XCTAssertEqual(audioFile.channels, 2)
        XCTAssertNotNil(audioFile.createdAt)
        XCTAssertNotNil(audioFile.modifiedAt)
    }

    func testAudioFileInitializationWithMinimalData() {
        let audioData = Data([0x01])
        let audioFile = AudioFile(
            text: "Test",
            voiceId: "voice",
            providerId: "provider",
            audioData: audioData,
            audioFormat: "m4a"
        )

        XCTAssertNotNil(audioFile.id)
        XCTAssertEqual(audioFile.text, "Test")
        XCTAssertNil(audioFile.duration)
        XCTAssertNil(audioFile.sampleRate)
        XCTAssertNil(audioFile.bitRate)
        XCTAssertNil(audioFile.channels)
    }

    func testAudioFileCustomId() {
        let customId = UUID()
        let audioFile = AudioFile(
            id: customId,
            text: "Custom ID test",
            voiceId: "voice",
            providerId: "provider",
            audioData: Data(),
            audioFormat: "caf"
        )

        XCTAssertEqual(audioFile.id, customId)
    }

    func testAudioFileCustomDates() {
        let createdDate = Date(timeIntervalSince1970: 1000000)
        let modifiedDate = Date(timeIntervalSince1970: 2000000)

        let audioFile = AudioFile(
            text: "Date test",
            voiceId: "voice",
            providerId: "provider",
            audioData: Data(),
            audioFormat: "mp3",
            createdAt: createdDate,
            modifiedAt: modifiedDate
        )

        XCTAssertEqual(audioFile.createdAt, createdDate)
        XCTAssertEqual(audioFile.modifiedAt, modifiedDate)
    }

    // MARK: - SwiftData Persistence Tests

    func testAudioFilePersistence() throws {
        let audioData = Data([0x01, 0x02, 0x03, 0x04])
        let audioFile = AudioFile(
            text: "Persist test",
            voiceId: "voice-1",
            providerId: "provider-1",
            audioData: audioData,
            audioFormat: "mp3"
        )

        modelContext.insert(audioFile)
        try modelContext.save()

        let descriptor = FetchDescriptor<AudioFile>(
            predicate: #Predicate { $0.text == "Persist test" }
        )
        let fetched = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.voiceId, "voice-1")
        XCTAssertEqual(fetched.first?.audioData, audioData)
    }

    func testAudioFileUniqueness() throws {
        let id = UUID()
        let audioFile1 = AudioFile(
            id: id,
            text: "First",
            voiceId: "voice",
            providerId: "provider",
            audioData: Data([0x01]),
            audioFormat: "mp3"
        )

        let audioFile2 = AudioFile(
            id: id,
            text: "Second",
            voiceId: "voice",
            providerId: "provider",
            audioData: Data([0x02]),
            audioFormat: "mp3"
        )

        modelContext.insert(audioFile1)
        try modelContext.save()

        modelContext.insert(audioFile2)

        // SwiftData should handle uniqueness constraint on id
        do {
            try modelContext.save()
            // If save succeeds, verify only one exists
            let descriptor = FetchDescriptor<AudioFile>()
            let all = try modelContext.fetch(descriptor)
            XCTAssertEqual(all.count, 1)
        } catch {
            // Expected if uniqueness constraint is enforced
            XCTAssertTrue(true)
        }
    }

    func testAudioFileDeletion() throws {
        let audioFile = AudioFile(
            text: "Delete test",
            voiceId: "voice",
            providerId: "provider",
            audioData: Data([0x01]),
            audioFormat: "mp3"
        )

        modelContext.insert(audioFile)
        try modelContext.save()

        let id = audioFile.id
        modelContext.delete(audioFile)
        try modelContext.save()

        let descriptor = FetchDescriptor<AudioFile>(
            predicate: #Predicate { $0.id == id }
        )
        let fetched = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetched.count, 0)
    }

    // MARK: - Query Tests

    func testAudioFileQueryByVoiceId() throws {
        let audio1 = AudioFile(
            text: "Text 1",
            voiceId: "voice-a",
            providerId: "provider",
            audioData: Data([0x01]),
            audioFormat: "mp3"
        )

        let audio2 = AudioFile(
            text: "Text 2",
            voiceId: "voice-b",
            providerId: "provider",
            audioData: Data([0x02]),
            audioFormat: "mp3"
        )

        let audio3 = AudioFile(
            text: "Text 3",
            voiceId: "voice-a",
            providerId: "provider",
            audioData: Data([0x03]),
            audioFormat: "mp3"
        )

        modelContext.insert(audio1)
        modelContext.insert(audio2)
        modelContext.insert(audio3)
        try modelContext.save()

        let descriptor = FetchDescriptor<AudioFile>(
            predicate: #Predicate { $0.voiceId == "voice-a" }
        )
        let voiceAFiles = try modelContext.fetch(descriptor)

        XCTAssertEqual(voiceAFiles.count, 2)
        XCTAssertTrue(voiceAFiles.contains { $0.text == "Text 1" })
        XCTAssertTrue(voiceAFiles.contains { $0.text == "Text 3" })
    }

    func testAudioFileQueryByProviderId() throws {
        let audio1 = AudioFile(
            text: "Provider 1 text",
            voiceId: "voice",
            providerId: "provider-1",
            audioData: Data([0x01]),
            audioFormat: "mp3"
        )

        let audio2 = AudioFile(
            text: "Provider 2 text",
            voiceId: "voice",
            providerId: "provider-2",
            audioData: Data([0x02]),
            audioFormat: "mp3"
        )

        modelContext.insert(audio1)
        modelContext.insert(audio2)
        try modelContext.save()

        let descriptor = FetchDescriptor<AudioFile>(
            predicate: #Predicate { $0.providerId == "provider-1" }
        )
        let provider1Files = try modelContext.fetch(descriptor)

        XCTAssertEqual(provider1Files.count, 1)
        XCTAssertEqual(provider1Files.first?.text, "Provider 1 text")
    }

    func testAudioFileQueryByTextAndVoiceAndProvider() throws {
        let audio1 = AudioFile(
            text: "Unique text",
            voiceId: "voice-1",
            providerId: "provider-1",
            audioData: Data([0x01]),
            audioFormat: "mp3"
        )

        let audio2 = AudioFile(
            text: "Unique text",
            voiceId: "voice-1",
            providerId: "provider-2",
            audioData: Data([0x02]),
            audioFormat: "mp3"
        )

        modelContext.insert(audio1)
        modelContext.insert(audio2)
        try modelContext.save()

        let descriptor = FetchDescriptor<AudioFile>(
            predicate: #Predicate {
                $0.text == "Unique text" &&
                $0.voiceId == "voice-1" &&
                $0.providerId == "provider-1"
            }
        )
        let matchingFiles = try modelContext.fetch(descriptor)

        XCTAssertEqual(matchingFiles.count, 1)
        XCTAssertEqual(matchingFiles.first?.providerId, "provider-1")
    }

    func testAudioFileSortedByCreatedDate() throws {
        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)
        let date3 = Date(timeIntervalSince1970: 3000)

        let audio3 = AudioFile(
            text: "Third",
            voiceId: "voice",
            providerId: "provider",
            audioData: Data([0x03]),
            audioFormat: "mp3",
            createdAt: date3
        )

        let audio1 = AudioFile(
            text: "First",
            voiceId: "voice",
            providerId: "provider",
            audioData: Data([0x01]),
            audioFormat: "mp3",
            createdAt: date1
        )

        let audio2 = AudioFile(
            text: "Second",
            voiceId: "voice",
            providerId: "provider",
            audioData: Data([0x02]),
            audioFormat: "mp3",
            createdAt: date2
        )

        modelContext.insert(audio3)
        modelContext.insert(audio1)
        modelContext.insert(audio2)
        try modelContext.save()

        let descriptor = FetchDescriptor<AudioFile>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let sortedFiles = try modelContext.fetch(descriptor)

        XCTAssertEqual(sortedFiles.count, 3)
        XCTAssertEqual(sortedFiles[0].text, "First")
        XCTAssertEqual(sortedFiles[1].text, "Second")
        XCTAssertEqual(sortedFiles[2].text, "Third")
    }

    // MARK: - Audio Format Tests

    func testAudioFileFormats() throws {
        let formats = ["mp3", "m4a", "caf", "wav", "aac"]

        for format in formats {
            let audioFile = AudioFile(
                text: "Format test",
                voiceId: "voice",
                providerId: "provider",
                audioData: Data([0x01]),
                audioFormat: format
            )

            XCTAssertEqual(audioFile.audioFormat, format)
        }
    }

    // MARK: - Audio Metadata Tests

    func testAudioFileWithCompleteMetadata() {
        let audioFile = AudioFile(
            text: "Complete metadata test",
            voiceId: "voice",
            providerId: "provider",
            audioData: Data([0x01, 0x02]),
            audioFormat: "mp3",
            duration: 5.75,
            sampleRate: 48000,
            bitRate: 320,
            channels: 2
        )

        XCTAssertEqual(audioFile.duration, 5.75)
        XCTAssertEqual(audioFile.sampleRate, 48000)
        XCTAssertEqual(audioFile.bitRate, 320)
        XCTAssertEqual(audioFile.channels, 2)
    }

    func testAudioFileMonoVsStereo() {
        let mono = AudioFile(
            text: "Mono",
            voiceId: "voice",
            providerId: "provider",
            audioData: Data(),
            audioFormat: "mp3",
            channels: 1
        )

        let stereo = AudioFile(
            text: "Stereo",
            voiceId: "voice",
            providerId: "provider",
            audioData: Data(),
            audioFormat: "mp3",
            channels: 2
        )

        XCTAssertEqual(mono.channels, 1)
        XCTAssertEqual(stereo.channels, 2)
    }

    // MARK: - Empty Data Tests

    func testAudioFileWithEmptyData() {
        let audioFile = AudioFile(
            text: "Empty data",
            voiceId: "voice",
            providerId: "provider",
            audioData: Data(),
            audioFormat: "mp3"
        )

        XCTAssertTrue(audioFile.audioData.isEmpty)
    }

    func testAudioFileWithLargeData() {
        let largeData = Data(repeating: 0x42, count: 1024 * 1024) // 1 MB
        let audioFile = AudioFile(
            text: "Large data test",
            voiceId: "voice",
            providerId: "provider",
            audioData: largeData,
            audioFormat: "mp3"
        )

        XCTAssertEqual(audioFile.audioData.count, 1024 * 1024)
    }
}
