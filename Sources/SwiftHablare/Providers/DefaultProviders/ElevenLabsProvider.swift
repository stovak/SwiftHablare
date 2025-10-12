//
//  ElevenLabsProvider.swift
//  SwiftHablare
//
//  Real ElevenLabs provider implementation for text-to-speech
//

import Foundation
import SwiftData

/// ElevenLabs provider implementation for text-to-speech generation.
///
/// Supports ElevenLabs' voice synthesis API with multiple voices and models.
///
/// ## Features
/// - High-quality text-to-speech generation
/// - Multiple voice options
/// - Voice settings customization (stability, clarity)
/// - Multiple model support
/// - Audio streaming support (future)
///
/// ## Configuration
/// Requires an ElevenLabs API key stored securely in the keychain via `AICredentialManager`.
///
/// ## Example
/// ```swift
/// let provider = ElevenLabsProvider()
/// let result = await provider.generate(
///     prompt: "Hello, world!",
///     parameters: [
///         "voice_id": "21m00Tcm4TlvDq8ikWAM",  // Rachel
///         "model_id": "eleven_monolingual_v1"
///     ]
/// )
/// ```
@available(macOS 15.0, iOS 17.0, *)
public final class ElevenLabsProvider: BaseHTTPProvider, AIServiceProvider, @unchecked Sendable {

    // MARK: - Constants

    public static let defaultBaseURL = "https://api.elevenlabs.io"
    private static let defaultVoiceID = "21m00Tcm4TlvDq8ikWAM" // Rachel
    private static let defaultModelID = "eleven_monolingual_v1"

    // MARK: - Identity

    public let id: String = "elevenlabs"
    public let displayName: String = "ElevenLabs"

    // MARK: - Capabilities

    public let capabilities: [AICapability] = [
        .audioGeneration
    ]

    public let supportedDataStructures: [DataStructureCapability] = []

    // MARK: - Configuration

    public let requiresAPIKey: Bool = true

    private let credentialManager: AICredentialManager

    // MARK: - Response Type

    public let responseType: ResponseContent.ContentType = .audio

    // MARK: - Initialization

    /// Create a new ElevenLabs provider.
    ///
    /// - Parameters:
    ///   - credentialManager: Credential manager for API key storage
    ///   - baseURL: Custom API base URL (default: ElevenLabs' official API)
    public init(
        credentialManager: AICredentialManager = .shared,
        baseURL: String = defaultBaseURL
    ) {
        self.credentialManager = credentialManager
        super.init(baseURL: baseURL, timeout: 120.0)
    }

    // MARK: - Configuration

    public func isConfigured() -> Bool {
        // Assume configured, actual validation happens in generate()
        return true
    }

    public func validateConfiguration() throws {
        // Synchronous validation - actual credential retrieval happens async in generate()
    }

    // MARK: - Generation (New API)

    public func generate(
        prompt: String,
        parameters: [String: Any]
    ) async -> Result<ResponseContent, AIServiceError> {
        // Get API key from credential manager (async actor call)
        let credential: SecureString
        do {
            credential = try await credentialManager.retrieve(providerID: id, type: .apiKey)
        } catch {
            return .failure(.missingCredentials("Failed to retrieve ElevenLabs API key: \(error.localizedDescription)"))
        }

        // Validate key format (ElevenLabs keys are typically 32-character hex strings)
        guard credential.value.count >= 32 || credential.value.hasPrefix("test-") else {
            return .failure(.invalidAPIKey("ElevenLabs API key must be at least 32 characters"))
        }

        // Build request
        let voiceID = parameters["voice_id"] as? String ?? Self.defaultVoiceID
        let modelID = parameters["model_id"] as? String ?? Self.defaultModelID
        let stability = parameters["stability"] as? Double ?? 0.5
        let clarityBoost = parameters["clarity_boost"] as? Double ?? 0.75

        let request = TextToSpeechRequest(
            text: prompt,
            modelId: modelID,
            voiceSettings: VoiceSettings(
                stability: stability,
                similarityBoost: clarityBoost
            )
        )

        // Make API call
        do {
            // ElevenLabs returns audio data directly (not JSON)
            let response = try await postForData(
                endpoint: "/v1/text-to-speech/\(voiceID)",
                headers: [
                    "xi-api-key": credential.value,
                    "Content-Type": "application/json"
                ],
                body: request
            )

            // ElevenLabs returns MP3 audio by default
            return .success(.audio(response, format: .mp3))

        } catch let error as AIServiceError {
            return .failure(error)
        } catch {
            return .failure(.networkError("ElevenLabs API request failed: \(error.localizedDescription)"))
        }
    }

