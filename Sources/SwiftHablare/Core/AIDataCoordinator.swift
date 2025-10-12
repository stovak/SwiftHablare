import Foundation
import SwiftData

/// Main actor coordinator for merging AI-generated responses into SwiftData.
///
/// `AIDataCoordinator` is the **only** component that should interact with SwiftData's
/// ModelContext for AI-generated content. It operates exclusively on the main actor,
/// ensuring all SwiftData operations are thread-safe and race-condition-free.
///
/// This coordinator:
/// - Receives immutable `AIResponseData` from background actors
/// - Validates and transforms response content
/// - Updates SwiftData models on the main actor
/// - Provides callbacks for UI updates
///
/// ## Example
/// ```swift
/// @MainActor
/// let coordinator = AIDataCoordinator()
///
/// // After receiving response from AIRequestManager
/// try coordinator.mergeResponse(
///     responseData,
///     into: article,
///     property: \.content,
///     context: modelContext
/// )
/// ```
@MainActor
public final class AIDataCoordinator {

    // MARK: - Properties

    /// Content validator for response validation.
    private let validator: AIContentValidator

    /// Property binder for type conversion.
    private let binder: AIPropertyBinder

    /// Callback invoked before merging a response.
    public var willMergeResponse: ((AIResponseData) -> Void)?

    /// Callback invoked after successfully merging a response.
    public var didMergeResponse: ((AIResponseData) -> Void)?

    /// Callback invoked when merge fails.
    public var didFailMerge: ((AIResponseData, Error) -> Void)?

    // MARK: - Initialization

    /// Creates a new data coordinator.
    ///
    /// - Parameters:
    ///   - validator: Content validator (default: new instance)
    ///   - binder: Property binder (default: new instance)
    public init(
        validator: AIContentValidator = AIContentValidator(),
        binder: AIPropertyBinder = AIPropertyBinder()
    ) {
        self.validator = validator
        self.binder = binder
    }

    // MARK: - Response Merging

    /// Merges a response into a model property.
    ///
    /// This method:
    /// 1. Validates the response succeeded
    /// 2. Converts content to the property's expected type
    /// 3. Validates content against constraints
    /// 4. Updates the model property
    /// 5. Saves the context
    ///
    /// - Parameters:
    ///   - response: The response data to merge
    ///   - model: The target model instance
    ///   - property: KeyPath to the property to update
    ///   - context: SwiftData model context
    ///   - constraints: Optional validation constraints
    ///   - transform: Optional transformation function
    /// - Throws: `AIServiceError` if merge fails
    public func mergeResponse<T: PersistentModel, V>(
        _ response: AIResponseData,
        into model: T,
        property: ReferenceWritableKeyPath<T, V>,
        context: ModelContext,
        constraints: [String: String] = [:],
        transform: ((ResponseContent) throws -> Any)? = nil
    ) throws {
        willMergeResponse?(response)

        do {
            // Check if response was successful
            guard case .success(let content) = response.result else {
                if let error = response.error {
                    throw error
                } else {
                    throw AIServiceError.unexpectedResponseFormat("Response has no content or error")
                }
            }

            // Apply transformation if provided
            let value: Any
            if let transform = transform {
                value = try transform(content)
            } else {
                value = try convertContentToValue(content, for: property)
            }

            // Validate if constraints provided
            if !constraints.isEmpty {
                try validator.validate(value: value, constraints: constraints)
            }

            // Bind to model property
            try binder.bind(
                value: value,
                to: model,
                property: property,
                context: context
            )

            // Save context
            try context.save()

            didMergeResponse?(response)

        } catch {
            didFailMerge?(response, error)
            throw error
        }
    }

