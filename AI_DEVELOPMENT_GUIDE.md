# SwiftHablaré AI Development Guide

**Target Audience:** AI assistants, code generation tools, and automated development agents

This guide provides structured information for AI bots to effectively understand, use, and extend SwiftHablaré v2.0.

## Table of Contents

1. [Quick Facts](#quick-facts)
2. [Architecture Overview](#architecture-overview)
3. [Core Concepts](#core-concepts)
4. [Common Patterns](#common-patterns)
5. [Error Handling](#error-handling)
6. [Testing Patterns](#testing-patterns)
7. [Extension Guide](#extension-guide)

---

## Quick Facts

### Project Status
- **Current Version:** v2.0 (in development)
- **Core AI Phase:** Phase 7 Complete (Test Coverage & QA)
- **UI Sprint Phase:** Phase 2 Complete (ScreenplaySpeech Task System)
- **Next Phase:** UI Sprint Phase 3 (Character Mapping)
- **Test Coverage:** 787 tests, 96% average coverage
- **Swift Version:** 6.0 (strict concurrency mode)
- **Platforms:** macOS 15.0+, iOS 17.0+
- **Framework:** Swift Package Manager

### Key Technologies
- **Concurrency:** Swift structured concurrency (async/await, actors)
- **Persistence:** SwiftData for model storage
- **Security:** Keychain for credential management
- **UI:** SwiftUI components (Phase 7A + UI Sprint)
- **Testing:** XCTest + Swift Testing framework
- **Screenplay Processing:** SwiftGuion integration for Fountain format parsing

---

## Architecture Overview

### Three-Layer Architecture

```
┌─────────────────────────────────────────┐
│         Application Layer                │
│  (SwiftUI Views, ViewModels)            │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│      Coordination Layer                  │
│  • AIServiceManager (provider registry)  │
│  • AIDataCoordinator (main actor)        │
│  • AIPersistenceCoordinator             │
│  • AIRequestManager (actor)              │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│         Provider Layer                   │
│  • OpenAIProvider                        │
│  • AnthropicProvider                     │
│  • ElevenLabsProvider                    │
│  • AppleIntelligenceProvider             │
└─────────────────────────────────────────┘
```

### Module Organization

```
Sources/SwiftHablare/
├── Core/              # Protocols, managers, coordinators
├── Providers/         # AI service implementations
├── Requestors/        # Typed request interfaces
├── Models/            # SwiftData persistence models
├── Security/          # Keychain, credential management
├── Request/           # Request lifecycle management
├── UI/                # SwiftUI configuration views
└── ScreenplaySpeech/  # Screenplay to speech pipeline (UI Sprint)
    ├── Models/        # SpeakableItem, SpeakableAudio
    ├── Tasks/         # BackgroundTask, SpeakableItemGenerationTask
    ├── Processing/    # ScreenplayToSpeechProcessor
    ├── Logic/         # SpeechLogicRulesV1_0, SceneContext
    └── UI/            # BackgroundTasksPalette, BackgroundTaskRow
```

---

## Core Concepts

### 1. Providers (AIServiceProvider Protocol)

**Purpose:** Abstract interface to AI services

**Key Methods:**
```swift
protocol AIServiceProvider: Sendable {
    var providerId: String { get }
    var displayName: String { get }
    var capabilities: Set<AICapability> { get }
    var requiresAPIKey: Bool { get }

    func generate(
        prompt: String,
        parameters: [String: Any],
        context: ModelContext
    ) async throws -> Result<ResponseContent, AIServiceError>
}
```

**Implementations:**
- `OpenAIProvider` - GPT models, DALL-E, embeddings
- `AnthropicProvider` - Claude models
- `ElevenLabsProvider` - Text-to-speech
- `AppleIntelligenceProvider` - On-device text generation

### 2. Requestors (AIRequestor Protocol)

**Purpose:** Typed interface for specific content generation

**Pattern:**
```swift
protocol AIRequestor<OutputType> {
    associatedtype OutputType

    func generate(
        prompt: String,
        parameters: [String: Any]
    ) async throws -> OutputType
}
```

**Available Requestors:**
- **Text:** `OpenAITextRequestor`, `AnthropicTextRequestor`
- **Audio:** `ElevenLabsAudioRequestor`
- **Image:** `OpenAIImageRequestor` (DALL-E 2/3)
- **Embedding:** `OpenAIEmbeddingRequestor`

### 3. Content Types (ResponseContent Enum)

**Purpose:** Unified response wrapper

```swift
enum ResponseContent: Sendable {
    case text(String)
    case data(Data)
    case audio(Data, format: AudioFormat)
    case image(Data, format: ImageFormat)
    case structured([String: SendableValue])
    case embedding([Float], dimensions: Int)
}
```

### 4. Capabilities (AICapability Enum)

**Purpose:** Declare what a provider can do

```swift
enum AICapability: Sendable, Codable {
    case textGeneration(models: [String])
    case audioGeneration(formats: [String])
    case imageGeneration(sizes: [String])
    case embedding(dimensions: [Int])
    case chat
    case streaming
}
```

### 5. ScreenplaySpeech (Background Task System)

**New in UI Sprint Phase 1-2**

**Purpose:** Convert screenplays (Fountain format) into speakable audio with progress tracking

**Key Classes:**
- `BackgroundTask` - Observable task with progress tracking (@MainActor)
- `BackgroundTaskManager` - Task queue and execution manager (@MainActor)
- `ScreenplayTask` - Protocol for screenplay processing tasks
- `SpeakableItemGenerationTask` - Converts screenplay to SpeakableItems

**Task States:**
```swift
enum TaskState {
    case queued      // Waiting to run
    case running     // Currently executing
    case completed   // Successfully finished
    case failed      // Error occurred
    case cancelled   // User cancelled
}
```

**Pattern:**
```swift
// Create and enqueue task
let task = SpeakableItemGenerationTask(
    screenplay: screenplay,
    context: modelContext,
    saveInterval: 50  // Save every 50 items
)

let manager = BackgroundTaskManager.shared
await manager.enqueue(task)

// Monitor progress
task.backgroundTask.state         // current state
task.backgroundTask.currentStep   // items processed
task.backgroundTask.totalSteps    // total items
task.backgroundTask.message       // status message

// Cancel if needed
task.cancel()
```

### 6. SpeakableItem (SwiftData Model)

**Purpose:** Persistent storage for screenplay speech elements

**Key Properties:**
```swift
@Model
final class SpeakableItem {
    var id: UUID
    var orderIndex: Int                          // Sequence order
    var screenplayID: String                      // Links to screenplay
    var sourceElementID: String                   // Original element ID
    var sourceElementType: String                 // "Dialogue", "Action", etc.
    var sceneID: String?                         // Scene identifier
    var speakableText: String                    // Text to speak
    var characterName: String?                   // Normalized name
    var rawCharacterName: String?                // Original name
    var status: SpeakableItemStatus              // Generation status
    var ruleVersion: String                      // Speech logic version
    var includesCharacterAnnouncement: Bool      // "JOHN says:"
    var toneHint: ToneHint?                      // .narrative or .character
    var audioVersions: [SpeakableAudio]          // Generated audio
}
```

**Status Enum:**
```swift
enum SpeakableItemStatus: String, Codable {
    case textGenerated    // Item created, no audio yet
    case audioQueued      // Waiting for audio generation
    case audioGenerating  // Audio being created
    case audioComplete    // Audio ready
    case audioFailed      // Audio generation failed
}
```

### 7. Voice Providers (VoiceProvider Protocol)

**Purpose:** Abstract interface for text-to-speech services

**Key Protocol:**
```swift
public protocol VoiceProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    var requiresAPIKey: Bool { get }
    var isConfigured: Bool { get }

    func getAvailableVoices() async throws -> [VoiceModel]
    func generateAudio(text: String, voiceID: String, parameters: [String: Any]) async throws -> Data
}
```

**Built-in Providers:**
- `ElevenLabsVoiceProvider` - Professional TTS with 11+ voices
- `AppleVoiceProvider` - System voices (no API key needed)

**Pattern:**
```swift
// Get provider
let manager = VoiceProviderManager.shared
let provider = manager.currentProvider

// Configure if needed
if provider.requiresAPIKey && !provider.isConfigured {
    try SecureKeychainManager.shared.saveAPIKey(apiKey, for: provider.id)
}

// Get voices
let voices = try await provider.getAvailableVoices()

// Generate audio
let audioData = try await provider.generateAudio(
    text: "Hello, world!",
    voiceID: voices[0].id,
    parameters: ["model_id": "eleven_monolingual_v1"]
)
```

---

## Common Patterns

### Pattern 1: Register and Query Providers

```swift
// Register provider
let manager = AIServiceManager.shared
manager.register(OpenAIProvider())
manager.register(AnthropicProvider())

// Query by capability
let textProviders = manager.providers(
    withCapability: .textGeneration(models: [])
)

// Query by model
let gptProvider = manager.provider(
    supportingModel: "gpt-4",
    capability: .textGeneration(models: [])
)
```

### Pattern 2: Generate Content with Requestor

```swift
// Text generation
let requestor = OpenAITextRequestor(
    provider: openAIProvider,
    modelContext: context
)

let response = try await requestor.generate(
    prompt: "Explain quantum computing",
    parameters: [
        "model": "gpt-4",
        "temperature": 0.7,
        "max_tokens": 500
    ]
)

print(response.content) // Generated text
```

### Pattern 3: SwiftData Persistence

```swift
// Generate and persist
let coordinator = AIPersistenceCoordinator()

try await coordinator.generateAndPersist(
    provider: provider,
    prompt: "Write a summary",
    model: article,
    property: \Article.summary,
    context: context
)

// Article.summary is now populated
```

### Pattern 4: Manage Credentials

```swift
let keychain = SecureKeychainManager.shared

// Save
try keychain.saveAPIKey(
    "sk-...",
    for: "openai",
    validate: true
)

// Retrieve
let key = try keychain.getAPIKey(for: "openai")
defer { key.clear() } // Auto-clear on deinit

// Check
if keychain.hasCredential(for: "openai", type: .apiKey) {
    // Proceed with API call
}
```

### Pattern 5: Error Handling

```swift
do {
    let response = try await provider.generate(...)
} catch let error as AIServiceError {
    switch error {
    case .invalidAPIKey:
        // Prompt user for valid key
    case .rateLimitExceeded(let retryAfter):
        // Wait and retry
    case .modelNotFound(let model):
        // Suggest alternative model
    case .networkError:
        // Check connectivity
    default:
        // Generic error handling
    }
}
```

### Pattern 6: SpeakableItem CRUD Operations

**Create:**
```swift
let item = SpeakableItem(
    orderIndex: 0,
    screenplayID: screenplay.id.uuidString,
    sourceElementID: "scene-1",
    sourceElementType: "Dialogue",
    speakableText: "JOHN says: Hello there!",
    characterName: "john",
    rawCharacterName: "JOHN",
    ruleVersion: "1.0",
    includesCharacterAnnouncement: true,
    toneHint: .character
)
context.insert(item)
try context.save()
```

**Read (Query):**
```swift
// Fetch all items for a screenplay
let descriptor = FetchDescriptor<SpeakableItem>(
    predicate: #Predicate { $0.screenplayID == screenplayID },
    sortBy: [SortDescriptor(\.orderIndex)]
)
let items = try context.fetch(descriptor)

// Filter by status
let pending = items.filter { $0.status == .textGenerated }

// Get dialogue items only
let dialogueDescriptor = FetchDescriptor<SpeakableItem>(
    predicate: #Predicate {
        $0.screenplayID == screenplayID &&
        $0.sourceElementType == "Dialogue"
    }
)
let dialogueItems = try context.fetch(dialogueDescriptor)
```

**Update:**
```swift
// Update status
item.status = .audioQueued
try context.save()

// Add audio version
let audio = SpeakableAudio(
    hablareAudioID: UUID(),
    providerName: "ElevenLabs",
    voiceID: "voice-123",
    voiceName: "Rachel",
    audioFormat: "mp3",
    characterCount: item.speakableText.count
)
item.audioVersions.append(audio)
try context.save()
```

**Delete:**
```swift
// Delete single item
context.delete(item)
try context.save()

// Delete all items for screenplay
for item in items {
    context.delete(item)
}
try context.save()
```

### Pattern 7: Add Custom Voice Provider

**Step 1: Implement VoiceProvider Protocol**
```swift
import SwiftHablare

final class CustomVoiceProvider: VoiceProvider, @unchecked Sendable {
    let id = "custom-tts"
    let displayName = "Custom TTS Service"
    let requiresAPIKey = true

    var isConfigured: Bool {
        SecureKeychainManager.shared.hasCredential(
            for: id,
            type: .apiKey
        )
    }

    func getAvailableVoices() async throws -> [VoiceModel] {
        // Fetch voices from your API
        let response = try await fetchVoices()
        return response.map { apiVoice in
            VoiceModel(
                id: apiVoice.id,
                name: apiVoice.name,
                previewURL: apiVoice.previewURL,
                labels: apiVoice.labels,
                category: apiVoice.category
            )
        }
    }

    func generateAudio(
        text: String,
        voiceID: String,
        parameters: [String: Any]
    ) async throws -> Data {
        // Call your TTS API
        guard let apiKey = try? SecureKeychainManager.shared
            .getAPIKey(for: id).value else {
            throw VoiceProviderError.missingAPIKey
        }

        let audioData = try await callTTSAPI(
            text: text,
            voiceID: voiceID,
            apiKey: apiKey,
            parameters: parameters
        )

        return audioData
    }
}
```

**Step 2: Register Provider**
```swift
// In your app startup
let customProvider = CustomVoiceProvider()
VoiceProviderManager.shared.register(customProvider)
```

**Step 3: Use Provider**
```swift
// Switch to your provider
VoiceProviderManager.shared.switchProvider(to: "custom-tts")

// Configure API key
try SecureKeychainManager.shared.saveAPIKey(
    apiKey,
    for: "custom-tts"
)

// Generate audio
let voices = try await customProvider.getAvailableVoices()
let audio = try await customProvider.generateAudio(
    text: "Test",
    voiceID: voices[0].id,
    parameters: [:]
)
```

**Step 4: Test Provider**
```swift
final class CustomVoiceProviderTests: XCTestCase {
    func testProviderRegistration() {
        let provider = CustomVoiceProvider()
        XCTAssertEqual(provider.id, "custom-tts")
        XCTAssertTrue(provider.requiresAPIKey)
    }

    func testVoiceFetching() async throws {
        let provider = CustomVoiceProvider()
        // Configure test API key
        let voices = try await provider.getAvailableVoices()
        XCTAssertGreaterThan(voices.count, 0)
    }
}
```

**See Also:** `VOICE_PROVIDER_INTEGRATION_GUIDE.md` for comprehensive provider integration instructions

### Pattern 8: Process Screenplay with Progress Tracking

```swift
// Full workflow: Screenplay → SpeakableItems → Audio

// 1. Load screenplay
let screenplay = try context.fetch(
    FetchDescriptor<GuionDocumentModel>(
        predicate: #Predicate { $0.id == screenplayID }
    )
).first

// 2. Create generation task
let task = SpeakableItemGenerationTask(
    screenplay: screenplay,
    context: context,
    saveInterval: 50
)

// 3. Enqueue and monitor
await BackgroundTaskManager.shared.enqueue(task)

// 4. Wait for completion or monitor in UI
while task.backgroundTask.state == .running {
    print("Progress: \(task.backgroundTask.progressPercentage)%")
    try await Task.sleep(for: .milliseconds(500))
}

// 5. Query generated items
let items = try context.fetch(FetchDescriptor<SpeakableItem>(
    predicate: #Predicate { $0.screenplayID == screenplay.filename },
    sortBy: [SortDescriptor(\.orderIndex)]
))

print("Generated \(items.count) speakable items")
```

---

## Error Handling

### AIServiceError Enum

All errors conform to `AIServiceError`:

```swift
enum AIServiceError: Error {
    case invalidAPIKey
    case missingCredentials
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case modelNotFound(String)
    case invalidRequest(String)
    case networkError(Error)
    case unexpectedResponseFormat(String)
    case dataConversionError(String)
    case validationError(String)
    case providerError(String)
    case configurationError(String)
    case unsupportedOperation(String)
    case authenticationFailed
    case dataBindingError(String)
    case cacheError(String)
}
```

### Error Recovery Patterns

```swift
// Pattern 1: Retry with exponential backoff
var attempt = 0
while attempt < 3 {
    do {
        return try await provider.generate(...)
    } catch AIServiceError.rateLimitExceeded(let retryAfter) {
        try await Task.sleep(for: .seconds(retryAfter ?? Double(1 << attempt)))
        attempt += 1
    }
}

// Pattern 2: Fallback to alternative provider
do {
    return try await openAIProvider.generate(...)
} catch {
    return try await anthropicProvider.generate(...)
}

// Pattern 3: Validate before calling
guard provider.isConfigured() else {
    throw AIServiceError.missingCredentials
}
```

---

## Testing Patterns

### Pattern 1: Mock Provider

```swift
let mockProvider = MockAIServiceProvider(
    id: "mock",
    displayName: "Mock Provider",
    capabilities: [.textGeneration(models: ["mock-model"])],
    requiresAPIKey: false
)

// Configure response
mockProvider.mockResponse = .success(
    ResponseContent.text("Mocked response")
)

// Use in tests
let response = try await mockProvider.generate(...)
```

### Pattern 2: In-Memory SwiftData

```swift
let config = ModelConfiguration(isStoredInMemoryOnly: true)
let container = try ModelContainer(
    for: TestModel.self,
    configurations: config
)
let context = ModelContext(container)

// Use context for testing
```

### Pattern 3: Test Keychain

The keychain automatically detects test environment and uses `kSecAttrAccessibleAlways` for tests (no user confirmation).

```swift
// Test runs with automatic test detection
let keychain = SecureKeychainManager.shared
try keychain.saveAPIKey("test-key", for: "test", validate: false)
```

---

## Extension Guide

### Adding a New Provider

1. **Conform to Protocol**

```swift
final class CustomProvider: AIServiceProvider {
    let providerId = "custom"
    let displayName = "Custom AI"
    let capabilities: Set<AICapability> = [
        .textGeneration(models: ["custom-1"])
    ]
    let requiresAPIKey = true

    func generate(
        prompt: String,
        parameters: [String: Any],
        context: ModelContext
    ) async throws -> Result<ResponseContent, AIServiceError> {
        // Implementation
    }

    func isConfigured() -> Bool {
        SecureKeychainManager.shared.hasCredential(
            for: "custom",
            type: .apiKey
        )
    }
}
```

2. **Register with Manager**

```swift
AIServiceManager.shared.register(CustomProvider())
```

3. **Add Tests**

```swift
final class CustomProviderTests: XCTestCase {
    func testProviderRegistration() {
        let provider = CustomProvider()
        XCTAssertEqual(provider.providerId, "custom")
        XCTAssertTrue(provider.capabilities.contains(.textGeneration))
    }
}
```

### Adding a New Requestor

```swift
actor CustomRequestor: AIRequestor {
    typealias OutputType = CustomResult

    private let provider: AIServiceProvider
    private let modelContext: ModelContext

    func generate(
        prompt: String,
        parameters: [String: Any]
    ) async throws -> CustomResult {
        let result = try await provider.generate(
            prompt: prompt,
            parameters: parameters,
            context: modelContext
        )

        // Process result
        return CustomResult(from: result)
    }
}
```

### Adding a New SwiftData Model

```swift
import SwiftData

@Model
final class CustomContent {
    var id: UUID
    var prompt: String
    var response: String
    var createdAt: Date
    var providerID: String

    init(prompt: String, response: String, providerID: String) {
        self.id = UUID()
        self.prompt = prompt
        self.response = response
        self.createdAt = Date()
        self.providerID = providerID
    }
}
```

---

## Quick Reference Cheat Sheet

### Most Common Operations

```swift
// 1. Setup
let manager = AIServiceManager.shared
let provider = manager.provider(for: "openai")

// 2. Configure credentials
try SecureKeychainManager.shared.saveAPIKey(key, for: "openai")

// 3. Generate content
let result = try await provider.generate(
    prompt: "Your prompt",
    parameters: ["model": "gpt-4"],
    context: modelContext
)

// 4. Access content
switch result {
case .success(let content):
    if let text = content.text {
        print(text)
    }
case .failure(let error):
    print("Error: \(error)")
}

// 5. Persist to SwiftData
try await coordinator.generateAndPersist(
    provider: provider,
    prompt: "Generate...",
    model: myModel,
    property: \MyModel.field,
    context: context
)
```

### Import Statements

```swift
import SwiftData         // For persistence
import SwiftHablare      // Main framework
```

### File Locations for Common Tasks

| Task | File to Reference |
|------|-------------------|
| Add AI provider | `Sources/SwiftHablare/Providers/` |
| Add requestor | `Sources/SwiftHablare/Requestors/` |
| Add SwiftData model | `Sources/SwiftHablare/Models/` |
| Modify protocols | `Sources/SwiftHablare/Core/AIServiceProvider.swift` |
| Update credentials | `Sources/SwiftHablare/Security/SecureKeychainManager.swift` |
| Add voice provider | `Sources/SwiftHablare/VoiceProvider.swift` (protocol), then register with `VoiceProviderManager` |
| Add screenplay task | `Sources/SwiftHablare/ScreenplaySpeech/Tasks/` |
| Modify speech logic | `Sources/SwiftHablare/ScreenplaySpeech/Logic/SpeechLogicRulesV1_0.swift` |
| Query SpeakableItems | Use `FetchDescriptor<SpeakableItem>` with SwiftData |
| Add tests | `Tests/SwiftHablareTests/` (AI) or `Tests/SwiftHablareTests/ScreenplaySpeech/` (Speech) |

---

## Best Practices for AI Agents

### Core AI Framework
1. **Always check `isConfigured()`** before calling provider methods
2. **Use `defer { secureString.clear() }`** when handling credentials
3. **Prefer `@MainActor`** for SwiftUI integration code
4. **Use actors** for shared mutable state
5. **Follow existing naming conventions** (e.g., `ProviderNameProvider`)
6. **Handle all error cases** from AIServiceError
7. **Use strict concurrency** (Swift 6 mode)
8. **Document public APIs** with /// comments

### ScreenplaySpeech System
9. **Query by screenplayID** - Always filter SpeakableItems by screenplayID to avoid mixing screenplay data
10. **Sort by orderIndex** - SpeakableItems must be processed in sequence order
11. **Check task state** - Monitor `backgroundTask.state` before assuming task completion
12. **Handle cancellation** - Design tasks to preserve partial results on cancellation
13. **Use periodic saves** - Long-running tasks should save incrementally (every 50 items)
14. **Track progress** - Update `currentStep` and `message` for user feedback
15. **Respect blocking tasks** - UI should indicate when blocking tasks prevent user interaction

### Testing
16. **Test with in-memory SwiftData** for fast, isolated tests
17. **Add comprehensive tests** (aim for 90%+ coverage)
18. **Mock voice providers** for unit tests (avoid real API calls)
19. **Test cancellation** - Verify tasks handle mid-execution cancellation
20. **Test progress tracking** - Ensure totalSteps and currentStep are accurate

---

## Additional Resources

### Core AI Framework
- **API Reference:** See `API.md` for detailed type documentation
- **Usage Examples:** See `Docs/Previous/EXAMPLES.md` for code samples
- **Quick Start:** See `QUICK_START.md` for getting started
- **Requirements:** See `REQUIREMENTS.md` for full specifications
- **Methodology:** See `Docs/Previous/METHODOLOGY.md` for development process

### ScreenplaySpeech System
- **UI Sprint Methodology:** See `Docs/SCREENPLAY_UI_SPRINT_METHODOLOGY.md` for phased development approach
- **UI Workflow Design:** See `Docs/SCREENPLAY_UI_WORKFLOW_DESIGN.md` for complete UI specification
- **UI Decisions:** See `Docs/SCREENPLAY_UI_DECISIONS.md` for critical design decisions
- **Voice Provider Integration:** See `VOICE_PROVIDER_INTEGRATION_GUIDE.md` for custom provider creation
- **SwiftGuion Integration:** See `Docs/Previous/SWIFTGUION_INTEGRATION_ANALYSIS.md` for screenplay parser details

---

**Last Updated:** October 18, 2025
**Version:** 2.0 (Core AI Phase 7 + UI Sprint Phase 2)
**Test Coverage:** 787 tests, 96% average
**ScreenplaySpeech Coverage:** 90%+ (Phase 1-2 modules at 92-100%)
