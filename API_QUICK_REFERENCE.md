# SwiftHablaré API Quick Reference

Fast lookup reference for AI bots and developers. All APIs use Swift 6.2+ strict concurrency.

## Core Protocols

### AIServiceProvider

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

    func isConfigured() -> Bool
    func supportsCapability(_ capability: AICapability) -> Bool
    func supportsModel(_ model: String, capability: AICapability) -> Bool
}
```

### AIRequestor

```swift
protocol AIRequestor<OutputType> {
    associatedtype OutputType

    func generate(
        prompt: String,
        parameters: [String: Any]
    ) async throws -> OutputType
}
```

## Enums

### AICapability

```swift
enum AICapability: Sendable, Codable, Hashable {
    case textGeneration(models: [String])
    case audioGeneration(formats: [String])
    case imageGeneration(sizes: [String])
    case videoGeneration(formats: [String])
    case embedding(dimensions: [Int])
    case chat
    case streaming
    case functionCalling
}
```

### ResponseContent

```swift
enum ResponseContent: Sendable {
    case text(String)
    case data(Data)
    case audio(Data, format: AudioFormat)
    case image(Data, format: ImageFormat)
    case video(Data, format: VideoFormat)
    case structured([String: SendableValue])
    case embedding([Float], dimensions: Int)

    var text: String? { get }
    var dataContent: Data? { get }
    var structuredContent: [String: SendableValue]? { get }
}
```

### AIServiceError

```swift
enum AIServiceError: Error, LocalizedError {
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

    var failureReason: String? { get }
    var recoverySuggestion: String? { get }
}
```

## Managers

### AIServiceManager

```swift
@MainActor
final class AIServiceManager {
    static let shared: AIServiceManager

    func register(_ provider: AIServiceProvider)
    func unregister(providerId: String)
    func provider(for id: String) -> AIServiceProvider?
    func getAvailableProviders() -> [AIServiceProvider]
    func providers(withCapability: AICapability) -> [AIServiceProvider]
    func provider(
        supportingModel: String,
        capability: AICapability
    ) -> AIServiceProvider?
}
```

### SecureKeychainManager

```swift
final class SecureKeychainManager: Sendable {
    static let shared: SecureKeychainManager

    // API Keys
    func saveAPIKey(
        _ key: String,
        for account: String,
        validate: Bool = true
    ) throws

    func getAPIKey(for account: String) throws -> SecureString
    func deleteAPIKey(for account: String) throws

    // OAuth Tokens
    func saveOAuthToken(
        _ token: String,
        for account: String,
        validate: Bool = true
    ) throws

    func getOAuthToken(for account: String) throws -> SecureString
    func deleteOAuthToken(for account: String) throws

    // Certificates
    func saveCertificate(
        _ data: Data,
        for account: String,
        validate: Bool = true
    ) throws

    func getCertificate(for account: String) throws -> Data
    func deleteCertificate(for account: String) throws

    // Generic
    func hasCredential(
        for account: String,
        type: AICredentialType
    ) -> Bool

    func listAccounts(for type: AICredentialType) -> [String]
    func deleteAllCredentials() throws
}
```

## Coordinators

### AIPersistenceCoordinator

```swift
struct AIPersistenceCoordinator {
    func generateAndPersist<T>(
        provider: AIServiceProvider,
        prompt: String,
        model: T,
        property: WritableKeyPath<T, String>,
        context: ModelContext,
        parameters: [String: Any] = [:],
        constraints: [String: String] = [:],
        transform: ((Any) throws -> Any)? = nil,
        useCache: Bool = false
    ) async throws

    func generateAndPersistMultiple<T>(
        provider: AIServiceProvider,
        prompts: [String: String],
        model: T,
        context: ModelContext
    ) async throws

    func clearCache() async
    func invalidateCache(forProvider: String) async
    func cacheStatistics() async -> [String: Int]
    func registerValidationRule(_ rule: AIContentValidator.ValidationRule)
}
```

### AIDataCoordinator

```swift
@MainActor
final class AIDataCoordinator {
    init(
        validator: AIContentValidator = AIContentValidator(),
        binder: AIPropertyBinder = AIPropertyBinder()
    )

    func mergeResponse<T, V>(
        _ response: AIResponseData,
        into model: T,
        property: ReferenceWritableKeyPath<T, V>,
        context: ModelContext,
        transform: ((ResponseContent) throws -> V)? = nil,
        constraints: [String: String] = [:]
    ) async throws

    func mergeTextResponse<T>(
        _ response: AIResponseData,
        into model: T,
        property: ReferenceWritableKeyPath<T, String>,
        context: ModelContext
    ) async throws

