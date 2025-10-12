# Phase 6: Pre-Implementation Requirements Checklist

**Status**: Requirements Review
**Date**: 2025-10-12
**Goal**: Identify and clarify vague/missing specifications before Phase 6 implementation begins

---

## ✅ RESOLVED Requirements

### 1. File Reference Structure ✅
**Resolution**: File operations abstracted through .guion document interface
- Files stored in Resources folder with UUID-based unique IDs
- File references contain unique IDs for retrieval
- All I/O through SwiftGuion document interface

**Implementation Pattern**:
```swift
struct TypedDataFileReference: Codable, Sendable {
    let uniqueID: UUID           // Unique identifier for file
    let bundlePath: URL          // Path to .guion bundle
    let contentType: String      // MIME type
    let sizeBytes: Int64
    let createdAt: Date

    // File stored as: Resources/{uniqueID}.{extension}
}
```

### 2. Performance Thresholds ✅
**Resolution**: Record performance metrics, determine thresholds later
- Measure performance for various data sizes (1KB, 10KB, 100KB, 1MB, 10MB, 100MB)
- Record metrics for in-memory vs file-based storage
- Defer threshold decisions until after data collection
- Quality Gate 6.8 updated to performance measurement instead of threshold enforcement

---

## ⚠️ CRITICAL - Must Define Before Implementation Begins

### 1. API Requestor Protocol Interface
**Priority**: 🔴 CRITICAL
**Status**: ⚠️ NEEDS DEFINITION
**Impact**: Core architecture - all providers depend on this

**Current State**: High-level definition exists
> "An API Requestor is a request-based interface to a local or remote AI system provider"

**Missing Specifications**:
- [ ] Required protocol methods/properties
- [ ] Relationship to existing `AIServiceProvider` protocol
- [ ] Method signatures for requesting typed data
- [ ] How configuration widgets are provided
- [ ] How SwiftData models are provided
- [ ] Associated types and constraints
- [ ] Error handling patterns

**Suggested Interface**:
```swift
protocol AIRequestor {
    // Type definitions
    associatedtype Configuration: View         // Configuration widget
    associatedtype ResponseModel: AIGeneratedContent  // SwiftData model
    associatedtype TypedData: Codable & Sendable      // Typed data structure

    // Core request functionality
    func request(
        with configuration: Configuration,
        options: RequestOptions
    ) async throws -> TypedData

    // UI provision
    func makeConfigurationView() -> Configuration

    // Type information
    var supportedTypes: [TypedDataSchema] { get }
    var providerCategory: ProviderCategory { get }  // Audio, Text, Image, Video

    // SwiftData model factory
    func makeResponseModel(from data: TypedData) -> ResponseModel
}

enum ProviderCategory {
    case audio
    case text
    case image
    case video
    case multiModal([ProviderCategory])
}
```

**Questions to Resolve**:
1. Does `AIRequestor` extend `AIServiceProvider` or replace it?
2. How do existing Phase 5 providers (OpenAI, Anthropic, ElevenLabs, Apple) adopt this?
3. What happens to providers that return multiple types (e.g., vision models)?

**Action Required**: Define complete protocol interface with examples

---

### 2. Schema System Type Support
**Priority**: 🔴 CRITICAL
**Status**: ⚠️ NEEDS CLARIFICATION
**Impact**: Type validation system architecture

**Current State**: Vague support statement
> "Support for JSON schema, Pydantic-style models, or Swift Codable types"

**Missing Specifications**:
- [ ] Which is the PRIMARY system?
- [ ] How do JSON Schema and Pydantic models convert to Swift?
- [ ] Are providers required to support all three?
- [ ] Validation engine for each type
- [ ] Conversion utilities between formats

**Recommended Approach**:
```swift
// Primary: Swift Codable (native)
protocol TypedDataSchema {
    associatedtype DataType: Codable & Sendable
    func validate(_ data: Any) throws -> DataType
}

// Secondary: JSON Schema support
struct JSONSchemaValidator: TypedDataSchema {
    let schema: JSONSchema
    // ... validation implementation
}

// Optional: Pydantic-style via property wrappers
@propertyWrapper
struct Validated<T: Codable> {
    // ... validation decorators
}
```

**Questions to Resolve**:
1. Should we focus on Swift Codable only for Phase 6, defer others to Phase 7?
2. How complex should JSON Schema support be? (Basic validation or full spec?)
3. Do we need Pydantic support at all, or is Swift Codable sufficient?

**Recommendation**:
- Phase 6: Swift Codable only (native, well-tested)
- Phase 7+: Add JSON Schema support if community requests it
- Defer Pydantic: Low priority unless specific use case emerges

