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
- **Phase:** Phase 7 Complete (Test Coverage & QA)
- **Next Phase:** Phase 8 (Sample Applications)
- **Test Coverage:** 559 tests, 96% average coverage
- **Swift Version:** 6.0 (strict concurrency mode)
- **Platforms:** macOS 15.0+, iOS 17.0+
- **Framework:** Swift Package Manager

### Key Technologies
- **Concurrency:** Swift structured concurrency (async/await, actors)
- **Persistence:** SwiftData for model storage
- **Security:** Keychain for credential management
- **UI:** SwiftUI components (Phase 7A)
- **Testing:** XCTest + Swift Testing framework

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
└── UI/                # SwiftUI configuration views
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
| Add provider | `Sources/SwiftHablare/Providers/` |
| Add requestor | `Sources/SwiftHablare/Requestors/` |
| Add model | `Sources/SwiftHablare/Models/` |
| Modify protocols | `Sources/SwiftHablare/Core/AIServiceProvider.swift` |
| Update credentials | `Sources/SwiftHablare/Security/SecureKeychainManager.swift` |
| Add tests | `Tests/SwiftHablareTests/` |

---

## Best Practices for AI Agents

1. **Always check `isConfigured()`** before calling provider methods
2. **Use `defer { secureString.clear() }`** when handling credentials
3. **Prefer `@MainActor`** for SwiftUI integration code
4. **Use actors** for shared mutable state
5. **Test with in-memory SwiftData** for fast, isolated tests
6. **Follow existing naming conventions** (e.g., `ProviderNameProvider`)
7. **Add comprehensive tests** (aim for 90%+ coverage)
8. **Document public APIs** with /// comments
9. **Use strict concurrency** (Swift 6 mode)
10. **Handle all error cases** from AIServiceError

---

## Additional Resources

- **API Reference:** See `API.md` for detailed type documentation
- **Usage Examples:** See `EXAMPLES.md` for code samples
- **Quick Start:** See `QUICK_START.md` for getting started
- **Requirements:** See `REQUIREMENTS.md` for full specifications
- **Methodology:** See `METHODOLOGY.md` for development process

---

**Last Updated:** October 13, 2025
**Version:** 2.0 (Phase 7 Complete)
**Test Coverage:** 559 tests, 96% average
