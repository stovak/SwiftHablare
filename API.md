# SwiftHablaré API Reference (Concise)

This document highlights the primary types exposed by SwiftHablaré so that automated agents can understand the surface area without scanning the full source tree.

## Module Layout

```
Sources/SwiftHablare/
├── KeychainManager.swift        // Secure credential storage helper
├── SwiftHablare.swift           // Package entry point exports
├── VoiceProvider.swift          // Provider protocol + enums
├── VoiceProviderManager.swift   // High-level orchestration
├── Models/                      // SwiftData models + DTOs
└── Providers/                   // Provider-specific implementations
```

SwiftUI helper views live in `Sources/SwiftHablare/UI/`.

## Core Types

### `VoiceProviderManager`
High-level coordinator responsible for:
- Registering providers (`registerProvider(_:)`).
- Persisting the selected provider (`currentProviderType`).
- Fetching voices with automatic SwiftData caching (`getVoices(forceRefresh:)`).
- Generating audio, with (`generateAndCacheAudio`) or without (`generateAudio`) persistence.
- Writing cached audio to disk (`writeAudioFile(_:to:)`).
- Switching providers and emitting errors through `lastError`.

A `ModelContext` is required at initialization; caching relies on `AudioFile` and `VoiceModel` entities.

### `VoiceProvider` Protocol
Providers must supply:
- Identity metadata (`providerId`, `displayName`, `requiresAPIKey`).
- Runtime state (`isConfigured()`).
- Voice discovery (`fetchVoices()`).
- Audio generation (`generateAudio(text:voiceId:)`).
- Duration estimation (`estimateDuration(text:voiceId:)`).
- Voice availability checks (`isVoiceAvailable(voiceId:)`).

`VoiceProviderType` offers canonical IDs (`.elevenlabs`, `.apple`) and human-readable labels. Errors are represented by `VoiceProviderError` (`.notConfigured`, `.networkError`, `.invalidResponse`, `.unsupportedProvider`, `.notSupported`).

### Data Models
- `Voice`: Codable DTO used across providers.
- `AudioFile`: SwiftData model caching generated audio bytes plus metadata (format, duration, sample rate, etc.).
- `VoiceModel`: SwiftData cache for provider voice listings.

Conversions between `Voice` and `VoiceModel` are implemented as helpers on `VoiceModel`.

## Providers

### `ElevenLabsVoiceProvider`
- Requires API key stored under `"elevenlabs-api-key"` in `KeychainManager`.
- Fetches localized voice lists from `https://api.elevenlabs.io/v1/voices` filtered by the current locale.
- Generates audio via `https://api.elevenlabs.io/v1/text-to-speech/{voiceId}` with configurable body payload.
- Estimates duration heuristically by character count and adds a 15% buffer.
- Validates voice availability via `GET /v1/voices/{voiceId}`.
- Includes Codable structs (`VoicesResponse`, `ElevenLabsVoice`) to decode API payloads and expose helper properties (`language`, `locality`, `gender`).

### `AppleVoiceProvider`
- Always configured (`requiresAPIKey == false`).
- Uses `AVSpeechSynthesisVoice` to gather voices, filtering by the system language and enriching metadata (quality, gender guess).
- Generates placeholder audio using `AVAudioFile` + `AVAudioPCMBuffer` to avoid crashes from `AVSpeechSynthesizer.write` (silent CAF output).
- Estimates duration using `AVSpeechUtterance` heuristics with a small safety buffer.
- Checks availability through `AVSpeechSynthesisVoice(identifier:)` or scanning the voice list.

## Utilities

### `KeychainManager`
Singleton (`shared`) wrapping Keychain CRUD:
- `saveAPIKey(_:for:)`
- `getAPIKey(for:)`
- `deleteAPIKey(for:)`
- `hasAPIKey(for:)`
- `getObfuscatedAPIKey(for:)`

Throws `KeychainError` variants (`.invalidData`, `.notFound`, `.unableToSave`, `.unableToDelete`).

## SwiftUI Components

- `VoiceProviderWidget`: Provider selector + status UI.
- `VoiceSettingsWidget`: Aggregates provider controls, API key management, and voice picker.
- `VoicePickerWidget`: Voice search, filter, and preview list. Exposes reusable row view (`VoiceRow`) and binding-based variant (`VoicePickerWithBinding`).

Each widget expects a `VoiceProviderManager` environment object and uses the SwiftData models for persistence.

## Extension Points

To add a new provider:
1. Implement `VoiceProvider` with the provider ID and required network logic.
2. Register the provider in `VoiceProviderManager` (either via constructor or `registerProvider`).
3. Optionally add SwiftUI controls mirroring the patterns in the existing widgets.
4. Persist provider-specific metadata by extending `VoiceModel`/`AudioFile` or introducing new SwiftData models.

When altering persistence, update migrations or `ModelContainer` setup inside host apps to include the new models.