**Action Required**: Decide on primary schema system and scope for Phase 6

---

### 3. TextPack Coordinator Actor Interface
**Priority**: 🔴 CRITICAL
**Status**: ⚠️ NEEDS DEFINITION
**Impact**: Thread-safe file operations

**Current State**: General requirement
> "Use actor or appropriate synchronization for thread-safe TextPack bundle modifications"

**Missing Specifications**:
- [ ] Actor name and complete interface
- [ ] Methods for creating/reading/updating/deleting from bundles
- [ ] Thread-safe queue management
- [ ] Error handling for bundle operations
- [ ] Integration with SwiftGuion library API

**Suggested Interface**:
```swift
actor TextPackCoordinator {
    private var activeBundles: [URL: TextPackBundle] = [:]

    // Bundle lifecycle
    func createBundle(at url: URL) async throws -> TextPackBundle
    func openBundle(at url: URL) async throws -> TextPackBundle
    func closeBundle(at url: URL) async throws

    // File operations (using UUID-based naming)
    func writeResource(
        data: Data,
        withID id: UUID,
        contentType: String,
        to bundle: TextPackBundle
    ) async throws -> TypedDataFileReference

    func readResource(
        from reference: TypedDataFileReference
    ) async throws -> Data

    func deleteResource(
        _ reference: TypedDataFileReference
    ) async throws

    // Bulk operations
    func writeMultipleResources(
        _ items: [(UUID, Data, String)],
        to bundle: TextPackBundle
    ) async throws -> [TypedDataFileReference]
}
```

**Questions to Resolve**:
1. Should the actor manage a pool of open bundles or open/close per operation?
2. How do we handle concurrent writes to the same bundle?
3. What's the error recovery strategy for corrupted bundles?
4. How does this integrate with SwiftGuion's existing API?

**Action Required**: Define complete actor interface with SwiftGuion integration

---

### 4. Error Object Structure for Missing/Invalid Typed Data
**Priority**: 🟡 HIGH
**Status**: ⚠️ NEEDS DEFINITION
**Impact**: Error handling and debugging experience

**Current State**: General requirement
> "Error handling for missing typed data" and "Error handling for invalid/malformed typed data"

**Missing Specifications**:
- [ ] Error type hierarchy for typed data errors
- [ ] Information included in error objects
- [ ] Error propagation to UI
- [ ] Recovery suggestions
- [ ] Localization support

**Suggested Error Hierarchy**:
```swift
enum TypedDataError: Error, LocalizedError {
    case missingRequiredField(fieldName: String, expectedType: String)
    case typeMismatch(fieldName: String, expected: String, received: String)
    case validationFailed(fieldName: String, reason: String)
    case schemaViolation(description: String, path: String)
    case fileTooLarge(sizeBytes: Int64, fileName: String)
    case fileAccessFailed(fileID: UUID, reason: String)
    case bundleCorrupted(bundlePath: URL, reason: String)

    var errorDescription: String? {
        switch self {
        case .missingRequiredField(let field, let type):
            return "Required field '\(field)' of type '\(type)' is missing from the response"
        // ... other cases
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .missingRequiredField:
            return "Check the provider's response format or update the schema definition"
        // ... other cases
        }
    }
}
```

**Questions to Resolve**:
1. Should errors include the full response for debugging?
2. How do we handle partial success (some fields valid, others invalid)?
3. What level of detail should be logged vs shown to users?

**Action Required**: Define complete error type hierarchy with localization

---

### 5. Three-View Pattern Protocol/Interface
**Priority**: 🟡 HIGH
**Status**: ⚠️ NEEDS DEFINITION
**Impact**: UI consistency across providers

**Current State**: High-level description
> "Three-view pattern for displaying AI responses: List View, Detail View, Combined View"

**Missing Specifications**:
- [ ] Protocol requirements for each view type
- [ ] How filtering works (filterable properties)
- [ ] State management for click-to-reveal
- [ ] Data binding patterns
- [ ] Common filtering predicates

**Suggested Pattern**:
```swift
// List View Protocol
protocol AIResponseListView: View {
    associatedtype Item: AIGeneratedContent

    var items: [Item] { get }
    var filterPredicate: NSPredicate? { get set }

    func filtered() -> [Item]
}

// Detail View Protocol
protocol AIResponseDetailView: View {
    associatedtype Item: AIGeneratedContent

    init(item: Item)
}

// Combined View Protocol
protocol AIResponseCombinedView: View {
    associatedtype Item: AIGeneratedContent
    associatedtype ListView: AIResponseListView where ListView.Item == Item
    associatedtype DetailView: AIResponseDetailView where DetailView.Item == Item

    var selectedItem: Item? { get set }

    func makeListView() -> ListView
    func makeDetailView(for item: Item) -> DetailView
}

// Standard filtering support
protocol Filterable {
    var filterableProperties: [String: Any] { get }
}
```

