//
//  VoiceProviderWidgetTests.swift
//  SwiftHablare
//
//  Tests for VoiceProviderWidget component
//

import Testing
import SwiftUI
import SwiftData
@testable import SwiftHablare

@Suite("VoiceProviderWidget Tests")
@MainActor
struct VoiceProviderWidgetTests {

    @Test("Widget initializes correctly")
    func testInitialization() async throws {
        let context = try ModelContext(ModelContainer(for: AudioFile.self, VoiceModel.self))
        let providerManager = VoiceProviderManager(modelContext: context)

        let widget = VoiceProviderWidget(providerManager: providerManager)

        #expect(widget.providerManager === providerManager)
    }

    @Test("Widget works with different provider managers")
    func testDifferentProviderManagers() async throws {
        let context1 = try ModelContext(ModelContainer(for: AudioFile.self, VoiceModel.self))
        let context2 = try ModelContext(ModelContainer(for: AudioFile.self, VoiceModel.self))

        let manager1 = VoiceProviderManager(modelContext: context1)
        let manager2 = VoiceProviderManager(modelContext: context2)

        // Set different provider types
        manager1.currentProviderType = .apple
        manager2.currentProviderType = .elevenlabs

        let widget1 = VoiceProviderWidget(providerManager: manager1)
        let widget2 = VoiceProviderWidget(providerManager: manager2)

        #expect(widget1.providerManager.currentProviderType == .apple)
        #expect(widget2.providerManager.currentProviderType == .elevenlabs)
    }

    @Test("Widget reflects provider type changes")
    func testProviderTypeChanges() async throws {
        let context = try ModelContext(ModelContainer(for: AudioFile.self, VoiceModel.self))
        let providerManager = VoiceProviderManager(modelContext: context)

        let widget = VoiceProviderWidget(providerManager: providerManager)

        // Change provider type
        providerManager.currentProviderType = .apple
        #expect(widget.providerManager.currentProviderType == .apple)

        providerManager.currentProviderType = .elevenlabs
        #expect(widget.providerManager.currentProviderType == .elevenlabs)
    }

    @Test("Widget handles API key configuration state")
    func testAPIKeyConfigurationState() async throws {
        let context = try ModelContext(ModelContainer(for: AudioFile.self, VoiceModel.self))
        let providerManager = VoiceProviderManager(modelContext: context)

        let widget = VoiceProviderWidget(providerManager: providerManager)

        // Initially, ElevenLabs should not be configured (no API key)
        providerManager.currentProviderType = .elevenlabs
        #expect(widget.providerManager.isCurrentProviderConfigured() == false)

        // Apple should always be configured
        providerManager.currentProviderType = .apple
        #expect(widget.providerManager.isCurrentProviderConfigured() == true)
    }
}
