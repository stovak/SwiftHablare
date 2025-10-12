import Foundation
import SwiftData

/// Core protocol that all AI service provider implementations must conform to.
///
/// This protocol defines the contract for integrating AI services (text generation,
/// audio synthesis, image generation, etc.) with the SwiftHablaré framework.
///
/// ## Topics
/// ### Identity
/// - ``id``
/// - ``displayName``
///
/// ### Capabilities
/// - ``capabilities``
/// - ``supportedDataStructures``
///
/// ### Configuration
/// - ``requiresAPIKey``
/// - ``isConfigured()``
/// - ``validateConfiguration()``
///
/// ### Generation
/// - ``generate(prompt:parameters:context:)``
/// - ``generateProperty(for:property:prompt:context:)``
///
/// ## Example
/// ```swift
/// class OpenAIProvider: AIServiceProvider {
///     let id = "openai"
///     let displayName = "OpenAI"
///     let requiresAPIKey = true
///
///     var capabilities: [AICapability] {
///         [.textGeneration, .imageGeneration, .embeddings]
///     }
///
///     func generate(prompt: String, parameters: [String: Any], context: ModelContext) async throws -> Data {
///         // Implementation
///     }
/// }
/// ```

public protocol AIServiceProvider: Sendable {
    // MARK: - Identity

    /// Unique identifier for this provider.
    ///
    /// This should be a stable, lowercase string identifier (e.g., "openai", "anthropic").
    /// Used for provider registration and lookup.
    var id: String { get }

    /// Human-readable display name for UI purposes.
    ///
    /// This name is shown in configuration panels and provider selection UI.
    var displayName: String { get }

    // MARK: - Capabilities

    /// The types of AI capabilities this provider supports.
    ///
    /// Declares what kind of data this provider can generate (text, audio, images, etc.).
    var capabilities: [AICapability] { get }

    /// SwiftData structures this provider can generate data for.
    ///
    /// Declares which model types and properties this provider can populate.
    /// This enables the framework to validate generation requests before execution.
    var supportedDataStructures: [DataStructureCapability] { get }

    // MARK: - Configuration

    /// Whether this provider requires an API key or credentials.
    var requiresAPIKey: Bool { get }

    /// Checks if the provider is properly configured and ready to use.
    ///
    /// This should verify that all required credentials are available and valid.
    /// - Returns: `true` if the provider can be used, `false` otherwise.
    func isConfigured() -> Bool

    /// Validates the provider's configuration without making API calls.
    ///
    /// Performs local validation of credentials and settings.
    /// - Throws: ``AIServiceError/configurationError(_:)`` if configuration is invalid.
    func validateConfiguration() throws

    // MARK: - Response Type

    /// The type of response content this provider generates.
    ///
    /// Providers should return the primary content type they produce (e.g., `.text` for LLMs,
    /// `.audio` for TTS providers, `.image` for image generators).
    var responseType: ResponseContent.ContentType { get }

    // MARK: - API Requestors (Phase 6)

    /// Returns all available requestors offered by this provider.
    ///
    /// **Phase 6**: API Requestor pattern where one requestor = one file type.
    ///
    /// Each requestor is an independent request interface that generates exactly one
    /// type of data. A provider can offer multiple requestors across different categories.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // OpenAI offers three requestors
    /// func availableRequestors() -> [any AIRequestor] {
    ///     [
    ///         OpenAITextRequestor(provider: self),      // Text generation
    ///         OpenAIImageRequestor(provider: self),     // Image generation
    ///         OpenAIEmbeddingRequestor(provider: self)  // Embeddings
    ///     ]
    /// }
    ///
    /// // ElevenLabs offers one requestor
    /// func availableRequestors() -> [any AIRequestor] {
    ///     [ElevenLabsAudioRequestor(provider: self)]
    /// }
    /// ```
    ///
    /// - Returns: Array of requestor instances (may be empty for Phase 5 providers)
    ///
    /// - Note: During Phase 6 migration, Phase 5 providers will return an empty array
    ///         and continue to use the `generate()` method.
    @available(macOS 15.0, iOS 17.0, *)
    func availableRequestors() -> [any AIRequestor]

    // MARK: - Generation (New API)

