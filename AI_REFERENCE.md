# SwiftHablaré AI Reference Sheet

This sheet is optimized for bots needing rapid recall of project fundamentals.

## Core Facts

- **Purpose**: Unified text-to-speech abstraction over Apple TTS and ElevenLabs.
- **Language/Runtime**: Swift 6.2 targeting iOS 17+/macOS 15+ with SwiftData persistence (Xcode 16.4 toolchain).
- **Entry Point**: `VoiceProviderManager` orchestrates providers and caching.
- **State Storage**: SwiftData (`AudioFile`, `VoiceModel`) + Keychain for secrets.
- **UI Helpers**: SwiftUI widgets in `Sources/SwiftHablare/UI/` wrap provider selection and configuration.

## Default Providers

| Provider | ID | Requires Key | Notes |
| --- | --- | --- | --- |
| ElevenLabs | `elevenlabs` | ✅ | Network-backed voices, needs API key saved as `elevenlabs-api-key`. |
| Apple TTS | `apple` | ❌ | Local system voices, generates silent placeholder audio in current build. |

## Memory-Saving Tips for Agents

1. **Cache Awareness**: `generateAndCacheAudio` reuses existing audio automatically—avoid duplicate generation loops.
2. **Provider Selection**: Check `manager.currentProviderType` before switching; persisted via `UserDefaults`.
3. **Credential Checks**: Prefer `KeychainManager.shared.hasAPIKey` before attempting ElevenLabs calls.
4. **Voice Lists**: Use `getVoices(forceRefresh: false)` whenever possible; SwiftData caches results by provider.
5. **Error Surfacing**: Inspect `manager.lastError` after failures for user-facing diagnostics.

## Typical Automation Sequence

```
ensureAPIKey()
let voices = try await manager.getVoices()
let audio = try await manager.generateAndCacheAudio(...)
try manager.writeAudioFile(audio, to: outputURL)
```

Wrap task-specific logic around this pipeline.

## Testing Hooks

- Unit tests live under `Tests/SwiftHablareTests/` and focus on SwiftUI view behavior with injected managers.
- No CLI entry point exists; interactions happen through Swift APIs.

## Extensibility Reminders

- New providers must conform to `VoiceProvider` and be registered with the manager.
- Persist provider-specific metadata by extending SwiftData models or adding new ones to the host app's `ModelContainer`.
- Update documentation (`API.md`, `USAGE.md`) when exposing additional public types or workflows.
