//
//  VoicePickerWidgetTests.swift
//  SwiftHablare
//
//  Tests for VoicePickerWidget component
//

import Testing
import SwiftUI
import SwiftData
@testable import SwiftHablare

@Suite("VoicePickerWidget Tests")
@MainActor
struct VoicePickerWidgetTests {

    @Test("Widget initializes correctly")
    func testInitialization() async throws {
        let context = try ModelContext(ModelContainer(for: VoiceModel.self))
        let providerManager = VoiceProviderManager(modelContext: context)

        let widget = VoicePickerWidget(providerManager: providerManager)

        #expect(widget.providerManager === providerManager)
    }

    @Test("Widget works with different provider types")
    func testDifferentProviderTypes() async throws {
        let context = try ModelContext(ModelContainer(for: VoiceModel.self))
        let providerManager = VoiceProviderManager(modelContext: context)

        // Test with Apple provider
        providerManager.currentProviderType = .apple
        let widget1 = VoicePickerWidget(providerManager: providerManager)
        #expect(widget1.providerManager.currentProviderType == .apple)

        // Test with ElevenLabs provider
        providerManager.currentProviderType = .elevenlabs
        let widget2 = VoicePickerWidget(providerManager: providerManager)
        #expect(widget2.providerManager.currentProviderType == .elevenlabs)
    }

    @Test("Widget handles multiple provider managers")
    func testMultipleProviderManagers() async throws {
        let context1 = try ModelContext(ModelContainer(for: VoiceModel.self))
        let context2 = try ModelContext(ModelContainer(for: VoiceModel.self))

        let manager1 = VoiceProviderManager(modelContext: context1)
        let manager2 = VoiceProviderManager(modelContext: context2)

        let widget1 = VoicePickerWidget(providerManager: manager1)
        let widget2 = VoicePickerWidget(providerManager: manager2)

        #expect(widget1.providerManager !== widget2.providerManager)
    }
}
