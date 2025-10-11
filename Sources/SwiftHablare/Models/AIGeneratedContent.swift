import Foundation
import SwiftData

/// Base model for AI-generated content with common metadata fields.
///
/// This model stores metadata about AI generation operations that is common
/// across all types of generated content (text, audio, images, etc.).
///
/// Specific content types should extend this base or create their own models
/// that include similar metadata fields.
///
/// ## Example
/// ```swift
/// @Model
/// final class GeneratedArticle: AIGeneratedContent {
///     var title: String = ""
///     var content: String = ""
///     var wordCount: Int = 0
///
///     init(title: String, content: String, providerId: String, prompt: String) {
///         self.title = title
///         self.content = content
///         self.wordCount = content.split(separator: " ").count
///         super.init(providerId: providerId, prompt: prompt)
///     }
/// }
/// ```
@available(macOS 15.0, iOS 17.0, *)
@Model
public class AIGeneratedContent {
    /// Unique identifier for this content.
    @Attribute(.unique) public var id: UUID

    /// ID of the provider that generated this content.
    public var providerId: String

    /// The prompt used to generate this content.
    public var prompt: String

    /// When this content was generated.
    public var generatedAt: Date

    /// When this record was last modified.
    public var modifiedAt: Date

    /// Model identifier used by the provider (e.g., "gpt-4", "claude-3-sonnet").
    public var modelIdentifier: String?

    /// Token count (if applicable and provided by the provider).
    public var tokenCount: Int?

    /// Estimated cost in USD (if available).
    public var estimatedCost: Double?

    /// Request parameters used for generation.
    public var requestParameters: Data?

    /// Additional metadata as JSON.
    public var metadata: Data?

    public init(
        id: UUID = UUID(),
        providerId: String,
        prompt: String,
        generatedAt: Date = Date(),
        modelIdentifier: String? = nil,
        tokenCount: Int? = nil,
        estimatedCost: Double? = nil,
        requestParameters: Data? = nil,
        metadata: Data? = nil
    ) {
        self.id = id
        self.providerId = providerId
        self.prompt = prompt
        self.generatedAt = generatedAt
        self.modifiedAt = generatedAt
        self.modelIdentifier = modelIdentifier
        self.tokenCount = tokenCount
        self.estimatedCost = estimatedCost
        self.requestParameters = requestParameters
        self.metadata = metadata
    }

    /// Updates the modification timestamp.
    public func touch() {
        self.modifiedAt = Date()
    }
}

// MARK: - Type-Specific Models

/// Model for AI-generated text content.
@available(macOS 15.0, iOS 17.0, *)
@Model
public final class GeneratedText {
    @Attribute(.unique) public var id: UUID
    public var providerId: String
    public var prompt: String
    public var generatedAt: Date
    public var modifiedAt: Date

    /// The generated text content.
    public var content: String

    /// Character count.
    public var characterCount: Int

    /// Word count (approximate).
    public var wordCount: Int

    /// Language code (e.g., "en", "es").
    public var languageCode: String?

    /// Model identifier.
    public var modelIdentifier: String?

    /// Token count.
    public var tokenCount: Int?

    /// Estimated cost.
    public var estimatedCost: Double?

    public init(
        id: UUID = UUID(),
        providerId: String,
        prompt: String,
        content: String,
        languageCode: String? = nil,
        modelIdentifier: String? = nil
    ) {
        self.id = id
        self.providerId = providerId
        self.prompt = prompt
        self.content = content
        self.generatedAt = Date()
        self.modifiedAt = Date()
        self.languageCode = languageCode
        self.modelIdentifier = modelIdentifier

        // Calculate counts
        self.characterCount = content.count
        self.wordCount = content.split(separator: " ").count
    }
}

/// Model for AI-generated audio content.
@available(macOS 15.0, iOS 17.0, *)
@Model
public final class GeneratedAudio {
    @Attribute(.unique) public var id: UUID
    public var providerId: String
    public var prompt: String
    public var generatedAt: Date
    public var modifiedAt: Date

    /// The audio data.
    public var audioData: Data

    /// Audio format (e.g., "mp3", "wav", "aac").
    public var audioFormat: String

    /// Duration in seconds.
    public var duration: TimeInterval?

    /// Sample rate in Hz.
    public var sampleRate: Int?

    /// Bit rate in bps.
    public var bitRate: Int?

