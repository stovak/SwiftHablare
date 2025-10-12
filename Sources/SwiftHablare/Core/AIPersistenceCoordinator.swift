import Foundation
import SwiftData

/// Type-erased wrapper for values that are conceptually Sendable.
///
/// This wrapper uses `@unchecked Sendable` because AI providers return
/// values that are actually Sendable (String, Data, etc.) but typed as `Any`.
private struct UncheckedSendableBox: @unchecked Sendable {
    let value: Any
    init(_ value: Any) {
        self.value = value
    }
}

/// Coordinates automatic persistence of AI-generated content to SwiftData.
///
/// This component orchestrates the complete persistence workflow:
/// 1. Generate content via provider
/// 2. Validate generated content
/// 3. Transform/convert to target type
/// 4. Bind to model properties
/// 5. Save to SwiftData
/// 6. Cache response
///
/// ## Example
/// ```swift
/// let coordinator = AIPersistenceCoordinator(
///     binder: AIPropertyBinder(),
///     validator: AIContentValidator(),
///     cache: AIResponseCache()
/// )
///
/// // Generate and persist in one operation
/// try await coordinator.generateAndPersist(
///     provider: openaiProvider,
///     prompt: "Write an article about AI",
///     model: article,
///     property: \Article.content,
///     context: modelContext
/// )
/// ```

public struct AIPersistenceCoordinator: Sendable {

    // MARK: - Properties

    /// Property binder for type conversion.
    private let binder: AIPropertyBinder

    /// Content validator.
    private let validator: AIContentValidator

    /// Response cache.
    private let cache: AIResponseCache

    // MARK: - Initialization

    /// Creates a new persistence coordinator.
    ///
    /// - Parameters:
    ///   - binder: Property binder (default: new instance)
    ///   - validator: Content validator (default: new instance)
    ///   - cache: Response cache (default: new instance)
    public init(
        binder: AIPropertyBinder = AIPropertyBinder(),
        validator: AIContentValidator = AIContentValidator(),
        cache: AIResponseCache = AIResponseCache()
    ) {
        self.binder = binder
        self.validator = validator
        self.cache = cache
    }

    // MARK: - Generation and Persistence

    /// Generates content and persists it to a model property.
    ///
    /// This method handles the complete workflow:
    /// 1. Check cache for existing response
    /// 2. Generate content if not cached
    /// 3. Validate generated content
    /// 4. Apply custom transformations
    /// 5. Bind to model property
    /// 6. Save to SwiftData
    /// 7. Cache response
    ///
    /// - Parameters:
    ///   - provider: The AI service provider
    ///   - prompt: The generation prompt
    ///   - model: The target model instance
    ///   - property: The property keypath to populate
    ///   - context: The SwiftData model context
    ///   - parameters: Additional provider parameters
    ///   - constraints: Validation constraints
    ///   - transform: Optional transformation function
    ///   - useCache: Whether to use caching (default: true)
    /// - Throws: ``AIServiceError`` if any step fails
    public func generateAndPersist<T: PersistentModel, V>(
        provider: any AIServiceProvider,
        prompt: String,
        model: T,
        property: ReferenceWritableKeyPath<T, V>,
        context: ModelContext,
        parameters: [String: String] = [:],
        constraints: [String: String] = [:],
        transform: (@Sendable (Any) async throws -> Any)? = nil,
        useCache: Bool = true
    ) async throws {
        // 1. Check cache
        if useCache {
            if let cachedValue = await cache.get(
                providerId: provider.id,
                prompt: prompt,
                parameters: parameters
            ) {
                try binder.bind(
                    value: cachedValue.value,
                    to: model,
                    property: property,
                    context: context
                )
                try context.save()
                return
            }
        }

        // 2. Generate content
        // Convert parameters to [String: Any] for provider compatibility
        let anyParameters: [String: Any] = parameters.reduce(into: [:]) { result, pair in
            result[pair.key] = pair.value
        }
        let generatedValue = try await provider.generate(
            prompt: prompt,
            parameters: anyParameters,
            context: context
        )

        // 3. Apply transformation if provided
        let transformedValue: Any
        if let transform = transform {
            transformedValue = try await transform(generatedValue)
        } else {
            transformedValue = generatedValue
        }

        // Box the value for safe sending across actor boundaries
        let boxedValue = UncheckedSendableBox(transformedValue)

        // 4. Validate
        if !constraints.isEmpty {
            try await validator.validate(value: boxedValue.value, constraints: constraints)
        }

        // 5. Bind to property
        try binder.bind(
            value: boxedValue.value,
            to: model,
            property: property,
            context: context
        )

        // 6. Save to SwiftData
        try context.save()

        // 7. Cache response
        if useCache {
            await cache.set(
                boxedValue.value,
                providerId: provider.id,
                prompt: prompt,
                parameters: parameters
            )
        }
    }

    /// Generates and persists multiple properties atomically.
    ///
    /// All properties are generated and validated before any persistence occurs.
    /// If any step fails, no changes are persisted.
    ///
    /// - Parameters:
    ///   - provider: The AI service provider
    ///   - prompts: Dictionary mapping property names to prompts
    ///   - model: The target model instance
    ///   - context: The SwiftData model context
    ///   - useCache: Whether to use caching (default: true)
    /// - Throws: ``AIServiceError`` if any step fails
    public func generateAndPersistMultiple<T: PersistentModel>(
        provider: any AIServiceProvider,
        prompts: [String: String],
        model: T,
        context: ModelContext,
        useCache: Bool = true
    ) async throws {
        // This is a placeholder for batch generation
        // Full implementation would require KeyPath lookup by string name
        throw AIServiceError.unsupportedOperation("Batch property generation not yet implemented")
    }

    /// Generates content based on a model's AIGenerationSchema.
    ///
    /// This method uses the declarative schema defined in the model's
    /// `aiGenerationSchema` property to determine what to generate and how.
    ///
    /// - Parameters:
    ///   - model: The model conforming to AIGeneratable
    ///   - propertyName: The property name to generate
    ///   - context: The SwiftData model context
    ///   - provider: Optional specific provider to use
    ///   - contextValues: Additional context for prompt templates
    /// - Throws: ``AIServiceError`` if generation fails
    public func generateUsingSchema<T: PersistentModel & AIGeneratable>(
        model: T,
        propertyName: String,
        context: ModelContext,
        provider: (any AIServiceProvider)? = nil,
        contextValues: [String: String] = [:]
    ) async throws {
        // This is a placeholder for schema-based generation
        // Full implementation would parse the AIGenerationSchema
        throw AIServiceError.unsupportedOperation("Schema-based generation not yet implemented")
    }

    // MARK: - Cache Management

    /// Clears the response cache.
    public func clearCache() async {
        await cache.clear()
    }

    /// Invalidates cache entries for a specific provider.
    ///
    /// - Parameter providerId: The provider ID
    public func invalidateCache(forProvider providerId: String) async {
        await cache.invalidate(providerId: providerId)
    }

    /// Returns cache statistics.
    public func cacheStatistics() async -> [String: Int] {
        return await cache.statistics()
    }

    // MARK: - Validation

    /// Registers a custom validation rule.
    ///
    /// - Parameter rule: The validation rule
    public func registerValidationRule(_ rule: AIContentValidator.ValidationRule) async {
        await validator.registerRule(rule)
    }
}