    func mergeDataResponse<T>(
        _ response: AIResponseData,
        into model: T,
        property: ReferenceWritableKeyPath<T, Data>,
        context: ModelContext
    ) async throws

    func mergeBatch<T, V>(
        responses: [AIResponseData],
        into models: [T],
        property: ReferenceWritableKeyPath<T, V>,
        context: ModelContext
    ) async -> [Result<Void, Error>]

    func validateResponse(
        _ response: AIResponseData,
        constraints: [String: String]
    ) async throws

    func processResponse<T>(
        _ response: AIResponseData,
        as type: T.Type,
        transform: ((ResponseContent) throws -> T)? = nil
    ) throws -> T

    func registerValidationRule(_ rule: AIContentValidator.ValidationRule)

    var willMergeResponse: ((AIResponseData) -> Void)?
    var didMergeResponse: ((AIResponseData) -> Void)?
    var didFailMerge: ((AIResponseData, Error) -> Void)?
}
```

## Requestors

### OpenAITextRequestor

```swift
actor OpenAITextRequestor: AIRequestor {
    typealias OutputType = OpenAITextResponse

    init(provider: AIServiceProvider, modelContext: ModelContext)

    func generate(
        prompt: String,
        parameters: [String: Any]
    ) async throws -> OpenAITextResponse
}

struct OpenAITextResponse {
    let content: String
    let model: String
    let finishReason: String
    let usage: Usage
    let createdAt: Date

    struct Usage {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
    }
}
```

### OpenAIImageRequestor

```swift
actor OpenAIImageRequestor: AIRequestor {
    typealias OutputType = OpenAIImageResponse

    init(provider: AIServiceProvider, modelContext: ModelContext)

    func generate(
        prompt: String,
        parameters: [String: Any]
    ) async throws -> OpenAIImageResponse
}

struct OpenAIImageResponse {
    let imageData: Data
    let revisedPrompt: String?
    let model: String
    let createdAt: Date
}
```

### ElevenLabsAudioRequestor

```swift
actor ElevenLabsAudioRequestor: AIRequestor {
    typealias OutputType = ElevenLabsAudioResponse

    init(provider: AIServiceProvider, modelContext: ModelContext)

    func generate(
        prompt: String,
        parameters: [String: Any]
    ) async throws -> ElevenLabsAudioResponse
}

struct ElevenLabsAudioResponse {
    let audioData: Data
    let format: AudioFormat
    let voiceId: String
    let modelId: String
    let createdAt: Date
}
```

### OpenAIEmbeddingRequestor

```swift
actor OpenAIEmbeddingRequestor: AIRequestor {
    typealias OutputType = OpenAIEmbeddingResponse

    init(provider: AIServiceProvider, modelContext: ModelContext)

    func generate(
        prompt: String,
        parameters: [String: Any]
    ) async throws -> OpenAIEmbeddingResponse
}

struct OpenAIEmbeddingResponse {
    let values: [Float]
    let dimensions: Int
    let model: String
    let usage: Usage
    let createdAt: Date

