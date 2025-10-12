# Phase 6: Provider Refactoring Plan

**Created**: 2025-10-12
**Status**: Planning Document
**Purpose**: Document the required changes to Phase 5 providers to support Phase 6 API Requestor pattern

---

## Executive Summary

Phase 5 delivered four production-ready AI service providers (OpenAI, Anthropic, Apple Intelligence, ElevenLabs) using a **monolithic provider architecture** where each provider is a single entity capable of multiple generation types.

Phase 6 requires migrating to an **API Requestor pattern** where:
- One requestor generates **exactly one file type**
- Providers offer **multiple requestors** via `availableRequestors()` method
- Each requestor has its own configuration, SwiftData model, and UI

This document details the refactoring needed for existing Phase 5 providers and updates required to Phase 6+ milestones.

---

## Gap Analysis: Phase 5 vs Phase 6

### Phase 5 Architecture (Current)

**Monolithic Provider Pattern:**

```swift
// Single provider handles multiple capabilities
public class OpenAIProvider: AIServiceProvider {
    public let capabilities: [AICapability] = [
        .textGeneration,
        .embeddings
    ]

    // Single generate method returns different types based on parameters
    public func generate(
        prompt: String,
        parameters: [String: Any]
    ) async -> Result<ResponseContent, AIServiceError>
}
```

**Provider Structure:**
- `OpenAIProvider` - Handles text generation, embeddings
- `AnthropicProvider` - Handles text generation
- `AppleIntelligenceProvider` - Handles on-device text generation
- `ElevenLabsProvider` - Handles audio generation (TTS)

**Key Characteristics:**
- Single entry point (`generate()`)
- Generic `ResponseContent` enum return type
- Capabilities declared at provider level
- No type-specific configuration widgets
- No dedicated SwiftData models per type
- No three-view UI pattern

### Phase 6 Architecture (Required)

**API Requestor Pattern:**

```swift
// Provider offers multiple requestors
public class OpenAIProvider: AIServiceProvider {
    public func availableRequestors() -> [any AIRequestor] {
        return [
            OpenAITextRequestor(provider: self, model: .gpt4),
            OpenAIImageRequestor(provider: self, model: .dalle3),
            OpenAIEmbeddingRequestor(provider: self)
        ]
    }
}

// Each requestor generates exactly one file type
public class OpenAITextRequestor: AIRequestor {
    public typealias TypedData = GeneratedText
    public typealias ResponseModel = GeneratedTextRecord
    public typealias Configuration = TextGenerationConfig

    public let category: ProviderCategory = .text
    public let outputFileType = OutputFileType.plainText

    // Type-specific request
    public func request(
        prompt: String,
        configuration: Configuration,
        storageArea: StorageAreaReference
    ) async -> Result<TypedData, AIServiceError>

    // SwiftData model creation
    @MainActor
    public func makeResponseModel(
        from data: TypedData,
        fileReference: TypedDataFileReference?,
        requestID: UUID
    ) -> ResponseModel

    // UI components (Phase 7)
    @MainActor
    func makeConfigurationView(configuration: Binding<Configuration>) -> AnyView
    @MainActor
    func makeListItemView(model: ResponseModel) -> AnyView
    @MainActor
    func makeDetailView(model: ResponseModel) -> AnyView
}
```

**Key Differences:**
- Providers become **requestor factories**
- Each requestor = one file type
- Type-specific configurations
- Dedicated SwiftData models per requestor
- Three-view UI pattern per requestor
- Type-specific serialization strategies
- Storage area references for large data

---

## Required Refactoring by Provider

### 1. OpenAI Provider

**Current Capabilities:**
- Text generation (GPT-4, GPT-3.5)
- Embeddings (mentioned in capabilities)

**Required Requestors:**

#### OpenAITextRequestor
```swift
public class OpenAITextRequestor: AIRequestor {
    public typealias TypedData = GeneratedText
    public typealias ResponseModel = GeneratedTextRecord
    public typealias Configuration = TextGenerationConfig

    public let requestorID = "openai-text"
    public let displayName = "OpenAI Text Generation"
    public let category: ProviderCategory = .text
    public let outputFileType = OutputFileType.plainText

    struct TextGenerationConfig: Codable, Sendable {
        var model: String = "gpt-4"
        var temperature: Double = 0.7
        var maxTokens: Int? = nil
        var systemPrompt: String? = nil
    }
}
```

**SwiftData Model:**
```swift
@Model
public class GeneratedTextRecord: AIGeneratedContent {
    public var text: String
    public var model: String
    public var tokenUsage: TokenUsage?
    public var requestID: UUID
    public var createdAt: Date
}
```

