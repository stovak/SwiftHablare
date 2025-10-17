//
//  SceneContextTests.swift
//  SwiftHablareTests
//
//  Phase 5: Tests for SceneContext
//

import XCTest
@testable import SwiftHablare

final class SceneContextTests: XCTestCase {

    // MARK: - Initialization Tests

    func testSceneContextInitialization() {
        // WHEN
        let context = SceneContext(sceneID: "scene-1")

        // THEN
        XCTAssertEqual(context.sceneID, "scene-1")
        XCTAssertTrue(context.charactersWhoHaveSpoken.isEmpty)
        XCTAssertNil(context.lastSpeaker)
    }

    func testSceneContextInitializationWithEmptySceneID() {
        // WHEN
        let context = SceneContext(sceneID: "")

        // THEN
        XCTAssertEqual(context.sceneID, "")
        XCTAssertTrue(context.charactersWhoHaveSpoken.isEmpty)
        XCTAssertNil(context.lastSpeaker)
    }

    // MARK: - Character Tracking Tests

    func testMarkCharacterSpoken() {
        // GIVEN
        var context = SceneContext(sceneID: "scene-1")

        // WHEN
        context.markCharacterSpoken("JOHN")

        // THEN
        XCTAssertTrue(context.hasCharacterSpoken("JOHN"))
        XCTAssertEqual(context.lastSpeaker, "JOHN")
    }

    func testMarkMultipleCharactersSpoken() {
        // GIVEN
        var context = SceneContext(sceneID: "scene-1")

        // WHEN
        context.markCharacterSpoken("JOHN")
        context.markCharacterSpoken("SARAH")
        context.markCharacterSpoken("MIKE")

        // THEN
        XCTAssertTrue(context.hasCharacterSpoken("JOHN"))
        XCTAssertTrue(context.hasCharacterSpoken("SARAH"))
        XCTAssertTrue(context.hasCharacterSpoken("MIKE"))
        XCTAssertEqual(context.lastSpeaker, "MIKE", "Last speaker should be the most recent")
        XCTAssertEqual(context.charactersWhoHaveSpoken.count, 3)
    }

    func testMarkSameCharacterMultipleTimes() {
        // GIVEN
        var context = SceneContext(sceneID: "scene-1")

        // WHEN
        context.markCharacterSpoken("JOHN")
        context.markCharacterSpoken("JOHN")
        context.markCharacterSpoken("JOHN")

        // THEN
        XCTAssertTrue(context.hasCharacterSpoken("JOHN"))
        XCTAssertEqual(context.lastSpeaker, "JOHN")
        XCTAssertEqual(context.charactersWhoHaveSpoken.count, 1, "Should only track unique characters")
    }

    func testMarkCharacterWithDifferentCasing() {
        // GIVEN
        var context = SceneContext(sceneID: "scene-1")

        // WHEN
        context.markCharacterSpoken("JOHN")
        context.markCharacterSpoken("john")
        context.markCharacterSpoken("John")

        // THEN
        // Each case variation is treated as a different character
        XCTAssertTrue(context.hasCharacterSpoken("JOHN"))
        XCTAssertTrue(context.hasCharacterSpoken("john"))
        XCTAssertTrue(context.hasCharacterSpoken("John"))
        XCTAssertEqual(context.charactersWhoHaveSpoken.count, 3)
    }

    // MARK: - hasCharacterSpoken Tests

    func testHasCharacterSpokenReturnsFalseForUnknownCharacter() {
        // GIVEN
        var context = SceneContext(sceneID: "scene-1")
        context.markCharacterSpoken("JOHN")

        // WHEN
        let hasSarah = context.hasCharacterSpoken("SARAH")

        // THEN
        XCTAssertFalse(hasSarah)
    }

    func testHasCharacterSpokenReturnsTrueForKnownCharacter() {
        // GIVEN
        var context = SceneContext(sceneID: "scene-1")
        context.markCharacterSpoken("JOHN")

        // WHEN
        let hasJohn = context.hasCharacterSpoken("JOHN")

        // THEN
        XCTAssertTrue(hasJohn)
    }

    func testHasCharacterSpokenWithEmptyString() {
        // GIVEN
        var context = SceneContext(sceneID: "scene-1")
        context.markCharacterSpoken("")

        // WHEN
        let hasEmpty = context.hasCharacterSpoken("")

        // THEN
        XCTAssertTrue(hasEmpty, "Should track even empty character names")
    }