    /// Merges multiple responses into different properties of a model.
    ///
    /// All merges are performed atomically - if any fails, no changes are saved.
    ///
    /// - Parameters:
    ///   - responses: Array of (response, property) tuples
    ///   - model: The target model instance
    ///   - context: SwiftData model context
    /// - Throws: `AIServiceError` if any merge fails
    public func mergeMultipleResponses<T: PersistentModel>(
        _ responses: [(response: AIResponseData, property: PartialKeyPath<T>)],
        into model: T,
        context: ModelContext
    ) throws {
        // Validate all responses first
        for (response, _) in responses {
            guard case .success = response.result else {
                if let error = response.error {
                    throw error
                } else {
                    throw AIServiceError.unexpectedResponseFormat("Response has no content or error")
                }
            }
        }

        // Apply all merges
        // Note: This simplified version doesn't handle type-safe property updates
        // Full implementation would require reflection or code generation
        throw AIServiceError.unsupportedOperation("Multiple property merge not yet fully implemented")
    }

    /// Merges a response into a newly created model instance.
    ///
    /// - Parameters:
    ///   - response: The response data
    ///   - modelType: The type of model to create
    ///   - property: KeyPath to the property to populate
    ///   - context: SwiftData model context
    ///   - constraints: Optional validation constraints
    /// - Returns: The newly created and populated model
    /// - Throws: `AIServiceError` if creation or merge fails
    public func createAndMergeResponse<T: PersistentModel, V>(
        _ response: AIResponseData,
        modelType: T.Type,
        property: ReferenceWritableKeyPath<T, V>,
        context: ModelContext,
        constraints: [String: String] = [:]
    ) throws -> T {
        // Note: This requires the model to have a default initializer
        // Full implementation would need a factory pattern or builder
        throw AIServiceError.unsupportedOperation("Create and merge not yet fully implemented")
    }

    // MARK: - Batch Operations

    /// Merges a batch of responses for the same model property.
    ///
    /// This is useful for batch processing of multiple generation requests.
    ///
    /// - Parameters:
    ///   - responses: Array of response data
    ///   - models: Array of target models (same count as responses)
    ///   - property: The property to update in each model
    ///   - context: SwiftData model context
    /// - Returns: Array of Results indicating success/failure for each merge
    public func mergeBatch<T: PersistentModel, V>(
        responses: [AIResponseData],
        into models: [T],
        property: ReferenceWritableKeyPath<T, V>,
        context: ModelContext
    ) -> [Result<Void, Error>] {
        guard responses.count == models.count else {
            let error = AIServiceError.invalidRequest("Response count (\(responses.count)) doesn't match model count (\(models.count))")
            return Array(repeating: .failure(error), count: responses.count)
        }

        var results: [Result<Void, Error>] = []

        for (response, model) in zip(responses, models) {
            do {
                try mergeResponse(response, into: model, property: property, context: context)
                results.append(.success(()))
            } catch {
                results.append(.failure(error))
            }
        }

        return results
    }

    // MARK: - Response Processing

    /// Processes a response and returns the extracted value without persisting.
    ///
    /// This is useful for preview or validation before committing to SwiftData.
    ///
    /// - Parameters:
    ///   - response: The response data
    ///   - targetType: The expected value type
    ///   - transform: Optional transformation function
    /// - Returns: The extracted and transformed value
    /// - Throws: `AIServiceError` if processing fails
    public func processResponse<V>(
        _ response: AIResponseData,
        as targetType: V.Type,
        transform: ((ResponseContent) throws -> V)? = nil
    ) throws -> V {
        guard case .success(let content) = response.result else {
            if let error = response.error {
                throw error
            } else {
                throw AIServiceError.unexpectedResponseFormat("Response has no content or error")
            }
        }

        if let transform = transform {
            return try transform(content)
        } else {
            // Attempt automatic conversion
            guard let converted = try convertContent(content, to: targetType) as? V else {
                throw AIServiceError.dataConversionError(
                    "Cannot convert \(type(of: content)) to \(targetType)"
                )
            }
            return converted
        }
    }

    // MARK: - Validation

