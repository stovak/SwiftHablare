//
//  OpenAIEmbeddingRequestor.swift
//  SwiftHablare
//
//  Phase 6E: OpenAI embedding generation requestor
//

import Foundation
import SwiftUI

/// OpenAI embedding generation requestor.
///
/// Implements the AIRequestor protocol for OpenAI's embedding API.
/// Generates vector embeddings from text using various OpenAI embedding models.
///
/// ## Usage
/// ```swift
/// let requestor = OpenAIEmbeddingRequestor(
///     provider: openAIProvider,
///     model: .textEmbedding3Small
/// )
///
/// let config = EmbeddingConfig.default
///
/// let result = await requestor.request(
///     prompt: "The quick brown fox jumps over the lazy dog",
///     configuration: config,
///     storageArea: storageArea
/// )
/// ```
@available(macOS 15.0, iOS 17.0, *)
public final class OpenAIEmbeddingRequestor: AIRequestor, @unchecked Sendable {

    // MARK: - Associated Types

    public typealias TypedData = GeneratedEmbeddingData
    public typealias ResponseModel = GeneratedEmbeddingRecord
    public typealias Configuration = EmbeddingConfig

    // MARK: - Properties

    /// Unique identifier for this requestor
    public let requestorID: String

    /// Human-readable display name
    public let displayName: String

    /// The provider that offers this requestor
    public let providerID: String = "openai"

    /// Category of content this requestor generates
    public let category: ProviderCategory = .embedding

    /// Output file type (binary for efficient vector storage)
    public let outputFileType: OutputFileType = .binary(
        category: .embedding,
        fileExtension: "bin",
        storeAsFileThreshold: 100_000
    )

    /// Optional schema for validation
    public let schema: TypedDataSchema? = nil

    /// Maximum expected response size (1MB for embeddings)
    ///
    /// text-embedding-3-small (1536 dims): ~6KB
    /// text-embedding-3-large (3072 dims): ~12KB
    public let estimatedMaxSize: Int64? = 1_000_000

    // Private properties
    private let provider: OpenAIProvider
    private let model: EmbeddingConfig.Model

    // MARK: - Initialization

    /// Creates an OpenAI embedding requestor
    ///
    /// - Parameters:
    ///   - provider: OpenAI provider instance
    ///   - model: Embedding model to use (default: text-embedding-3-small)
    public init(provider: OpenAIProvider, model: EmbeddingConfig.Model = .textEmbedding3Small) {
        self.provider = provider
        self.model = model
        self.requestorID = "openai.embedding.\(model.rawValue)"
        self.displayName = "OpenAI \(model.displayName)"
    }

    // MARK: - Configuration

    public func defaultConfiguration() -> EmbeddingConfig {
        return EmbeddingConfig(model: model)
    }

    public func validateConfiguration(_ config: EmbeddingConfig) throws {
        // Validate model matches
        guard config.model == model else {
            throw AIServiceError.configurationError(
                "Configuration model (\(config.model.rawValue)) does not match requestor model (\(model.rawValue))"
            )
        }

        // Validate dimensions if specified
        if let dimensions = config.dimensions {
            let maxDims = model.defaultDimensions

            // Ada 002 does not support custom dimensions
            if model == .textEmbeddingAda002 {
                throw AIServiceError.configurationError(
                    "Model \(model.rawValue) does not support custom dimensions"
                )
            }

            // Validate dimension range for embedding-3 models
            guard dimensions > 0 && dimensions <= maxDims else {
                throw AIServiceError.configurationError(
                    "Dimensions must be between 1 and \(maxDims) for model \(model.rawValue)"
                )
            }
        }
    }

    // MARK: - Request Execution

    public func request(
        prompt: String,
        configuration: Configuration,
        storageArea: StorageAreaReference
    ) async -> Result<GeneratedEmbeddingData, AIServiceError> {
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
            "model": configuration.model.rawValue,
            "input": prompt,
            "encoding_format": configuration.encodingFormat.rawValue
        ]

        // Add optional dimensions
        if let dimensions = configuration.dimensions {
            parameters["dimensions"] = dimensions
        }

        // Add optional user
        if let user = configuration.user {
            parameters["user"] = user
        }

        // Make API call through provider's HTTP client
        let result = await makeEmbeddingRequest(parameters: parameters)