    /// Generates data based on a prompt and parameters.
    ///
    /// This is the **new** primary generation method that returns typed content without
    /// requiring ModelContext. This method executes in background contexts and should not
    /// interact with SwiftData directly.
    ///
    /// - Parameters:
    ///   - prompt: The input prompt or instruction for generation.
    ///   - parameters: Provider-specific parameters (model, temperature, etc.).
    /// - Returns: Result containing either the generated content or an error.
    ///
    /// - Note: This method is designed to be called from background actors. It should not
    ///         access ModelContext or other main-actor-bound resources.
    func generate(
        prompt: String,
        parameters: [String: Any]
    ) async -> Result<ResponseContent, AIServiceError>

    // MARK: - Generation (Legacy API - Deprecated)

    /// Generates data based on a prompt and parameters (legacy method).
    ///
    /// - Parameters:
    ///   - prompt: The input prompt or instruction for generation.
    ///   - parameters: Provider-specific parameters (model, temperature, etc.).
    ///   - context: SwiftData model context for persistence.
    /// - Returns: Generated data in a format appropriate for the capability type.
    /// - Throws: ``AIServiceError`` if generation fails.
    ///
    /// - Warning: This method is deprecated. Use the new `generate(prompt:parameters:)` method
    ///           that returns `Result<ResponseContent, AIServiceError>` and use `AIDataCoordinator`
    ///           for SwiftData persistence.
    @available(*, deprecated, message: "Use generate(prompt:parameters:) -> Result<ResponseContent, AIServiceError> instead")
    func generate(
        prompt: String,
        parameters: [String: Any],
        context: ModelContext
    ) async throws -> Data

    /// Generates data for a specific property of a SwiftData model (legacy method).
    ///
    /// This method enables property-level generation with automatic persistence.
    ///
    /// - Parameters:
    ///   - model: The SwiftData model instance to populate.
    ///   - property: KeyPath to the property to generate.
    ///   - prompt: The input prompt (optional, may use schema's template).
    ///   - context: Additional context for prompt template substitution.
    /// - Returns: The generated value, typed appropriately for the property.
    /// - Throws: ``AIServiceError`` if generation fails.
    ///
    /// - Warning: This method is deprecated. Use `AIRequestManager` and `AIDataCoordinator` instead.
    @available(*, deprecated, message: "Use AIRequestManager.submitAndExecute() and AIDataCoordinator.mergeResponse() instead")
    func generateProperty<T: PersistentModel>(
        for model: T,
        property: PartialKeyPath<T>,
        prompt: String?,
        context: [String: Any]
    ) async throws -> Any
}

// MARK: - Default Implementations

public extension AIServiceProvider {
    /// Default implementation validates that requiresAPIKey implies credentials exist.
    func validateConfiguration() throws {
        if requiresAPIKey && !isConfigured() {
            throw AIServiceError.configurationError("API key required but not configured for provider '\(id)'")
        }
    }

    /// Default implementation returns an empty array.
    ///
    /// **Phase 5 providers** (not yet migrated) will use this default.
    /// **Phase 6 providers** should override this to return their requestors.
    ///
    /// - Returns: Empty array (Phase 5 compatibility)
    @available(macOS 15.0, iOS 17.0, *)
    func availableRequestors() -> [any AIRequestor] {
        return []
    }

    /// Default implementation of the new generate method that calls the legacy method.
    ///
    /// Providers should override this with a proper implementation that doesn't use ModelContext.
    /// This default implementation is provided for backward compatibility during migration.
    func generate(
        prompt: String,
        parameters: [String: Any]
    ) async -> Result<ResponseContent, AIServiceError> {
        // For backward compatibility, create a temporary ModelContext
        // This is not ideal and should be replaced by providers
        return .failure(.unsupportedOperation(
            "Provider '\(id)' has not implemented the new generate(prompt:parameters:) method. " +
            "Please update the provider to support the new concurrency model."
        ))
    }

    /// Default implementation of responseType based on capabilities.
    ///
    /// Providers should override this to specify their actual response type.
    var responseType: ResponseContent.ContentType {
        // Infer from capabilities
        if capabilities.contains(.textGeneration) {
            return .text
        } else if capabilities.contains(.audioGeneration) {
            return .audio
        } else if capabilities.contains(.imageGeneration) {
            return .image
        } else {
            return .data
        }
    }
}
