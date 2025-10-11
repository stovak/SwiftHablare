import Foundation

/// Defines the types of AI capabilities that providers can support.
///
/// Used to query and filter providers based on what they can generate.
///
/// ## Example
/// ```swift
/// // Find providers that can generate text
/// let textProviders = manager.providers(withCapability: .textGeneration)
///
/// // Check if a provider supports images
/// if provider.capabilities.contains(.imageGeneration) {
///     // Use provider for image generation
/// }
/// ```
@available(macOS 15.0, iOS 17.0, *)
public enum AICapability: Sendable, Codable {
    /// Plain text generation (articles, stories, responses, etc.)
    case textGeneration

    /// Audio synthesis (text-to-speech, music generation, sound effects)
    case audioGeneration

    /// Image generation (creation, editing, analysis)
    case imageGeneration

    /// Video generation and editing
    case videoGeneration

    /// Structured data generation (JSON, CSV, XML)
    case structuredData

    /// Vector embeddings for semantic search
    case embeddings

    /// Speech-to-text transcription
    case transcription

    /// Image analysis and description
    case imageAnalysis

    /// Code generation and completion
    case codeGeneration

    /// Custom capability defined by provider
    case custom(String)

    // MARK: - Raw Value Support

    /// Raw value for standard cases
    public var rawValue: String {
        switch self {
        case .textGeneration: return "text_generation"
        case .audioGeneration: return "audio_generation"
        case .imageGeneration: return "image_generation"
        case .videoGeneration: return "video_generation"
        case .structuredData: return "structured_data"
        case .embeddings: return "embeddings"
        case .transcription: return "transcription"
        case .imageAnalysis: return "image_analysis"
        case .codeGeneration: return "code_generation"
        case .custom(let value): return value
        }
    }

    // MARK: - Codable Support

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case "text_generation": self = .textGeneration
        case "audio_generation": self = .audioGeneration
        case "image_generation": self = .imageGeneration
        case "video_generation": self = .videoGeneration
        case "structured_data": self = .structuredData
        case "embeddings": self = .embeddings
        case "transcription": self = .transcription
        case "image_analysis": self = .imageAnalysis
        case "code_generation": self = .codeGeneration
        default: self = .custom(rawValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .custom(let value):
            try container.encode(value)
        default:
            try container.encode(self.rawValue)
        }
    }

    // MARK: - All Standard Cases

    /// All standard (non-custom) capability cases
    public static var allStandardCases: [AICapability] {
        [
            .textGeneration,
            .audioGeneration,
            .imageGeneration,
            .videoGeneration,
            .structuredData,
            .embeddings,
            .transcription,
            .imageAnalysis,
            .codeGeneration
        ]
    }

    // MARK: - Display

    /// Human-readable name for this capability.
    public var displayName: String {
        switch self {
        case .textGeneration: return "Text Generation"
        case .audioGeneration: return "Audio Generation"
        case .imageGeneration: return "Image Generation"
        case .videoGeneration: return "Video Generation"
        case .structuredData: return "Structured Data"
        case .embeddings: return "Embeddings"
        case .transcription: return "Transcription"
        case .imageAnalysis: return "Image Analysis"
        case .codeGeneration: return "Code Generation"
        case .custom(let name): return name
        }
    }
}

// MARK: - Equatable

@available(macOS 15.0, iOS 17.0, *)
extension AICapability: Equatable {
    public static func == (lhs: AICapability, rhs: AICapability) -> Bool {
        switch (lhs, rhs) {
        case (.custom(let lValue), .custom(let rValue)):
            return lValue == rValue
        case (.textGeneration, .textGeneration),
             (.audioGeneration, .audioGeneration),
             (.imageGeneration, .imageGeneration),
             (.videoGeneration, .videoGeneration),
             (.structuredData, .structuredData),
             (.embeddings, .embeddings),
             (.transcription, .transcription),
             (.imageAnalysis, .imageAnalysis),
             (.codeGeneration, .codeGeneration):
            return true
        default:
            return false
        }
    }
}

// MARK: - Hashable

@available(macOS 15.0, iOS 17.0, *)
extension AICapability: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .custom(let value):
            hasher.combine("custom")
            hasher.combine(value)
        default:
            hasher.combine(self.rawValue)
        }
    }
}