        switch result {
        case .success(let response):
            // Extract first embedding from response
            guard let firstEmbedding = response.data.first else {
                return .failure(.unexpectedResponseFormat("No embeddings in response"))
            }

            // Determine actual dimensions
            let actualDimensions = configuration.dimensions ?? model.defaultDimensions

            // Determine if we should store as file based on size threshold
            let vectorSize = Int64(actualDimensions * MemoryLayout<Float>.size)
            let shouldStoreAsFile = outputFileType.shouldStoreAsFile(estimatedSize: vectorSize)

            // Storage decision: write to file if data exceeds threshold
            let storedEmbedding: [Float]?
            if shouldStoreAsFile {
                // Write to storage area and return nil embedding
                do {
                    // Create storage directory if needed
                    try storageArea.createDirectoryIfNeeded()

                    // Convert embedding to binary data
                    let embeddingData = firstEmbedding.embedding.withUnsafeBufferPointer { buffer in
                        Data(buffer: buffer)
                    }

                    // Write embedding to file
                    let fileURL = storageArea.defaultDataFileURL(extension: "bin")
                    try embeddingData.write(to: fileURL)

                    // Nil out embedding since it's now file-stored
                    storedEmbedding = nil
                } catch {
                    return .failure(.persistenceError(
                        "Failed to write embedding to storage: \(error.localizedDescription)"
                    ))
                }
            } else {
                // Store in-memory for small embeddings
                storedEmbedding = firstEmbedding.embedding
            }

            // Create typed data
            let typedData = GeneratedEmbeddingData(
                embedding: storedEmbedding,
                dimensions: actualDimensions,
                model: model.rawValue,
                inputText: prompt,
                tokenCount: response.usage.totalTokens,
                index: firstEmbedding.index
            )

            return .success(typedData)

        case .failure(let error):
            return .failure(error)
        }
    }

    // MARK: - Private API Methods

    /// Makes an embedding request to OpenAI API
    private func makeEmbeddingRequest(
        parameters: [String: Any]
    ) async -> Result<EmbeddingResponse, AIServiceError> {
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
        let url = URL(string: "\(OpenAIProvider.defaultBaseURL)/embeddings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(credential.value)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60.0

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
                    "Embedding generation failed",
                    code: "\(httpResponse.statusCode)"
                ))
            }

            // Decode response
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let embeddingResponse = try decoder.decode(EmbeddingResponse.self, from: data)

            return .success(embeddingResponse)

        } catch let error as AIServiceError {
            return .failure(error)
        } catch {
            return .failure(.networkError(
                "Embedding request failed: \(error.localizedDescription)"
            ))
        }
    }

    // MARK: - Response Processing

    @MainActor
    public func makeResponseModel(
        from data: GeneratedEmbeddingData,
        fileReference: TypedDataFileReference?,
        requestID: UUID
    ) -> GeneratedEmbeddingRecord {
        // Calculate estimated cost
        let estimatedCost: Double
        if let tokenCount = data.tokenCount {
            // Cost = (tokens / 1M) * cost_per_1M
            estimatedCost = (Double(tokenCount) / 1_000_000.0) * model.costPer1MTokens
        } else {
            // Rough estimate: ~1 token per 4 characters
            let estimatedTokens = (data.inputText?.count ?? 0) / 4
            estimatedCost = (Double(estimatedTokens) / 1_000_000.0) * model.costPer1MTokens
        }

        return GeneratedEmbeddingRecord(
            id: requestID,
            providerId: providerID,
            requestorID: requestorID,
            data: data,
            prompt: data.inputText ?? "",
            fileReference: fileReference,
            estimatedCost: estimatedCost
        )
    }

    // MARK: - UI Components (Phase 7 - Placeholder)

    @MainActor
    public func makeConfigurationView(
        configuration: Binding<EmbeddingConfig>
    ) -> AnyView {
        // Phase 7: Implement configuration UI
        return AnyView(Text("Embedding Configuration (Coming in Phase 7)"))
    }

    @MainActor
    public func makeListItemView(model: GeneratedEmbeddingRecord) -> AnyView {
        // Phase 7: Implement list item view
        return AnyView(Text("Embedding List Item (Coming in Phase 7)"))
    }

    @MainActor
    public func makeDetailView(model: GeneratedEmbeddingRecord) -> AnyView {
        // Phase 7: Implement detail view
        return AnyView(Text("Embedding Detail View (Coming in Phase 7)"))
    }
}

// MARK: - API Response Models

@available(macOS 15.0, iOS 17.0, *)
extension OpenAIEmbeddingRequestor {

    /// OpenAI embedding response
    struct EmbeddingResponse: Decodable {
        let object: String
        let data: [EmbeddingData]
        let model: String
        let usage: Usage

        struct EmbeddingData: Decodable {
            let object: String
            let embedding: [Float]
            let index: Int
        }

        struct Usage: Decodable {
            let promptTokens: Int
            let totalTokens: Int

            enum CodingKeys: String, CodingKey {
                case promptTokens = "prompt_tokens"
                case totalTokens = "total_tokens"
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
