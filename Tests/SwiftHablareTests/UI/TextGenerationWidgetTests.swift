//
//  TextGenerationWidgetTests.swift
//  SwiftHablare
//
//  Tests for TextGenerationWidget component
//

import Testing
import SwiftUI
import SwiftData
@testable import SwiftHablare

@Suite("TextGenerationWidget Tests")
@MainActor
struct TextGenerationWidgetTests {

    @Test("Widget initializes with correct default state")
    func testInitialization() async throws {
        let context = try ModelContext(ModelContainer(for: AudioFile.self, VoiceModel.self))
        let providerManager = VoiceProviderManager(modelContext: context)
        var callbackCalled = false

        let widget = TextGenerationWidget(
            providerManager: providerManager,
            modelContext: context,
            selectedVoice: nil,
            onAudioGenerated: { _ in callbackCalled = true }
        )

        // Widget should initialize successfully
        #expect(widget.providerManager === providerManager)
        #expect(widget.modelContext === context)
        #expect(widget.selectedVoice == nil)
        #expect(callbackCalled == false)
    }

    @Test("Widget initializes with selected voice")
    func testInitializationWithVoice() async throws {
        let context = try ModelContext(ModelContainer(for: AudioFile.self, VoiceModel.self))
        let providerManager = VoiceProviderManager(modelContext: context)

        let testVoice = Voice(
            id: "test-voice-1",
            name: "Test Voice",
            description: "A test voice",
            providerId: "test-provider"
        )

        let widget = TextGenerationWidget(
            providerManager: providerManager,
            modelContext: context,
            selectedVoice: testVoice,
            onAudioGenerated: { _ in }
        )

        #expect(widget.selectedVoice?.id == "test-voice-1")
        #expect(widget.selectedVoice?.name == "Test Voice")
    }

    @Test("Widget callback is invoked on audio generation")
    func testCallbackInvocation() async throws {
        let context = try ModelContext(ModelContainer(for: AudioFile.self, VoiceModel.self))
        let providerManager = VoiceProviderManager(modelContext: context)
        var capturedAudioFile: AudioFile?

        let widget = TextGenerationWidget(
            providerManager: providerManager,
            modelContext: context,
            selectedVoice: nil,
            onAudioGenerated: { audioFile in
                capturedAudioFile = audioFile
            }
        )

        // Verify callback can capture audio file
        let testAudioFile = AudioFile(
            text: "Test",
            voiceId: "voice-1",
            providerId: "apple",
            audioData: Data(),
            audioFormat: "mp3",
            duration: 1.0
        )

        widget.onAudioGenerated(testAudioFile)

        #expect(capturedAudioFile != nil)
        #expect(capturedAudioFile?.text == "Test")
    }

    @Test("Widget accepts multiple provider managers")
    func testMultipleProviderManagers() async throws {
        let context1 = try ModelContext(ModelContainer(for: AudioFile.self, VoiceModel.self))
        let context2 = try ModelContext(ModelContainer(for: AudioFile.self, VoiceModel.self))

        let manager1 = VoiceProviderManager(modelContext: context1)
        let manager2 = VoiceProviderManager(modelContext: context2)

        let widget1 = TextGenerationWidget(
            providerManager: manager1,
            modelContext: context1,
            selectedVoice: nil,
            onAudioGenerated: { _ in }
        )

        let widget2 = TextGenerationWidget(
            providerManager: manager2,
            modelContext: context2,
            selectedVoice: nil,
            onAudioGenerated: { _ in }
        )

        #expect(widget1.providerManager !== widget2.providerManager)
    }
}