#### OpenAIImageRequestor (Future)
```swift
public class OpenAIImageRequestor: AIRequestor {
    public typealias TypedData = GeneratedImage
    public typealias ResponseModel = GeneratedImageRecord
    public typealias Configuration = ImageGenerationConfig

    public let requestorID = "openai-image"
    public let displayName = "DALL-E Image Generation"
    public let category: ProviderCategory = .image
    public let outputFileType = OutputFileType.png

    struct ImageGenerationConfig: Codable, Sendable {
        var model: String = "dall-e-3"
        var size: String = "1024x1024"
        var quality: String = "standard"
        var style: String = "vivid"
    }
}
```

#### OpenAIEmbeddingRequestor (Future)
```swift
public class OpenAIEmbeddingRequestor: AIRequestor {
    public typealias TypedData = GeneratedEmbedding
    public typealias ResponseModel = GeneratedEmbeddingRecord
    public typealias Configuration = EmbeddingConfig

    public let requestorID = "openai-embedding"
    public let displayName = "OpenAI Embeddings"
    public let category: ProviderCategory = .embedding
    public let outputFileType = OutputFileType.binary

    struct EmbeddingConfig: Codable, Sendable {
        var model: String = "text-embedding-3-small"
        var dimensions: Int? = nil
    }
}
```

**Refactoring Plan:**
1. Keep `OpenAIProvider` as base class with credential management
2. Extract text generation logic to `OpenAITextRequestor`
3. Implement `availableRequestors()` returning `[OpenAITextRequestor()]`
4. Create `GeneratedTextRecord` SwiftData model
5. Implement `SerializableTypedData` for `GeneratedText` (JSON format)
6. **Phase 7**: Add configuration widget, list view, detail view

**Estimated Effort**: 2-3 days

---

### 2. Anthropic Provider

**Current Capabilities:**
- Text generation (Claude 3: Opus, Sonnet, Haiku)

**Required Requestors:**

#### AnthropicTextRequestor
```swift
public class AnthropicTextRequestor: AIRequestor {
    public typealias TypedData = GeneratedText
    public typealias ResponseModel = GeneratedTextRecord
    public typealias Configuration = TextGenerationConfig

    public let requestorID = "anthropic-text"
    public let displayName = "Claude Text Generation"
    public let category: ProviderCategory = .text
    public let outputFileType = OutputFileType.plainText

    struct TextGenerationConfig: Codable, Sendable {
        var model: String = "claude-3-sonnet-20240229"
        var maxTokens: Int = 1024
        var temperature: Double? = nil
        var systemPrompt: String? = nil
    }
}
```

**SwiftData Model:**
- Reuse `GeneratedTextRecord` from OpenAI (same structure)

**Refactoring Plan:**
1. Keep `AnthropicProvider` as base with credential management
2. Extract text generation to `AnthropicTextRequestor`
3. Implement `availableRequestors()` returning `[AnthropicTextRequestor()]`
4. Reuse `GeneratedTextRecord` SwiftData model
5. Implement `SerializableTypedData` for `GeneratedText`
6. **Phase 7**: Add configuration widget with Claude-specific options

**Estimated Effort**: 1-2 days

---

### 3. Apple Intelligence Provider

**Current Capabilities:**
- On-device text generation

**Required Requestors:**

#### AppleIntelligenceTextRequestor
```swift
public class AppleIntelligenceTextRequestor: AIRequestor {
    public typealias TypedData = GeneratedText
    public typealias ResponseModel = GeneratedTextRecord
    public typealias Configuration = TextGenerationConfig

    public let requestorID = "apple-intelligence-text"
    public let displayName = "Apple Intelligence Text"
    public let category: ProviderCategory = .text
    public let outputFileType = OutputFileType.plainText

    struct TextGenerationConfig: Codable, Sendable {
        var temperature: Double = 0.7
        var maxLength: Int = 500
        var onDevice: Bool = true
    }
}
```

**SwiftData Model:**
- Reuse `GeneratedTextRecord`

**Refactoring Plan:**
1. Keep `AppleIntelligenceProvider` as base
2. Extract generation to `AppleIntelligenceTextRequestor`
3. Implement `availableRequestors()`
4. Reuse `GeneratedTextRecord`
5. Implement `SerializableTypedData`
6. **Phase 7**: Configuration widget with privacy emphasis

**Estimated Effort**: 1-2 days

---

### 4. ElevenLabs Provider

**Current Capabilities:**
- Text-to-speech audio generation

**Required Requestors:**

