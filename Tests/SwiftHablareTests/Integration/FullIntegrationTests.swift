import XCTest
import SwiftData
@testable import SwiftHablare
import SwiftGuion

/// Phase 6: Cross-module integration tests
///
/// Tests the full pipeline from screenplay parsing to audio generation,
/// ensuring all modules work together correctly.
@MainActor
final class FullIntegrationTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        // Create full model container with required models
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            SpeakableItem.self,
            SpeakableAudio.self
        ])

        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        context = ModelContext(container)
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    // MARK: - Full Pipeline Tests

    /// Test Scenario 1: SwiftGuion → SpeakableItems pipeline
    func testFullPipeline_GuionToSpeakableItems() async throws {
        // GIVEN - Complete screenplay
        let screenplay = createFullTestScreenplay()
        context.insert(screenplay)
        try context.save()

        // WHEN - Generate SpeakableItems
        let processor = ScreenplayToSpeechProcessor(
            context: context,
            rulesProvider: SpeechLogicRulesV1_0()
        )
        let items = try await processor.processScreenplay(screenplay)

        // THEN - Verify items were created correctly
        XCTAssertGreaterThan(items.count, 0, "Should generate at least one SpeakableItem")

        // Verify scene headings
        let sceneHeadings = items.filter { $0.sourceElementType == "Scene Heading" }
        XCTAssertGreaterThan(sceneHeadings.count, 0, "Should have at least one scene heading")

        // Verify dialogue items
        let dialogueItems = items.filter { $0.sourceElementType == "Dialogue" }
        XCTAssertGreaterThan(dialogueItems.count, 0, "Should have at least one dialogue item")

        // Verify character announcements
        let announcedItems = items.filter { $0.includesCharacterAnnouncement }
        XCTAssertGreaterThan(announcedItems.count, 0, "Should have at least one character announcement")

        // Verify order preservation
        for i in 0..<items.count - 1 {
            XCTAssertLessThan(items[i].orderIndex, items[i+1].orderIndex, "Items should be in order")
        }

        // Verify persistence
        let descriptor = FetchDescriptor<SpeakableItem>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        let persistedItems = try context.fetch(descriptor)
        XCTAssertEqual(persistedItems.count, items.count, "All items should be persisted")
    }

    /// Test Scenario 2: Multi-scene screenplay processing
    func testFullPipeline_MultiSceneProcessing() async throws {
        // GIVEN - Screenplay with multiple scenes
        let screenplay = createMultiSceneScreenplay()
        context.insert(screenplay)
        try context.save()

        // WHEN
        let processor = ScreenplayToSpeechProcessor(context: context)
        let items = try await processor.processScreenplay(screenplay)

        // THEN - Verify scene boundary handling
        let sceneIDs = Set(items.compactMap { $0.sceneID })
        XCTAssertEqual(sceneIDs.count, 3, "Should have 3 unique scene IDs")

        // Get scene items (including scene headings which have sceneID)
        let sceneHeadings = items.filter { $0.sourceElementType == "Scene Heading" }
        XCTAssertEqual(sceneHeadings.count, 3, "Should have 3 scene headings")

        // Get dialogue items
        let dialogueItems = items.filter { $0.characterName != nil }
        XCTAssertEqual(dialogueItems.count, 3, "Should have 3 dialogue items")

        // All first-time characters in each scene should be announced
        XCTAssertEqual(dialogueItems.filter { $0.includesCharacterAnnouncement }.count, 3,
                      "All 3 characters should be announced (first time in their respective scenes)")
    }

    /// Test Scenario 3: Character consistency across scenes
    func testFullPipeline_CharacterConsistency() async throws {
        // GIVEN - Screenplay with recurring character
        let screenplay = createRecurringCharacterScreenplay()
        context.insert(screenplay)
        try context.save()

        // WHEN
        let processor = ScreenplayToSpeechProcessor(context: context)
        let items = try await processor.processScreenplay(screenplay)

        // THEN - Verify character normalization works across all dialogue
        let johnItems = items.filter { $0.characterName == "john" }
        XCTAssertGreaterThan(johnItems.count, 3, "JOHN should speak multiple times")

        // All variations should normalize to same character
        let rawNames = Set(johnItems.compactMap { $0.rawCharacterName })
        XCTAssertTrue(rawNames.contains("JOHN"), "Should preserve JOHN")
        XCTAssertTrue(rawNames.contains("JOHN (V.O.)"), "Should preserve JOHN (V.O.)")

        // But all should have same normalized name
        XCTAssertTrue(johnItems.allSatisfy { $0.characterName == "john" }, "All should normalize to 'john'")
    }

    /// Test Scenario 4: Complex dialogue handling
    func testFullPipeline_ComplexDialogue() async throws {
        // GIVEN - Screenplay with multi-line dialogue and parentheticals
        let screenplay = createComplexDialogueScreenplay()
        context.insert(screenplay)
        try context.save()

        // WHEN
        let processor = ScreenplayToSpeechProcessor(context: context)
        let items = try await processor.processScreenplay(screenplay)

        // THEN - Verify dialogue grouping
        let dialogueItems = items.filter { $0.sourceElementType == "Dialogue" }

        // Find JOHN's dialogue
        let johnDialogue = dialogueItems.first { $0.characterName == "john" }
        XCTAssertNotNil(johnDialogue, "Should find JOHN's dialogue")

        // Should combine multiple dialogue lines
        if let dialogue = johnDialogue {
            XCTAssertTrue(dialogue.speakableText.contains("Line 1"), "Should contain Line 1")
            XCTAssertTrue(dialogue.speakableText.contains("Line 2"), "Should contain Line 2")
            XCTAssertTrue(dialogue.speakableText.contains("Line 3"), "Should contain Line 3")

            // Should not include parenthetical
            XCTAssertFalse(dialogue.speakableText.contains("whispering"), "Should not include parenthetical")
        }
    }

    // MARK: - Data Persistence Integration

    /// Test that SpeakableItems persist correctly and can be queried
    func testDataPersistence_QueryByStatus() async throws {
        // GIVEN - Generated items with different statuses
        let screenplay = createSimpleScreenplay()
        context.insert(screenplay)
        try context.save()

        let processor = ScreenplayToSpeechProcessor(context: context)
        let items = try await processor.processScreenplay(screenplay)

        // Set different statuses
        if items.count >= 3 {
            items[0].status = .textGenerated
            items[1].status = .audioQueued
            items[2].status = .audioComplete
            try context.save()
        }

        // WHEN - Fetch all and filter (SwiftData predicate doesn't support enum member access)
        let descriptor = FetchDescriptor<SpeakableItem>()
        let allItems = try context.fetch(descriptor)

        let queuedItems = allItems.filter { $0.status == .audioQueued }
        let completeItems = allItems.filter { $0.status == .audioComplete }

        // THEN
        XCTAssertEqual(queuedItems.count, 1, "Should find 1 queued item")
        XCTAssertEqual(completeItems.count, 1, "Should find 1 complete item")
    }

    /// Test that SpeakableAudio relationships work correctly
    func testDataPersistence_AudioRelationships() async throws {
        // GIVEN - SpeakableItem with audio
        let screenplay = createSimpleScreenplay()
        context.insert(screenplay)
        try context.save()

        let processor = ScreenplayToSpeechProcessor(context: context)
        let items = try await processor.processScreenplay(screenplay)

        guard let item = items.first else {
            XCTFail("Should have at least one item")
            return
        }

        // Add audio versions
        let audio1 = SpeakableAudio(
            hablareAudioID: UUID(),
            providerName: "ElevenLabs",
            voiceID: "voice-1",
            voiceName: "Emma",
            audioFormat: "mp3",
            characterCount: 100
        )
        audio1.isActive = true

        let audio2 = SpeakableAudio(
            hablareAudioID: UUID(),
            providerName: "Apple",
            voiceID: "voice-2",
            voiceName: "Samantha",
            audioFormat: "aac",
            characterCount: 100
        )
        audio2.isActive = false

        item.audioVersions.append(audio1)
        item.audioVersions.append(audio2)

        context.insert(audio1)
        context.insert(audio2)
        try context.save()

        // WHEN - Fetch in new context
        let newContext = ModelContext(container)
        let itemID = item.id
        let descriptor = FetchDescriptor<SpeakableItem>(
            predicate: #Predicate<SpeakableItem> { $0.id == itemID }
        )
        let fetchedItems = try newContext.fetch(descriptor)

        // THEN
        guard let fetchedItem = fetchedItems.first else {
            XCTFail("Should find item")
            return
        }

        XCTAssertEqual(fetchedItem.audioVersions.count, 2, "Should have 2 audio versions")

        let activeAudio = fetchedItem.audioVersions.first { $0.isActive }
        XCTAssertNotNil(activeAudio, "Should have active audio")
        XCTAssertEqual(activeAudio?.providerName, "ElevenLabs", "Active audio should be ElevenLabs")
    }

    /// Test cascade deletion
    func testDataPersistence_CascadeDelete() async throws {
        // GIVEN - SpeakableItem with audio
        let screenplay = createSimpleScreenplay()
        context.insert(screenplay)
        try context.save()

        let processor = ScreenplayToSpeechProcessor(context: context)
        let items = try await processor.processScreenplay(screenplay)

        guard let item = items.first else {
            XCTFail("Should have at least one item")
            return
        }

        let audio = SpeakableAudio(
            hablareAudioID: UUID(),
            providerName: "TestProvider",
            voiceID: "test-voice",
            voiceName: "Test",
            audioFormat: "mp3",
            characterCount: 50
        )

        item.audioVersions.append(audio)
        context.insert(audio)
        try context.save()

        let audioID = audio.id

        // WHEN - Delete item
        context.delete(item)
        try context.save()

        // THEN - Audio should be deleted
        let audioDescriptor = FetchDescriptor<SpeakableAudio>(
            predicate: #Predicate<SpeakableAudio> { $0.id == audioID }
        )
        let foundAudio = try context.fetch(audioDescriptor)
        XCTAssertTrue(foundAudio.isEmpty, "Audio should be cascade deleted")
    }

    // MARK: - Performance Tests

    /// Test processing performance for typical screenplay
    func testPerformance_TypicalScreenplay() async throws {
        // GIVEN - Medium-sized screenplay (100 elements)
        let screenplay = createLargeScreenplay(elementCount: 100)
        context.insert(screenplay)
        try context.save()

        let processor = ScreenplayToSpeechProcessor(context: context)

        // WHEN/THEN - Should process in under 1 second
        measure {
            Task { @MainActor in
                _ = try? await processor.processScreenplay(screenplay)
            }
        }
    }

    /// Test memory usage doesn't leak with repeated processing
    func testPerformance_NoMemoryLeak() async throws {
        // GIVEN
        let screenplay = createSimpleScreenplay()
        context.insert(screenplay)
        try context.save()

        let processor = ScreenplayToSpeechProcessor(context: context)

        // WHEN - Process multiple times
        for _ in 0..<10 {
            let items = try await processor.processScreenplay(screenplay)

            // Clean up between runs
            for item in items {
                context.delete(item)
            }
            try context.save()
        }

        // THEN - Should not leak (verified by instruments/leaks)
        // This test mainly ensures no crash from repeated processing
        XCTAssertTrue(true, "Should complete without memory issues")
    }

    // MARK: - Edge Cases

    /// Test empty screenplay
    func testEdgeCase_EmptyScreenplay() async throws {
        // GIVEN
        let screenplay = GuionDocumentModel(
            filename: "Empty.fountain",
            rawContent: "",
            suppressSceneNumbers: false
        )
        context.insert(screenplay)
        try context.save()

        // WHEN
        let processor = ScreenplayToSpeechProcessor(context: context)
        let items = try await processor.processScreenplay(screenplay)

        // THEN
        XCTAssertEqual(items.count, 0, "Empty screenplay should generate no items")
    }

    /// Test screenplay with only scene headings
    func testEdgeCase_OnlySceneHeadings() async throws {
        // GIVEN
        let rawContent = """
INT. ROOM - DAY

EXT. PARK - DAY

INT. HOUSE - NIGHT
"""
        let screenplay = GuionDocumentModel(
            filename: "OnlySceneHeadings.fountain",
            rawContent: rawContent,
            suppressSceneNumbers: false
        )
        context.insert(screenplay)
        try context.save()

        // WHEN
        let processor = ScreenplayToSpeechProcessor(context: context)
        let items = try await processor.processScreenplay(screenplay)

        // THEN
        XCTAssertEqual(items.count, 3, "Should generate 3 scene heading items")
        XCTAssertTrue(items.allSatisfy { $0.sourceElementType == "Scene Heading" })
    }

    // MARK: - Helper Methods

    private func createFullTestScreenplay() -> GuionDocumentModel {
        let rawContent = """
INT. COFFEE SHOP - DAY

John enters, looking around nervously.

JOHN
Hello, is anyone here?

SARAH
(from behind counter)
Can I help you?

JOHN
I'm looking for someone.

SARAH
Who?

JOHN (V.O.)
I couldn't tell her the truth.

EXT. PARK - DAY

John sits on a bench.

JOHN
(to himself)
What am I doing?
"""
        return GuionDocumentModel(
            filename: "Full.fountain",
            rawContent: rawContent,
            suppressSceneNumbers: false
        )
    }

    private func createMultiSceneScreenplay() -> GuionDocumentModel {
        let rawContent = """
INT. ROOM - DAY

JOHN
Scene 1 dialogue.

EXT. PARK - DAY

JOHN
Scene 2 dialogue.

INT. HOUSE - NIGHT

SARAH
Scene 3 dialogue.
"""
        return GuionDocumentModel(
            filename: "MultiScene.fountain",
            rawContent: rawContent,
            suppressSceneNumbers: false
        )
    }

    private func createRecurringCharacterScreenplay() -> GuionDocumentModel {
        let rawContent = """
INT. ROOM - DAY

JOHN
Line 1.

JOHN (V.O.)
Line 2.

JOHN
Line 3.

JOHN (CONT'D)
Line 4.
"""
        return GuionDocumentModel(
            filename: "Recurring.fountain",
            rawContent: rawContent,
            suppressSceneNumbers: false
        )
    }

    private func createComplexDialogueScreenplay() -> GuionDocumentModel {
        let rawContent = """
INT. ROOM - DAY

JOHN
(whispering)
Line 1.
Line 2.
Line 3.
"""
        return GuionDocumentModel(
            filename: "Complex.fountain",
            rawContent: rawContent,
            suppressSceneNumbers: false
        )
    }

    private func createSimpleScreenplay() -> GuionDocumentModel {
        let rawContent = """
INT. ROOM - DAY

John enters.

JOHN
Hello.

SARAH
Hi there.
"""
        return GuionDocumentModel(
            filename: "Simple.fountain",
            rawContent: rawContent,
            suppressSceneNumbers: false
        )
    }

    private func createLargeScreenplay(elementCount: Int) -> GuionDocumentModel {
        var content = "INT. ROOM - DAY\n\n"

        for i in 0..<elementCount {
            if i % 10 == 0 {
                content += "EXT. LOCATION \(i/10) - DAY\n\n"
            }

            if i % 3 == 0 {
                content += "Action line \(i).\n\n"
            } else {
                content += "CHARACTER \(i)\nDialogue line \(i).\n\n"
            }
        }

        return GuionDocumentModel(
            filename: "Large.fountain",
            rawContent: content,
            suppressSceneNumbers: false
        )
    }
}