    struct Usage {
        let promptTokens: Int
        let totalTokens: Int
    }
}
```

## Providers

### OpenAIProvider

```swift
final class OpenAIProvider: AIServiceProvider {
    let providerId = "openai"
    let displayName = "OpenAI"
    let capabilities: Set<AICapability> = [
        .textGeneration(models: [
            "gpt-4", "gpt-4-turbo",
            "gpt-3.5-turbo"
        ]),
        .imageGeneration(sizes: ["1024x1024", "1792x1024", "1024x1792"]),
        .embedding(dimensions: [512, 1536, 3072])
    ]
    let requiresAPIKey = true
}
```

### AnthropicProvider

```swift
final class AnthropicProvider: AIServiceProvider {
    let providerId = "anthropic"
    let displayName = "Anthropic"
    let capabilities: Set<AICapability> = [
        .textGeneration(models: [
            "claude-3-opus-20240229",
            "claude-3-sonnet-20240229",
            "claude-3-haiku-20240307"
        ])
    ]
    let requiresAPIKey = true
}
```

### ElevenLabsProvider

```swift
final class ElevenLabsProvider: AIServiceProvider {
    let providerId = "elevenlabs"
    let displayName = "ElevenLabs"
    let capabilities: Set<AICapability> = [
        .audioGeneration(formats: ["mp3"])
    ]
    let requiresAPIKey = true
}
```

### AppleIntelligenceProvider

```swift
final class AppleIntelligenceProvider: AIServiceProvider {
    let providerId = "apple"
    let displayName = "Apple Intelligence"
    let capabilities: Set<AICapability> = [
        .textGeneration(models: ["apple-default"])
    ]
    let requiresAPIKey = false
}
```

## Helper Classes

### SecureString

```swift
final class SecureString {
    var value: String { get }
    func clear()
}
```

### AIContentValidator

```swift
actor AIContentValidator {
    func validate(
        _ value: Any,
        constraints: [String: String]
    ) async throws -> ValidationResult

    func registerRule(_ rule: ValidationRule)

    struct ValidationRule {
        let name: String
        let validate: (Any) async throws -> Bool
        let errorMessage: String
    }

    struct ValidationResult {
        let isValid: Bool
        let errors: [String]
    }
}
```

### AIResponseCache

```swift
actor AIResponseCache {
    func get(_ key: String) async -> ResponseContent?
    func set(_ key: String, _ content: ResponseContent) async
    func remove(_ key: String) async
    func clear() async
    func count() async -> Int
    func invalidate(forProvider: String) async
}
```

## Common Parameter Keys

### Text Generation (OpenAI)

```swift
[
    "model": "gpt-4",                 // Required
    "temperature": 0.7,               // 0.0-2.0
    "max_tokens": 500,                // Max completion length
    "top_p": 0.9,                     // Nucleus sampling
    "frequency_penalty": 0.0,         // -2.0 to 2.0
    "presence_penalty": 0.0,          // -2.0 to 2.0
    "stop": ["END"],                  // Stop sequences
    "stream": false                   // Streaming mode
]
```

### Text Generation (Anthropic)

```swift
[
    "model": "claude-3-opus-20240229",  // Required
    "max_tokens": 1000,                  // Required
    "temperature": 0.7,                  // 0.0-1.0
    "top_p": 0.9,
    "top_k": 40,
    "system": "You are helpful"          // System prompt
]
```

### Image Generation (DALL-E)

```swift
[
    "model": "dall-e-3",              // dall-e-2 or dall-e-3
    "size": "1024x1024",              // 256x256, 512x512, 1024x1024, etc.
    "quality": "hd",                  // standard or hd
    "style": "vivid",                 // vivid or natural
    "n": 1                            // Number of images
]
```

### Audio Generation (ElevenLabs)

```swift
[
    "voice_id": "21m00Tcm4TlvDq8ikWAM",    // Required
    "model_id": "eleven_monolingual_v1",   // Required
    "stability": 0.5,                       // 0.0-1.0
    "similarity_boost": 0.75,               // 0.0-1.0
    "style": 0.0,                          // 0.0-1.0
    "use_speaker_boost": true
]
```

### Embeddings (OpenAI)

```swift
[
    "model": "text-embedding-3-small",  // Required
    "dimensions": 512,                  // Optional reduction
    "encoding_format": "float"          // float or base64
]
```

## SwiftData Models

### Example Model Setup

```swift
import SwiftData

@Model
final class MyContent {
    var id: UUID
    var prompt: String
    var response: String
    var createdAt: Date
    var providerID: String
    var metadata: [String: String] = [:]

    init(prompt: String) {
        self.id = UUID()
        self.prompt = prompt
        self.response = ""
        self.createdAt = Date()
        self.providerID = ""
    }
}

// In app
let container = try ModelContainer(for: MyContent.self)
let context = ModelContext(container)
```

## Import Statements

```swift
import SwiftData         // Persistence
import SwiftHablare      // Main framework
import SwiftUI           // For UI integration
```

## Common Imports by File Type

**Provider Implementation:**
```swift
import Foundation
import SwiftData
```

**Requestor Implementation:**
```swift
import Foundation
import SwiftData
```

**SwiftUI View:**
```swift
import SwiftUI
import SwiftData
import SwiftHablare
```

**Tests:**
```swift
import XCTest
@testable import SwiftHablare
import SwiftData
```

---

## Quick Patterns

### Generate Text
```swift
let result = try await provider.generate(
    prompt: "Your prompt",
    parameters: ["model": "gpt-4"],
    context: context
)
```

### Save Credential
```swift
try SecureKeychainManager.shared.saveAPIKey(
    "key",
    for: "provider"
)
```

### Persist to SwiftData
```swift
try await coordinator.generateAndPersist(
    provider: provider,
    prompt: "prompt",
    model: model,
    property: \Model.field,
    context: context
)
```

### Handle Error
```swift
catch let error as AIServiceError {
    switch error {
    case .invalidAPIKey: // handle
    case .rateLimitExceeded: // handle
    default: // handle
    }
}
```

---

**Version:** 2.0 (Phase 7 Complete)
**Last Updated:** October 13, 2025
**Swift:** 6.2+ strict concurrency
**Platforms:** macOS 26+, iOS 17+
