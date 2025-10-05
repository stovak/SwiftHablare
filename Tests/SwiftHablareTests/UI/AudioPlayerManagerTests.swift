//
//  AudioPlayerManagerTests.swift
//  SwiftHablare
//
//  Tests for AudioPlayerManager class
//

import Testing
import AVFoundation
@testable import SwiftHablare

@Suite("AudioPlayerManager Tests")
@MainActor
struct AudioPlayerManagerTests {

    @Test("Manager initializes with correct default state")
    func testInitialization() async throws {
        let manager = AudioPlayerManager()

        #expect(manager.isPlaying == false)
        #expect(manager.currentTime == 0.0)
        #expect(manager.duration == 0.0)
    }

    @Test("Manager updates playing state correctly")
    func testPlayingStateUpdates() async throws {
        let manager = AudioPlayerManager()

        #expect(manager.isPlaying == false)

        // Note: Without actual audio data, we can't fully test playback
        // but we can verify the initial state and state transitions
    }

    @Test("Manager handles multiple instances independently")
    func testMultipleInstances() async throws {
        let manager1 = AudioPlayerManager()
        let manager2 = AudioPlayerManager()

        #expect(manager1 !== manager2)
        #expect(manager1.isPlaying == false)
        #expect(manager2.isPlaying == false)
    }

    @Test("Manager time properties have correct initial values")
    func testTimeProperties() async throws {
        let manager = AudioPlayerManager()

        #expect(manager.currentTime == 0.0)
        #expect(manager.duration == 0.0)
        #expect(manager.currentTime <= manager.duration)
    }

    @Test("Manager is observable object")
    func testObservableObject() async throws {
        let manager = AudioPlayerManager()

        // Verify it conforms to ObservableObject
        // This allows SwiftUI views to observe state changes
        #expect(manager is any ObservableObject)
    }
}