    // MARK: - lastSpeaker Tests

    func testLastSpeakerUpdatesCorrectly() {
        // GIVEN
        var context = SceneContext(sceneID: "scene-1")

        // WHEN/THEN - Track progression of last speaker
        XCTAssertNil(context.lastSpeaker, "Should start as nil")

        context.markCharacterSpoken("JOHN")
        XCTAssertEqual(context.lastSpeaker, "JOHN")

        context.markCharacterSpoken("SARAH")
        XCTAssertEqual(context.lastSpeaker, "SARAH")

        context.markCharacterSpoken("JOHN")
        XCTAssertEqual(context.lastSpeaker, "JOHN", "Should update to John again")
    }

    // MARK: - Edge Cases

    func testCharacterWithWhitespace() {
        // GIVEN
        var context = SceneContext(sceneID: "scene-1")

        // WHEN
        context.markCharacterSpoken("  JOHN  ")

        // THEN
        XCTAssertTrue(context.hasCharacterSpoken("  JOHN  "))
        XCTAssertFalse(context.hasCharacterSpoken("JOHN"), "Whitespace makes it a different character")
    }

    func testSceneContextWithManyCharacters() {
        // GIVEN
        var context = SceneContext(sceneID: "crowded-scene")
        let characters = ["JOHN", "SARAH", "MIKE", "EMMA", "TOM", "LISA", "BOB", "ALICE"]

        // WHEN
        for character in characters {
            context.markCharacterSpoken(character)
        }

        // THEN
        XCTAssertEqual(context.charactersWhoHaveSpoken.count, characters.count)
        for character in characters {
            XCTAssertTrue(context.hasCharacterSpoken(character))
        }
        XCTAssertEqual(context.lastSpeaker, "ALICE", "Last speaker should be the last one marked")
    }

    func testSceneContextDialogueSequence() {
        // GIVEN
        var context = SceneContext(sceneID: "conversation")

        // WHEN - Simulate back-and-forth dialogue
        context.markCharacterSpoken("JOHN")
        let firstAppearance = !context.hasCharacterSpoken("SARAH")
        context.markCharacterSpoken("SARAH")
        let johnRepeats = context.hasCharacterSpoken("JOHN")
        context.markCharacterSpoken("JOHN")

        // THEN
        XCTAssertTrue(firstAppearance, "Sarah's first line should be detected")
        XCTAssertTrue(johnRepeats, "John should be marked as having spoken")
        XCTAssertEqual(context.lastSpeaker, "JOHN")
        XCTAssertEqual(context.charactersWhoHaveSpoken.count, 2)
    }

    // MARK: - Scene Boundary Tests

    func testNewSceneContextResetsTracking() {
        // GIVEN
        var scene1 = SceneContext(sceneID: "scene-1")
        scene1.markCharacterSpoken("JOHN")
        scene1.markCharacterSpoken("SARAH")

        // WHEN - Create new context for different scene
        let scene2 = SceneContext(sceneID: "scene-2")

        // THEN
        XCTAssertNotEqual(scene1.sceneID, scene2.sceneID)
        XCTAssertTrue(scene1.hasCharacterSpoken("JOHN"))
        XCTAssertFalse(scene2.hasCharacterSpoken("JOHN"), "New scene should not have character history")
        XCTAssertTrue(scene2.charactersWhoHaveSpoken.isEmpty)
        XCTAssertNil(scene2.lastSpeaker)
    }

    func testSceneContextIsolation() {
        // GIVEN
        var scene1 = SceneContext(sceneID: "scene-1")
        var scene2 = SceneContext(sceneID: "scene-2")

        // WHEN
        scene1.markCharacterSpoken("JOHN")
        scene2.markCharacterSpoken("SARAH")

        // THEN - Contexts should be independent
        XCTAssertTrue(scene1.hasCharacterSpoken("JOHN"))
        XCTAssertFalse(scene1.hasCharacterSpoken("SARAH"))
        XCTAssertTrue(scene2.hasCharacterSpoken("SARAH"))
        XCTAssertFalse(scene2.hasCharacterSpoken("JOHN"))
    }
}
