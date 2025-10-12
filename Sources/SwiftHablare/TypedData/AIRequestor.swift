//
//  AIRequestor.swift
//  SwiftHablare
//
//  Phase 6A: Core protocol for typed data requests
//

import Foundation
import SwiftUI

/// Protocol for requesting typed data from AI providers.
///
/// An API Requestor is a request-based interface to a local or remote AI system provider.
/// Each requestor generates exactly one file type and provides a standardized interface
/// for requesting typed data from AI-generated sources.
///
/// ## Design Principles
///
/// - **Single Responsibility**: One requestor = one file type
/// - **Type Safety**: Associated types ensure compile-time type checking
/// - **Provider Independence**: Multiple providers can offer the same requestor type
/// - **Configuration Flexibility**: Each requestor defines its own configuration
///
/// ## Example
///
/// ```swift
/// public class OpenAITextRequestor: AIRequestor {
///     public typealias TypedData = GeneratedText
///     public typealias ResponseModel = GeneratedTextRecord
///     public typealias Configuration = TextGenerationConfig
///
///     public let requestorID = "openai-text"
///     public let displayName = "OpenAI Text Generation"
///     public let category: ProviderCategory = .text
///
///     public func request(
///         prompt: String,
///         configuration: Configuration,
///         storageArea: StorageAreaReference
///     ) async -> Result<TypedData, AIServiceError> {
///         // Implementation...
///     }
/// }
/// ```
@available(macOS 15.0, iOS 17.0, *)
public protocol AIRequestor: Sendable {

    // MARK: - Associated Types

    /// The typed data structure returned by this requestor.
    ///
    /// Must conform to `Codable` for serialization and `Sendable` for thread safety.
    associatedtype TypedData: Codable & Sendable

    /// The SwiftData model used to persist responses.
    ///
    /// Should extend `AIGeneratedContent` for consistent metadata.
    associatedtype ResponseModel: AnyObject

    /// The configuration structure for request parameters.
    ///
    /// Must conform to `Codable` for persistence and `Sendable` for thread safety.
    associatedtype Configuration: Codable & Sendable

    // MARK: - Identity

    /// Unique identifier for this requestor.
    ///
    /// Format: `"{provider}-{type}"` (e.g., "openai-text", "elevenlabs-audio")
    var requestorID: String { get }

    /// Human-readable display name.
    ///
    /// Example: "OpenAI Text Generation", "ElevenLabs Text-to-Speech"
    var displayName: String { get }

    /// The provider that offers this requestor.
    ///
    /// Should match the provider's ID (e.g., "openai", "anthropic", "elevenlabs")
    var providerID: String { get }

    /// The category of data this requestor generates.
    ///
    /// Used for filtering and UI organization.
    var category: ProviderCategory { get }

    // MARK: - Capabilities

    /// The output file type produced by this requestor.
    ///
    /// Defines MIME type, file extension, and storage preferences.
    var outputFileType: OutputFileType { get }

    /// Optional JSON schema for response validation.
    ///
    /// Future: Used for structured output validation.
    var schema: TypedDataSchema? { get }

    /// Estimated maximum size of generated data in bytes.
    ///
    /// Returns `nil` if size is unknown until generation.
    /// Used to determine if file storage is needed.
    var estimatedMaxSize: Int64? { get }

    // MARK: - Configuration

    /// Returns the default configuration for this requestor.
    ///
    /// Used when no custom configuration is provided.
    func defaultConfiguration() -> Configuration

    /// Validates a configuration before request execution.
    ///
    /// - Parameter config: The configuration to validate
    /// - Throws: `TypedDataError` if validation fails
    func validateConfiguration(_ config: Configuration) throws

    // MARK: - Request Execution

    /// Executes a request with the given prompt and configuration.
    ///
    /// This method should:
    /// 1. Validate the configuration
    /// 2. Call the underlying provider's API
    /// 3. Process the response into `TypedData`
    /// 4. Write large data to file storage if needed
    /// 5. Return typed data (with file reference if applicable)
    ///
    /// ## Thread Safety
    ///
    /// - Executed on background thread
    /// - Large data written to file on background thread
    /// - Only small file references passed to main thread
    ///
    /// - Parameters:
    ///   - prompt: The user prompt or input text
    ///   - configuration: Type-specific configuration
    ///   - storageArea: Request-specific storage area for large files
    /// - Returns: Result with typed data or error
    func request(
        prompt: String,
        configuration: Configuration,
        storageArea: StorageAreaReference
    ) async -> Result<TypedData, AIServiceError>

    // MARK: - Response Processing

    /// Creates a SwiftData model from typed data.
    ///
    /// Called on the main thread after successful request completion.
    ///
    /// - Parameters:
    ///   - data: The typed data returned from `request()`
    ///   - fileReference: Optional file reference for large data
    ///   - requestID: Unique request identifier for tracking
    /// - Returns: Configured SwiftData model ready for persistence
    @MainActor
    func makeResponseModel(
        from data: TypedData,
        fileReference: TypedDataFileReference?,
        requestID: UUID
    ) -> ResponseModel

    // MARK: - UI Components (Phase 7)

    /// Creates a configuration view for request parameters.
    ///
    /// **Phase 7**: Not implemented in Phase 6A.
    ///
    /// - Parameter configuration: Binding to configuration state
    /// - Returns: SwiftUI view for configuration
    @MainActor
    func makeConfigurationView(configuration: Binding<Configuration>) -> AnyView

    /// Creates a list item view for displaying the response.
    ///
    /// **Phase 7**: Not implemented in Phase 6A.
    ///
    /// Used in filterable list views.
    ///
    /// - Parameter model: The response model to display
    /// - Returns: SwiftUI view for list item
    @MainActor
    func makeListItemView(model: ResponseModel) -> AnyView

    /// Creates a detail view for displaying the full response.
    ///
    /// **Phase 7**: Not implemented in Phase 6A.
    ///
    /// Used for detailed response viewing.
    ///
    /// - Parameter model: The response model to display
    /// - Returns: SwiftUI view for detail display
    @MainActor
    func makeDetailView(model: ResponseModel) -> AnyView
}

// MARK: - TypedDataSchema

/// Placeholder for JSON schema validation (future).
///
/// **Phase 6A**: Not implemented yet.
/// **Future**: Will support JSON Schema, Pydantic-style models, or Swift Codable validation.
@available(macOS 15.0, iOS 17.0, *)
public struct TypedDataSchema: Sendable {
    // Future: JSON Schema validation
}
