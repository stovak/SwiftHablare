# Phase 6: Gated Sub-Phases

**Created**: 2025-10-12
**Status**: Implementation Plan
**Purpose**: Break Phase 6 into smaller, gated sub-phases for incremental validation and reduced risk

---

## Overview

Phase 6 is broken into **4 gated sub-phases** (6A, 6B, 6C, 6D) with clear quality gates between each. Each sub-phase must pass all gates before proceeding to the next.

**Total Duration**: 4-5 weeks
**Sub-Phases**: 4 (6A → 6B → 6C → 6D)
**Quality Gates**: 13 (3 per sub-phase + 1 final gate)

---

## Sub-Phase Structure

```
┌──────────────┐
│   Phase 6A   │  Foundation (Week 1)
│  Core Types  │  Duration: 1 week
└──────┬───────┘
       │
       ▼ Gate 6A (3 checks)
       │
┌──────────────┐
│   Phase 6B   │  Text Requestors (Week 2-3)
│ Text Refactor│  Duration: 1-2 weeks
└──────┬───────┘
       │
       ▼ Gate 6B (3 checks)
       │
┌──────────────┐
│   Phase 6C   │  Audio + Storage (Week 3-4)
│ Audio + Files│  Duration: 1-2 weeks
└──────┬───────┘
       │
       ▼ Gate 6C (3 checks)
       │
┌──────────────┐
│   Phase 6D   │  Integration (Week 5)
│  Integration │  Duration: 1 week
└──────┬───────┘
       │
       ▼ Gate 6D (4 checks)
       │
    Phase 7
```

---

## Phase 6A: Foundation & Core Types

**Duration**: 1 week (5 days)
**Goal**: Establish core protocols and types without breaking Phase 5 providers
**Risk**: Low (additive changes only, no modifications to existing code)

### Deliverables

#### Core Protocols
- [ ] `AIRequestor` protocol with associated types (TypedData, ResponseModel, Configuration)
- [ ] `SerializableTypedData` protocol with serialization interface
- [ ] Add `availableRequestors()` to `AIServiceProvider` protocol
- [ ] Default implementation of `availableRequestors()` returning `[]`

#### Supporting Types
- [ ] `ProviderCategory` enum (text, audio, image, video, embedding, code, structuredData)
- [ ] `SerializationFormat` enum (json, plist, binary, protobuf, messagepack)
- [ ] `OutputFileType` struct with predefined types (plainText, markdown, json, mp3, png, binary)
- [ ] `StorageAreaReference` struct for request-specific storage
- [ ] `TypedDataFileReference` struct for file references
- [ ] `TypedDataError` enum for validation errors

#### Documentation
- [ ] Inline API documentation (100% coverage on new types)
- [ ] Protocol usage examples
- [ ] Migration guide (Phase 5 → Phase 6 API)

#### Testing
- [ ] Protocol conformance tests (verify protocols compile)
- [ ] SerializationFormat conversion tests
- [ ] OutputFileType validation tests
- [ ] TypedDataError creation tests
- [ ] Backward compatibility tests (all Phase 5 tests still pass)

### Implementation Steps

**Day 1-2**: Core Protocols
1. Create `Sources/SwiftHablare/TypedData/AIRequestor.swift`
2. Create `Sources/SwiftHablare/TypedData/SerializableTypedData.swift`
3. Add `availableRequestors()` to `AIServiceProvider` with default implementation
4. Write protocol tests

**Day 3**: Supporting Enums and Structs
1. Create `Sources/SwiftHablare/TypedData/ProviderCategory.swift`
2. Create `Sources/SwiftHablare/TypedData/SerializationFormat.swift`
3. Create `Sources/SwiftHablare/TypedData/OutputFileType.swift`
4. Write enum/struct tests

**Day 4**: Reference Types
1. Create `Sources/SwiftHablare/TypedData/StorageAreaReference.swift`
2. Create `Sources/SwiftHablare/TypedData/TypedDataFileReference.swift`
3. Create `Sources/SwiftHablare/TypedData/TypedDataError.swift`
4. Write reference type tests

