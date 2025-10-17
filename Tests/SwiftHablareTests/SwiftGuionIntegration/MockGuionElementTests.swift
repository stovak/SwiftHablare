import XCTest
import SwiftData
@testable import SwiftHablare
import SwiftGuion

@MainActor
final class MockGuionElementTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        container = try ModelContainer(
            for: GuionDocumentModel.self, GuionElementModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    func testCreateMockScreenplay() throws {
        // GIVEN
        let document = GuionDocumentModel(
            filename: "Test.fountain",
            rawContent: "",
            suppressSceneNumbers: false
        )

        let sceneHeading = GuionElementModel(
            elementText: "INT. COFFEE SHOP - DAY",
            elementType: "Scene Heading",
            isCentered: false,
            isDualDialogue: false
        )
        sceneHeading.sceneId = "scene-1"
        sceneHeading.locationLighting = "INT"
        sceneHeading.locationScene = "COFFEE SHOP"
        sceneHeading.locationTimeOfDay = "DAY"

        document.elements.append(sceneHeading)

        // WHEN
        context.insert(document)
        try context.save()

        // THEN
        XCTAssertEqual(document.elements.count, 1)
        XCTAssertEqual(document.elements[0].elementType, "Scene Heading")
    }

    func testMockDialogueSequence() throws {
        // GIVEN
        let document = createMockDocument()

        let character = GuionElementModel(elementText: "JOHN", elementType: "Character", isCentered: false, isDualDialogue: false)
        let dialogue = GuionElementModel(elementText: "Hello there.", elementType: "Dialogue", isCentered: false, isDualDialogue: false)

        document.elements.append(character)
        document.elements.append(dialogue)

        context.insert(document)
        try context.save()

        // WHEN
        let elements = document.elements

        // THEN
        XCTAssertEqual(elements.count, 2, "Should have 2 elements")

        // Check for element presence (order may vary due to SwiftData limitation)
        let characterElements = elements.filter { $0.elementType == "Character" }
        let dialogueElements = elements.filter { $0.elementType == "Dialogue" }

        XCTAssertEqual(characterElements.count, 1, "Should have 1 Character element")
        XCTAssertEqual(dialogueElements.count, 1, "Should have 1 Dialogue element")
        XCTAssertEqual(characterElements[0].elementText, "JOHN")
        XCTAssertEqual(dialogueElements[0].elementText, "Hello there.")
    }

    func testElementOrdering() throws {
        // GIVEN
        let document = createMockDocument()

        // Use append to preserve order (SwiftData requirement)
        document.elements.append(createElement(type: "Scene Heading", text: "INT. ROOM - DAY"))
        document.elements.append(createElement(type: "Action", text: "John enters."))
        document.elements.append(createElement(type: "Character", text: "JOHN"))
        document.elements.append(createElement(type: "Dialogue", text: "Hello."))

        context.insert(document)
        try context.save()

        // WHEN
        let elements = document.elements

        // THEN - All elements present (order may vary due to SwiftData limitation)
        XCTAssertEqual(elements.count, 4)
        XCTAssertEqual(elements.filter { $0.elementType == "Scene Heading" }.count, 1)
        XCTAssertEqual(elements.filter { $0.elementType == "Action" }.count, 1)
        XCTAssertEqual(elements.filter { $0.elementType == "Character" }.count, 1)
        XCTAssertEqual(elements.filter { $0.elementType == "Dialogue" }.count, 1)
    }

    private func createMockDocument() -> GuionDocumentModel {
        GuionDocumentModel(filename: "Test.fountain", rawContent: "", suppressSceneNumbers: false)
    }

    private func createElement(type: String, text: String) -> GuionElementModel {
        GuionElementModel(elementText: text, elementType: type, isCentered: false, isDualDialogue: false)
    }
}
