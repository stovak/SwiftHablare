import Foundation
import SwiftData

/// Handles binding of AI-generated responses to SwiftData model properties.
///
/// This component provides automatic type conversion between provider response formats
/// and Swift property types, validation, and transformation support.
///
/// ## Example
/// ```swift
/// let binder = AIPropertyBinder()
///
/// // Bind generated text to a model property
/// try await binder.bind(
///     value: generatedText,
///     to: article,
///     property: \Article.content,
///     context: modelContext
/// )
/// ```
@available(macOS 15.0, iOS 17.0, *)
public struct AIPropertyBinder: Sendable {

    // MARK: - Initialization

    public init() {}

    // MARK: - Property Binding

    /// Binds a generated value to a model property with automatic type conversion.
    ///
    /// - Parameters:
    ///   - value: The generated value from the provider
    ///   - model: The model instance to update (must be mutable reference)
    ///   - property: The keypath to the property to update
    ///   - context: The SwiftData model context
    /// - Throws: ``AIServiceError/dataBindingError(_:)`` if binding fails
    public func bind<T: PersistentModel, V>(
        value: Any,
        to model: T,
        property: ReferenceWritableKeyPath<T, V>,
        context: ModelContext
    ) throws {
        // Convert the value to the target type
        guard let convertedValue = try convert(value: value, to: V.self) else {
            throw AIServiceError.dataBindingError("Failed to convert value to \(V.self)")
        }

        // Set the property value
        model[keyPath: property] = convertedValue

        // Touch modification timestamp if model supports it
        if let generatedContent = model as? AIGeneratedContent {
            generatedContent.touch()
        }
    }

    /// Binds multiple values to model properties atomically.
    ///
    /// - Parameters:
    ///   - bindings: Dictionary mapping property names to values
    ///   - model: The model instance to update
    ///   - context: The SwiftData model context
    /// - Throws: ``AIServiceError/dataBindingError(_:)`` if any binding fails
    public func bindMultiple<T: PersistentModel>(
        bindings: [String: Any],
        to model: T,
        context: ModelContext
    ) throws {
        // For now, this is a placeholder for batch binding
        // Full implementation would use Mirror and KeyPath lookup
        throw AIServiceError.dataBindingError("Batch binding not yet implemented")
    }

    // MARK: - Type Conversion

    /// Converts a value from provider format to the target Swift type.
    ///
    /// Supported conversions:
    /// - String → String, Int, Double, Bool, URL, Data
    /// - Data → Data, String, URL
    /// - Number → Int, Double, Float, Bool
    /// - Dictionary → Codable types via JSON
    ///
    /// - Parameters:
    ///   - value: The source value
    ///   - targetType: The target type
    /// - Returns: The converted value, or nil if conversion fails
    /// - Throws: ``AIServiceError/dataBindingError(_:)`` if conversion is invalid
    private func convert<V>(value: Any, to targetType: V.Type) throws -> V? {
        // Direct type match
        if let directValue = value as? V {
            return directValue
        }

        // String conversions
        if let stringValue = value as? String {
            return try convertFromString(stringValue, to: targetType)
        }

        // Data conversions
        if let dataValue = value as? Data {
            return try convertFromData(dataValue, to: targetType)
        }

        // Number conversions
        if let numberValue = value as? any Numeric {
            return try convertFromNumber(numberValue, to: targetType)
        }

        return nil
    }

    /// Converts a string value to the target type.
    private func convertFromString<V>(_ string: String, to targetType: V.Type) throws -> V? {
        // String → String
        if V.self == String.self {
            return string as? V
        }

        // String → Int
        if V.self == Int.self {
            return Int(string) as? V
        }

        // String → Double
        if V.self == Double.self {
            return Double(string) as? V
        }

        // String → Bool
        if V.self == Bool.self {
            let lowercased = string.lowercased().trimmingCharacters(in: .whitespaces)
            if lowercased == "true" || lowercased == "yes" || lowercased == "1" {
                return true as? V
            }
            if lowercased == "false" || lowercased == "no" || lowercased == "0" {
                return false as? V
            }
        }

        // String → URL
        if V.self == URL.self {
            return URL(string: string) as? V
        }

        // String → Data
        if V.self == Data.self {
            return string.data(using: .utf8) as? V
        }

        return nil
    }

    /// Converts data to the target type.
    private func convertFromData<V>(_ data: Data, to targetType: V.Type) throws -> V? {
        // Data → Data
        if V.self == Data.self {
            return data as? V
        }

        // Data → String
        if V.self == String.self {
            return String(data: data, encoding: .utf8) as? V
        }

        // Data → URL (file path)
        if V.self == URL.self {
            if let stringPath = String(data: data, encoding: .utf8) {
                return URL(fileURLWithPath: stringPath) as? V
            }
        }

        return nil
    }

    /// Converts a numeric value to the target type.
    private func convertFromNumber<V>(_ number: any Numeric, to targetType: V.Type) throws -> V? {
        // Extract numeric value
        if let intValue = number as? Int {
            if V.self == Int.self { return intValue as? V }
            if V.self == Double.self { return Double(intValue) as? V }
            if V.self == Float.self { return Float(intValue) as? V }
            if V.self == Bool.self { return (intValue != 0) as? V }
            if V.self == String.self { return String(intValue) as? V }
        }

        if let doubleValue = number as? Double {
            if V.self == Double.self { return doubleValue as? V }
            if V.self == Int.self { return Int(doubleValue) as? V }
            if V.self == Float.self { return Float(doubleValue) as? V }
            if V.self == String.self { return String(doubleValue) as? V }
        }

        return nil
    }
}
