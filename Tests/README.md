# SwiftHablare Tests

Comprehensive test suite for the SwiftHablare text-to-speech library.

## Test Coverage

### Model Tests

#### VoiceTests.swift
Tests for the `Voice` model:
- Initialization with various configurations
- Default values
- Codable conformance (encoding/decoding)
- Round-trip encoding/decoding
- Identifiable conformance
- Mutable properties

#### VoiceModelTests.swift
Tests for the `VoiceModel` SwiftData model:
- Initialization
- SwiftData persistence
- Uniqueness constraints
- Deletion
- Conversion to/from `Voice`
- Round-trip conversion
- Querying by provider ID
- Sorted queries
- Timestamp handling

#### AudioFileTests.swift
Tests for the `AudioFile` SwiftData model:
- Initialization with various metadata
- Custom IDs and dates
- SwiftData persistence
- Uniqueness constraints
- Deletion
- Querying by voice ID, provider ID, and combined criteria
- Sorted queries by creation date
- Audio format handling
- Audio metadata (sample rate, bit rate, channels)
- Mono vs stereo configurations
- Empty and large data handling

#### SwiftHablareLibraryTests.swift
Tests for the main library interface:
- Version information
- Semantic versioning format validation

### Protocol and Type Tests

#### VoiceProviderTests.swift
Tests for `VoiceProvider` protocol and related types:
- `VoiceProviderType` enum (raw values, display names, all cases, Codable)
- `VoiceProviderError` error descriptions
- `MockVoiceProvider` implementation
- Mock provider configuration and behavior
- Call tracking and verification
- Error simulation
- Sendable conformance

### Manager Tests

#### VoiceProviderManagerTests.swift
Tests for `VoiceProviderManager`:
- Initialization (default and with saved preferences)
- Provider registration and retrieval
- Provider configuration checks
- Provider switching
- Voice caching and retrieval
- Force refresh functionality
- Audio generation
- Audio caching with SwiftData
- Duplicate detection
- File writing
- Published property observation
- UserDefaults persistence
- Error handling

### Provider Tests

#### AppleVoiceProviderTests.swift
Tests for Apple Voice Provider using mock simulator (24 tests):
- Provider properties and configuration
- Voice fetching with quality levels
- Gender detection
- Language and locality parsing
- Audio generation in CAF format
- Duration estimation algorithm
- Voice availability checks
- Error handling
- Complete integration flows

#### ElevenLabsVoiceProviderTests.swift
Tests for ElevenLabs Voice Provider using mock simulator (35 tests):
- Provider properties and API key management
- Voice fetching with ElevenLabs API format
- Voice descriptions and metadata
- Gender and language information
- Audio generation in MP3 format
- HTTP error code handling (401, 404, 429, 500)
- Duration estimation algorithm
- Voice availability checks
- API response format validation
- Complete integration flows
- Multiple consecutive generations

## Mock Objects

### MockVoiceProvider.swift
A comprehensive mock implementation of `VoiceProvider` for testing:
- Configurable responses for all protocol methods
- Call tracking for verification
- Error simulation
- State management
- Reset functionality

### MockAppleVoiceProviderSimulator.swift
Simulates Apple VoiceProvider with realistic responses (no actual speech generation):
- Returns simulated Apple voices (Samantha, Alex, Daniel, Karen, Ava)
- Generates valid CAF audio file headers
- Simulates Apple's duration estimation algorithm (~14.5 chars/sec)
- Supports quality levels (Enhanced, Premium)
- Gender detection for common Apple voice names
- Language/locality parsing
- Configurable error states
- Call tracking

### MockElevenLabsVoiceProviderSimulator.swift
Simulates ElevenLabs VoiceProvider with documented API responses (no actual speech generation):
- Returns simulated ElevenLabs voices (Rachel, Antoni, Bella, etc.)
- Generates valid MP3 audio file headers
- Simulates ElevenLabs duration estimation algorithm (~13 chars/sec)
- API key management
- HTTP error code simulation (401, 404, 429, 500)
- Documented API response formats
- Voice metadata (gender, accent, age, use case)
- Configurable error states
- Call tracking

## Running Tests

```bash
# Run all tests
swift test

# Clean build and run tests
swift package clean && swift test
```

## Test Statistics

- **Total Tests**: 138
- **Test Suites**: 8
- **Model Tests**: 36
- **Protocol/Type Tests**: 16
- **Manager Tests**: 24
- **Library Tests**: 3
- **Provider Tests**: 59 (Apple: 24, ElevenLabs: 35)

## Test Organization

```
Tests/SwiftHablareTests/
├── Mocks/
│   ├── MockVoiceProvider.swift
│   ├── MockAppleVoiceProviderSimulator.swift
│   └── MockElevenLabsVoiceProviderSimulator.swift
├── AudioFileTests.swift
├── VoiceTests.swift
├── VoiceModelTests.swift
├── VoiceProviderTests.swift
├── VoiceProviderManagerTests.swift
├── AppleVoiceProviderTests.swift
├── ElevenLabsVoiceProviderTests.swift
├── SwiftHablareLibraryTests.swift
└── SwiftHablareTests.swift (original)
```

## Notes

- All tests use in-memory SwiftData containers to avoid side effects
- Tests are isolated and can run in parallel
- Mock objects support comprehensive verification
- UserDefaults are cleaned up in tearDown methods
- Temporary files are cleaned up after file I/O tests