**Day 5**: Documentation and Validation
1. Complete inline documentation
2. Write migration guide section
3. Run all Phase 5 tests (ensure nothing broken)
4. Prepare for Gate 6A review

### Quality Gate 6A

**Gate ID**: QG-6A
**Must Pass Before**: Phase 6B begins

| Check | Requirement | Measurement | Pass Criteria |
|-------|-------------|-------------|---------------|
| **6A.1** | All protocols compile | Swift build | Clean build, no warnings |
| **6A.2** | Backward compatibility | Phase 5 tests | All 402 tests pass |
| **6A.3** | Documentation complete | API coverage | 100% inline docs on new types |

**Exit Criteria**:
- ✅ All new types and protocols implemented
- ✅ All Phase 5 providers still compile
- ✅ All Phase 5 tests pass (402/402)
- ✅ Zero Swift concurrency warnings
- ✅ Documentation complete
- ✅ Code review approved

**Rollback Plan**: Delete new types/protocols, revert to Phase 5

---

## Phase 6B: Text Requestor Refactoring

**Duration**: 1-2 weeks (7-10 days)
**Goal**: Refactor OpenAI, Anthropic, Apple Intelligence to requestor pattern
**Risk**: Medium (modifies existing providers, but maintains backward compatibility)

### Deliverables

#### Shared Text Types
- [ ] `GeneratedText` struct implementing `SerializableTypedData`
- [ ] `GeneratedTextRecord` SwiftData model
- [ ] `TextGenerationConfig` struct (shared across text requestors)
- [ ] `TokenUsage` struct for token tracking

#### OpenAI Refactoring
- [ ] `OpenAITextRequestor` class implementing `AIRequestor`
- [ ] Update `OpenAIProvider.availableRequestors()` to return `[OpenAITextRequestor()]`
- [ ] Maintain existing `generate()` method (backward compatibility)
- [ ] 40+ tests for OpenAITextRequestor

#### Anthropic Refactoring
- [ ] `AnthropicTextRequestor` class implementing `AIRequestor`
- [ ] Update `AnthropicProvider.availableRequestors()` to return `[AnthropicTextRequestor()]`
- [ ] Maintain existing `generate()` method
- [ ] 35+ tests for AnthropicTextRequestor

#### Apple Intelligence Refactoring
- [ ] `AppleIntelligenceTextRequestor` class implementing `AIRequestor`
- [ ] Update `AppleIntelligenceProvider.availableRequestors()` to return `[AppleIntelligenceTextRequestor()]`
- [ ] Maintain existing `generate()` method
- [ ] 31+ tests for AppleIntelligenceTextRequestor

#### Documentation
- [ ] Requestor implementation guide
- [ ] Text requestor examples
- [ ] Migration examples (Phase 5 → Phase 6 for text)

### Implementation Steps

**Days 1-2**: Shared Text Types
1. Create `Sources/SwiftHablare/TypedData/GeneratedText.swift`
2. Create `Sources/SwiftHablare/Models/GeneratedTextRecord.swift`
3. Create `Sources/SwiftHablare/TypedData/TextGenerationConfig.swift`
4. Write serialization/deserialization tests
5. Write SwiftData model tests

**Days 3-4**: OpenAI Refactoring
1. Create `Sources/SwiftHablare/Requestors/OpenAITextRequestor.swift`
2. Implement `request()` method (calls existing OpenAI provider)
3. Implement `makeResponseModel()` method
4. Update `OpenAIProvider.availableRequestors()`
5. Write 40 tests for OpenAITextRequestor
6. Ensure all existing OpenAI tests pass

**Days 5-6**: Anthropic Refactoring
1. Create `Sources/SwiftHablare/Requestors/AnthropicTextRequestor.swift`
2. Implement `request()` and `makeResponseModel()`
3. Update `AnthropicProvider.availableRequestors()`
4. Write 35 tests for AnthropicTextRequestor
5. Ensure all existing Anthropic tests pass

