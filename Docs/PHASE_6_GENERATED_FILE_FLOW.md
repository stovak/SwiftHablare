# Phase 6: Generated File Workflow - Flow Diagram

This document illustrates the complete workflow for generating a file using SwiftHablare, from request initiation through display.

## Overview

The workflow demonstrates:
1. Request initiation by a parent element
2. Request ID assignment by the broker
3. Background API processing
4. File storage in TextPack (.guion) bundles
5. SwiftData persistence
6. Display view retrieval and rendering

---

## Complete Workflow Diagram

```mermaid
sequenceDiagram
    participant Parent as Parent Element<br/>(Main Thread)
    participant Broker as TypedDataBroker<br/>(Actor - Proposed)
    participant ReqMgr as AIRequestManager<br/>(Actor - Existing)
    participant Provider as AI Provider<br/>(Background)
    participant Coordinator as TextPackCoordinator<br/>(Actor - Proposed)
    participant DataCoord as AIDataCoordinator<br/>(Main Actor - Existing)
    participant SwiftData as SwiftData Context<br/>(Main Thread)
    participant Storage as .guion Bundle<br/>(File System)

    rect rgb(240, 248, 255)
        Note over Parent,Storage: Phase 1: Request Initiation & ID Assignment
        Parent->>+Broker: requestFile(prompt, params, parentID)
        Broker->>Broker: Generate Request ID (UUID)
        Broker->>+Coordinator: createRequestStorageArea(requestID)
        Coordinator->>+Storage: Create .guion bundle at<br/>Requests/{requestID}.guion
        Storage-->>-Coordinator: Bundle created
        Coordinator->>Coordinator: Initialize bundle structure<br/>(info.json, Resources/)
        Coordinator-->>-Broker: StorageAreaReference(bundleURL)
        Broker->>Broker: Store storage area mapping<br/>(requestID → bundleURL)
        Broker->>+ReqMgr: submit(AIRequest, provider, storageArea)
        ReqMgr-->>-Broker: requestID
        Broker->>Broker: Store request metadata<br/>(requestID → parentID mapping)
        Broker-->>-Parent: requestID
        Note over Parent: Parent stores requestID<br/>for later reference
    end

    rect rgb(255, 250, 240)
        Note over Parent,Storage: Phase 2: Background API Processing
        Broker->>+ReqMgr: execute(requestID)
        activate ReqMgr
        ReqMgr->>ReqMgr: Update status: executing
        ReqMgr->>ReqMgr: Retrieve storage area<br/>for request
        ReqMgr->>+Provider: generate(prompt, parameters, storageArea)<br/>(Background Task)
        Note over Provider: Make API call<br/>to remote service<br/>Provider has access to<br/>request-specific storage
        Provider->>Provider: Receive typed data<br/>+ optional text
        Provider-->>-ReqMgr: ResponseContent<br/>(Sendable)
        ReqMgr->>ReqMgr: Create AIResponseData<br/>with requestID
        deactivate ReqMgr
    end

    rect rgb(240, 255, 240)
        Note over Parent,Storage: Phase 3: File Storage (if large data)
        ReqMgr->>ReqMgr: Check data size
        alt Large Data (requires file storage)
            ReqMgr->>+Coordinator: writeResource(data, UUID, contentType, storageArea)
            Coordinator->>Coordinator: Generate unique file ID<br/>(UUID-based)
            Coordinator->>+Storage: Write to storageArea/Resources/{UUID}.{ext}
            Note over Storage: File written to request-specific<br/>.guion bundle: Requests/{requestID}.guion
            Storage-->>-Coordinator: File written
            Coordinator->>Coordinator: Create TypedDataFileReference<br/>(uniqueID, bundlePath, contentType, size)
            Coordinator-->>-ReqMgr: TypedDataFileReference
            ReqMgr->>ReqMgr: Store file reference<br/>in ResponseContent
        else Small Data (in-memory)
            ReqMgr->>ReqMgr: Store data directly<br/>in ResponseContent
        end
        ReqMgr-->>-Broker: AIResponseData<br/>(with file ref or inline data)
    end

    rect rgb(255, 240, 240)
        Note over Parent,Storage: Phase 4: SwiftData Persistence
        Broker->>Broker: Retrieve parentID<br/>from request mapping
        Broker->>+DataCoord: mergeResponse(responseData, parent, context)
        DataCoord->>DataCoord: Extract typed data<br/>from response
        DataCoord->>+SwiftData: Update parent element<br/>with file reference
        Note over SwiftData: Parent.generatedFileRef = fileReference<br/>Parent.generatedText = additionalText
        SwiftData-->>-DataCoord: Persisted
        DataCoord->>DataCoord: Trigger completion callbacks
        DataCoord-->>-Broker: Merge complete
        Broker->>Parent: Notify completion<br/>(via callback/observer)
    end

    rect rgb(248, 240, 255)
        Note over Parent,Storage: Phase 5: Display Request
        Parent->>+Broker: requestDisplayView(fileReference, providerID)
        Broker->>+Provider: makeTypedDataView(fileReference)
        Provider->>Provider: Identify typed data type<br/>from file reference

        alt File-based storage
            Provider->>+Coordinator: readResource(fileReference)
            Coordinator->>+Storage: Read Resources/{UUID}.{ext}
            Storage-->>-Coordinator: File data
            Coordinator-->>-Provider: Data
        else In-memory storage
            Provider->>Provider: Access inline data
        end

        Provider->>Provider: Parse typed data<br/>(JSON, binary, etc.)
        Provider->>Provider: Create SwiftUI view<br/>for data type
        Provider-->>-Broker: SwiftUI View
        Broker-->>-Parent: SwiftUI View
        Parent->>Parent: Display view<br/>in UI hierarchy
    end
```

