import Foundation
import SwiftData

/// Protocol for SwiftData models that support AI-generated content.
///
/// Models conforming to this protocol can declaratively specify which properties
/// can be populated by AI providers, along with constraints and generation parameters.
///
/// ## Example
/// ```swift
/// @Model
/// class Product: AIGeneratable {
///     var name: String = ""
///     var description: String = ""
///     var price: Decimal = 0
///
///     static var aiGenerationSchema: AIGenerationSchema {
///         AIGenerationSchema {
///             AIProperty(\.description)
///                 .providers(["openai", "anthropic"])
///                 .constraints(minLength: 50, maxLength: 500)
///                 .promptTemplate("Write a product description for {name}")
///         }
///     }
/// }
/// ```
@available(macOS 15.0, iOS 17.0, *)
public protocol AIGeneratable: PersistentModel {
    /// Declares which properties can be AI-generated and how.
    static var aiGenerationSchema: AIGenerationSchema { get }
}

/// Describes how AI generation works for a model.
///
/// Built using a result builder for clean, declarative syntax.
@available(macOS 15.0, iOS 17.0, *)
public struct AIGenerationSchema: Sendable {
    /// The property specifications for AI generation.
    public let properties: [AIPropertySpec]

    public init(properties: [AIPropertySpec]) {
        self.properties = properties
    }

    public init(@AIGenerationSchemaBuilder _ builder: () -> [AIPropertySpec]) {
        self.properties = builder()
    }
}

/// Specification for how a property should be AI-generated.
@available(macOS 15.0, iOS 17.0, *)
public struct AIPropertySpec: Sendable {
    /// The property name (derived from KeyPath).
    public let propertyName: String

    /// Provider IDs that can generate this property.
    public var allowedProviders: [String]

    /// Minimum length for string values.
    public var minLength: Int?

    /// Maximum length for string values.
    public var maxLength: Int?

    /// Prompt template with placeholder substitution.
    /// Use {propertyName} syntax for substitution.
    public var promptTemplate: String?

    /// Whether this property is required for generation.
    public var required: Bool

    /// Name of another property to use as input.
    public var inputPropertyName: String?

    /// Custom transformation function applied after generation.
    public var transformFunction: TransformFunction?

    /// Additional arbitrary constraints.
    public var additionalConstraints: [String: String]

    public init(propertyName: String) {
        self.propertyName = propertyName
        self.allowedProviders = []
        self.required = false
        self.additionalConstraints = [:]
    }

    // MARK: - Builder Methods

    /// Specifies which providers can generate this property.
    public func providers(_ providerIds: [String]) -> AIPropertySpec {
        var copy = self
        copy.allowedProviders = providerIds
        return copy
    }

    /// Sets length constraints for string properties.
    public func constraints(minLength: Int? = nil, maxLength: Int? = nil) -> AIPropertySpec {
        var copy = self
        copy.minLength = minLength
        copy.maxLength = maxLength
        return copy
    }

    /// Sets the prompt template for generation.
    public func promptTemplate(_ template: String) -> AIPropertySpec {
        var copy = self
        copy.promptTemplate = template
        return copy
    }

    /// Marks this property as required.
    public func required(_ isRequired: Bool = true) -> AIPropertySpec {
        var copy = self
        copy.required = isRequired
        return copy
    }

    /// Marks this property as optional.
    public func optional() -> AIPropertySpec {
        required(false)
    }

    /// Specifies another property to use as input for generation.
    public func inputProperty(_ name: String) -> AIPropertySpec {
        var copy = self
        copy.inputPropertyName = name
        return copy
    }

    /// Sets a transformation function to apply after generation.
    public func resultTransform(_ transform: @escaping TransformFunction) -> AIPropertySpec {
        var copy = self
        copy.transformFunction = transform
        return copy
    }

    /// Adds arbitrary constraints.
    public func addConstraint(key: String, value: String) -> AIPropertySpec {
        var copy = self
        copy.additionalConstraints[key] = value
        return copy
    }
}

/// Type alias for transformation functions.
@available(macOS 15.0, iOS 17.0, *)
public typealias TransformFunction = @Sendable (Any, Any) throws -> Any

/// Creates an AI property specification from a KeyPath.
///
/// - Parameters:
///   - keyPath: The KeyPath to the property (used for type safety)
///   - name: An optional explicit property name. If omitted, the name is inferred from the KeyPath.
///
/// ## Example
/// ```swift
/// AIProperty(\Article.title)
///     .providers(["openai", "anthropic"])
///     .constraints(minLength: 10, maxLength: 100)
/// ```
@available(macOS 15.0, iOS 17.0, *)
public func AIProperty<T, V>(_ keyPath: KeyPath<T, V>, name: String? = nil) -> AIPropertySpec {
    let resolvedName: String
    if let explicitName = name, !explicitName.isEmpty {
        resolvedName = explicitName
    } else if let inferredName = inferPropertyName(from: keyPath) {
        resolvedName = inferredName
    } else {
        preconditionFailure("Unable to infer property name from key path: \(keyPath)")
    }

    return AIPropertySpec(propertyName: resolvedName)
}

@available(macOS 15.0, iOS 17.0, *)
private func inferPropertyName<T, V>(from keyPath: KeyPath<T, V>) -> String? {
    let description = String(describing: keyPath)
    guard let lastComponent = description.split(separator: ".").last else {
        return nil
    }

    let trimmed = lastComponent.trimmingCharacters(in: CharacterSet(charactersIn: "\\"))
    return trimmed.isEmpty ? nil : trimmed
}

@available(macOS 15.0, iOS 17.0, *)
public extension AIGeneratable {
    /// Convenience helper that allows calling ``AIProperty(_:_:)`` using a KeyPath relative to `Self`.
    ///
    /// This mirrors the natural SwiftData style of referencing properties within a model's
    /// ``AIGenerationSchema`` declaration:
    ///
    /// ```swift
    /// static var aiGenerationSchema: AIGenerationSchema {
    ///     AIGenerationSchema {
    ///         Self.AIProperty(\.title)
    ///             .providers(["openai"])
    ///     }
    /// }
    /// ```
    static func AIProperty<V>(_ keyPath: KeyPath<Self, V>, name: String? = nil) -> AIPropertySpec {
        SwiftHablare.AIProperty(keyPath, name: name)
    }
}

// MARK: - Result Builder

/// Result builder for constructing AIGenerationSchema.
@available(macOS 15.0, iOS 17.0, *)
@resultBuilder
public struct AIGenerationSchemaBuilder {
    public static func buildBlock(_ components: AIPropertySpec...) -> [AIPropertySpec] {
        components
    }

    public static func buildArray(_ components: [[AIPropertySpec]]) -> [AIPropertySpec] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [AIPropertySpec]?) -> [AIPropertySpec] {
        component ?? []
    }

    public static func buildEither(first component: [AIPropertySpec]) -> [AIPropertySpec] {
        component
    }

    public static func buildEither(second component: [AIPropertySpec]) -> [AIPropertySpec] {
        component
    }
}
