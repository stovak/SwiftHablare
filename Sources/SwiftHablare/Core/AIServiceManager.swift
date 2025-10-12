import Foundation
import SwiftData

/// Central registry and management system for AI service providers.
///
/// `AIServiceManager` is the primary interface for registering, querying, and managing
/// AI service providers in the SwiftHablaré framework. It provides thread-safe operations
/// for provider lifecycle management and capability-based querying.
///
/// ## Features
/// - Thread-safe provider registration and lookup
/// - Capability-based provider querying
/// - Multiple instance support (same provider type with different configurations)
/// - Provider lifecycle management (register, update, unregister)
/// - Type-safe provider retrieval
///
/// ## Example
/// ```swift
/// let manager = AIServiceManager.shared
///
/// // Register a provider
/// try await manager.register(provider: myProvider)
///
/// // Query providers by capability
/// let textProviders = manager.providers(withCapability: .textGeneration)
///
/// // Get specific provider
/// if let openai = manager.provider(withID: "openai") {
///     let result = try await openai.generate(prompt: "Hello", parameters: [:], context: context)
/// }
/// ```

public actor AIServiceManager {

    // MARK: - Singleton

    /// Shared singleton instance of the service manager.
    public static let shared = AIServiceManager()

    // MARK: - Private Properties

    /// Internal storage for registered providers, keyed by provider ID.
    private var providers: [String: any AIServiceProvider] = [:]

    /// Secondary index for providers by capability for fast querying.
    private var capabilityIndex: [AICapability: Set<String>] = [:]

    /// Index for providers supporting specific model types.
    private var modelTypeIndex: [String: Set<String>] = [:]

    // MARK: - Initialization

    /// Private initializer to enforce singleton pattern.
    /// Creates a new service manager instance.
    ///
    /// While the framework primarily exposes the shared singleton via ``shared``,
    /// tests can initialize isolated instances to avoid cross-test interference
    /// when running in parallel.
    internal init() {}

    // MARK: - Registration

    /// Registers a provider with the manager.
    ///
    /// If a provider with the same ID is already registered, it will be replaced.
    ///
    /// - Parameter provider: The provider to register.
    /// - Throws: ``AIServiceError/configurationError(_:)`` if provider validation fails.
    public func register(provider: any AIServiceProvider) throws {
        // Validate provider configuration
        try provider.validateConfiguration()

        // Remove existing provider if present
        if providers[provider.id] != nil {
            unregister(providerID: provider.id)
        }

        // Store provider
        providers[provider.id] = provider

        // Update capability index
        for capability in provider.capabilities {
            capabilityIndex[capability, default: []].insert(provider.id)
        }

        // Update model type index
        for structure in provider.supportedDataStructures {
            if let modelType = structure.modelType {
                modelTypeIndex[modelType, default: []].insert(provider.id)
            }
        }
    }

    /// Registers multiple providers at once.
    ///
    /// This is more efficient than registering providers individually when adding many at once.
    ///
    /// - Parameter providers: Array of providers to register.
    /// - Throws: ``AIServiceError`` if any provider validation fails. Already registered providers
    ///           from the batch will remain registered even if later ones fail.
    public func registerAll(providers: [any AIServiceProvider]) throws {
        for provider in providers {
            try register(provider: provider)
        }
    }

    /// Unregisters a provider from the manager.
    ///
    /// - Parameter providerID: The ID of the provider to unregister.
    public func unregister(providerID: String) {
        guard let provider = providers.removeValue(forKey: providerID) else {
            return
        }

        // Remove from capability index
        for capability in provider.capabilities {
            capabilityIndex[capability]?.remove(providerID)
            if capabilityIndex[capability]?.isEmpty == true {
                capabilityIndex.removeValue(forKey: capability)
            }
        }

        // Remove from model type index
        for structure in provider.supportedDataStructures {
            if let modelType = structure.modelType {
                modelTypeIndex[modelType]?.remove(providerID)
                if modelTypeIndex[modelType]?.isEmpty == true {
                    modelTypeIndex.removeValue(forKey: modelType)
                }
            }
        }
    }

    /// Unregisters all providers from the manager.
    ///
    /// Use this method for cleanup or testing purposes.
    public func unregisterAll() {
        providers.removeAll()
        capabilityIndex.removeAll()
        modelTypeIndex.removeAll()
    }

    // MARK: - Querying

    /// Retrieves a provider by its unique identifier.
    ///
    /// - Parameter id: The provider's unique identifier.
    /// - Returns: The provider if found, or `nil` if no provider with that ID is registered.
    public func provider(withID id: String) -> (any AIServiceProvider)? {
        return providers[id]
    }

    /// Retrieves all registered providers.
    ///
    /// - Returns: Array of all registered providers in no particular order.
    public func allProviders() -> [any AIServiceProvider] {
        return Array(providers.values)
    }

    /// Retrieves all providers that support a specific capability.
    ///
    /// - Parameter capability: The capability to query for.
    /// - Returns: Array of providers supporting the capability.
    public func providers(withCapability capability: AICapability) -> [any AIServiceProvider] {
        guard let providerIDs = capabilityIndex[capability] else {
            return []
        }

        return providerIDs.compactMap { providers[$0] }
    }

    /// Retrieves all providers that support multiple capabilities.
    ///
    /// - Parameter capabilities: Array of capabilities that providers must all support.
    /// - Returns: Array of providers supporting all specified capabilities.
    public func providers(withCapabilities capabilities: [AICapability]) -> [any AIServiceProvider] {
        guard !capabilities.isEmpty else {
            return allProviders()
        }

        // Start with providers supporting first capability
        guard var candidateIDs = capabilityIndex[capabilities[0]] else {
            return []
        }

        // Intersect with providers supporting each additional capability
        for capability in capabilities.dropFirst() {
            guard let providerIDs = capabilityIndex[capability] else {
                return []
            }
            candidateIDs.formIntersection(providerIDs)

            if candidateIDs.isEmpty {
                return []
            }
        }

        return candidateIDs.compactMap { providers[$0] }
    }

    /// Retrieves all providers that can generate data for a specific model type.
    ///
    /// - Parameter modelType: The SwiftData model type name (e.g., "Article", "Product").
    /// - Returns: Array of providers supporting the model type.
    public func providers(forModelType modelType: String) -> [any AIServiceProvider] {
        guard let providerIDs = modelTypeIndex[modelType] else {
            return []
        }

        return providerIDs.compactMap { providers[$0] }
    }

    /// Retrieves all providers that can generate data for a specific model.
    ///
    /// - Parameter modelType: The SwiftData model type (e.g., `Article.self`).
    /// - Returns: Array of providers supporting the model type.
    public func providers<T: PersistentModel>(forModel modelType: T.Type) -> [any AIServiceProvider] {
        let modelTypeName = String(describing: modelType)
        return providers(forModelType: modelTypeName)
    }

    /// Checks if any provider supports a specific capability.
    ///
    /// - Parameter capability: The capability to check for.
    /// - Returns: `true` if at least one provider supports the capability, `false` otherwise.
    public func hasProvider(withCapability capability: AICapability) -> Bool {
        return capabilityIndex[capability]?.isEmpty == false
    }

    /// Checks if a provider is registered with the manager.
    ///
    /// - Parameter id: The provider ID to check.
    /// - Returns: `true` if the provider is registered, `false` otherwise.
    public func isRegistered(providerID id: String) -> Bool {
        return providers[id] != nil
    }

    // MARK: - Statistics

    /// Returns the total number of registered providers.
    public func providerCount() -> Int {
        return providers.count
    }

    /// Returns statistics about registered providers.
    ///
    /// - Returns: A dictionary with capability names as keys and provider counts as values.
    public func statistics() -> [String: Int] {
        var stats: [String: Int] = [:]

        stats["total_providers"] = providers.count

        for (capability, providerIDs) in capabilityIndex {
            stats["capability_\(capability)"] = providerIDs.count
        }

        return stats
    }
}