---

## Component Details

### 1. Parent Element (Main Thread)
- **Role**: Initiates file generation requests, stores request IDs, displays results
- **Examples**: Document editor, content generator, multi-media creator
- **Thread**: Main Actor
- **Key Operations**:
  - Requests file generation from broker
  - Stores requestID for tracking
  - Requests display view when ready

### 2. TypedDataBroker (Actor - Proposed)
- **Role**: Central coordinator for typed data requests and responses
- **Thread**: Actor (isolated)
- **Responsibilities**:
  - Assigns request IDs (UUID)
  - **Creates request-specific storage areas** (on init)
  - Maintains requestID → parentID mappings
  - Maintains requestID → storageArea mappings
  - Coordinates between request manager and data coordinator
  - Manages request lifecycle
  - Provides status updates to parent elements
- **New Component**: To be implemented in Phase 6
- **Initialization**:
  - On broker init, establishes base storage directory
  - Creates `Requests/` directory for request-specific bundles
  - Each request gets isolated `.guion` bundle at `Requests/{requestID}.guion`

### 3. AIRequestManager (Actor - Existing)
- **Role**: Manages request execution lifecycle
- **Thread**: Actor (isolated)
- **Location**: `Sources/SwiftHablare/Request/AIRequestManager.swift`
- **Key Features**:
  - Submits requests to providers
  - Executes in background tasks
  - Tracks request status (pending → executing → completed)
  - Stores AIResponseData
  - Supports cancellation and batch operations

### 4. AI Provider (Background)
- **Role**: Executes API calls to remote AI services
- **Thread**: Background Task
- **Protocol**: `AIServiceProvider`
- **Location**: `Sources/SwiftHablare/Core/AIServiceProvider.swift`
- **Key Operations**:
  - `generate(prompt, parameters)` → Returns `ResponseContent`
  - `makeTypedDataView(fileReference)` → Returns SwiftUI View (proposed)
  - Returns Sendable response types

