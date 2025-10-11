import Foundation
import SwiftData

/// Describes a provider's capability to generate data for specific SwiftData structures.
///
/// Providers use this to declare which model types and properties they can populate.
/// The framework validates generation requests against these declarations.
///
/// ## Example
/// ```swift
/// var supportedDataStructures: [DataStructureCapability] {
///     [
///         // Can generate Product descriptions
///         .model(Product.self, properties: [
///             .property(\.description, constraints: .init(minLength: 50, maxLength: 500))
///         ]),
///
///         // Can generate any AIGeneratable model
///         .protocol(AIGeneratable.self, typeConstraints: [
///             .canGenerate(.string),
///             .canGenerate(.data)
///         ])
///     ]
/// }
/// ```
@available(macOS 15.0, iOS 17.0, *)
public enum DataStructureCapability: Sendable {
    /// Provider can generate data for a specific model type.
    ///
    /// - Parameters:
    ///   - modelType: The SwiftData model type (e.g., `Product.self`).
    ///   - properties: Specific properties that can be generated.
    case model(modelType: String, properties: [PropertyCapability])

    /// Provider can generate data for any model conforming to a protocol.
    ///
    /// - Parameters:
    ///   - protocolType: The protocol name (e.g., "AIGeneratable").
    ///   - typeConstraints: Constraints on what types can be generated.
    case `protocol`(protocolType: String, typeConstraints: [TypeConstraint])

    // MARK: - Factory Methods

    /// Creates a model capability for a specific PersistentModel type.
    public static func model<T: PersistentModel>(
        _: T.Type,
        properties: [PropertyCapability]
    ) -> DataStructureCapability {
        .model(modelType: String(describing: T.self), properties: properties)
    }

    /// Creates a protocol capability.
    public static func `protocol`<P>(
        _: P.Type,
        typeConstraints: [TypeConstraint]
    ) -> DataStructureCapability {
        .protocol(protocolType: String(describing: P.self), typeConstraints: typeConstraints)
    }

    // MARK: - Accessors

    /// Returns the model type name if this is a model capability.
    public var modelType: String? {
        if case .model(let type, _) = self {
            return type
        }
        return nil
    }

    /// Returns the protocol type name if this is a protocol capability.
    public var protocolType: String? {
        if case .protocol(let type, _) = self {
            return type
        }
        return nil
    }

    /// Returns the property capabilities for model types.
    public var properties: [PropertyCapability] {
        if case .model(_, let props) = self {
            return props
        }
        return []
    }

    /// Returns the type constraints for protocol types.
    public var typeConstraints: [TypeConstraint] {
        if case .protocol(_, let constraints) = self {
            return constraints
        }
        return []
    }
}

/// Describes a provider's capability to generate a specific property.
@available(macOS 15.0, iOS 17.0, *)
public struct PropertyCapability: Sendable {
    /// The property name (derived from KeyPath).
    public let propertyName: String

    /// Optional constraints for generated data.
    public let constraints: PropertyConstraints?

    public init(propertyName: String, constraints: PropertyConstraints? = nil) {
        self.propertyName = propertyName
        self.constraints = constraints
    }

    /// Creates a property capability from a KeyPath with an explicit property name.
    ///
    /// - Parameters:
    ///   - keyPath: The KeyPath to the property (used for type safety)
    ///   - name: The explicit property name (e.g., "title", "description")
    ///   - constraints: Optional constraints for the property generation
    ///
    /// - Note: Swift does not provide a reliable way to extract property names from KeyPaths at runtime,
    ///         so an explicit name parameter is required for reliable property identification.
    ///
    /// ## Example
    /// ```swift
    /// PropertyCapability.property(\Product.description, name: "description",
    ///                              constraints: .init(minLength: 50, maxLength: 500))
    /// ```
    public static func property<T, V>(
        _ keyPath: KeyPath<T, V>,
        name: String,
        constraints: PropertyConstraints? = nil
    ) -> PropertyCapability {
        return PropertyCapability(propertyName: name, constraints: constraints)
    }
}

/// Constraints for property generation.
@available(macOS 15.0, iOS 17.0, *)
public struct PropertyConstraints: Sendable {
    /// Minimum length for string properties.
    public let minLength: Int?

    /// Maximum length for string properties.
    public let maxLength: Int?

    /// Additional arbitrary constraints.
    public let additionalConstraints: [String: String]

    public init(
        minLength: Int? = nil,
        maxLength: Int? = nil,
        additionalConstraints: [String: String] = [:]
    ) {
        self.minLength = minLength
        self.maxLength = maxLength
        self.additionalConstraints = additionalConstraints
    }
}

/// Type constraints for protocol-based capabilities.
@available(macOS 15.0, iOS 17.0, *)
public enum TypeConstraint: Sendable {
    /// Provider can generate values of this Swift type.
    case canGenerate(SwiftType)

    /// Provider cannot generate values of this Swift type.
    case cannotGenerate(SwiftType)
}

/// Swift types that can be generated.
@available(macOS 15.0, iOS 17.0, *)
public enum SwiftType: String, Sendable {
    case string = "String"
    case int = "Int"
    case double = "Double"
    case bool = "Bool"
    case data = "Data"
    case url = "URL"
    case date = "Date"
    case uuid = "UUID"
}