#### ElevenLabsAudioRequestor
```swift
public class ElevenLabsAudioRequestor: AIRequestor {
    public typealias TypedData = GeneratedAudio
    public typealias ResponseModel = GeneratedAudioRecord
    public typealias Configuration = AudioGenerationConfig

    public let requestorID = "elevenlabs-audio"
    public let displayName = "ElevenLabs Text-to-Speech"
    public let category: ProviderCategory = .audio
    public let outputFileType = OutputFileType.mp3

    struct AudioGenerationConfig: Codable, Sendable {
        var voiceID: String = "21m00Tcm4TlvDq8ikWAM" // Rachel
        var modelID: String = "eleven_monolingual_v1"
        var stability: Double = 0.5
        var clarityBoost: Double = 0.75
    }
}
```

**SwiftData Model:**
```swift
@Model
public class GeneratedAudioRecord: AIGeneratedContent {
    public var audioFileReference: TypedDataFileReference
    public var voiceID: String
    public var voiceName: String?
    public var durationSeconds: Double?
    public var format: String // "mp3"
    public var requestID: UUID
    public var createdAt: Date
}
```

**TypedData:**
```swift
public struct GeneratedAudio: SerializableTypedData {
    public let audioData: Data
    public let voiceID: String
    public let voiceName: String?
    public let durationSeconds: Double?
    public let format: String

    public var preferredFormat: SerializationFormat { .binary }

    public func serialize() throws -> Data {
        return audioData // Already binary MP3
    }
}
```

**Refactoring Plan:**
1. Keep `ElevenLabsProvider` as base
2. Extract audio generation to `ElevenLabsAudioRequestor`
3. Implement `availableRequestors()`
4. Create `GeneratedAudioRecord` SwiftData model
5. Implement `SerializableTypedData` for audio (binary format)
6. **Large data handling**: Write MP3 to `.guion` Resources folder
7. **Phase 7**: Voice selection configuration widget

**Estimated Effort**: 2-3 days (includes file storage)

---

## Shared Components to Create

### 1. Common TypedData Structures

**GeneratedText** (for OpenAI, Anthropic, Apple Intelligence):
```swift
public struct GeneratedText: SerializableTypedData {
    public let text: String
    public let model: String?
    public let tokenUsage: TokenUsage?

    public var preferredFormat: SerializationFormat { .json }

    public func serialize() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    public static func deserialize(from data: Data, format: SerializationFormat) throws -> Self {
        return try JSONDecoder().decode(Self.self, from: data)
    }
}
```

**GeneratedAudio** (for ElevenLabs):
```swift
public struct GeneratedAudio: SerializableTypedData {
    public let audioData: Data
    public let voiceID: String
    public let voiceName: String?
    public let durationSeconds: Double?
    public let format: String

    public var preferredFormat: SerializationFormat { .binary }
}
```

**GeneratedImage** (future, for DALL-E):
```swift
public struct GeneratedImage: SerializableTypedData {
    public let imageData: Data
    public let width: Int
    public let height: Int
    public let format: String
    public let revisedPrompt: String?

    public var preferredFormat: SerializationFormat { .binary }
}
```

**GeneratedEmbedding** (future, for OpenAI embeddings):
```swift
public struct GeneratedEmbedding: SerializableTypedData {
    public let vector: [Float]
    public let model: String
    public let dimensions: Int

    public var preferredFormat: SerializationFormat { .binary }
}
```

### 2. Common SwiftData Models

**GeneratedTextRecord:**
```swift
@Model
public class GeneratedTextRecord: AIGeneratedContent {
    public var text: String
    public var model: String?
    public var tokenUsage: TokenUsage?
    public var requestID: UUID
    public var providerID: String
    public var requestorID: String
    public var createdAt: Date
    public var parentID: UUID?
}
```

**GeneratedAudioRecord:**
```swift
@Model
public class GeneratedAudioRecord: AIGeneratedContent {
    public var audioFileReference: TypedDataFileReference
    public var voiceID: String
    public var voiceName: String?
    public var durationSeconds: Double?
    public var format: String
    public var requestID: UUID
    public var providerID: String
    public var requestorID: String
    public var createdAt: Date
    public var parentID: UUID?
}
```

### 3. OutputFileType Definitions

```swift
public struct OutputFileType: Codable, Sendable {
    let mimeType: String
    let fileExtension: String
    let description: String
    let preferFileStorage: Bool

    public static let plainText = OutputFileType(
        mimeType: "text/plain",
        fileExtension: "txt",
        description: "Plain text",
        preferFileStorage: false
    )

    public static let markdown = OutputFileType(
        mimeType: "text/markdown",
        fileExtension: "md",
        description: "Markdown text",
        preferFileStorage: false
    )

    public static let json = OutputFileType(
        mimeType: "application/json",
        fileExtension: "json",
        description: "JSON data",
        preferFileStorage: false
    )

    public static let mp3 = OutputFileType(
        mimeType: "audio/mpeg",
        fileExtension: "mp3",
        description: "MP3 audio",
        preferFileStorage: true // Large binary data
    )

    public static let png = OutputFileType(
        mimeType: "image/png",
        fileExtension: "png",
        description: "PNG image",
        preferFileStorage: true // Large binary data
    )

    public static let binary = OutputFileType(
        mimeType: "application/octet-stream",
        fileExtension: "bin",
        description: "Binary data",
        preferFileStorage: true
    )
}
```

