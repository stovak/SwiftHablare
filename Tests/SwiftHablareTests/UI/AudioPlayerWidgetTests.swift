//
//  AudioPlayerWidgetTests.swift
//  SwiftHablare
//
//  Tests for AudioPlayerWidget component
//

import Testing
import SwiftUI
import SwiftData
@testable import SwiftHablare

@Suite("AudioPlayerWidget Tests")
@MainActor
struct AudioPlayerWidgetTests {

    @Test("Widget initializes correctly")
    func testInitialization() async throws {
        let context = try ModelContext(ModelContainer(for: AudioFile.self, VoiceModel.self))
        let playerManager = AudioPlayerManager()
        let providerManager = VoiceProviderManager(modelContext: context)

        let widget = AudioPlayerWidget(
            playerManager: playerManager,
            providerManager: providerManager
        )

        #expect(widget.playerManager === playerManager)
        #expect(widget.providerManager === providerManager)
    }

    @Test("Widget works with different managers")
    func testDifferentManagers() async throws {
        let context1 = try ModelContext(ModelContainer(for: AudioFile.self, VoiceModel.self))
        let context2 = try ModelContext(ModelContainer(for: AudioFile.self, VoiceModel.self))

        let playerManager1 = AudioPlayerManager()
        let playerManager2 = AudioPlayerManager()

        let providerManager1 = VoiceProviderManager(modelContext: context1)
        let providerManager2 = VoiceProviderManager(modelContext: context2)

        let widget1 = AudioPlayerWidget(
            playerManager: playerManager1,
            providerManager: providerManager1
        )

        let widget2 = AudioPlayerWidget(
            playerManager: playerManager2,
            providerManager: providerManager2
        )

        #expect(widget1.playerManager !== widget2.playerManager)
        #expect(widget1.providerManager !== widget2.providerManager)
    }

    @Test("Widget accepts different provider types")
    func testDifferentProviderTypes() async throws {
        let context = try ModelContext(ModelContainer(for: AudioFile.self, VoiceModel.self))
        let playerManager = AudioPlayerManager()
        let providerManager = VoiceProviderManager(modelContext: context)

        // Test with Apple provider
        providerManager.currentProviderType = .apple
        let widget1 = AudioPlayerWidget(
            playerManager: playerManager,
            providerManager: providerManager
        )
        #expect(widget1.providerManager.currentProviderType == .apple)

        // Test with ElevenLabs provider
        providerManager.currentProviderType = .elevenlabs
        let widget2 = AudioPlayerWidget(
            playerManager: playerManager,
            providerManager: providerManager
        )
        #expect(widget2.providerManager.currentProviderType == .elevenlabs)
    }
}