### 5. TextPackCoordinator (Actor - Proposed)
- **Role**: Thread-safe file operations for .guion bundles
- **Thread**: Actor (isolated)
- **Integration**: Uses SwiftGuion library
- **Responsibilities**:
  - **Creates request-specific storage areas** (per-request .guion bundles)
  - Opens/closes .guion bundles
  - Writes resources with UUID-based naming to request-specific bundles
  - Reads resources by file reference
  - Manages concurrent bundle access
  - Initializes bundle structure (info.json, Resources/ directory)
- **New Component**: To be implemented in Phase 6
- **Storage Organization**:
  ```
  Base Storage Directory/
  └── Requests/
      ├── {requestID-1}.guion/
      │   ├── info.json
      │   └── Resources/
      │       ├── {fileUUID-1}.png
      │       └── {fileUUID-2}.json
      └── {requestID-2}.guion/
          ├── info.json
          └── Resources/
              └── {fileUUID-3}.mp3
  ```

### 6. AIDataCoordinator (Main Actor - Existing)
- **Role**: Merges AI responses into SwiftData models
- **Thread**: Main Actor
- **Location**: `Sources/SwiftHablare/Core/AIDataCoordinator.swift`
- **Key Features**:
  - Receives AIResponseData from background
  - Updates SwiftData models on main thread
  - Validates and transforms response content
  - Provides completion callbacks

### 7. SwiftData Context (Main Thread)
- **Role**: Persists model data
- **Thread**: Main Actor
- **Models**: Based on `AIGeneratedContent`
- **Location**: `Sources/SwiftHablare/Models/AIGeneratedContent.swift`
- **Storage**:
  - File references (TypedDataFileReference)
  - Request metadata
  - Parent element relationships