---

## Migration Strategy

### Phase 6A: Core Requestor Pattern (Week 1-2)

**Goal**: Implement requestor pattern without breaking existing Phase 5 providers

1. **Create new protocols and types:**
   - `AIRequestor` protocol with associated types
   - `SerializableTypedData` protocol
   - `SerializationFormat` enum
   - `ProviderCategory` enum
   - `OutputFileType` struct
   - `StorageAreaReference` struct
   - `TypedDataFileReference` struct

2. **Add `availableRequestors()` to `AIServiceProvider`:**
   ```swift
   public protocol AIServiceProvider {
       // Existing methods...

       // New Phase 6 method
       func availableRequestors() -> [any AIRequestor]
   }
   ```

3. **Default implementation for backward compatibility:**
   ```swift
   extension AIServiceProvider {
       public func availableRequestors() -> [any AIRequestor] {
           return [] // Phase 5 providers return empty array
       }
   }
   ```

**Deliverables:**
- `AIRequestor.swift` - Protocol definition
- `SerializableTypedData.swift` - Serialization protocol
- `ProviderCategory.swift` - Category enum
- `OutputFileType.swift` - File type definitions
- `StorageAreaReference.swift` - Storage reference type
- `TypedDataFileReference.swift` - File reference type
- All Phase 5 providers still compile and pass tests

### Phase 6B: Text Requestor Refactoring (Week 3)

**Goal**: Migrate text generation providers to requestor pattern

1. **Create shared text types:**
   - `GeneratedText` struct (SerializableTypedData)
   - `GeneratedTextRecord` SwiftData model
   - `TextGenerationConfig` (reusable across providers)

2. **Refactor OpenAI:**
   - Create `OpenAITextRequestor`
   - Implement `availableRequestors()` in `OpenAIProvider`
   - Move generation logic from provider to requestor
   - Keep backward compatibility with existing `generate()` method

3. **Refactor Anthropic:**
   - Create `AnthropicTextRequestor`
   - Implement `availableRequestors()`
   - Reuse `GeneratedText` and `GeneratedTextRecord`

4. **Refactor Apple Intelligence:**
   - Create `AppleIntelligenceTextRequestor`
   - Implement `availableRequestors()`

**Deliverables:**
- `GeneratedText.swift` - Shared text typed data
- `GeneratedTextRecord.swift` - Shared SwiftData model
- `OpenAITextRequestor.swift`
- `AnthropicTextRequestor.swift`
- `AppleIntelligenceTextRequestor.swift`
- Updated tests for all requestors
- All Phase 5 tests still pass

### Phase 6C: Audio Requestor Refactoring (Week 3-4)

**Goal**: Migrate ElevenLabs to requestor pattern with file storage

1. **Create audio types:**
   - `GeneratedAudio` struct (binary serialization)
   - `GeneratedAudioRecord` SwiftData model with file reference
   - `AudioGenerationConfig`

2. **Implement file storage:**
   - Integrate SwiftGuion library
   - Create TextPackCoordinator actor
   - Implement storage area creation
   - Implement file write on background thread

3. **Refactor ElevenLabs:**
   - Create `ElevenLabsAudioRequestor`
   - Implement file storage for MP3 data
   - Use storage area reference
   - Return file reference in SwiftData model

**Deliverables:**
- `GeneratedAudio.swift` - Audio typed data
- `GeneratedAudioRecord.swift` - SwiftData model
- `ElevenLabsAudioRequestor.swift`
- `TextPackCoordinator.swift` - Actor for file operations
- `SwiftGuion` library integration
- Tests for audio requestor and file storage

### Phase 6D: TypedDataBroker and Integration (Week 4)

**Goal**: Implement broker for request coordination

1. **Create TypedDataBroker actor:**
   - Request ID assignment
   - Storage area creation
   - Request → parent mapping
   - File attachment registry

2. **Integrate with AIRequestManager:**
   - Pass storage area to requestors
   - Handle file references in responses
   - Coordinate with AIDataCoordinator

3. **End-to-end integration testing:**
   - Background request → background file write → main thread persistence
   - Verify no large data on main thread
   - Test Sendable compliance
   - Test concurrent requests

