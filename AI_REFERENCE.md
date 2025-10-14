# SwiftHablaré AI Reference Sheet

**Optimized for AI bots needing rapid recall of project fundamentals.**

## Core Facts (60-Second Overview)

- **Purpose**: Unified Swift framework for AI service integration across OpenAI, Anthropic, ElevenLabs, and Apple Intelligence
- **Version**: 2.0 (Phase 7 Complete - 559 tests, 96% coverage)
- **Language**: Swift 6.2+ with strict concurrency
- **Platforms**: macOS 26+, iOS 17+
- **Architecture**: Three-layer (Application → Coordination → Provider)
- **Persistence**: SwiftData for all generated content
- **Security**: Keychain for credential management
- **Testing**: 559 tests, 96% average coverage, Swift Testing + XCTest

## Key Concepts (5 Minutes)

### 1. Providers = AI Services
**4 Built-in Providers:**
- `OpenAIProvider` - GPT models, DALL-E, embeddings
- `AnthropicProvider` - Claude models
- `ElevenLabsProvider` - Text-to-speech
- `AppleIntelligenceProvider` - On-device AI

**Access:** `AIServiceManager.shared.provider(for: "openai")`

### 2. Requestors = Typed Interfaces
**12 Available Requestors:**
- Text: OpenAI, Anthropic (8 models)
- Audio: ElevenLabs (11 voices)
- Image: DALL-E 2/3
- Embedding: OpenAI (3 models)

**Pattern:**
```swift
let requestor = OpenAITextRequestor(provider, context)
let response = try await requestor.generate(prompt, params)
```

### 3. Content Types = Responses
**Unified enum:**
- `.text(String)` - Text content
- `.audio(Data, format)` - Audio files
- `.image(Data, format)` - Image files
- `.embedding([Float], dimensions)` - Vector embeddings
- `.structured([String: Value])` - JSON data
- `.data(Data)` - Raw binary

### 4. SwiftData = Auto-Persistence
**Pattern:**
```swift
let coordinator = AIPersistenceCoordinator()
try await coordinator.generateAndPersist(
    provider: provider,
    prompt: "Generate...",
    model: article,
    property: \Article.summary,
    context: context
)
// article.summary now populated and saved
```

### 5. Keychain = Secure Credentials
**Pattern:**
```swift
let keychain = SecureKeychainManager.shared
try keychain.saveAPIKey("sk-...", for: "openai")
let key = try keychain.getAPIKey(for: "openai")
defer { key.clear() }  // Auto-clear
```

## Memory-Saving Tips for AI Agents

1. **Check Configuration First**
   ```swift
   guard provider.isConfigured() else { return }
   ```

2. **Use In-Memory SwiftData for Tests**
   ```swift
   let config = ModelConfiguration(isStoredInMemoryOnly: true)
   let container = try ModelContainer(for: Model.self, configurations: config)
   ```

3. **Always Clear Credentials**
   ```swift
   let key = try keychain.getAPIKey(for: "openai")
   defer { key.clear() }  // Critical for security
   ```

4. **Batch Operations with TaskGroup**
   ```swift
   try await withThrowingTaskGroup(of: Response.self) { group in
       for prompt in prompts {
           group.addTask { try await provider.generate(...) }
       }
   }
   ```

5. **Cache Awareness**
   ```swift
   try await coordinator.generateAndPersist(..., useCache: true)
   ```

6. **Error Recovery**
   ```swift
   catch AIServiceError.rateLimitExceeded(let retryAfter) {
       try await Task.sleep(for: .seconds(retryAfter ?? 1))
       // Retry
   }
   ```

## Typical Automation Sequences

### Generate Text Content
```swift
// 1. Get provider
let manager = AIServiceManager.shared
let provider = manager.provider(for: "openai")!

// 2. Ensure configured
guard provider.isConfigured() else {
    try keychain.saveAPIKey(apiKey, for: "openai")
}

// 3. Generate
let result = try await provider.generate(
    prompt: "Your prompt",
    parameters: ["model": "gpt-4"],
    context: context
)

// 4. Handle result
if case .success(let content) = result {
    print(content.text ?? "")
}
```

### Generate and Persist
```swift
// 1. Setup
let coordinator = AIPersistenceCoordinator()
let article = Article(title: "Swift Concurrency")
context.insert(article)

// 2. Generate and save
try await coordinator.generateAndPersist(
    provider: provider,
    prompt: "Summarize: \(article.title)",
    model: article,
    property: \Article.summary,
    context: context
)

// 3. Article.summary is now populated
```

### Multiple Providers
```swift
// Query by capability
let textProviders = manager.providers(
    withCapability: .textGeneration(models: [])
)

// Query by model
let gpt4Provider = manager.provider(
    supportingModel: "gpt-4",
    capability: .textGeneration(models: [])
)
```

## Testing Hooks

### Mock Provider
```swift
let mock = MockAIServiceProvider(
    id: "mock",
    capabilities: [.textGeneration(models: ["mock"])],
    requiresAPIKey: false
)
mock.mockResponse = .success(.text("Mocked"))
```

### Test Patterns
- **Unit Tests**: `Tests/SwiftHablareTests/`
- **In-Memory Data**: `ModelConfiguration(isStoredInMemoryOnly: true)`
- **Auto-Unlocking Keychain**: Automatic in test environment
- **Coverage Target**: 90%+ for all new code
- **Framework**: XCTest + Swift Testing

## Module Structure

