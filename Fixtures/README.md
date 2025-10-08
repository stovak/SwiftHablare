# Test Fixtures

This directory contains centralized test fixtures for SwiftHablare tests.

## Structure

- `audio/` - Audio file fixtures (MP3, CAF formats)
- `voices/` - Voice data JSON fixtures

## Usage

Tests use `SwiftFixtureManager` to load these fixtures:

```swift
import SwiftFixtureManager

// Load a JSON fixture
let fixtureURL = try FixtureManager.getFixture("voices/apple_voices", extension: "json")
let data = try Data(contentsOf: fixtureURL)
```

## Files

### Audio Fixtures
- `audio/sample_mp3.fixture` - Minimal valid MP3 file header
- `audio/sample_caf.fixture` - Minimal valid CAF file header

### Voice Fixtures
- `voices/apple_voices.json` - Apple TTS voice definitions
- `voices/elevenlabs_voices.json` - ElevenLabs voice definitions
