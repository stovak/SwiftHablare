//
//  VoiceModelTests.swift
//  SwiftHablareTests
//
//  Tests for the VoiceModel (SwiftData model)
//

import XCTest
import SwiftData
@testable import SwiftHablare

final class VoiceModelTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        // Create an in-memory model container for testing
        let schema = Schema([VoiceModel.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
    }

    // MARK: - Initialization Tests

    func testVoiceModelInitialization() {
        let voiceModel = VoiceModel(
            voiceId: "test-id",
            name: "Test Voice",
            voiceDescription: "A test voice",
            providerId: "test-provider",
            language: "en",
            locality: "US",
            gender: "female"
        )

        XCTAssertEqual(voiceModel.voiceId, "test-id")
        XCTAssertEqual(voiceModel.name, "Test Voice")
        XCTAssertEqual(voiceModel.voiceDescription, "A test voice")
        XCTAssertEqual(voiceModel.providerId, "test-provider")
        XCTAssertEqual(voiceModel.language, "en")
        XCTAssertEqual(voiceModel.locality, "US")
        XCTAssertEqual(voiceModel.gender, "female")
        XCTAssertNotNil(voiceModel.lastFetched)
    }

    func testVoiceModelInitializationWithMinimalData() {
        let voiceModel = VoiceModel(
            voiceId: "minimal-id",
            name: "Minimal",
            voiceDescription: nil,
            providerId: "provider"
        )

        XCTAssertEqual(voiceModel.voiceId, "minimal-id")
        XCTAssertEqual(voiceModel.name, "Minimal")
        XCTAssertNil(voiceModel.voiceDescription)
        XCTAssertNil(voiceModel.language)
        XCTAssertNil(voiceModel.locality)
        XCTAssertNil(voiceModel.gender)
    }

    // MARK: - SwiftData Persistence Tests

    func testVoiceModelPersistence() throws {
        let voiceModel = VoiceModel(
            voiceId: "persist-test",
            name: "Persist Test",
            voiceDescription: "Testing persistence",
            providerId: "provider1"
        )

        modelContext.insert(voiceModel)
        try modelContext.save()

        let descriptor = FetchDescriptor<VoiceModel>(
            predicate: #Predicate { $0.voiceId == "persist-test" }
        )
        let fetched = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Persist Test")
    }

    func testVoiceModelUniqueness() throws {
        let voiceModel1 = VoiceModel(
            voiceId: "unique-id",
            name: "First",
            voiceDescription: nil,
            providerId: "provider1"
        )

        let voiceModel2 = VoiceModel(
            voiceId: "unique-id",
            name: "Second",
            voiceDescription: nil,
            providerId: "provider1"
        )

        modelContext.insert(voiceModel1)
        try modelContext.save()

        modelContext.insert(voiceModel2)

        // SwiftData should handle uniqueness constraint
        // The second insert should either fail or replace the first
        do {
            try modelContext.save()
            // If save succeeds, verify only one exists
            let descriptor = FetchDescriptor<VoiceModel>()
            let all = try modelContext.fetch(descriptor)
            XCTAssertEqual(all.count, 1)
        } catch {
            // Expected if uniqueness constraint is enforced
            XCTAssertTrue(true)
        }
    }

    func testVoiceModelDeletion() throws {
        let voiceModel = VoiceModel(
            voiceId: "delete-test",
            name: "Delete Test",
            voiceDescription: nil,
            providerId: "provider1"
        )

        modelContext.insert(voiceModel)
        try modelContext.save()

        modelContext.delete(voiceModel)
        try modelContext.save()

        let descriptor = FetchDescriptor<VoiceModel>(
            predicate: #Predicate { $0.voiceId == "delete-test" }
        )
        let fetched = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetched.count, 0)
    }

    // MARK: - Conversion Tests

    func testVoiceModelFromVoice() {
        let voice = Voice(
            id: "convert-id",
            name: "Convert Test",
            description: "Testing conversion",
            providerId: "provider1",
            language: "es",
            locality: "ES",
            gender: "male"
        )

        let voiceModel = VoiceModel.from(voice)

        XCTAssertEqual(voiceModel.voiceId, voice.id)
        XCTAssertEqual(voiceModel.name, voice.name)
        XCTAssertEqual(voiceModel.voiceDescription, voice.description)
        XCTAssertEqual(voiceModel.providerId, voice.providerId)
        XCTAssertEqual(voiceModel.language, voice.language)
        XCTAssertEqual(voiceModel.locality, voice.locality)
        XCTAssertEqual(voiceModel.gender, voice.gender)
    }

    func testVoiceModelToVoice() {
        let voiceModel = VoiceModel(
            voiceId: "model-to-voice",
            name: "Model to Voice",
            voiceDescription: "Testing conversion",
            providerId: "provider2",
            language: "fr",
            locality: "FR",
            gender: "female"
        )

        let voice = voiceModel.toVoice()

        XCTAssertEqual(voice.id, voiceModel.voiceId)
        XCTAssertEqual(voice.name, voiceModel.name)
        XCTAssertEqual(voice.description, voiceModel.voiceDescription)
        XCTAssertEqual(voice.providerId, voiceModel.providerId)
        XCTAssertEqual(voice.language, voiceModel.language)
        XCTAssertEqual(voice.locality, voiceModel.locality)
        XCTAssertEqual(voice.gender, voiceModel.gender)
    }

    func testVoiceModelRoundTripConversion() {
        let originalVoice = Voice(
            id: "roundtrip",
            name: "Round Trip",
            description: "Testing round trip",
            providerId: "provider3",
            language: "de",
            locality: "DE",
            gender: "male"
        )

        let voiceModel = VoiceModel.from(originalVoice)
        let convertedVoice = voiceModel.toVoice()

        XCTAssertEqual(convertedVoice.id, originalVoice.id)
        XCTAssertEqual(convertedVoice.name, originalVoice.name)
        XCTAssertEqual(convertedVoice.description, originalVoice.description)
        XCTAssertEqual(convertedVoice.providerId, originalVoice.providerId)
        XCTAssertEqual(convertedVoice.language, originalVoice.language)
        XCTAssertEqual(convertedVoice.locality, originalVoice.locality)
        XCTAssertEqual(convertedVoice.gender, originalVoice.gender)
    }

    // MARK: - Query Tests

    func testVoiceModelQueryByProviderId() throws {
        let voice1 = VoiceModel(
            voiceId: "voice1",
            name: "Voice 1",
            voiceDescription: nil,
            providerId: "provider1"
        )

        let voice2 = VoiceModel(
            voiceId: "voice2",
            name: "Voice 2",
            voiceDescription: nil,
            providerId: "provider2"
        )

        let voice3 = VoiceModel(
            voiceId: "voice3",
            name: "Voice 3",
            voiceDescription: nil,
            providerId: "provider1"
        )

        modelContext.insert(voice1)
        modelContext.insert(voice2)
        modelContext.insert(voice3)
        try modelContext.save()

        let descriptor = FetchDescriptor<VoiceModel>(
            predicate: #Predicate { $0.providerId == "provider1" }
        )
        let provider1Voices = try modelContext.fetch(descriptor)

        XCTAssertEqual(provider1Voices.count, 2)
        XCTAssertTrue(provider1Voices.contains { $0.voiceId == "voice1" })
        XCTAssertTrue(provider1Voices.contains { $0.voiceId == "voice3" })
    }

    func testVoiceModelSortedQuery() throws {
        let voiceC = VoiceModel(voiceId: "c", name: "Charlie", voiceDescription: nil, providerId: "p1")
        let voiceA = VoiceModel(voiceId: "a", name: "Alice", voiceDescription: nil, providerId: "p1")
        let voiceB = VoiceModel(voiceId: "b", name: "Bob", voiceDescription: nil, providerId: "p1")

        modelContext.insert(voiceC)
        modelContext.insert(voiceA)
        modelContext.insert(voiceB)
        try modelContext.save()

        let descriptor = FetchDescriptor<VoiceModel>(
            sortBy: [SortDescriptor(\.name)]
        )
        let sortedVoices = try modelContext.fetch(descriptor)

        XCTAssertEqual(sortedVoices.count, 3)
        XCTAssertEqual(sortedVoices[0].name, "Alice")
        XCTAssertEqual(sortedVoices[1].name, "Bob")
        XCTAssertEqual(sortedVoices[2].name, "Charlie")
    }

    // MARK: - LastFetched Tests

    func testVoiceModelLastFetchedTimestamp() {
        let beforeCreation = Date()
        let voiceModel = VoiceModel(
            voiceId: "timestamp-test",
            name: "Timestamp Test",
            voiceDescription: nil,
            providerId: "provider1"
        )
        let afterCreation = Date()

        XCTAssertGreaterThanOrEqual(voiceModel.lastFetched, beforeCreation)
        XCTAssertLessThanOrEqual(voiceModel.lastFetched, afterCreation)
    }

    func testVoiceModelCustomLastFetched() {
        let customDate = Date(timeIntervalSince1970: 1000000)
        let voiceModel = VoiceModel(
            voiceId: "custom-date",
            name: "Custom Date",
            voiceDescription: nil,
            providerId: "provider1",
            lastFetched: customDate
        )

        XCTAssertEqual(voiceModel.lastFetched, customDate)
    }
}