**Deliverables:**
- `TypedDataBroker.swift` - Actor implementation
- Integration with AIRequestManager
- Integration with AIDataCoordinator
- Comprehensive integration tests

---

## Impact on Phase 6+ Milestones

### Phase 6 Updates Required

**Updated Duration**: 4-5 weeks (increased from 3-4 weeks)

**Reason**: Provider refactoring adds 1 week

**Updated Deliverables:**

#### Core Implementation (Updated)
- ✅ Typed response schema system → `SerializableTypedData` protocol
- ✅ Request-level type specification → `AIRequestor` protocol
- ✅ Schema validation → Type-specific serialization
- ✅ Type-safe data extraction → Associated types in requestor
- ✅ Error handling for missing/invalid data → `TypedDataError` enum
- ✅ Provider capability declarations → `ProviderCategory` enum
- 🆕 **Provider refactoring**: Migrate Phase 5 providers to requestor pattern
- 🆕 **Requestor implementations**: Text and audio requestors for all Phase 5 providers
- 🆕 **Backward compatibility**: Keep Phase 5 `generate()` methods for migration period

#### Testing (Updated)
- 🆕 **Requestor unit tests**: Test each requestor independently
- 🆕 **Backward compatibility tests**: Ensure Phase 5 behavior preserved
- 🆕 **Migration tests**: Test gradual migration from providers to requestors
- Existing Phase 6 tests remain

**Updated Quality Gates:**

| Gate | Requirement | Pass Criteria | Updated |
|------|-------------|---------------|---------|
| **QG-6.9** | Provider refactoring | All Phase 5 providers migrated | 🆕 NEW |
| **QG-6.10** | Backward compatibility | Phase 5 tests still pass | 🆕 NEW |
| **QG-6.11** | Requestor coverage | ≥85% test coverage per requestor | 🆕 NEW |

### Phase 7 Updates Required

**Updated Dependencies**: Depends on Phase 6 requestor refactoring

**Updated Implementation:**

Each requestor must provide three UI components:

```swift
public protocol AIRequestor {
    // Phase 7 UI requirements
    @MainActor
    func makeConfigurationView(configuration: Binding<Configuration>) -> AnyView

    @MainActor
    func makeListItemView(model: ResponseModel) -> AnyView

    @MainActor
    func makeDetailView(model: ResponseModel) -> AnyView
}
```

**UI Components Per Requestor:**

1. **OpenAITextRequestor**:
   - Configuration: Model picker, temperature slider, max tokens, system prompt
   - List view: Text preview (first 100 chars), model name, token count
   - Detail view: Full text, copy button, metadata

2. **AnthropicTextRequestor**:
   - Configuration: Claude model picker, max tokens, temperature, system prompt
   - List view: Text preview, model name, token count
   - Detail view: Full text with Claude-specific formatting

3. **AppleIntelligenceTextRequestor**:
   - Configuration: Temperature, max length, on-device toggle
   - List view: Text preview, privacy badge
   - Detail view: Full text, privacy information

4. **ElevenLabsAudioRequestor**:
   - Configuration: Voice picker (with preview), stability, clarity boost
   - List view: Waveform thumbnail, duration, voice name
   - Detail view: Audio player, waveform, metadata

**Updated Deliverables:**
- 🆕 Configuration widgets for each requestor (4 widgets)
- 🆕 List item views for each requestor (4 views)
- 🆕 Detail views for each requestor (4 views)
- 🆕 Voice picker with preview (ElevenLabs)
- 🆕 Waveform visualization (ElevenLabs)

### Phase 8 Updates Required

**Updated Sample Applications:**

1. **Basic Integration** → Use `OpenAITextRequestor` instead of `OpenAIProvider`
2. **Multi-Provider** → Show requestor selection from multiple providers
3. **Audio Generation** → Use `ElevenLabsAudioRequestor` with file storage
4. **Advanced Usage** → Show custom requestor implementation

**New Sample Application:**

5. **Requestor Migration Example**
   - Shows migration from Phase 5 to Phase 6 API
   - Side-by-side comparison
   - Best practices for gradual migration

---

## Testing Strategy

### Backward Compatibility Testing

**Goal**: Ensure Phase 5 functionality preserved during migration

```swift
// Phase 5 API still works
let provider = OpenAIProvider()
let result = await provider.generate(
    prompt: "Hello",
    parameters: ["model": "gpt-4"]
)
// ✅ Should still work

// Phase 6 API now available
let requestors = provider.availableRequestors()
let textRequestor = requestors.first as! OpenAITextRequestor
let config = TextGenerationConfig(model: "gpt-4")
let typedResult = await textRequestor.request(
    prompt: "Hello",
    configuration: config,
    storageArea: storageArea
)
// ✅ New API also works
```