**Days 7-8**: Apple Intelligence Refactoring
1. Create `Sources/SwiftHablare/Requestors/AppleIntelligenceTextRequestor.swift`
2. Implement `request()` and `makeResponseModel()`
3. Update `AppleIntelligenceProvider.availableRequestors()`
4. Write 31 tests for AppleIntelligenceTextRequestor
5. Ensure all existing Apple Intelligence tests pass

**Days 9-10**: Integration and Documentation
1. Test all three text requestors together
2. Test backward compatibility (Phase 5 API still works)
3. Complete requestor implementation guide
4. Prepare for Gate 6B review

### Quality Gate 6B

**Gate ID**: QG-6B
**Must Pass Before**: Phase 6C begins

| Check | Requirement | Measurement | Pass Criteria |
|-------|-------------|-------------|---------------|
| **6B.1** | Text requestors complete | Code review | All 3 requestors implemented |
| **6B.2** | Test coverage | Coverage report | ≥85% per requestor |
| **6B.3** | Backward compatibility | Regression tests | All Phase 5 tests pass |

**Additional Checks**:
- ✅ OpenAI, Anthropic, Apple Intelligence requestors working
- ✅ All providers return requestors via `availableRequestors()`
- ✅ `GeneratedText` serializes/deserializes correctly
- ✅ `GeneratedTextRecord` persists to SwiftData
- ✅ Phase 5 `generate()` API still works for all 3 providers
- ✅ 106+ new tests passing (40 + 35 + 31)
- ✅ Zero Swift concurrency warnings

**Exit Criteria**:
- All text requestors implemented
- ≥85% test coverage per requestor
- Backward compatibility maintained
- Code review approved

**Rollback Plan**: Remove requestor implementations, keep Phase 5 API only

---

## Phase 6C: Audio Requestor + File Storage

**Duration**: 1-2 weeks (7-10 days)
**Goal**: Refactor ElevenLabs to requestor pattern + implement file storage infrastructure
**Risk**: High (new file storage system, binary data handling, SwiftGuion integration)

### Deliverables

#### File Storage Infrastructure
- [ ] SwiftGuion library integrated (Package.swift dependency)
- [ ] `TextPackCoordinator` actor for thread-safe file operations
- [ ] Storage area creation and management
- [ ] File write operations on background thread
- [ ] File reference creation and resolution

#### Audio Types
- [ ] `GeneratedAudio` struct implementing `SerializableTypedData` (binary format)
- [ ] `GeneratedAudioRecord` SwiftData model with file reference
- [ ] `AudioGenerationConfig` struct

#### ElevenLabs Refactoring
- [ ] `ElevenLabsAudioRequestor` class implementing `AIRequestor`
- [ ] File storage for MP3 data (large binary data)
- [ ] Update `ElevenLabsProvider.availableRequestors()` to return `[ElevenLabsAudioRequestor()]`
- [ ] Maintain existing `generate()` method
- [ ] File storage tests (write, read, reference resolution)
- [ ] Audio requestor tests

#### Documentation
- [ ] File storage architecture guide
- [ ] SwiftGuion integration guide
- [ ] Audio requestor implementation examples
- [ ] Performance measurement guide (file I/O)

### Implementation Steps

**Days 1-2**: SwiftGuion Integration
1. Add SwiftGuion to `Package.swift` dependencies
2. Create spike/prototype of file operations
3. Create `Sources/SwiftHablare/FileStorage/TextPackCoordinator.swift`
4. Implement basic file write/read operations
5. Write TextPackCoordinator tests

**Days 3-4**: Storage Area Management
1. Implement storage area creation in `TextPackCoordinator`
2. Implement file reference creation
3. Implement file reference resolution
4. Test concurrent file writes
5. Test thread safety with TSAN

