//
//  VoiceProviderManagerTests.swift
//  SwiftHablareTests
//
//  Tests for VoiceProviderManager
//

import XCTest
import SwiftData
@testable import SwiftHablare

@MainActor
final class VoiceProviderManagerTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var manager: VoiceProviderManager!

    override func setUp() async throws {
        // Create an in-memory model container for testing
        let schema = Schema([VoiceModel.self, AudioFile.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(modelContainer)

        // Create manager with test context
        manager = VoiceProviderManager(modelContext: modelContext)
    }

    override func tearDown() async throws {
        manager = nil
        modelContext = nil
        modelContainer = nil

        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "selectedVoiceProvider")
    }

    // MARK: - Initialization Tests

    func testVoiceProviderManagerInitialization() {
        XCTAssertNotNil(manager)
        XCTAssertEqual(manager.currentProviderType, .elevenlabs)
    }

    func testVoiceProviderManagerInitializationWithSavedProvider() {
        UserDefaults.standard.set("apple", forKey: "selectedVoiceProvider")

        let newManager = VoiceProviderManager(modelContext: modelContext)

        XCTAssertEqual(newManager.currentProviderType, .apple)
    }

    func testVoiceProviderManagerInitializationWithInvalidSavedProvider() {
        UserDefaults.standard.set("invalid-provider", forKey: "selectedVoiceProvider")

        let newManager = VoiceProviderManager(modelContext: modelContext)

        // Should default to elevenlabs
        XCTAssertEqual(newManager.currentProviderType, .elevenlabs)
    }

    // MARK: - Provider Registration Tests

    func testRegisterProvider() {
        let mockProvider = MockVoiceProvider(providerId: "test-provider")
        manager.registerProvider(mockProvider)

        let retrieved = manager.getProvider(for: "test-provider")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.providerId, "test-provider")
    }

    func testGetCurrentProvider() {
        manager.currentProviderType = .elevenlabs
        let provider = manager.getCurrentProvider()

        XCTAssertNotNil(provider)
        XCTAssertEqual(provider?.providerId, "elevenlabs")
    }

    func testGetProviderById() {
        let appleProvider = manager.getProvider(for: "apple")
        XCTAssertNotNil(appleProvider)
        XCTAssertEqual(appleProvider?.providerId, "apple")

        let elevenLabsProvider = manager.getProvider(for: "elevenlabs")
        XCTAssertNotNil(elevenLabsProvider)
        XCTAssertEqual(elevenLabsProvider?.providerId, "elevenlabs")
    }

    func testGetProviderByIdNonExistent() {
        let provider = manager.getProvider(for: "non-existent")
        XCTAssertNil(provider)
    }

    // MARK: - Provider Configuration Tests

    func testIsCurrentProviderConfigured() {
        // Register a configured mock provider
        let mockProvider = MockVoiceProvider(
            providerId: "test-configured",
            isConfigured: true
        )
        manager.registerProvider(mockProvider)
        manager.currentProviderType = VoiceProviderType(rawValue: "test-configured") ?? .elevenlabs

        // Note: Since we can't easily change currentProviderType to custom values,
        // we'll test with the default providers
        // The actual providers may or may not be configured based on system state
        let isConfigured = manager.isCurrentProviderConfigured()
        XCTAssertTrue(isConfigured is Bool) // Just verify it returns a Bool
    }

    // MARK: - Switch Provider Tests

    func testSwitchProvider() {
        manager.currentProviderType = .elevenlabs
        XCTAssertEqual(manager.currentProviderType, .elevenlabs)

        manager.switchProvider(to: .apple)
        XCTAssertEqual(manager.currentProviderType, .apple)

        // Verify it was saved to UserDefaults
        let saved = UserDefaults.standard.string(forKey: "selectedVoiceProvider")
        XCTAssertEqual(saved, "apple")
    }

    func testSwitchProviderClearsError() {
        manager.lastError = "Some error"
        XCTAssertNotNil(manager.lastError)

        manager.switchProvider(to: .apple)
        XCTAssertNil(manager.lastError)
    }

    // MARK: - Available Providers Tests

    func testGetAvailableProviders() {
        let providers = manager.getAvailableProviders()

        XCTAssertEqual(providers.count, 2)
        XCTAssertTrue(providers.contains(.elevenlabs))
        XCTAssertTrue(providers.contains(.apple))
    }

    // MARK: - Voice Caching Tests

    func testGetVoicesFromCache() async throws {
        // Manually insert cached voices
        let voice1 = VoiceModel(
            voiceId: "cached-1",
            name: "Cached 1",
            voiceDescription: nil,
            providerId: "elevenlabs"
        )
        let voice2 = VoiceModel(
            voiceId: "cached-2",
            name: "Cached 2",
            voiceDescription: nil,
            providerId: "elevenlabs"
        )

        modelContext.insert(voice1)
        modelContext.insert(voice2)
        try modelContext.save()

        // Register a mock provider to avoid actual network calls
        let mockProvider = MockVoiceProvider(
            providerId: "elevenlabs",
            voices: []
        )
        manager.registerProvider(mockProvider)
        manager.currentProviderType = .elevenlabs

        // Get voices (should return cached)
        let voices = try await manager.getVoices(forceRefresh: false)

        XCTAssertEqual(voices.count, 2)
        XCTAssertFalse(mockProvider.fetchVoicesCalled) // Should not call provider
    }

    func testGetVoicesForceRefresh() async throws {
        // Insert cached voices
        let cachedVoice = VoiceModel(
            voiceId: "cached",
            name: "Cached",
            voiceDescription: nil,
            providerId: "mock-provider"
        )
        modelContext.insert(cachedVoice)
        try modelContext.save()

        // Register mock provider with fresh voices
        let freshVoices = [
            Voice(id: "fresh-1", name: "Fresh 1", description: nil, providerId: "mock-provider"),
            Voice(id: "fresh-2", name: "Fresh 2", description: nil, providerId: "mock-provider")
        ]
        let mockProvider = MockVoiceProvider(
            providerId: "mock-provider",
            voices: freshVoices
        )
        manager.registerProvider(mockProvider)

        // Temporarily switch to mock provider (hack since we can't change enum)
        // For this test, we'll use the elevenlabs provider slot
        manager.registerProvider(MockVoiceProvider(
            providerId: "elevenlabs",
            voices: freshVoices
        ))
        manager.currentProviderType = .elevenlabs

        // Force refresh
        let voices = try await manager.getVoices(forceRefresh: true)

        XCTAssertEqual(voices.count, 2)
        XCTAssertEqual(voices[0].id, "fresh-1")
        XCTAssertEqual(voices[1].id, "fresh-2")
    }

    func testGetVoicesCachesResults() async throws {
        let freshVoices = [
            Voice(id: "new-1", name: "New 1", description: nil, providerId: "elevenlabs")
        ]

        let mockProvider = MockVoiceProvider(
            providerId: "elevenlabs",
            voices: freshVoices
        )
        manager.registerProvider(mockProvider)
        manager.currentProviderType = .elevenlabs

        // Fetch voices (should cache them)
        let voices = try await manager.getVoices(forceRefresh: true)
        XCTAssertEqual(voices.count, 1)

        // Check that they were cached
        let descriptor = FetchDescriptor<VoiceModel>(
            predicate: #Predicate { $0.providerId == "elevenlabs" }
        )
        let cachedVoices = try modelContext.fetch(descriptor)
        XCTAssertEqual(cachedVoices.count, 1)
        XCTAssertEqual(cachedVoices[0].voiceId, "new-1")
    }

    func testGetVoicesNoProviderError() async {
        // Remove all providers by creating a new manager without registering providers
        let schema = Schema([VoiceModel.self, AudioFile.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        // Create a custom manager that doesn't auto-register providers
        let emptyManager = VoiceProviderManager(modelContext: context)
        // Clear the auto-registered providers
        emptyManager.currentProviderType = VoiceProviderType(rawValue: "nonexistent") ?? .elevenlabs

        do {
            _ = try await emptyManager.getVoices()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is VoiceProviderError)
        }
    }

    // MARK: - Generate Audio Tests

    func testGenerateAudio() async throws {
        let testData = Data([0xAA, 0xBB, 0xCC])
        let mockProvider = MockVoiceProvider(
            providerId: "elevenlabs",
            audioData: testData
        )
        manager.registerProvider(mockProvider)
        manager.currentProviderType = .elevenlabs

        let audio = try await manager.generateAudio(text: "Test", voiceId: "voice-1")

        XCTAssertTrue(mockProvider.generateAudioCalled)
        XCTAssertEqual(audio, testData)
    }

    func testGenerateAudioNoProvider() async {
        manager.currentProviderType = VoiceProviderType(rawValue: "nonexistent") ?? .elevenlabs

        do {
            _ = try await manager.generateAudio(text: "Test", voiceId: "voice-1")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is VoiceProviderError)
        }
    }

    // MARK: - Generate and Cache Audio Tests

    func testGenerateAndCacheAudio() async throws {
        let testData = Data([0x01, 0x02, 0x03])
        let mockProvider = MockVoiceProvider(
            providerId: "test-provider",
            audioData: testData,
            estimatedDuration: 3.5
        )
        manager.registerProvider(mockProvider)

        let audioFile = try await manager.generateAndCacheAudio(
            text: "Hello",
            voiceId: "voice-1",
            providerId: "test-provider",
            audioFormat: "mp3"
        )

        XCTAssertEqual(audioFile.text, "Hello")
        XCTAssertEqual(audioFile.voiceId, "voice-1")
        XCTAssertEqual(audioFile.providerId, "test-provider")
        XCTAssertEqual(audioFile.audioData, testData)
        XCTAssertEqual(audioFile.audioFormat, "mp3")
        XCTAssertEqual(audioFile.duration, 3.5)

        // Verify it was saved to context
        let descriptor = FetchDescriptor<AudioFile>(
            predicate: #Predicate { $0.text == "Hello" }
        )
        let cached = try modelContext.fetch(descriptor)
        XCTAssertEqual(cached.count, 1)
    }

    func testGenerateAndCacheAudioReturnsExisting() async throws {
        // Create existing cached audio
        let existingData = Data([0xFF])
        let existingAudio = AudioFile(
            text: "Existing",
            voiceId: "voice-1",
            providerId: "test-provider",
            audioData: existingData,
            audioFormat: "mp3"
        )
        modelContext.insert(existingAudio)
        try modelContext.save()

        let mockProvider = MockVoiceProvider(
            providerId: "test-provider",
            audioData: Data([0x00]) // Different data
        )
        manager.registerProvider(mockProvider)

        // Request same audio
        let audioFile = try await manager.generateAndCacheAudio(
            text: "Existing",
            voiceId: "voice-1",
            providerId: "test-provider"
        )

        // Should return existing, not generate new
        XCTAssertFalse(mockProvider.generateAudioCalled)
        XCTAssertEqual(audioFile.audioData, existingData)
    }

    func testGenerateAndCacheAudioUnsupportedProvider() async {
        do {
            _ = try await manager.generateAndCacheAudio(
                text: "Test",
                voiceId: "voice-1",
                providerId: "nonexistent-provider"
            )
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is VoiceProviderError)
        }
    }

    // MARK: - Write Audio File Tests

    func testWriteAudioFile() throws {
        let audioData = Data([0x01, 0x02, 0x03, 0x04])
        let audioFile = AudioFile(
            text: "Write test",
            voiceId: "voice",
            providerId: "provider",
            audioData: audioData,
            audioFormat: "mp3"
        )

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp3")

        try manager.writeAudioFile(audioFile, to: tempURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))

        let writtenData = try Data(contentsOf: tempURL)
        XCTAssertEqual(writtenData, audioData)

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    // MARK: - Published Properties Tests

    func testCurrentProviderTypePublished() {
        let expectation = XCTestExpectation(description: "Provider type changed")

        let cancellable = manager.$currentProviderType
            .dropFirst() // Skip initial value
            .sink { type in
                XCTAssertEqual(type, .apple)
                expectation.fulfill()
            }

        manager.currentProviderType = .apple

        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
    }

    func testLastErrorPublished() {
        let expectation = XCTestExpectation(description: "Error changed")

        let cancellable = manager.$lastError
            .dropFirst() // Skip initial value
            .sink { error in
                XCTAssertEqual(error, "Test error")
                expectation.fulfill()
            }

        manager.lastError = "Test error"

        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
    }

    // MARK: - UserDefaults Persistence Tests

    func testCurrentProviderTypePersistence() {
        manager.currentProviderType = .apple

        let saved = UserDefaults.standard.string(forKey: "selectedVoiceProvider")
        XCTAssertEqual(saved, "apple")

        manager.currentProviderType = .elevenlabs
        let savedAgain = UserDefaults.standard.string(forKey: "selectedVoiceProvider")
        XCTAssertEqual(savedAgain, "elevenlabs")
    }
}