### 8. .guion Bundle Storage (File System)
- **Role**: Persistent file storage
- **Format**: TextPack (.guion) bundles
- **Library**: SwiftGuion (https://github.com/intrusive-memory/SwiftGuion)
- **Organization**: Request-specific bundles at `Requests/{requestID}.guion/`
- **File Naming**: `Resources/{UUID}.{extension}` within each bundle
- **Access**: Through TextPackCoordinator actor only
- **Bundle Structure**:
  - `info.json`: Bundle metadata (request ID, creation date, provider ID)
  - `Resources/`: Directory containing all generated files for this request
- **Isolation**: Each request has its own isolated storage area
- **Cleanup**: Request bundles can be deleted independently when request completes

---

## Data Types & Structures

### StorageAreaReference (Proposed)
```swift
struct StorageAreaReference: Codable, Sendable {
    let requestID: UUID          // Associated request ID
    let bundleURL: URL           // Path to request-specific .guion bundle
    let createdAt: Date          // When storage area was created

    // Computed path to Resources directory
    var resourcesDirectory: URL {
        bundleURL.appendingPathComponent("Resources")
    }
}
```

### TypedDataFileReference (Proposed)
```swift
struct TypedDataFileReference: Codable, Sendable {
    let uniqueID: UUID           // Unique identifier for file
    let requestID: UUID          // Associated request ID
    let bundlePath: URL          // Path to .guion bundle (request-specific)
    let relativePath: String     // Relative path within bundle: "Resources/{UUID}.{ext}"
    let contentType: String      // MIME type
    let sizeBytes: Int64         // File size
    let createdAt: Date          // Creation timestamp

    // Full path to file
    var fullPath: URL {
        bundlePath.appendingPathComponent(relativePath)
    }
}
```

### AIResponseData (Existing)
```swift
struct AIResponseData: Sendable {
    let requestID: UUID
    let providerID: String
    let content: ResponseContent    // Contains typed data or file reference
    let metadata: [String: String]
    let receivedAt: Date
    var error: AIServiceError?
}
```

### ResponseContent (Existing)
```swift
enum ResponseContent: Sendable {
    case text(String)
    case data(Data)
    case audio(Data, format: String)
    case image(Data, format: String)
    case structured([String: SendableValue])
}
```

---

## Broker Initialization & Storage Management

### TypedDataBroker Initialization
```swift
actor TypedDataBroker {
    private let baseStorageURL: URL
    private let textPackCoordinator: TextPackCoordinator
    private var storageAreas: [UUID: StorageAreaReference] = [:]

    init(baseStorageURL: URL) async throws {
        self.baseStorageURL = baseStorageURL
        self.textPackCoordinator = TextPackCoordinator()

        // Create base storage structure
        let requestsDirectory = baseStorageURL.appendingPathComponent("Requests")
        try FileManager.default.createDirectory(
            at: requestsDirectory,
            withIntermediateDirectories: true
        )
    }

    func createStorageArea(for requestID: UUID) async throws -> StorageAreaReference {
        let bundleURL = baseStorageURL
            .appendingPathComponent("Requests")
            .appendingPathComponent("\(requestID.uuidString).guion")

        // Create bundle through coordinator
        let storageArea = try await textPackCoordinator.createRequestBundle(
            at: bundleURL,
            requestID: requestID
        )

        // Store mapping
        storageAreas[requestID] = storageArea

        return storageArea
    }
}
```

### Storage Area Lifecycle
1. **Creation**: When request is initiated
   - Broker generates request ID
   - Broker asks TextPackCoordinator to create bundle
   - Bundle created at `Requests/{requestID}.guion/`
   - StorageAreaReference returned and mapped

2. **Usage**: During request execution
   - Provider receives storage area reference
   - Provider can write files via TextPackCoordinator
   - All files isolated to request's bundle

3. **Persistence**: After request completion
   - File references stored in SwiftData
   - Bundle persists on disk
   - Can be accessed later for display

4. **Cleanup** (optional): When request data no longer needed
   - Broker can delete bundle via TextPackCoordinator
   - All request files removed atomically
   - SwiftData maintains metadata about deleted files

### Benefits of Request-Specific Storage
- **Isolation**: Each request's files are separate and independent
- **Atomic Cleanup**: Delete entire request's data with single operation
- **Organization**: Easy to navigate and debug file structure
- **Security**: No file name collisions between requests
- **Portability**: Each .guion bundle is self-contained and shareable
- **Provider Control**: Provider writes to its own isolated area without conflicts

---

## Request Flow States

### Request Lifecycle
1. **Pending**: Request submitted, waiting for execution
2. **Executing**: Provider making API call
3. **Processing**: File write in progress (if large data)
4. **Persisting**: SwiftData merge in progress
5. **Completed**: Ready for display
6. **Failed**: Error occurred (with AIServiceError)

### Status Observation
```swift
// Parent can observe request status
for await status in broker.statusStream(for: requestID) {
    switch status {
    case .pending:
        showLoadingIndicator()
    case .executing:
        updateProgress()
    case .completed(let response):
        requestDisplayView(response)
    case .failed(let error):
        showError(error)
    }
}
```

---

## Thread Safety Guarantees

### Actor Isolation
- **TypedDataBroker**: Actor-isolated, thread-safe request coordination
- **AIRequestManager**: Actor-isolated, manages background execution
- **TextPackCoordinator**: Actor-isolated, serializes file I/O
- **AIDataCoordinator**: Main-actor-isolated, safe SwiftData access

### Sendable Types
- All data crossing actor boundaries is `Sendable`:
  - `AIRequest`, `AIResponseData`, `ResponseContent`
  - `TypedDataFileReference`
  - Provider responses

### Zero Race Conditions
- SwiftData operations only on main thread (AIDataCoordinator)
- Background providers never touch ModelContext
- File operations serialized through TextPackCoordinator
- Request state managed by single actor (AIRequestManager)

---

## Display Flow (Three-View Pattern)

### Provider View Creation (Proposed)
```swift
protocol AIRequestor {
    // Creates view for displaying typed data
    func makeListItemView(data: TypedData) -> some View
    func makeDetailView(data: TypedData) -> some View
    func makeCombinedView(items: [TypedData]) -> some View
}
```

### View Retrieval Process
1. Parent requests view from broker
2. Broker delegates to provider's `makeTypedDataView`
3. Provider reads file (if needed) via TextPackCoordinator
4. Provider parses typed data
5. Provider returns SwiftUI view
6. Parent embeds view in hierarchy

### Example Views by Type
- **Audio**: Waveform + play controls + metadata
- **Image**: Thumbnail + zoom controls + properties
- **Text**: Formatted display + word count + styling
- **Video**: Player + timeline + quality selector

---

## Performance Considerations

### Data Size Thresholds (To Be Measured)
Per Phase 6 Pre-Implementation Checklist:
- Measure performance for: 1KB, 10KB, 100KB, 1MB, 10MB, 100MB
- Record metrics for in-memory vs file-based storage
- Defer threshold decisions until after data collection

### Current Strategy
- **Small data** (exact threshold TBD): Store inline in ResponseContent
- **Large data** (exact threshold TBD): Store in .guion bundle files
- All data can be accessed through same interface regardless of storage method

### File Storage Benefits
- Prevents main thread blocking
- Supports streaming/chunked access
- Enables efficient memory management
- Allows external tool access (.guion is standard TextBundle format)

---

## Error Handling

### Error Types (Proposed in Checklist)
```swift
enum TypedDataError: Error, LocalizedError {
    case missingRequiredField(fieldName: String, expectedType: String)
    case typeMismatch(fieldName: String, expected: String, received: String)
    case validationFailed(fieldName: String, reason: String)
    case schemaViolation(description: String, path: String)
    case fileTooLarge(sizeBytes: Int64, fileName: String)
    case fileAccessFailed(fileID: UUID, reason: String)
    case bundleCorrupted(bundlePath: URL, reason: String)
}
```

### Error Propagation
1. Provider errors → AIServiceError in ResponseContent
2. File I/O errors → TypedDataError from TextPackCoordinator
3. Validation errors → TypedDataError in AIDataCoordinator
4. All errors propagate to parent via status updates

---

## Integration with Existing Architecture

### Leverages Phase 0-5 Components
- ✅ **AIServiceProvider**: Base provider protocol
- ✅ **AIRequestManager**: Request lifecycle management
- ✅ **AIDataCoordinator**: SwiftData integration
- ✅ **AIGeneratedContent**: Model base classes
- ✅ **Concurrency Architecture**: Actor-based design
- ✅ **Security Layer**: Credential management

### New Phase 6 Components
- 🆕 **TypedDataBroker**: Central typed data coordinator
- 🆕 **TextPackCoordinator**: File storage manager
- 🆕 **TypedDataFileReference**: File reference structure
- 🆕 **Provider View Methods**: Display view creation
- 🆕 **Three-View Pattern**: List/Detail/Combined views

---

## Future Enhancements (Post-Phase 6)

### Schema Validation
- JSON Schema support for structured data
- Type-safe data extraction with Codable
- Custom validation rules per provider

### Streaming Support
- Large file streaming during generation
- Progress callbacks during download
- Incremental display updates

### Caching Layer
- Cache typed data views for faster display
- LRU eviction for memory management
- Disk cache for file-based storage

---

## References

- **Phase 6 Pre-Implementation Checklist**: `/Docs/PHASE_6_PRE_IMPLEMENTATION_CHECKLIST.md`
- **SwiftGuion Library**: https://github.com/intrusive-memory/SwiftGuion
- **AIRequestManager**: `/Sources/SwiftHablare/Request/AIRequestManager.swift`
- **AIDataCoordinator**: `/Sources/SwiftHablare/Core/AIDataCoordinator.swift`
- **AIServiceProvider**: `/Sources/SwiftHablare/Core/AIServiceProvider.swift`
- **AIGeneratedContent**: `/Sources/SwiftHablare/Models/AIGeneratedContent.swift`

---

**Document Version**: 1.0
**Created**: 2025-10-12
**Status**: Design Document
**Next Steps**: Implement TypedDataBroker and TextPackCoordinator based on this flow