**Days 5-6**: Audio Types
1. Create `Sources/SwiftHablare/TypedData/GeneratedAudio.swift`
2. Create `Sources/SwiftHablare/Models/GeneratedAudioRecord.swift`
3. Create `Sources/SwiftHablare/TypedData/AudioGenerationConfig.swift`
4. Implement binary serialization
5. Write audio type tests

**Days 7-8**: ElevenLabs Refactoring
1. Create `Sources/SwiftHablare/Requestors/ElevenLabsAudioRequestor.swift`
2. Implement `request()` with file storage
3. Implement `makeResponseModel()` with file references
4. Update `ElevenLabsProvider.availableRequestors()`
5. Write audio requestor tests

**Days 9-10**: File Storage Testing and Documentation
1. Test large file handling (1MB, 10MB, 100MB)
2. Performance benchmarking (file I/O)
3. Memory usage testing (no large data on main thread)
4. Complete file storage guide
5. Prepare for Gate 6C review

### Quality Gate 6C

**Gate ID**: QG-6C
**Must Pass Before**: Phase 6D begins

| Check | Requirement | Measurement | Pass Criteria |
|-------|-------------|-------------|---------------|
| **6C.1** | File storage working | Integration tests | Files write/read correctly |
| **6C.2** | Audio requestor complete | Code review | ElevenLabsAudioRequestor implemented |
| **6C.3** | Performance acceptable | Benchmarks | File I/O <100ms for 10MB |

**Additional Checks**:
- ✅ SwiftGuion library integrated and working
- ✅ TextPackCoordinator actor thread-safe (TSAN clean)
- ✅ ElevenLabsAudioRequestor working with file storage
- ✅ MP3 files written to `.guion` bundles on background thread
- ✅ File references transferred to main thread (not large data)
- ✅ `GeneratedAudioRecord` persists with file reference
- ✅ Phase 5 ElevenLabs `generate()` API still works
- ✅ All audio tests passing
- ✅ Zero Swift concurrency warnings

**Exit Criteria**:
- File storage infrastructure working
- Audio requestor implemented
- Performance benchmarks met
- Code review approved

**Rollback Plan**: Remove file storage code, keep in-memory only (fallback for ElevenLabs)

---

## Phase 6D: TypedDataBroker & Integration

**Duration**: 1 week (5 days)
**Goal**: Implement broker for request coordination + end-to-end integration testing
**Risk**: Medium (complex integration, but builds on working components)

### Deliverables

#### TypedDataBroker Actor
- [ ] `TypedDataBroker` actor implementation
- [ ] Request ID assignment
- [ ] Storage area creation and mapping (requestID → storageArea)
- [ ] Parent mapping (requestID → parentID)
- [ ] File attachment registry
- [ ] Status updates and observation

#### AIRequestManager Integration
- [ ] Pass storage area to requestors during execution
- [ ] Handle file references in responses
- [ ] Coordinate with AIDataCoordinator for SwiftData persistence

#### End-to-End Integration
- [ ] Complete workflow: parent → broker → requestor → file → persistence
- [ ] Multiple concurrent requests
- [ ] Error propagation through all layers
- [ ] Cancellation support

#### Documentation
- [ ] TypedDataBroker architecture guide
- [ ] Request lifecycle documentation
- [ ] Integration patterns and examples
- [ ] Phase 6 completion report

#### Testing
- [ ] TypedDataBroker unit tests
- [ ] Integration tests (all requestors)
- [ ] Concurrent request tests
- [ ] Performance benchmarks (full workflow)

### Implementation Steps

**Day 1-2**: TypedDataBroker Implementation
1. Create `Sources/SwiftHablare/Core/TypedDataBroker.swift`
2. Implement request ID assignment
3. Implement storage area creation and mapping
4. Implement parent mapping
5. Implement file attachment registry
6. Write TypedDataBroker unit tests

**Day 3**: AIRequestManager Integration
1. Update AIRequestManager to use TypedDataBroker
2. Pass storage area to requestors
3. Handle file references in responses
4. Coordinate with AIDataCoordinator
5. Write integration tests