    /// Number of channels (1 = mono, 2 = stereo).
    public var channels: Int?

    /// Voice ID used (for TTS).
    public var voiceId: String?

    /// Model identifier.
    public var modelIdentifier: String?

    /// Estimated cost.
    public var estimatedCost: Double?

    public init(
        id: UUID = UUID(),
        providerId: String,
        prompt: String,
        audioData: Data,
        audioFormat: String,
        duration: TimeInterval? = nil,
        sampleRate: Int? = nil,
        voiceId: String? = nil
    ) {
        self.id = id
        self.providerId = providerId
        self.prompt = prompt
        self.audioData = audioData
        self.audioFormat = audioFormat
        self.duration = duration
        self.sampleRate = sampleRate
        self.voiceId = voiceId
        self.generatedAt = Date()
        self.modifiedAt = Date()
    }
}

/// Model for AI-generated image content.
@available(macOS 15.0, iOS 17.0, *)
@Model
public final class GeneratedImage {
    @Attribute(.unique) public var id: UUID
    public var providerId: String
    public var prompt: String
    public var generatedAt: Date
    public var modifiedAt: Date

    /// The image data.
    public var imageData: Data

    /// Image format (e.g., "png", "jpg", "webp").
    public var imageFormat: String

    /// Width in pixels.
    public var width: Int?

    /// Height in pixels.
    public var height: Int?

    /// File size in bytes.
    public var fileSize: Int

    /// Model identifier.
    public var modelIdentifier: String?

    /// Estimated cost.
    public var estimatedCost: Double?

    public init(
        id: UUID = UUID(),
        providerId: String,
        prompt: String,
        imageData: Data,
        imageFormat: String,
        width: Int? = nil,
        height: Int? = nil
    ) {
        self.id = id
        self.providerId = providerId
        self.prompt = prompt
        self.imageData = imageData
        self.imageFormat = imageFormat
        self.width = width
        self.height = height
        self.fileSize = imageData.count
        self.generatedAt = Date()
        self.modifiedAt = Date()
    }
}

/// Model for AI-generated video content.
@available(macOS 15.0, iOS 17.0, *)
@Model
public final class GeneratedVideo {
    @Attribute(.unique) public var id: UUID
    public var providerId: String
    public var prompt: String
    public var generatedAt: Date
    public var modifiedAt: Date

    /// URL or path to the video file (videos typically too large for Data).
    public var videoURL: URL

    /// Video format (e.g., "mp4", "mov", "webm").
    public var videoFormat: String

    /// Duration in seconds.
    public var duration: TimeInterval?

    /// Width in pixels.
    public var width: Int?

    /// Height in pixels.
    public var height: Int?

    /// Frame rate (fps).
    public var frameRate: Double?

    /// File size in bytes.
    public var fileSize: Int64?

    /// Model identifier.
    public var modelIdentifier: String?

    /// Estimated cost.
    public var estimatedCost: Double?

    public init(
        id: UUID = UUID(),
        providerId: String,
        prompt: String,
        videoURL: URL,
        videoFormat: String,
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.providerId = providerId
        self.prompt = prompt
        self.videoURL = videoURL
        self.videoFormat = videoFormat
        self.duration = duration
        self.generatedAt = Date()
        self.modifiedAt = Date()
    }
}

/// Model for AI-generated structured data.
@available(macOS 15.0, iOS 17.0, *)
@Model
public final class GeneratedStructuredData {
    @Attribute(.unique) public var id: UUID
    public var providerId: String
    public var prompt: String
    public var generatedAt: Date
    public var modifiedAt: Date

    /// The structured data (JSON, CSV, XML, etc.).
    public var data: Data

    /// Data format (e.g., "json", "csv", "xml").
    public var dataFormat: String

    /// Schema version (if applicable).
    public var schemaVersion: String?

    /// Model identifier.
    public var modelIdentifier: String?

    /// Estimated cost.
    public var estimatedCost: Double?

    public init(
        id: UUID = UUID(),
        providerId: String,
        prompt: String,
        data: Data,
        dataFormat: String,
        schemaVersion: String? = nil
    ) {
        self.id = id
        self.providerId = providerId
        self.prompt = prompt
        self.data = data
        self.dataFormat = dataFormat
        self.schemaVersion = schemaVersion
        self.generatedAt = Date()
        self.modifiedAt = Date()
    }
}
