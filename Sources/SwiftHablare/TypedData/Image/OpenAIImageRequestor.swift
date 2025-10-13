//
//  OpenAIImageRequestor.swift
//  SwiftHablare
//
//  Phase 6D: OpenAI DALL-E image generation requestor
//

import Foundation
import SwiftUI

/// OpenAI DALL-E image generation requestor.
///
/// Implements the AIRequestor protocol for OpenAI's DALL-E API.
/// Generates images from text prompts using DALL-E 2 or DALL-E 3.
///
/// ## Usage
/// ```swift
/// let requestor = OpenAIImageRequestor(provider: openAIProvider)
///
/// // For storyboards: use widescreen (16:9) format
/// let config = ImageGenerationConfig(
///     size: .wide16x9,
///     quality: .hd,
///     style: .natural,
///     numberOfImages: 1
/// )
///
/// let result = await requestor.request(
///     prompt: "A sunset over mountains, cinematic lighting",
///     configuration: config,
///     storageArea: storageArea
/// )
/// ```
@available(macOS 15.0, iOS 17.0, *)
public final class OpenAIImageRequestor: AIRequestor, @unchecked Sendable {

    // MARK: - Associated Types

    public typealias TypedData = GeneratedImageData
    public typealias ResponseModel = GeneratedImageRecord
    public typealias Configuration = ImageGenerationConfig

    // MARK: - Properties

    /// Unique identifier for this requestor
    public let requestorID: String

    /// Human-readable display name
    public let displayName: String

    /// The provider that offers this requestor
    public let providerID: String = "openai"

    /// Category of content this requestor generates
    public let category: ProviderCategory = .image

    /// Output file type
    public let outputFileType: OutputFileType = .png()

    /// Optional schema for validation
    public let schema: TypedDataSchema? = nil

    /// Maximum expected response size (10MB for images)
    public let estimatedMaxSize: Int64? = 10_000_000

    // Private properties
    private let provider: OpenAIProvider
    private let model: Model

    // MARK: - Model Selection

    /// DALL-E model options
    public enum Model: String, Codable, Sendable {
        case dalle2 = "dall-e-2"
        case dalle3 = "dall-e-3"

        public var displayName: String {
            switch self {
            case .dalle2: return "DALL-E 2"
            case .dalle3: return "DALL-E 3"
            }
        }
    }

    // MARK: - Cost Estimation

    /// Estimated cost per image based on OpenAI pricing
    /// DALL-E 3: $0.04 (standard 1024x1024), $0.08 (HD 1024x1024), $0.12 (HD 1792x1024)
    /// DALL-E 2: $0.016 (256x256), $0.018 (512x512), $0.02 (1024x1024)
    private func estimatedCost(for config: ImageGenerationConfig) -> Double {
        switch model {
        case .dalle3:
            if config.quality == .hd {
                // HD widescreen/portrait (1792x1024 or 1024x1792)
                if config.size == .wide16x9 || config.size == .portrait9x16 {
                    return 0.12
                } else {
                    // HD square (1024x1024)
                    return 0.08
                }
            } else {
                // Standard quality (1024x1024)
                return 0.04
            }
        case .dalle2:
            switch config.size {
            case .square256: return 0.016
            case .square512: return 0.018
            case .square1024: return 0.02
            default: return 0.02
            }
        }
    }

    // MARK: - Initialization

    /// Creates an OpenAI image requestor
    ///
    /// - Parameters:
    ///   - provider: OpenAI provider instance
    ///   - model: DALL-E model to use (default: DALL-E 3)
    public init(provider: OpenAIProvider, model: Model = .dalle3) {
        self.provider = provider
        self.model = model
        self.requestorID = "openai.image.\(model.rawValue)"
        self.displayName = "OpenAI \(model.displayName)"
    }

    // MARK: - Configuration

    public func defaultConfiguration() -> ImageGenerationConfig {
        return ImageGenerationConfig.default
    }