**Day 4**: End-to-End Testing
1. Test complete workflow (text requestors)
2. Test complete workflow (audio requestor with files)
3. Test concurrent requests
4. Test error scenarios
5. Test cancellation

**Day 5**: Performance and Documentation
1. Run performance benchmarks (full workflow)
2. Verify performance targets met
3. Complete TypedDataBroker guide
4. Write Phase 6 completion report
5. Prepare for Gate 6D review

### Quality Gate 6D (Final Phase 6 Gate)

**Gate ID**: QG-6D
**Must Pass Before**: Phase 7 begins

| Check | Requirement | Measurement | Pass Criteria |
|-------|-------------|-------------|---------------|
| **6D.1** | TypedDataBroker working | Integration tests | Broker coordinates requests correctly |
| **6D.2** | End-to-end tests passing | Test results | All workflow tests pass |
| **6D.3** | Performance targets met | Benchmarks | <5ms requestor overhead |
| **6D.4** | All Phase 6 gates passed | Gate review | Gates 6A, 6B, 6C, 6D all passed |

**Additional Checks**:
- ✅ TypedDataBroker actor implemented and tested
- ✅ Integration with AIRequestManager working
- ✅ Integration with AIDataCoordinator working
- ✅ All 4 requestors working in production workflows
- ✅ File storage working for audio
- ✅ Backward compatibility maintained (all Phase 5 tests pass)
- ✅ ≥85% test coverage per requestor
- ✅ ≥90% overall test coverage (Phase 6 components)
- ✅ Zero Swift concurrency warnings
- ✅ All performance benchmarks met
- ✅ Documentation complete

**Exit Criteria**:
- All Phase 6 deliverables complete
- All quality gates passed (6A, 6B, 6C, 6D)
- Code review approved
- Ready for Phase 7 (UI components)

**Rollback Plan**: Not applicable (Phase 6 must complete before Phase 7)

---

## Risk Management by Sub-Phase

### Phase 6A Risks (Low)

| Risk | Impact | Mitigation |
|------|--------|------------|
| Protocol design flaws | Medium | External review before implementation |
| Backward compatibility break | High | Default implementation, extensive tests |

### Phase 6B Risks (Medium)

| Risk | Impact | Mitigation |
|------|--------|------------|
| Requestor refactoring breaks Phase 5 | High | Keep Phase 5 API, extensive regression tests |
| Test coverage gaps | Medium | ≥85% coverage requirement per requestor |
| Performance regression | Low | Benchmarking, <5ms overhead target |

### Phase 6C Risks (High)

| Risk | Impact | Mitigation |
|------|--------|------------|
| SwiftGuion integration issues | High | Early spike (Days 1-2), prototype first |
| File I/O performance problems | Medium | Benchmarking, optimization if needed |
| Thread safety bugs (file operations) | High | TSAN testing, actor isolation |
| Large data on main thread | High | Strict code review, memory tests |

### Phase 6D Risks (Medium)

| Risk | Impact | Mitigation |
|------|--------|------------|
| Integration complexity | Medium | Build on tested components, incremental integration |
| Concurrent request bugs | Medium | Extensive concurrent testing, TSAN |
| Performance bottlenecks | Low | Early benchmarking, optimization pass |

---

## Testing Strategy by Sub-Phase

### Phase 6A Testing
- Protocol conformance tests
- Enum/struct initialization tests
- Serialization format conversion tests
- Backward compatibility tests (all Phase 5 tests)

### Phase 6B Testing
- Requestor unit tests (≥85% coverage each)
  - Configuration validation
  - Request execution
  - Response model creation
  - Serialization/deserialization
- Backward compatibility tests
- Integration tests (requestors with providers)

### Phase 6C Testing
- File storage unit tests
  - Storage area creation
  - File write operations
  - File reference creation/resolution
- Thread safety tests (TSAN)
- Performance tests (file I/O)
- Audio requestor tests
- Integration tests (audio workflow)

