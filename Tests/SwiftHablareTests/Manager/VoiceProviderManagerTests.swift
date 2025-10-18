//
//  VoiceProviderManagerTests.swift
//  SwiftHablareTests
//
//  Phase 3: Tests for VoiceProviderManager
//

import XCTest
import SwiftData
@testable import SwiftHablare

@MainActor
final class VoiceProviderManagerTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var manager: VoiceProviderManager!

    override func setUp() async throws {
        // Create in-memory container
        let schema = Schema([
            VoiceModel.self,
            AudioFile.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)

        manager = VoiceProviderManager(modelContext: context)
    }

    override func tearDown() async throws {
        manager = nil
        context = nil
        container = nil

        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "selectedVoiceProvider")
    }

    // MARK: - Initialization Tests

    func testInitializationWithDefaultProvider() {
        // THEN
        XCTAssertEqual(manager.currentProviderType, .elevenlabs, "Should default to ElevenLabs")
        XCTAssertNil(manager.lastError)
    }

    func testInitializationWithSavedProvider() {
        // GIVEN
        UserDefaults.standard.set("apple", forKey: "selectedVoiceProvider")

        // WHEN
        let newManager = VoiceProviderManager(modelContext: context)

        // THEN
        XCTAssertEqual(newManager.currentProviderType, .apple, "Should load saved provider")
    }

    func testProviderRegistration() {
        // WHEN
        let mockProvider = MockVoiceProvider(providerId: "custom-provider")
        manager.registerProvider(mockProvider)

        // THEN
        let retrieved = manager.getProvider(for: "custom-provider")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.providerId, "custom-provider")
    }

    // MARK: - Provider Management Tests

    func testGetCurrentProvider() {
        // GIVEN
        manager.currentProviderType = .elevenlabs

        // WHEN
        let provider = manager.getCurrentProvider()

        // THEN
        XCTAssertNotNil(provider)
        XCTAssertEqual(provider?.providerId, "elevenlabs")
    }

    func testGetProviderByID() {
        // WHEN
        let elevenLabsProvider = manager.getProvider(for: "elevenlabs")
        let appleProvider = manager.getProvider(for: "apple")
        let nonExistentProvider = manager.getProvider(for: "nonexistent")

        // THEN
        XCTAssertNotNil(elevenLabsProvider)
        XCTAssertNotNil(appleProvider)
        XCTAssertNil(nonExistentProvider)
    }

    func testSwitchProvider() {
        // GIVEN
        manager.currentProviderType = .elevenlabs
        manager.lastError = "Some error"

        // WHEN
        manager.switchProvider(to: .apple)

        // THEN
        XCTAssertEqual(manager.currentProviderType, .apple)
        XCTAssertNil(manager.lastError, "Should clear error when switching")

        // Verify UserDefaults was updated
        let saved = UserDefaults.standard.string(forKey: "selectedVoiceProvider")
        XCTAssertEqual(saved, "apple")
    }

    func testGetAvailableProviders() {
        // WHEN
        let providers = manager.getAvailableProviders()

        // THEN
        XCTAssertEqual(providers.count, 2, "Should have 2 providers (ElevenLabs and Apple)")
        XCTAssertTrue(providers.contains(.elevenlabs))
        XCTAssertTrue(providers.contains(.apple))
    }

    // MARK: - Configuration Tests

    func testIsCurrentProviderConfigured() {
        // WHEN - Apple provider is always configured (system voices)
        manager.currentProviderType = .apple
        let appleConfigured = manager.isCurrentProviderConfigured()

        // THEN
        XCTAssertTrue(appleConfigured, "Apple provider should be configured")
    }

    // MARK: - Voice Fetching Tests

    func testGetVoicesWithoutCache() async throws {
        // GIVEN - Use Apple provider since it doesn't require API key
        manager.currentProviderType = .apple

        // WHEN
        let voices = try await manager.getVoices(forceRefresh: false)

        // THEN
        XCTAssertFalse(voices.isEmpty, "Should fetch voices from Apple provider")
        XCTAssertNil(manager.lastError)

        // Verify voices were cached
        let descriptor = FetchDescriptor<VoiceModel>(
            predicate: #Predicate<VoiceModel> { voice in
                voice.providerId == "apple"
            }
        )
        let cachedVoices = try context.fetch(descriptor)
        XCTAssertEqual(cachedVoices.count, voices.count, "Should cache all voices")
    }

    func testGetVoicesWithCache() async throws {
        // GIVEN - Pre-cache some voices
        manager.currentProviderType = .apple
        let voice1 = VoiceModel(
            voiceId: "test1",
            name: "Test Voice 1",
            voiceDescription: "Test",
            providerId: "apple"
        )
        let voice2 = VoiceModel(
            voiceId: "test2",
            name: "Test Voice 2",
            voiceDescription: "Test",
            providerId: "apple"
        )
        context.insert(voice1)
        context.insert(voice2)
        try context.save()

        // WHEN
        let voices = try await manager.getVoices(forceRefresh: false)

        // THEN - Should return cached voices (2) instead of fetching from provider
        XCTAssertEqual(voices.count, 2, "Should return cached voices")
        XCTAssertTrue(voices.contains { $0.id == "test1" })
        XCTAssertTrue(voices.contains { $0.id == "test2" })
    }

    func testGetVoicesWithForceRefresh() async throws {
        // GIVEN - Pre-cache some voices
        manager.currentProviderType = .apple
        let voice1 = VoiceModel(
            voiceId: "cached1",
            name: "Cached Voice",
            voiceDescription: "Old cache",
            providerId: "apple"
        )
        context.insert(voice1)
        try context.save()

        // WHEN - Force refresh
        let voices = try await manager.getVoices(forceRefresh: true)

        // THEN - Should fetch from provider (which will have different voices)
        XCTAssertFalse(voices.isEmpty)
        // Old cached voice should be replaced
        let descriptor = FetchDescriptor<VoiceModel>(
            predicate: #Predicate<VoiceModel> { voice in
                voice.providerId == "apple"
            }
        )
        let cachedVoices = try context.fetch(descriptor)
        XCTAssertFalse(cachedVoices.contains { $0.voiceId == "cached1" }, "Old cache should be cleared")
    }

    func testGetVoicesErrorHandling() async {
        // GIVEN - Mock provider that returns error
        let mockProvider = MockVoiceProvider(providerId: "apple")
        mockProvider.setShouldThrowOnFetchVoices(true)
        manager.registerProvider(mockProvider)
        manager.currentProviderType = .apple

        // WHEN/THEN
        do {
            _ = try await manager.getVoices()
            XCTFail("Should throw error")
        } catch {
            // Expected error
            XCTAssertNotNil(manager.lastError)
        }
    }

    // MARK: - Audio Generation Tests

    func testGenerateAudio() async throws {
        // GIVEN - Use mock provider
        let mockProvider = MockVoiceProvider(
            providerId: "apple",
            audioData: Data("test audio".utf8)
        )
        manager.registerProvider(mockProvider)
        manager.currentProviderType = .apple

        // WHEN
        let audioData = try await manager.generateAudio(text: "Hello", voiceId: "test-voice")

        // THEN
        XCTAssertEqual(audioData, Data("test audio".utf8))
    }

    func testGenerateAndCacheAudio() async throws {
        // GIVEN - Use mock provider
        let mockProvider = MockVoiceProvider(
            providerId: "apple",
            audioData: Data("test audio".utf8),
            estimatedDuration: 2.5
        )
        manager.registerProvider(mockProvider)

        // WHEN
        let audioFile = try await manager.generateAndCacheAudio(
            text: "Hello world",
            voiceId: "test-voice",
            providerId: "apple",
            audioFormat: "mp3"
        )

        // THEN
        XCTAssertEqual(audioFile.text, "Hello world")
        XCTAssertEqual(audioFile.voiceId, "test-voice")
        XCTAssertEqual(audioFile.providerId, "apple")
        XCTAssertEqual(audioFile.audioData, Data("test audio".utf8))
        XCTAssertEqual(audioFile.audioFormat, "mp3")
        XCTAssertEqual(audioFile.duration, 2.5)

        // Verify it was saved to context
        let descriptor = FetchDescriptor<AudioFile>(
            predicate: #Predicate<AudioFile> { audio in
                audio.text == "Hello world"
            }
        )
        let cached = try context.fetch(descriptor)
        XCTAssertEqual(cached.count, 1)
    }

    func testGenerateAndCacheAudioUsesCache() async throws {
        // GIVEN - Pre-cache audio
        let cachedAudio = AudioFile(
            text: "Cached text",
            voiceId: "voice1",
            providerId: "apple",
            audioData: Data("cached audio".utf8),
            audioFormat: "mp3",
            duration: 1.0
        )
        context.insert(cachedAudio)
        try context.save()

        let mockProvider = MockVoiceProvider(
            providerId: "apple",
            audioData: Data("new audio".utf8)  // This shouldn't be used
        )
        manager.registerProvider(mockProvider)

        // WHEN
        let audioFile = try await manager.generateAndCacheAudio(
            text: "Cached text",
            voiceId: "voice1",
            providerId: "apple"
        )

        // THEN - Should return cached audio, not generate new
        XCTAssertEqual(audioFile.audioData, Data("cached audio".utf8))
        XCTAssertEqual(audioFile.duration, 1.0)
    }

    func testWriteAudioFile() throws {
        // GIVEN
        let audioData = Data("test audio data".utf8)
        let audioFile = AudioFile(
            text: "Test",
            voiceId: "voice1",
            providerId: "test",
            audioData: audioData,
            audioFormat: "mp3"
        )

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp3")

        // WHEN
        try manager.writeAudioFile(audioFile, to: tempURL)

        // THEN
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))
        let writtenData = try Data(contentsOf: tempURL)
        XCTAssertEqual(writtenData, audioData)

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }
}