**Questions to Resolve**:
1. Should filtering be type-safe (enums) or dynamic (predicates)?
2. How do providers specify which fields are filterable?
3. Is click-to-reveal state managed by the view or view model?
4. Should we provide default implementations?

**Action Required**: Define complete three-view protocol with filtering patterns

---

## 🟢 IMPORTANT - Should Define Before or During Phase 6

### 6. Provider Capability Declarations for Typed Responses
**Priority**: 🟢 MEDIUM
**Status**: ⚠️ NEEDS CLARIFICATION

**Current State**: General statement
> "Provider capability declarations for supported return types"

**Missing Specifications**:
- [ ] Extension to existing `AICapability` enum
- [ ] How to query providers by typed data capability
- [ ] Version information for schema evolution

**Suggested Approach**:
```swift
extension AICapability {
    case typedResponse(schema: TypedDataSchema, version: String)
    case multipleTypedResponses([TypedDataSchema])
}

extension AIServiceManager {
    func providers(supporting schema: TypedDataSchema) -> [any AIServiceProvider]
}
```

**Action Required**: Extend `AICapability` enum with typed response support

---

### 7. Type Conversion and Validation Middleware
**Priority**: 🟢 MEDIUM
**Status**: ⚠️ NEEDS ARCHITECTURE DECISION

**Current State**: Single requirement line
> "Type conversion and validation middleware"

**Missing Specifications**:
- [ ] Middleware architecture (chain? pipeline?)
- [ ] Custom middleware support
- [ ] Built-in validators
- [ ] Error accumulation vs fail-fast

**Suggested Middleware Pattern**:
```swift
protocol TypeValidationMiddleware {
    func validate(
        _ data: Any,
        against schema: TypedDataSchema
    ) async throws -> ValidationResult
}

struct ValidationPipeline {
    var middleware: [TypeValidationMiddleware]

    func process(
        _ data: Any,
        against schema: TypedDataSchema
    ) async throws -> Any {
        var result = data
        for validator in middleware {
            result = try await validator.validate(result, against: schema)
        }
        return result
    }
}

// Built-in validators
struct TypeCheckValidator: TypeValidationMiddleware { }
struct RangeValidator: TypeValidationMiddleware { }
struct FormatValidator: TypeValidationMiddleware { }
struct CustomValidator: TypeValidationMiddleware {
    let validateBlock: (Any) throws -> Bool
}
```

**Questions to Resolve**:
1. Should validation be synchronous or asynchronous?
2. Error accumulation (collect all errors) or fail-fast (stop at first)?
3. How do providers add custom validators?

**Action Required**: Design middleware architecture and built-in validators

---

### 8. SwiftData Model Requirements Detail
**Priority**: 🟢 MEDIUM
**Status**: ⚠️ NEEDS SPECIFICATION

**Current State**: General requirement
> "Each API requestor must provide its own SwiftData table/model for storing typed data"

**Missing Specifications**:
- [ ] Base class or protocol all models must conform to
- [ ] Required properties
- [ ] Relationship to `AIGeneratedContent`
- [ ] Index requirements
- [ ] Migration strategy

**Suggested Pattern**:
```swift
@Model
class TypedAIResponse: AIGeneratedContent {
    // Existing AIGeneratedContent properties
    // + typed data additions

    var typedDataJSON: Data?                    // In-memory typed data (if small)
    var fileReference: TypedDataFileReference?  // File reference (if large)
    var schemaVersion: String
    var validationStatus: ValidationStatus

    // Providers extend with specific properties
}

enum ValidationStatus: Codable {
    case pending
    case valid
    case invalid(errors: [TypedDataError])
}

// Example: Audio provider's typed response model
@Model
class AudioTypedResponse: TypedAIResponse {
    var audioFormat: String
    var durationSeconds: Double
    var voiceID: String?
    var transcript: String?
}
```

**Questions to Resolve**:
1. Should all typed responses inherit from a base class?
2. How do we handle schema migrations?
3. Should file references be nullable (optional)?

**Action Required**: Define base model structure and requirements

---

### 9. Configuration Widget State Persistence
**Priority**: 🟢 MEDIUM
**Status**: ⚠️ NEEDS DECISION

**Current State**: Configuration widget pattern described, persistence not specified