### Phase 6D Testing
- TypedDataBroker unit tests
- Integration tests (full workflow)
  - Text generation workflow
  - Audio generation workflow with files
  - Multiple concurrent requests
  - Error scenarios
  - Cancellation
- Performance tests (end-to-end)
- Regression tests (all Phase 5 tests)

---

## Success Criteria Summary

### Phase 6A Success
- ✅ All core types and protocols implemented
- ✅ All Phase 5 tests pass (402/402)
- ✅ Zero concurrency warnings
- ✅ Documentation complete

### Phase 6B Success
- ✅ 3 text requestors implemented (OpenAI, Anthropic, Apple)
- ✅ ≥85% test coverage per requestor
- ✅ All Phase 5 tests pass
- ✅ Backward compatibility maintained

### Phase 6C Success
- ✅ File storage infrastructure working
- ✅ SwiftGuion integrated
- ✅ ElevenLabs audio requestor working
- ✅ File I/O performance acceptable (<100ms for 10MB)
- ✅ Thread safety verified (TSAN clean)

### Phase 6D Success
- ✅ TypedDataBroker working
- ✅ End-to-end integration working
- ✅ All 4 requestors in production workflows
- ✅ All performance benchmarks met
- ✅ All Phase 6 quality gates passed

---

## Timeline Summary

| Sub-Phase | Duration | Key Milestone |
|-----------|----------|---------------|
| **6A** | 1 week (5 days) | Core types and protocols |
| **Gate 6A** | 1 day | Review and approval |
| **6B** | 1-2 weeks (7-10 days) | Text requestors refactored |
| **Gate 6B** | 1 day | Review and approval |
| **6C** | 1-2 weeks (7-10 days) | Audio + file storage |
| **Gate 6C** | 1 day | Review and approval |
| **6D** | 1 week (5 days) | Integration complete |
| **Gate 6D** | 1 day | Final review |
| **Total** | **4-5 weeks** | Ready for Phase 7 |

---

## Rollback Procedures

### Rollback from 6A
- **Trigger**: Gate 6A fails
- **Action**: Delete new protocol/type files, revert to Phase 5
- **Risk**: None (no dependencies yet)
- **Time**: <1 hour

### Rollback from 6B
- **Trigger**: Gate 6B fails, requestors not working
- **Action**: Remove requestor implementations, keep Phase 5 API
- **Risk**: Low (backward compatibility maintained)
- **Time**: 1-2 days

### Rollback from 6C
- **Trigger**: Gate 6C fails, file storage not working
- **Action**: Remove file storage code, keep in-memory only
- **Risk**: Medium (audio would be in-memory only)
- **Time**: 2-3 days

### Rollback from 6D
- **Trigger**: Gate 6D fails, integration issues
- **Action**: Not applicable (Phase 6 must complete)
- **Risk**: High (cannot proceed to Phase 7)
- **Time**: Fix issues (no rollback option)

---

## Communication Plan

### After Each Gate

**Gate 6A**:
- Notify team: Core types complete, backward compatibility verified
- Update project board: Phase 6A complete

**Gate 6B**:
- Notify team: Text requestors complete, 3 providers migrated
- Update project board: Phase 6B complete
- Community: Blog post about requestor pattern

**Gate 6C**:
- Notify team: File storage working, audio requestor complete
- Update project board: Phase 6C complete
- Community: Demo of audio generation with file storage

**Gate 6D**:
- Notify team: Phase 6 complete, ready for Phase 7
- Update project board: Phase 6 complete
- Community: Phase 6 completion announcement
- Documentation: Publish Phase 6 completion report

---

## Next Steps

1. **Review this gated plan** with team
2. **Get approval** for sub-phase structure
3. **Create branch**: `phase-6a-foundation`
4. **Begin Phase 6A**: Core types and protocols (Week 1)

---

**Document Version**: 1.0
**Created**: 2025-10-12
**Author**: Claude (claude-sonnet-4-5-20250929)
**Status**: Implementation Plan
**Next Review**: Before Phase 6A begins
