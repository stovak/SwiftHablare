//
//  SwiftHablare.swift
//  SwiftHablare
//
//  A Swift package for text-to-speech audio generation with multiple providers
//

import Foundation

/// SwiftHablare - A Swift package for text-to-speech audio generation
///
/// This package provides a unified interface for working with multiple TTS providers,
/// including Apple's built-in TTS and ElevenLabs.
///
/// ## Usage
///
/// ```swift
/// import SwiftHablare
/// import SwiftData
///
/// // Initialize with a ModelContext
/// let manager = VoiceProviderManager(modelContext: modelContext)
///
/// // Generate and cache audio
/// let audioFile = try await manager.generateAndCacheAudio(
///     text: "Hello, world!",
///     voiceId: "voice-id",
///     providerId: "elevenlabs"
/// )
///
/// // Write to file
/// try manager.writeAudioFile(audioFile, to: url)
/// ```
public struct SwiftHablare {
    public static let version = "1.0.0"
}