**Missing Specifications**:
- [ ] Where are configuration values persisted?
- [ ] Per-provider or global configuration?
- [ ] Sensitive values in Keychain?

**Suggested Approach**:
```swift
// Per-provider configuration storage
@Model
class ProviderConfiguration {
    let providerID: String
    var settingsJSON: Data  // Non-sensitive settings
    var lastUsed: Date

    // Sensitive values (API keys) already in Keychain via Phase 4
}

// Configuration widget protocol
protocol ConfigurationWidget: View {
    associatedtype ConfigurationType: Codable

    @Binding var configuration: ConfigurationType

    func save() async throws
    func load() async throws
}
```

**Action Required**: Decide on configuration persistence strategy

---

### 10. Multi-Type Provider Dynamic Configuration
**Priority**: 🟢 MEDIUM
**Status**: ⚠️ NEEDS UI PATTERN

**Current State**: Requirement stated
> "Multi-type providers: type selection dropdown + dynamic type-specific configuration"

**Missing Specifications**:
- [ ] SwiftUI pattern for dynamic configuration
- [ ] State management for type switching

**Suggested Pattern**:
```swift
struct MultiTypeConfigurationView: View {
    @State private var selectedType: ProviderCategory

    var body: some View {
        VStack {
            Picker("Type", selection: $selectedType) {
                ForEach(provider.supportedTypes, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }

            configurationView(for: selectedType)
        }
    }

    @ViewBuilder
    func configurationView(for type: ProviderCategory) -> some View {
        switch type {
        case .audio:
            AudioConfigurationView(...)
        case .text:
            TextConfigurationView(...)
        case .image:
            ImageConfigurationView(...)
        // ...
        }
    }
}
```

**Action Required**: Define dynamic UI pattern for multi-type providers

---

## 🔵 NICE TO HAVE - Can Define During Implementation

### 11. Workflow Pattern State Machine
**Priority**: 🔵 LOW
**Status**: 🟢 CAN BE REFINED DURING IMPLEMENTATION

**Current State**: Linear workflow described
> "background request → background file write → file reference to main → SwiftData persistence"

**Could Be Enhanced With**:
- State transitions and error handling
- Rollback mechanisms
- Progress reporting
- Cancellation handling

**Note**: Current linear workflow is sufficient for Phase 6 start. State machine can be added if complexity demands it during implementation.

---

## Summary Statistics

| Priority | Count | Status |
|----------|-------|--------|
| 🔴 **CRITICAL** (Must Define Before) | 3 | Blocking |
| 🟡 **HIGH** (Must Define Before/Early) | 2 | Blocking |
| 🟢 **MEDIUM** (Should Define Before/During) | 5 | Non-blocking |
| 🔵 **LOW** (Can Define During) | 1 | Non-blocking |
| ✅ **RESOLVED** | 2 | Complete |
| **TOTAL** | 13 | |

---

## Recommended Pre-Implementation Phase

### Week 1: Critical Definitions (Blocking Issues)
**Goal**: Resolve all 🔴 CRITICAL and 🟡 HIGH priority items

**Tasks**:
1. **API Requestor Protocol** (2 days)
   - Define complete protocol interface
   - Create example implementations for 2-3 provider types
   - Document relationship to `AIServiceProvider`

2. **Schema System Decision** (1 day)
   - Decide: Swift Codable only for Phase 6, or include JSON Schema?
   - Document scope and rationale

3. **TextPack Coordinator Actor** (2 days)
   - Define complete actor interface
   - Research SwiftGuion API integration
   - Design thread-safe bundle management

4. **Error Hierarchy** (1 day)
   - Define complete error types
   - Add localization support
   - Document error handling patterns

5. **Three-View Pattern** (1 day)
   - Define protocols for all three views
   - Design filtering patterns
   - Create basic example implementation

### Week 2: Important Definitions (Non-blocking, High Value)
**Goal**: Resolve 🟢 MEDIUM priority items that provide clarity

**Tasks**:
1. Provider capability extensions
2. Validation middleware architecture
3. SwiftData model base structure
4. Configuration persistence strategy
5. Multi-type provider UI pattern

### After Definitions: Phase 6 Implementation (3 weeks)
Proceed with Phase 6 implementation once critical definitions are complete.

---

## Next Steps

1. **Review this document** with the team/user
2. **Prioritize** which items to tackle first
3. **Schedule** definition meetings/sessions
4. **Document** decisions in corresponding files
5. **Update** METHODOLOGY.md with concrete specifications
6. **Begin** Phase 6 implementation

---

**Document Version**: 1.0
**Last Updated**: 2025-10-12
**Next Review**: After critical definitions are complete
