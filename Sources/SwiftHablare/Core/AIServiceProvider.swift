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
@available(macOS 15.0, iOS 17.0, *)
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

    // MARK: - Generation

    /// Generates data based on a prompt and parameters.
    ///
    /// This is the primary generation method for creating AI-generated content.
    ///
    /// - Parameters:
    ///   - prompt: The input prompt or instruction for generation.
    ///   - parameters: Provider-specific parameters (model, temperature, etc.).
    ///   - context: SwiftData model context for persistence.
    /// - Returns: Generated data in a format appropriate for the capability type.
    /// - Throws: ``AIServiceError`` if generation fails.
    func generate(
        prompt: String,
        parameters: [String: Any],
        context: ModelContext
    ) async throws -> Data

    /// Generates data for a specific property of a SwiftData model.
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
    func generateProperty<T: PersistentModel>(
        for model: T,
        property: PartialKeyPath<T>,
        prompt: String?,
        context: [String: Any]
    ) async throws -> Any
}

// MARK: - Default Implementations

@available(macOS 15.0, iOS 17.0, *)
public extension AIServiceProvider {
    /// Default implementation validates that requiresAPIKey implies credentials exist.
    func validateConfiguration() throws {
        if requiresAPIKey && !isConfigured() {
            throw AIServiceError.configurationError("API key required but not configured for provider '\(id)'")
        }
    }
}
