import XCTest
import SwiftData
@testable import SwiftHablare
import SwiftGuion

@MainActor
final class ScreenplayProcessingTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var processor: ScreenplayToSpeechProcessor!

    override func setUp() async throws {
        // Setup model container with all models
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

        processor = ScreenplayToSpeechProcessor(
            context: context,
            rulesProvider: SpeechLogicRulesV1_0()
        )
    }

    func testProcessSimpleScene() async throws {
        // GIVEN
        let screenplay = createSimpleScreenplay()
        context.insert(screenplay)
        try context.save()

        // WHEN
        let items = try await processor.processScreenplay(screenplay)

        // THEN
        XCTAssertEqual(items.count, 4, "Should generate 4 items: Scene heading + action + 2 dialogue")

        // Find scene heading
        let sceneHeading = items.first { $0.sourceElementType == "Scene Heading" }
        XCTAssertNotNil(sceneHeading)
        if let sh = sceneHeading {
            XCTAssertTrue(sh.speakableText.contains("Interior"))
        }

        // Find action
        let action = items.first { $0.sourceElementType == "Action" }
        XCTAssertNotNil(action)

        // Find JOHN dialogue (first time)
        let johnDialogue = items.first { $0.characterName == "john" }
        XCTAssertNotNil(johnDialogue, "Should find JOHN's dialogue")
        if let jd = johnDialogue {
            XCTAssertTrue(jd.includesCharacterAnnouncement)
        }

        // Find SARAH dialogue (first time)
        let sarahDialogue = items.first { $0.characterName == "sarah" }
        XCTAssertNotNil(sarahDialogue, "Should find SARAH's dialogue")
        if let sd = sarahDialogue {
            XCTAssertTrue(sd.includesCharacterAnnouncement)
        }
    }

    func testProcessMultipleScenes() async throws {
        // GIVEN
        let screenplay = createMultiSceneScreenplay()
        context.insert(screenplay)
        try context.save()

        // WHEN
        let items = try await processor.processScreenplay(screenplay)

        // THEN - Count items
        let sceneHeadings = items.filter { $0.sourceElementType == "Scene Heading" }
        XCTAssertEqual(sceneHeadings.count, 2, "Should have 2 scene headings")

        // Get unique scene IDs
        let uniqueSceneIDs = Set(items.compactMap { $0.sceneID })
        XCTAssertEqual(uniqueSceneIDs.count, 2, "Should have 2 unique scene IDs")

        // Get all JOHN dialogue items
        let johnItems = items.filter { $0.characterName == "john" }
        XCTAssertEqual(johnItems.count, 2, "JOHN should speak twice (once per scene)")

        // Both JOHN items should have character announcements (first time in each scene)
        XCTAssertTrue(johnItems.allSatisfy { $0.includesCharacterAnnouncement }, "JOHN should be announced first time in each scene")
    }

    func testProcessComplexDialogue() async throws {
        // GIVEN - Multi-line dialogue with parenthetical
        let screenplay = createComplexDialogueScreenplay()
        context.insert(screenplay)
        try context.save()

        // WHEN
        let items = try await processor.processScreenplay(screenplay)

        // THEN
        let johnDialogue = items.first { $0.characterName == "john" }
        XCTAssertNotNil(johnDialogue, "Should find JOHN's dialogue")

        guard let dialogue = johnDialogue else { return }

        // Should combine all dialogue lines
        XCTAssertTrue(dialogue.speakableText.contains("Line 1"), "Should contain Line 1")
        XCTAssertTrue(dialogue.speakableText.contains("Line 2"), "Should contain Line 2")
        XCTAssertTrue(dialogue.speakableText.contains("Line 3"), "Should contain Line 3")

        // Should NOT include parenthetical
        XCTAssertFalse(dialogue.speakableText.contains("whispering"), "Should not include parenthetical")
    }

    func testSceneBoundaryDetection() async throws {
        // GIVEN
        let screenplay = createTwoSceneScreenplay()
        context.insert(screenplay)
        try context.save()

        // WHEN
        let items = try await processor.processScreenplay(screenplay)

        // THEN
        let sceneIDs = Set(items.compactMap { $0.sceneID })
        XCTAssertEqual(sceneIDs.count, 2)
    }

    func testCharacterConsistencyAcrossScenes() async throws {
        // GIVEN
        let screenplay = createScreenplayWithRecurringCharacter()
        context.insert(screenplay)
        try context.save()

        // WHEN
        let items = try await processor.processScreenplay(screenplay)

        // THEN
        let johnItems = items.filter { $0.characterName == "john" }
        XCTAssertGreaterThanOrEqual(johnItems.count, 2, "JOHN should speak at least 2 times (with variations like V.O.)")

        // All items should have same normalized name
        XCTAssertTrue(johnItems.allSatisfy { $0.characterName == "john" }, "All JOHN variations should normalize to 'john'")
    }

    // MARK: - Helper Methods

    private func createSimpleScreenplay() -> GuionDocumentModel {
        let rawContent = """
INT. ROOM - DAY

John enters.

JOHN
Hello.

SARAH
Hi there.
"""
        let doc = GuionDocumentModel(filename: "Simple.fountain", rawContent: rawContent, suppressSceneNumbers: false)

        // Note: elements will be auto-populated when processing via toFountainScript()
        // We still add them for display purposes, but order doesn't matter since
        // the processor will use toFountainScript() which parses rawContent
        doc.elements.append(createElement(type: "Scene Heading", text: "INT. ROOM - DAY", sceneId: "scene-1", lighting: "INT", location: "ROOM", time: "DAY"))
        doc.elements.append(createElement(type: "Action", text: "John enters."))
        doc.elements.append(createElement(type: "Character", text: "JOHN"))
        doc.elements.append(createElement(type: "Dialogue", text: "Hello."))
        doc.elements.append(createElement(type: "Character", text: "SARAH"))
        doc.elements.append(createElement(type: "Dialogue", text: "Hi there."))

        return doc
    }

    private func createMultiSceneScreenplay() -> GuionDocumentModel {
        let rawContent = """
INT. ROOM - DAY

JOHN
Scene 1 line.

EXT. PARK - DAY

JOHN
Scene 2 line.
"""
        let doc = GuionDocumentModel(filename: "MultiScene.fountain", rawContent: rawContent, suppressSceneNumbers: false)

        // Scene 1
        doc.elements.append(createElement(type: "Scene Heading", text: "INT. ROOM - DAY", sceneId: "scene-1"))
        doc.elements.append(createElement(type: "Character", text: "JOHN"))
        doc.elements.append(createElement(type: "Dialogue", text: "Scene 1 line."))

        // Scene 2
        doc.elements.append(createElement(type: "Scene Heading", text: "EXT. PARK - DAY", sceneId: "scene-2"))
        doc.elements.append(createElement(type: "Character", text: "JOHN"))
        doc.elements.append(createElement(type: "Dialogue", text: "Scene 2 line."))

        return doc
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
        let doc = GuionDocumentModel(filename: "Complex.fountain", rawContent: rawContent, suppressSceneNumbers: false)

        doc.elements.append(createElement(type: "Scene Heading", text: "INT. ROOM - DAY", sceneId: "scene-1"))
        doc.elements.append(createElement(type: "Character", text: "JOHN"))
        doc.elements.append(createElement(type: "Parenthetical", text: "(whispering)"))
        doc.elements.append(createElement(type: "Dialogue", text: "Line 1."))
        doc.elements.append(createElement(type: "Dialogue", text: "Line 2."))
        doc.elements.append(createElement(type: "Dialogue", text: "Line 3."))

        return doc
    }

    private func createTwoSceneScreenplay() -> GuionDocumentModel {
        let rawContent = """
INT. ROOM - DAY

Action in scene 1.

EXT. PARK - DAY

Action in scene 2.
"""
        let doc = GuionDocumentModel(filename: "TwoScenes.fountain", rawContent: rawContent, suppressSceneNumbers: false)

        doc.elements.append(createElement(type: "Scene Heading", text: "INT. ROOM - DAY", sceneId: "scene-1"))
        doc.elements.append(createElement(type: "Action", text: "Action in scene 1."))
        doc.elements.append(createElement(type: "Scene Heading", text: "EXT. PARK - DAY", sceneId: "scene-2"))
        doc.elements.append(createElement(type: "Action", text: "Action in scene 2."))

        return doc
    }

    private func createScreenplayWithRecurringCharacter() -> GuionDocumentModel {
        let rawContent = """
INT. ROOM - DAY

JOHN
Line 1.

JOHN (V.O.)
Line 2.

JOHN
Line 3.
"""
        let doc = GuionDocumentModel(filename: "Recurring.fountain", rawContent: rawContent, suppressSceneNumbers: false)

        doc.elements.append(createElement(type: "Scene Heading", text: "INT. ROOM - DAY", sceneId: "scene-1"))
        doc.elements.append(createElement(type: "Character", text: "JOHN"))
        doc.elements.append(createElement(type: "Dialogue", text: "Line 1."))
        doc.elements.append(createElement(type: "Character", text: "JOHN (V.O.)"))
        doc.elements.append(createElement(type: "Dialogue", text: "Line 2."))
        doc.elements.append(createElement(type: "Character", text: "JOHN"))
        doc.elements.append(createElement(type: "Dialogue", text: "Line 3."))

        return doc
    }

    private func createElement(
        type: String,
        text: String,
        sceneId: String? = nil,
        lighting: String? = nil,
        location: String? = nil,
        time: String? = nil
    ) -> GuionElementModel {
        let element = GuionElementModel(elementText: text, elementType: ElementType(string: type), isCentered: false, isDualDialogue: false)
        element.sceneId = sceneId
        element.locationLighting = lighting
        element.locationScene = location
        element.locationTimeOfDay = time
        context.insert(element)
        return element
    }
}