```
Sources/SwiftHablare/
├── Core/               # Protocols, managers, coordinators
│   ├── AIServiceProvider.swift
│   ├── AIServiceManager.swift
│   ├── AIDataCoordinator.swift
│   └── AIPersistenceCoordinator.swift
├── Providers/          # AI service implementations
│   ├── OpenAIProvider.swift
│   ├── AnthropicProvider.swift
│   ├── ElevenLabsProvider.swift
│   └── AppleIntelligenceProvider.swift
├── Requestors/         # Typed request interfaces
│   ├── Text/
│   ├── Audio/
│   ├── Image/
│   └── Embedding/
├── Models/             # SwiftData persistence
├── Security/           # Keychain management
├── Request/            # Request lifecycle
└── UI/                 # SwiftUI components
```

## Common Error Codes

```swift
enum AIServiceError {
    case invalidAPIKey              // Bad credential
    case missingCredentials         // No credential
    case rateLimitExceeded(retry?)  // Wait and retry
    case modelNotFound(String)      // Wrong model name
    case networkError(Error)        // Connectivity
    case unexpectedResponseFormat   // API changed
    case validationError(String)    // Content invalid
    case providerError(String)      // Provider-specific
}
```

## Parameter Quick Reference

### Text (OpenAI)
```swift
["model": "gpt-4", "temperature": 0.7, "max_tokens": 500]
```

### Text (Anthropic)
```swift
["model": "claude-3-opus-20240229", "max_tokens": 1000]
```

### Image (DALL-E)
```swift
["model": "dall-e-3", "size": "1024x1024", "quality": "hd"]
```

### Audio (ElevenLabs)
```swift
["voice_id": "21m00Tcm4TlvDq8ikWAM", "model_id": "eleven_monolingual_v1"]
```

### Embedding (OpenAI)
```swift
["model": "text-embedding-3-small", "dimensions": 512]
```

## Available Models (Quick Lookup)

**Text Generation:**
- OpenAI: `gpt-4`, `gpt-4-turbo`, `gpt-3.5-turbo`
- Anthropic: `claude-3-opus-20240229`, `claude-3-sonnet-20240229`, `claude-3-haiku-20240307`

**Image Generation:**
- OpenAI: `dall-e-2`, `dall-e-3`

**Embeddings:**
- OpenAI: `text-embedding-3-small`, `text-embedding-3-large`, `text-embedding-ada-002`

**Audio:**
- ElevenLabs: 11 voices (Rachel, Drew, Clyde, Paul, etc.)

## Extensibility Checklist

Adding a new provider:
1. ✅ Conform to `AIServiceProvider` protocol
2. ✅ Register with `AIServiceManager.shared.register(provider)`
3. ✅ Add tests (aim for 90%+ coverage)
4. ✅ Document in provider docs
5. ✅ Add credential support if needed

Adding a new requestor:
1. ✅ Conform to `AIRequestor` protocol
2. ✅ Define `OutputType` struct
3. ✅ Implement `generate(prompt:parameters:)`
4. ✅ Add tests
5. ✅ Update examples documentation

## Documentation Map

- **Quick Start**: `QUICK_START.md` - Get started in 5 minutes
- **Examples**: `EXAMPLES.md` - Copy-paste code samples
- **AI Guide**: `Docs/AI_DEVELOPMENT_GUIDE.md` - Comprehensive AI bot guide
- **API Reference**: `API_QUICK_REFERENCE.md` - Fast API lookup
- **Requirements**: `REQUIREMENTS.md` - Full specifications
- **Methodology**: `METHODOLOGY.md` - Development process

## Performance Tips

1. **Concurrent Requests**
   ```swift
   async let r1 = generate(prompt1)
   async let r2 = generate(prompt2)
   let (result1, result2) = try await (r1, r2)
   ```

2. **Batch Processing**
   ```swift
   try await withThrowingTaskGroup(of: Result.self) { group in
       for item in items {
           group.addTask { try await process(item) }
       }
   }
   ```

3. **Cache Strategy**
   ```swift
   try await coordinator.generateAndPersist(..., useCache: true)
   ```

4. **Retry Logic**
   ```swift
   for attempt in 1...3 {
       do {
           return try await provider.generate(...)
       } catch AIServiceError.rateLimitExceeded(let retry) {
           try await Task.sleep(for: .seconds(retry ?? Double(1 << attempt)))
       }
   }
   ```

## Concurrency Model

- **Actors**: Thread-safe mutable state
  - `AIRequestManager` - Request lifecycle
  - `AIContentValidator` - Validation logic
  - `AIResponseCache` - Caching layer
  - All requestors are actors

- **@MainActor**: UI and SwiftData
  - `AIServiceManager` - Provider registry
  - `AIDataCoordinator` - Data merging
  - SwiftUI views

- **Sendable**: Cross-actor passing
  - All providers conform to `Sendable`
  - All content types are `Sendable`
  - All errors are `Sendable`

## Import Cheat Sheet

```swift
// Basic usage
import SwiftData
import SwiftHablare

// SwiftUI integration
import SwiftUI
import SwiftData
import SwiftHablare

// Testing
import XCTest
@testable import SwiftHablare
import SwiftData
```

## Status & Roadmap

**Current Phase**: Phase 7 Complete ✅
- 559 tests, 96% average coverage
- All core modules at 90%+ coverage
- Production-ready test infrastructure

**Next Phase**: Phase 8 - Sample Applications
- Example apps demonstrating framework usage
- Real-world integration patterns
- Best practices showcase

---

**Version**: 2.0 (Phase 7 Complete)
**Last Updated**: October 13, 2025
**Test Coverage**: 559 tests, 96% average
**Swift**: 6.2+ strict concurrency
**Platforms**: macOS 26+, iOS 17+

For detailed information, see comprehensive documentation in `Docs/` and root-level guides.
