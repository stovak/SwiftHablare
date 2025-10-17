import SwiftData
import Foundation

@Model
public final class SpeakableAudio {
    // MARK: - Identity

    public var id: UUID
    public var createdAt: Date

    // MARK: - Relationship to SpeakableItem

    /// The SpeakableItem this audio was generated from
    public var speakableItem: SpeakableItem?

    // MARK: - Audio Generation Details

    /// Reference to SwiftHablare GeneratedAudioRecord
    /// This is the ID of the SwiftHablare audio model
    public var hablareAudioID: UUID

    /// TTS provider used (e.g., "ElevenLabs", "Apple", "OpenAI")
    public var providerName: String

    /// Voice ID used for generation
    public var voiceID: String

    /// Voice name (human-readable)
    public var voiceName: String?

    // MARK: - Audio Metadata

    /// Duration in seconds
    public var durationSeconds: Double?

    /// File size in bytes (if stored as file)
    public var fileSizeBytes: Int?

    /// Audio format (e.g., "mp3", "wav", "m4a")
    public var audioFormat: String

    /// Sample rate (e.g., 44100, 48000)
    public var sampleRate: Int?

    // MARK: - Generation Metadata

    /// Cost to generate (in USD or provider credits)
    public var generationCost: Double?

    /// Character count of source text
    public var characterCount: Int

    /// Generation timestamp
    public var generatedAt: Date

    /// TTS generation settings (JSON encoded)
    /// Stores settings like temperature, speed, emotion, etc.
    public var generationSettings: String?

    // MARK: - Status

    /// Whether this audio is the active/preferred version
    public var isActive: Bool

    /// Quality rating (user feedback)
    public var qualityRating: Int?  // 1-5 stars

    /// User notes about this audio version
    public var notes: String?

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        hablareAudioID: UUID,
        providerName: String,
        voiceID: String,
        voiceName: String? = nil,
        audioFormat: String,
        characterCount: Int,
        isActive: Bool = true,
        createdAt: Date = Date(),
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.hablareAudioID = hablareAudioID
        self.providerName = providerName
        self.voiceID = voiceID
        self.voiceName = voiceName
        self.audioFormat = audioFormat
        self.characterCount = characterCount
        self.isActive = isActive
        self.createdAt = createdAt
        self.generatedAt = generatedAt
    }
}