### Migration Testing

**Gradual Migration Test:**

1. Start with Phase 5 API
2. Add Phase 6 requestor alongside
3. Verify both work simultaneously
4. Gradually migrate code to Phase 6
5. Deprecate Phase 5 API (mark with `@available(*, deprecated)`)

### Requestor-Specific Testing

Each requestor needs:
- Configuration validation tests
- Request execution tests
- Response model creation tests
- File storage tests (audio/image requestors)
- Serialization/deserialization tests
- SwiftData persistence tests

### Integration Testing

Full workflow tests:
- Parent element requests generation
- Broker assigns request ID and storage area
- Requestor executes on background thread
- Large data written to `.guion` bundle
- File reference created
- Main thread SwiftData persistence
- Display retrieval via file reference

---

## Timeline and Effort Estimation

### Phase 6 Detailed Timeline

| Week | Tasks | Deliverables | Status |
|------|-------|--------------|--------|
| **Week 1** | Core protocols, types, backward compatibility | AIRequestor, SerializableTypedData, OutputFileType | 📋 Planned |
| **Week 2** | Storage infrastructure, SwiftGuion integration | TextPackCoordinator, StorageAreaReference, TypedDataFileReference | 📋 Planned |
| **Week 3** | Text requestor refactoring (OpenAI, Anthropic, Apple) | 3 text requestors, GeneratedText, GeneratedTextRecord | 📋 Planned |
| **Week 4** | Audio requestor refactoring (ElevenLabs), file storage | ElevenLabsAudioRequestor, GeneratedAudio, file storage tests | 📋 Planned |
| **Week 5** | TypedDataBroker, integration, comprehensive testing | TypedDataBroker, integration tests, documentation | 📋 Planned |

**Total Phase 6 Duration**: 5 weeks (updated from 3-4 weeks)

### Provider Refactoring Effort

| Provider | Complexity | Effort | Reason |
|----------|-----------|--------|--------|
| **OpenAI** | Medium | 2 days | Single requestor (text), straightforward |
| **Anthropic** | Low | 1 day | Single requestor (text), reuses text types |
| **Apple Intelligence** | Low | 1 day | Single requestor (text), simple config |
| **ElevenLabs** | High | 3 days | File storage, binary data, audio-specific handling |
| **Integration** | High | 3 days | Broker, coordinator, end-to-end testing |

**Total Refactoring**: 10 days (2 weeks)

---

## Risk Assessment

### High Risks

1. **Breaking Changes to Phase 5 API**
   - **Risk**: Refactoring breaks existing functionality
   - **Mitigation**: Maintain backward compatibility, extensive regression testing
   - **Impact**: High (could delay release)

2. **File Storage Complexity**
   - **Risk**: SwiftGuion integration issues, actor coordination bugs
   - **Mitigation**: Early prototype, comprehensive file storage tests
   - **Impact**: Medium (workarounds available)

3. **Test Coverage Gaps**
   - **Risk**: New requestor pattern not fully tested
   - **Mitigation**: ≥85% coverage requirement per requestor, integration tests
   - **Impact**: Medium

### Medium Risks

4. **SwiftData Model Migration**
   - **Risk**: Existing Phase 5 data incompatible with Phase 6 models
   - **Mitigation**: Schema versioning, migration guides
   - **Impact**: Low-Medium

5. **Performance Regression**
   - **Risk**: Requestor indirection adds overhead
   - **Mitigation**: Performance benchmarking, optimization pass
   - **Impact**: Low

### Low Risks

6. **Documentation Drift**
   - **Risk**: Docs not updated to reflect requestor pattern
   - **Mitigation**: Documentation updates in same PRs as code changes
   - **Impact**: Low

---

## Success Criteria

### Phase 6 Updated Success Criteria

1. ✅ All Phase 5 providers refactored to requestor pattern
2. ✅ Backward compatibility maintained (Phase 5 tests pass)
3. ✅ TypedDataBroker actor implemented and tested
4. ✅ File storage working for audio (ElevenLabs)
5. ✅ SwiftGuion library integrated
6. ✅ ≥85% test coverage per requestor
7. ✅ ≥90% overall test coverage (Phase 6 components)
8. ✅ All quality gates passed
9. ✅ Integration tests passing (end-to-end workflows)
10. ✅ Zero Swift concurrency warnings
11. ✅ Performance benchmarks met (<5ms requestor overhead)
12. ✅ Documentation updated (Phase 6 API, migration guide)

### Phase 7 Dependency Update

Phase 7 can begin once:
- ✅ All requestors implemented
- ✅ Requestor protocol stable
- ✅ SwiftData models finalized
- ✅ Phase 6 quality gates passed

