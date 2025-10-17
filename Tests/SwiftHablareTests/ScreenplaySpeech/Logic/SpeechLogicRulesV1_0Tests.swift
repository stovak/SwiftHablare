import XCTest
import SwiftData
@testable import SwiftHablare
import SwiftGuion

@MainActor
final class SpeechLogicRulesV1_0Tests: XCTestCase {
    var rules: SpeechLogicRulesV1_0!
    var context: SceneContext!

    override func setUp() async throws {
        rules = SpeechLogicRulesV1_0()
        context = SceneContext(sceneID: "scene-1")
    }

    // MARK: - Scene Heading Tests

    func testSceneHeadingTransformation_InteriorDay() {
        // GIVEN
        let element = createMockElement(
            type: "Scene Heading",
            text: "INT. COFFEE SHOP - DAY",
            locationLighting: "INT",
            locationScene: "COFFEE SHOP",
            locationTimeOfDay: "DAY"
        )

        // WHEN
        let item = rules.processSceneHeading(element, orderIndex: 0)

        // THEN
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.speakableText, "Interior. COFFEE SHOP. DAY.")
        XCTAssertEqual(item?.toneHint, .narrative)
    }

    func testSceneHeadingTransformation_ExteriorNight() {
        // GIVEN
        let element = createMockElement(
            type: "Scene Heading",
            text: "EXT. PARK - NIGHT",
            locationLighting: "EXT",
            locationScene: "PARK",
            locationTimeOfDay: "NIGHT"
        )

        // WHEN
        let item = rules.processSceneHeading(element, orderIndex: 0)

        // THEN
        XCTAssertEqual(item?.speakableText, "Exterior. PARK. NIGHT.")
    }

    // MARK: - Character Announcement Tests

    func testCharacterAnnouncement_FirstTimeInScene() {
        // GIVEN
        let elements = [
            createMockElement(type: "Character", text: "JOHN"),
            createMockElement(type: "Dialogue", text: "Hello there.")
        ]

        // WHEN
        let (items, _) = rules.processDialogueBlock(
            startIndex: 0,
            elements: elements,
            context: &context
        )

        // THEN
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].speakableText, "JOHN says: Hello there.")
        XCTAssertTrue(items[0].includesCharacterAnnouncement)
        XCTAssertTrue(context.hasCharacterSpoken("john"))
    }

    func testCharacterAnnouncement_SecondLineNoAnnouncement() {
        // GIVEN - First dialogue
        let elements1 = [
            createMockElement(type: "Character", text: "JOHN"),
            createMockElement(type: "Dialogue", text: "First line.")
        ]
        _ = rules.processDialogueBlock(startIndex: 0, elements: elements1, context: &context)

        // GIVEN - Second dialogue same scene
        let elements2 = [
            createMockElement(type: "Character", text: "JOHN"),
            createMockElement(type: "Dialogue", text: "Second line.")
        ]

        // WHEN
        let (items, _) = rules.processDialogueBlock(
            startIndex: 0,
            elements: elements2,
            context: &context
        )

        // THEN
        XCTAssertEqual(items[0].speakableText, "Second line.")
        XCTAssertFalse(items[0].includesCharacterAnnouncement)
    }

    func testCharacterAnnouncement_DifferentCharacter() {
        // GIVEN - JOHN speaks first
        let elements1 = [
            createMockElement(type: "Character", text: "JOHN"),
            createMockElement(type: "Dialogue", text: "Hello.")
        ]
        _ = rules.processDialogueBlock(startIndex: 0, elements: elements1, context: &context)

        // GIVEN - SARAH speaks (different character)
        let elements2 = [
            createMockElement(type: "Character", text: "SARAH"),
            createMockElement(type: "Dialogue", text: "Hi there.")
        ]

        // WHEN
        let (items, _) = rules.processDialogueBlock(
            startIndex: 0,
            elements: elements2,
            context: &context
        )

        // THEN - SARAH gets announcement (first time)
        XCTAssertEqual(items[0].speakableText, "SARAH says: Hi there.")
        XCTAssertTrue(items[0].includesCharacterAnnouncement)
    }

    func testCharacterAnnouncement_AlternatingCharacters() {
        // GIVEN - JOHN speaks
        var elements = [createMockElement(type: "Character", text: "JOHN"), createMockElement(type: "Dialogue", text: "Line 1.")]
        _ = rules.processDialogueBlock(startIndex: 0, elements: elements, context: &context)

        // SARAH speaks
        elements = [createMockElement(type: "Character", text: "SARAH"), createMockElement(type: "Dialogue", text: "Line 2.")]
        _ = rules.processDialogueBlock(startIndex: 0, elements: elements, context: &context)

        // JOHN speaks again
        elements = [createMockElement(type: "Character", text: "JOHN"), createMockElement(type: "Dialogue", text: "Line 3.")]

        // WHEN
        let (items, _) = rules.processDialogueBlock(startIndex: 0, elements: elements, context: &context)

        // THEN - JOHN already announced in this scene, no announcement
        XCTAssertEqual(items[0].speakableText, "Line 3.")
        XCTAssertFalse(items[0].includesCharacterAnnouncement)
    }

    // MARK: - Dialogue Grouping Tests

    func testDialogueGrouping_MultipleLines() {
        // GIVEN
        let elements = [
            createMockElement(type: "Character", text: "JOHN"),
            createMockElement(type: "Dialogue", text: "I can't believe this."),
            createMockElement(type: "Dialogue", text: "We need to leave."),
            createMockElement(type: "Dialogue", text: "Now.")
        ]

        // WHEN
        let (items, consumed) = rules.processDialogueBlock(
            startIndex: 0,
            elements: elements,
            context: &context
        )

        // THEN
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].speakableText, "JOHN says: I can't believe this. We need to leave. Now.")
        XCTAssertEqual(consumed, 4)
    }

    func testDialogueGrouping_WithParenthetical() {
        // GIVEN
        let elements = [
            createMockElement(type: "Character", text: "JOHN"),
            createMockElement(type: "Parenthetical", text: "(whispering)"),
            createMockElement(type: "Dialogue", text: "We need to go.")
        ]

        // WHEN
        let (items, consumed) = rules.processDialogueBlock(
            startIndex: 0,
            elements: elements,
            context: &context
        )

        // THEN - Parenthetical skipped, not spoken
        XCTAssertEqual(items[0].speakableText, "JOHN says: We need to go.")
        XCTAssertEqual(consumed, 3)
    }

    // MARK: - Character Modifier Tests

    func testCharacterModifier_VoiceOver() {
        // GIVEN
        let elements = [
            createMockElement(type: "Character", text: "JOHN (V.O.)"),
            createMockElement(type: "Dialogue", text: "This is my story.")
        ]

        // WHEN
        let (items, _) = rules.processDialogueBlock(
            startIndex: 0,
            elements: elements,
            context: &context
        )

        // THEN
        XCTAssertEqual(items[0].characterName, "john")  // Normalized
        XCTAssertEqual(items[0].rawCharacterName, "JOHN (V.O.)")  // Original preserved
        XCTAssertEqual(items[0].speakableText, "JOHN (V.O.) says: This is my story.")
    }

    func testCharacterModifier_SameCharacterDifferentModifiers() {
        // GIVEN - JOHN (V.O.)
        var elements = [createMockElement(type: "Character", text: "JOHN (V.O.)"), createMockElement(type: "Dialogue", text: "Line 1.")]
        _ = rules.processDialogueBlock(startIndex: 0, elements: elements, context: &context)

        // GIVEN - JOHN (no modifier)
        elements = [createMockElement(type: "Character", text: "JOHN"), createMockElement(type: "Dialogue", text: "Line 2.")]

        // WHEN
        let (items, _) = rules.processDialogueBlock(startIndex: 0, elements: elements, context: &context)

        // THEN - Both normalize to "john", so no announcement
        XCTAssertEqual(items[0].speakableText, "Line 2.")
        XCTAssertFalse(items[0].includesCharacterAnnouncement)
    }

    // MARK: - Action Line Tests

    func testActionLine_Speakable() {
        // GIVEN
        let element = createMockElement(
            type: "Action",
            text: "John enters the room, looking around nervously."
        )

        // WHEN
        let item = rules.processSingleElement(element, orderIndex: 0)

        // THEN
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.speakableText, "John enters the room, looking around nervously.")
        XCTAssertEqual(item?.toneHint, .narrative)
    }

    // MARK: - Non-Speakable Elements Tests

    func testNonSpeakableElements() {
        let nonSpeakable = ["Parenthetical", "Transition", "Note", "Boneyard", "Synopsis"]

        for type in nonSpeakable {
            let element = createMockElement(type: type, text: "Should not be spoken")
            let item = rules.processSingleElement(element, orderIndex: 0)
            XCTAssertNil(item, "\(type) should not be speakable")
        }
    }

    // MARK: - Helper Methods

    private func createMockElement(
        type: String,
        text: String,
        locationLighting: String? = nil,
        locationScene: String? = nil,
        locationTimeOfDay: String? = nil
    ) -> GuionElementModel {
        let element = GuionElementModel(
            elementText: text,
            elementType: type,
            isCentered: false,
            isDualDialogue: false
        )
        element.locationLighting = locationLighting
        element.locationScene = locationScene
        element.locationTimeOfDay = locationTimeOfDay
        return element
    }
}