    public func validateConfiguration(_ config: ImageGenerationConfig) throws {
        // Only support single image generation
        // Note: While DALL-E 2 API supports multiple images, the AIRequestor protocol
        // returns a single TypedData. Batch generation can be added in a future phase.
        guard config.numberOfImages == 1 else {
            throw AIServiceError.configurationError(
                "Only single image generation is supported. Got numberOfImages=\(config.numberOfImages), expected 1."
            )
        }

        // DALL-E 3 specific validations
        if model == .dalle3 {
            // DALL-E 3 doesn't support small square sizes
            guard config.size != .square256 && config.size != .square512 else {
                throw AIServiceError.configurationError(
                    "DALL-E 3 does not support sizes smaller than 1024x1024 (use square1024, wide16x9, or portrait9x16)"
                )
            }
        }

        // DALL-E 2 specific validations
        if model == .dalle2 {
            // DALL-E 2 doesn't support HD or styles
            if config.quality == .hd {
                throw AIServiceError.configurationError(
                    "DALL-E 2 does not support HD quality"
                )
            }

            // DALL-E 2 only supports square formats
            if config.size == .wide16x9 || config.size == .portrait9x16 {
                throw AIServiceError.configurationError(
                    "DALL-E 2 only supports square aspect ratios (use square256, square512, or square1024)"
                )
            }
        }
    }

    // MARK: - Request Execution

    public func request(
        prompt: String,
        configuration: Configuration,
        storageArea: StorageAreaReference
    ) async -> Result<GeneratedImageData, AIServiceError> {
        // Validate configuration first
        do {
            try validateConfiguration(configuration)
        } catch let error as AIServiceError {
            return .failure(error)
        } catch {
            return .failure(.configurationError(error.localizedDescription))
        }

        // Validate prompt is not empty
        guard !prompt.isEmpty else {
            return .failure(.configurationError("Prompt cannot be empty"))
        }

        // Build parameters for OpenAI API
        var parameters: [String: Any] = [
            "model": model.rawValue,
            "prompt": prompt,
            "n": configuration.numberOfImages,
            "size": configuration.size.rawValue,
            "response_format": "b64_json" // Get base64 for easier handling
        ]

        // Add DALL-E 3 specific parameters
        if model == .dalle3 {
            parameters["quality"] = configuration.quality.rawValue
            parameters["style"] = configuration.style.rawValue
        }

        // Make API call through provider's HTTP client
        let result = await makeImageGenerationRequest(parameters: parameters)

        switch result {
        case .success(let response):
            // For now, handle single image (DALL-E 3 or first image from DALL-E 2)
            guard let firstImage = response.data.first else {
                return .failure(.unexpectedResponseFormat("No images in response"))
            }

            // Decode base64 image data
            guard let imageData = Data(base64Encoded: firstImage.b64Json) else {
                return .failure(.unexpectedResponseFormat("Failed to decode base64 image data"))
            }

            // Determine if we should store as file based on size threshold
            let shouldStoreAsFile = outputFileType.shouldStoreAsFile(estimatedSize: Int64(imageData.count))

            // Storage decision: write to file if data exceeds threshold
            let storedImageData: Data?
            if shouldStoreAsFile {
                // Write to storage area and return nil imageData
                do {
                    // Create storage directory if needed
                    try storageArea.createDirectoryIfNeeded()

                    // Write image to file
                    let fileURL = storageArea.defaultDataFileURL(extension: "png")
                    try imageData.write(to: fileURL)

                    // Nil out imageData since it's now file-stored
                    storedImageData = nil
                } catch {
                    return .failure(.persistenceError(
                        "Failed to write image to storage: \(error.localizedDescription)"
                    ))
                }
            } else {
                // Store in-memory for small images
                storedImageData = imageData
            }

            // Create typed data
            let typedData = GeneratedImageData(
                imageData: storedImageData,
                format: .png,
                width: configuration.size.width,
                height: configuration.size.height,
                model: model.rawValue,
                revisedPrompt: firstImage.revisedPrompt
            )

            return .success(typedData)

        case .failure(let error):
            return .failure(error)
        }
    }