No UI work can proceed without stable requestor implementations.

---

## Recommendations

### Immediate Actions (Pre-Phase 6)

1. **Create branch**: `phase-6-requestor-refactoring`
2. **Update METHODOLOGY.md**: Reflect increased Phase 6 duration (5 weeks)
3. **Update Pre-Implementation Checklist**: Mark provider refactoring as requirement
4. **Spike SwiftGuion**: Prototype file storage before full implementation
5. **Review with team**: Get feedback on requestor pattern before implementation

### Phase 6 Implementation Order

**Week 1**: Foundation
1. Define all protocols and types
2. Add `availableRequestors()` to `AIServiceProvider`
3. Ensure Phase 5 providers still compile

**Week 2**: Storage Infrastructure
1. Integrate SwiftGuion library
2. Create TextPackCoordinator actor
3. Implement storage area creation
4. Test file write/read with thread safety

**Week 3**: Text Requestors
1. Create `GeneratedText` and `GeneratedTextRecord`
2. Refactor OpenAI → `OpenAITextRequestor`
3. Refactor Anthropic → `AnthropicTextRequestor`
4. Refactor Apple Intelligence → `AppleIntelligenceTextRequestor`
5. All text provider tests passing

**Week 4**: Audio Requestor
1. Create `GeneratedAudio` and `GeneratedAudioRecord`
2. Refactor ElevenLabs → `ElevenLabsAudioRequestor`
3. Implement file storage for MP3 data
4. Audio provider tests passing

**Week 5**: Integration
1. Implement TypedDataBroker actor
2. Integrate with AIRequestManager
3. End-to-end integration tests
4. Performance benchmarking
5. Documentation updates

### Communication Plan

**Stakeholders to Notify:**
- Core development team
- Beta testers (if Phase 5 already shared)
- Documentation team
- Community (via GitHub Discussions)

**Key Messages:**
- Phase 6 duration increased to 5 weeks (from 3-4)
- Provider refactoring needed for requestor pattern
- Backward compatibility maintained during migration
- New capabilities: type-safe requests, file storage, per-type configuration

---

## Appendix A: Requestor Pattern Examples

### Complete OpenAI Text Requestor Example

```swift
import Foundation
import SwiftData

@available(macOS 15.0, iOS 17.0, *)
public class OpenAITextRequestor: AIRequestor {
    // MARK: - Associated Types

    public typealias TypedData = GeneratedText
    public typealias ResponseModel = GeneratedTextRecord
    public typealias Configuration = TextGenerationConfig

    // MARK: - Identity

    public let requestorID = "openai-text"
    public let displayName = "OpenAI Text Generation"
    public let providerID = "openai"
    public let category: ProviderCategory = .text

    // MARK: - Capabilities

    public let outputFileType = OutputFileType.plainText
    public let schema: TypedDataSchema? = nil // Future: JSON schema
    public let estimatedMaxSize: Int64? = nil // Unknown until generation

    // MARK: - Properties

    private let provider: OpenAIProvider
    private let model: String

    // MARK: - Initialization

    public init(provider: OpenAIProvider, model: String = "gpt-4") {
        self.provider = provider
        self.model = model
    }

    // MARK: - Configuration

    public func defaultConfiguration() -> TextGenerationConfig {
        return TextGenerationConfig(
            model: model,
            temperature: 0.7,
            maxTokens: nil,
            systemPrompt: nil
        )
    }

    public func validateConfiguration(_ config: TextGenerationConfig) throws {
        guard !config.model.isEmpty else {
            throw TypedDataError.validationFailed(
                fieldName: "model",
                reason: "Model cannot be empty"
            )
        }

        guard (0.0...2.0).contains(config.temperature) else {
            throw TypedDataError.validationFailed(
                fieldName: "temperature",
                reason: "Temperature must be between 0.0 and 2.0"
            )
        }
    }

    // MARK: - Request Execution

    public func request(
        prompt: String,
        configuration: TextGenerationConfig,
        storageArea: StorageAreaReference
    ) async -> Result<TypedData, AIServiceError> {
        // Validate configuration
        do {
            try validateConfiguration(configuration)
        } catch let error as TypedDataError {
            return .failure(.validationError(error.localizedDescription))
        } catch {
            return .failure(.validationError("Configuration validation failed"))
        }

        // Build parameters for provider
        var parameters: [String: Any] = [
            "model": configuration.model,
            "temperature": configuration.temperature
        ]

        if let maxTokens = configuration.maxTokens {
            parameters["max_tokens"] = maxTokens
        }

        if let systemPrompt = configuration.systemPrompt {
            parameters["system"] = systemPrompt
        }

        // Call provider's generate method
        let result = await provider.generate(prompt: prompt, parameters: parameters)

        // Convert to typed data
        switch result {
        case .success(let content):
            guard let text = content.text else {
                return .failure(.unexpectedResponseFormat("No text in response"))
            }

            let typedData = GeneratedText(
                text: text,
                model: configuration.model,
                tokenUsage: nil // Parse from provider response if available
            )

            return .success(typedData)

        case .failure(let error):
            return .failure(error)
        }
    }

    // MARK: - Response Processing

    @MainActor
    public func makeResponseModel(
        from data: TypedData,
        fileReference: TypedDataFileReference?,
        requestID: UUID
    ) -> GeneratedTextRecord {
        return GeneratedTextRecord(
            text: data.text,
            model: data.model,
            tokenUsage: data.tokenUsage,
            requestID: requestID,
            providerID: providerID,
            requestorID: requestorID,
            createdAt: Date()
        )
    }

    // MARK: - UI Components (Phase 7)

    @MainActor
    public func makeConfigurationView(
        configuration: Binding<TextGenerationConfig>
    ) -> AnyView {
        // To be implemented in Phase 7
        fatalError("Phase 7: UI components not yet implemented")
    }

    @MainActor
    public func makeListItemView(model: GeneratedTextRecord) -> AnyView {
        // To be implemented in Phase 7
        fatalError("Phase 7: UI components not yet implemented")
    }

    @MainActor
    public func makeDetailView(model: GeneratedTextRecord) -> AnyView {
        // To be implemented in Phase 7
        fatalError("Phase 7: UI components not yet implemented")
    }
}

// MARK: - Configuration Type

public struct TextGenerationConfig: Codable, Sendable {
    public var model: String
    public var temperature: Double
    public var maxTokens: Int?
    public var systemPrompt: String?

    public init(
        model: String = "gpt-4",
        temperature: Double = 0.7,
        maxTokens: Int? = nil,
        systemPrompt: String? = nil
    ) {
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.systemPrompt = systemPrompt
    }
}
```