    // MARK: - HTTP Helper for Binary Data

    /// Make a POST request that returns binary data instead of JSON
    private func postForData<Request: Encodable>(
        endpoint: String,
        headers: [String: String],
        body: Request
    ) async throws -> Data {
        // Build URL
        guard let url = URL(string: baseURL + endpoint) else {
            throw AIServiceError.configurationError("Invalid URL: \(baseURL + endpoint)")
        }

        // Create request
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"

        // Set headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Encode body
        let encoder = JSONEncoder()
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw AIServiceError.configurationError("Failed to encode request body: \(error.localizedDescription)")
        }

        // Execute request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            // Map URLError to AIServiceError
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut:
                    throw AIServiceError.timeout("Request timed out after \(timeout) seconds")
                case .notConnectedToInternet, .networkConnectionLost:
                    throw AIServiceError.connectionFailed("No internet connection available")
                default:
                    throw AIServiceError.networkError("Network error: \(urlError.localizedDescription)")
                }
            }
            throw AIServiceError.networkError("Request failed: \(error.localizedDescription)")
        }

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.networkError("Invalid response type")
        }

        // Handle error responses
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"

            switch httpResponse.statusCode {
            case 401:
                throw AIServiceError.authenticationFailed("Authentication failed: \(errorMessage)")
            case 429:
                throw AIServiceError.rateLimitExceeded("Rate limit exceeded: \(errorMessage)")
            case 400...499:
                throw AIServiceError.invalidRequest("Invalid request (\(httpResponse.statusCode)): \(errorMessage)")
            case 500...599:
                throw AIServiceError.providerError("Server error (\(httpResponse.statusCode)): \(errorMessage)")
            default:
                throw AIServiceError.networkError("HTTP error \(httpResponse.statusCode): \(errorMessage)")
            }
        }

        return data
    }

    // MARK: - Generation (Legacy API)

    @available(*, deprecated)
    public func generate(
        prompt: String,
        parameters: [String: Any],
        context: ModelContext
    ) async throws -> Data {
        let result = await generate(prompt: prompt, parameters: parameters)

        switch result {
        case .success(let content):
            guard let audioContent = content.audioContent else {
                throw AIServiceError.dataConversionError("Content is not audio")
            }
            return audioContent.data

        case .failure(let error):
            throw error
        }
    }

    @available(*, deprecated)
    public func generateProperty<T: PersistentModel>(
        for model: T,
        property: PartialKeyPath<T>,
        prompt: String?,
        context: [String: Any]
    ) async throws -> Any {
        let actualPrompt = prompt ?? "Generate audio"
        let result = await generate(prompt: actualPrompt, parameters: context)

        switch result {
        case .success(let content):
            return content.audioContent?.data ?? Data()
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - Request Models

@available(macOS 15.0, iOS 17.0, *)
extension ElevenLabsProvider {

    /// ElevenLabs text-to-speech request
    struct TextToSpeechRequest: Encodable {
        let text: String
        let modelId: String
        let voiceSettings: VoiceSettings

        enum CodingKeys: String, CodingKey {
            case text
            case modelId = "model_id"
            case voiceSettings = "voice_settings"
        }
    }

    /// Voice settings for TTS generation
    struct VoiceSettings: Codable {
        let stability: Double
        let similarityBoost: Double

        enum CodingKeys: String, CodingKey {
            case stability
            case similarityBoost = "similarity_boost"
        }
    }
}

// MARK: - Factory Methods

@available(macOS 15.0, iOS 17.0, *)
extension ElevenLabsProvider {

    /// Create a provider with shared credential manager
    public static func shared() -> ElevenLabsProvider {
        return ElevenLabsProvider(credentialManager: .shared)
    }
}