    // MARK: - Private API Methods

    /// Makes an image generation request to OpenAI API
    private func makeImageGenerationRequest(
        parameters: [String: Any]
    ) async -> Result<ImageGenerationResponse, AIServiceError> {
        // Get API key from credential manager
        let credential: SecureString
        do {
            credential = try await AICredentialManager.shared.retrieve(
                providerID: providerID,
                type: .apiKey
            )
        } catch {
            return .failure(.missingCredentials(
                "Failed to retrieve OpenAI API key: \(error.localizedDescription)"
            ))
        }

        // Validate key format
        guard credential.value.hasPrefix("sk-") || credential.value.hasPrefix("test-") else {
            return .failure(.invalidAPIKey("OpenAI API key must start with 'sk-'"))
        }

        // Build request
        let url = URL(string: "\(OpenAIProvider.defaultBaseURL)/images/generations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(credential.value)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120.0

        // Encode parameters
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            return .failure(.dataConversionError(
                "Failed to encode request parameters: \(error.localizedDescription)"
            ))
        }

        // Make request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // Check HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.networkError("Invalid response type"))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to decode error message
                if let errorResponse = try? JSONDecoder().decode(
                    OpenAIErrorResponse.self,
                    from: data
                ) {
                    return .failure(.providerError(
                        errorResponse.error.message,
                        code: "\(httpResponse.statusCode)"
                    ))
                }
                return .failure(.providerError(
                    "Image generation failed",
                    code: "\(httpResponse.statusCode)"
                ))
            }

            // Decode response
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let imageResponse = try decoder.decode(ImageGenerationResponse.self, from: data)

            return .success(imageResponse)

        } catch let error as AIServiceError {
            return .failure(error)
        } catch {
            return .failure(.networkError(
                "Image generation request failed: \(error.localizedDescription)"
            ))
        }
    }

    // MARK: - Response Processing

    @MainActor
    public func makeResponseModel(
        from data: GeneratedImageData,
        fileReference: TypedDataFileReference?,
        requestID: UUID
    ) -> GeneratedImageRecord {
        // Calculate estimated cost based on configuration
        // We don't have the original config here, so estimate based on image properties
        let estimatedCost = self.estimatedCost(for: ImageGenerationConfig.default)

        return GeneratedImageRecord(
            id: requestID,
            providerId: providerID,
            requestorID: requestorID,
            data: data,
            prompt: "", // Prompt will be set by caller
            fileReference: fileReference,
            estimatedCost: estimatedCost
        )
    }

    // MARK: - UI Components (Phase 7 - Placeholder)

    @MainActor
    public func makeConfigurationView(
        configuration: Binding<ImageGenerationConfig>
    ) -> AnyView {
        // Phase 7: Implement configuration UI
        return AnyView(Text("Image Configuration (Coming in Phase 7)"))
    }

    @MainActor
    public func makeListItemView(model: GeneratedImageRecord) -> AnyView {
        // Phase 7: Implement list item view
        return AnyView(Text("Image List Item (Coming in Phase 7)"))
    }

    @MainActor
    public func makeDetailView(model: GeneratedImageRecord) -> AnyView {
        // Phase 7: Implement detail view
        return AnyView(Text("Image Detail View (Coming in Phase 7)"))
    }
}

// MARK: - API Response Models

@available(macOS 15.0, iOS 17.0, *)
extension OpenAIImageRequestor {

    /// OpenAI image generation response
    struct ImageGenerationResponse: Decodable {
        let created: Int
        let data: [ImageData]

        struct ImageData: Decodable {
            let b64Json: String
            let revisedPrompt: String?

            enum CodingKeys: String, CodingKey {
                case b64Json = "b64_json"
                case revisedPrompt = "revised_prompt"
            }
        }
    }

    /// OpenAI error response
    struct OpenAIErrorResponse: Decodable {
        let error: ErrorDetail

        struct ErrorDetail: Decodable {
            let message: String
            let type: String?
            let code: String?
        }
    }
}