---

## Appendix B: File Storage Pattern Example

### ElevenLabs Audio Requestor with File Storage

```swift
public class ElevenLabsAudioRequestor: AIRequestor {
    public typealias TypedData = GeneratedAudio
    public typealias ResponseModel = GeneratedAudioRecord
    public typealias Configuration = AudioGenerationConfig

    private let provider: ElevenLabsProvider
    private let textPackCoordinator: TextPackCoordinator

    public func request(
        prompt: String,
        configuration: AudioGenerationConfig,
        storageArea: StorageAreaReference
    ) async -> Result<TypedData, AIServiceError> {
        // 1. Call provider to generate audio (background thread)
        let result = await provider.generate(prompt: prompt, parameters: [:])

        // 2. Extract audio data
        guard case .success(let content) = result,
              let audioData = content.data else {
            return .failure(.unexpectedResponseFormat("No audio data"))
        }

        // 3. Write large data to file on BACKGROUND thread
        do {
            let fileReference = try await textPackCoordinator.writeResource(
                data: audioData,
                storageArea: storageArea,
                contentType: "audio/mpeg",
                fileExtension: "mp3"
            )

            // 4. Create typed data with FILE REFERENCE (small object)
            let typedData = GeneratedAudio(
                audioFileReference: fileReference, // Small reference, not large data!
                voiceID: configuration.voiceID,
                voiceName: nil,
                durationSeconds: nil,
                format: "mp3"
            )

            return .success(typedData)

        } catch {
            return .failure(.storageError("Failed to write audio file: \(error)"))
        }
    }

    @MainActor
    public func makeResponseModel(
        from data: TypedData,
        fileReference: TypedDataFileReference?,
        requestID: UUID
    ) -> GeneratedAudioRecord {
        // Main thread: only receives small file reference, never large audio data
        return GeneratedAudioRecord(
            audioFileReference: data.audioFileReference, // Small reference
            voiceID: data.voiceID,
            voiceName: data.voiceName,
            durationSeconds: data.durationSeconds,
            format: data.format,
            requestID: requestID,
            providerID: providerID,
            requestorID: requestorID,
            createdAt: Date()
        )
    }
}
```

**Key Points:**
- Audio generation on background thread
- File write on background thread (SwiftGuion via TextPackCoordinator)
- Only small file reference transferred to main thread
- SwiftData persistence on main thread with file reference
- No large data ever on main thread

---

**Document Version**: 1.0
**Author**: Claude (claude-sonnet-4-5-20250929)
**Status**: Planning Document
**Next Steps**: Review with team, update METHODOLOGY.md, begin Phase 6 implementation