    /// Validates a response without merging it.
    ///
    /// - Parameters:
    ///   - response: The response to validate
    ///   - constraints: Validation constraints
    /// - Throws: `AIServiceError` if validation fails
    public func validateResponse(
        _ response: AIResponseData,
        constraints: [String: String]
    ) throws {
        guard case .success(let content) = response.result else {
            if let error = response.error {
                throw error
            } else {
                throw AIServiceError.unexpectedResponseFormat("Response has no content or error")
            }
        }

        // Extract value based on content type
        let value: Any
        switch content {
        case .text(let string):
            value = string
        case .data(let data):
            value = data
        case .audio(let data, _):
            value = data
        case .image(let data, _):
            value = data
        case .structured(let dict):
            value = dict
        }

        try validator.validate(value: value, constraints: constraints)
    }

    /// Registers a custom validation rule.
    ///
    /// - Parameter rule: The validation rule to register
    public func registerValidationRule(_ rule: AIContentValidator.ValidationRule) {
        Task {
            await validator.registerRule(rule)
        }
    }

    // MARK: - Private Helpers

    /// Converts response content to a value suitable for a property.
    private func convertContentToValue<T, V>(
        _ content: ResponseContent,
        for property: ReferenceWritableKeyPath<T, V>
    ) throws -> Any {
        // For now, use simple type matching
        // Full implementation would inspect property type at runtime
        switch content {
        case .text(let string):
            return string
        case .data(let data):
            return data
        case .audio(let data, _):
            return data
        case .image(let data, _):
            return data
        case .structured(let dict):
            return dict
        }
    }

    /// Converts response content to a specific type.
    private func convertContent<V>(
        _ content: ResponseContent,
        to type: V.Type
    ) throws -> Any {
        switch content {
        case .text(let string):
            if type == String.self {
                return string
            } else if type == Data.self {
                guard let data = string.data(using: .utf8) else {
                    throw AIServiceError.dataConversionError("Cannot convert string to Data")
                }
                return data
            }

        case .data(let data):
            if type == Data.self {
                return data
            } else if type == String.self {
                guard let string = String(data: data, encoding: .utf8) else {
                    throw AIServiceError.dataConversionError("Cannot convert Data to String")
                }
                return string
            }

        case .audio(let data, _):
            if type == Data.self {
                return data
            }

        case .image(let data, _):
            if type == Data.self {
                return data
            }

        case .structured(let dict):
            if type == [String: SendableValue].self {
                return dict
            }
        }

        throw AIServiceError.dataConversionError(
            "Cannot convert \(content.contentType) to \(type)"
        )
    }
}

// MARK: - Convenience Extensions

extension AIDataCoordinator {

    /// Convenience method for merging a text response into a String property.
    ///
    /// - Parameters:
    ///   - response: The response containing text
    ///   - model: The target model
    ///   - property: KeyPath to a String property
    ///   - context: SwiftData context
    /// - Throws: `AIServiceError` if merge fails
    public func mergeTextResponse<T: PersistentModel>(
        _ response: AIResponseData,
        into model: T,
        property: ReferenceWritableKeyPath<T, String>,
        context: ModelContext
    ) throws {
        try mergeResponse(
            response,
            into: model,
            property: property,
            context: context,
            transform: { content in
                guard let text = content.text else {
                    throw AIServiceError.dataConversionError("Response is not text content")
                }
                return text
            }
        )
    }

    /// Convenience method for merging a data response into a Data property.
    ///
    /// - Parameters:
    ///   - response: The response containing data
    ///   - model: The target model
    ///   - property: KeyPath to a Data property
    ///   - context: SwiftData context
    /// - Throws: `AIServiceError` if merge fails
    public func mergeDataResponse<T: PersistentModel>(
        _ response: AIResponseData,
        into model: T,
        property: ReferenceWritableKeyPath<T, Data>,
        context: ModelContext
    ) throws {
        try mergeResponse(
            response,
            into: model,
            property: property,
            context: context,
            transform: { content in
                guard let data = content.dataContent else {
                    throw AIServiceError.dataConversionError("Cannot extract data from response")
                }
                return data
            }
        )
    }
}
