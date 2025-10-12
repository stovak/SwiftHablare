import Foundation
import SwiftData

/// Validates AI-generated content before persistence.
///
/// This component provides validation rules for generated content, including
/// type checking, constraint validation, and custom validation logic.
///
/// ## Example
/// ```swift
/// let validator = AIContentValidator()
///
/// // Validate generated text
/// try validator.validate(
///     value: generatedText,
///     property: \Article.content,
///     constraints: ["minLength": 100, "maxLength": 5000]
/// )
/// ```

public actor AIContentValidator {

    // MARK: - Types

    /// Validation rule for a property.
    public struct ValidationRule: Sendable {
        let name: String
        let validate: @Sendable (Any) throws -> Bool
        let errorMessage: String
    }

    /// Validation result.
    public enum ValidationResult: Sendable {
        case valid
        case invalid(reason: String)

        public var isValid: Bool {
            if case .valid = self {
                return true
            }
            return false
        }
    }

    // MARK: - Properties

    /// Custom validation rules.
    private var customRules: [String: ValidationRule] = [:]

    // MARK: - Initialization

    public init() {
        // Standard rules are built-in and don't need registration
    }

    // MARK: - Validation

    /// Validates a value against constraints.
    ///
    /// - Parameters:
    ///   - value: The value to validate
    ///   - constraints: Dictionary of constraint names to string values
    /// - Throws: ``AIServiceError/validationError(_:)`` if validation fails
    ///
    /// - Note: This method is nonisolated and can be called synchronously from any context.
    nonisolated public func validate(value: Any, constraints: [String: String]) throws {
        let result = validateValue(value, constraints: constraints)
        if case .invalid(let reason) = result {
            throw AIServiceError.validationError(reason)
        }
    }

    /// Validates a value and returns a result.
    ///
    /// - Parameters:
    ///   - value: The value to validate
    ///   - constraints: Dictionary of constraint names to string values
    /// - Returns: Validation result
    ///
    /// - Note: This method is nonisolated and can be called synchronously from any context.
    ///         It only validates standard constraints, not custom rules.
    nonisolated public func validateValue(_ value: Any, constraints: [String: String]) -> ValidationResult {
        for (constraintName, constraintValue) in constraints {
            let result = validateConstraint(value, name: constraintName, value: constraintValue)
            if !result.isValid {
                return result
            }
        }
        return .valid
    }

    /// Validates a value including custom rules (actor-isolated).
    ///
    /// - Parameters:
    ///   - value: The value to validate
    ///   - constraints: Dictionary of constraint names to string values
    /// - Returns: Validation result
    public func validateValueWithCustomRules(_ value: Any, constraints: [String: String]) -> ValidationResult {
        for (constraintName, constraintValue) in constraints {
            // Check custom rules first
            if let customRule = customRules[constraintName] {
                do {
                    let isValid = try customRule.validate(value)
                    if !isValid {
                        return .invalid(reason: customRule.errorMessage)
                    }
                } catch {
                    return .invalid(reason: "Custom rule '\(constraintName)' failed: \(error.localizedDescription)")
                }
            } else {
                // Fall back to standard validation
                let result = validateConstraint(value, name: constraintName, value: constraintValue)
                if !result.isValid {
                    return result
                }
            }
        }
        return .valid
    }

    /// Registers a custom validation rule.
    ///
    /// - Parameter rule: The validation rule to register
    public func registerRule(_ rule: ValidationRule) {
        customRules[rule.name] = rule
    }

    /// Removes a custom validation rule.
    ///
    /// - Parameter name: The rule name
    public func unregisterRule(name: String) {
        customRules.removeValue(forKey: name)
    }

    // MARK: - Private Methods

    /// Validates a single constraint.
    ///
    /// Note: This method cannot access customRules directly since it's nonisolated.
    /// Custom rules validation needs to happen in isolated context.
    nonisolated private func validateConstraint(_ value: Any, name: String, value constraintValue: String) -> ValidationResult {
        // Standard constraints only (custom rules not accessible from nonisolated context)
        switch name {
        case "minLength":
            return validateMinLength(value, constraint: constraintValue)
        case "maxLength":
            return validateMaxLength(value, constraint: constraintValue)
        case "minValue":
            return validateMinValue(value, constraint: constraintValue)
        case "maxValue":
            return validateMaxValue(value, constraint: constraintValue)
        case "pattern":
            return validatePattern(value, constraint: constraintValue)
        case "allowedValues":
            return validateAllowedValues(value, constraint: constraintValue)
        case "format":
            return validateFormat(value, constraint: constraintValue)
        case "required":
            return validateRequired(value, constraint: constraintValue)
        default:
            // Unknown constraint - skip validation
            return .valid
        }
    }

    /// Validates minimum length for strings or data.
    nonisolated private func validateMinLength(_ value: Any, constraint: String) -> ValidationResult {
        guard let minLength = Int(constraint) else {
            return .invalid(reason: "minLength constraint must be a valid integer")
        }

        let length: Int
        if let string = value as? String {
            length = string.count
        } else if let data = value as? Data {
            length = data.count
        } else if let array = value as? [Any] {
            length = array.count
        } else {
            return .invalid(reason: "minLength constraint only applies to String, Data, or Array")
        }

        if length < minLength {
            return .invalid(reason: "Value length (\(length)) is less than minimum (\(minLength))")
        }

        return .valid
    }

    /// Validates maximum length for strings or data.
    nonisolated private func validateMaxLength(_ value: Any, constraint: String) -> ValidationResult {
        guard let maxLength = Int(constraint) else {
            return .invalid(reason: "maxLength constraint must be a valid integer")
        }

        let length: Int
        if let string = value as? String {
            length = string.count
        } else if let data = value as? Data {
            length = data.count
        } else if let array = value as? [Any] {
            length = array.count
        } else {
            return .invalid(reason: "maxLength constraint only applies to String, Data, or Array")
        }

        if length > maxLength {
            return .invalid(reason: "Value length (\(length)) exceeds maximum (\(maxLength))")
        }

        return .valid
    }

    /// Validates minimum numeric value.
    nonisolated private func validateMinValue(_ value: Any, constraint: String) -> ValidationResult {
        guard let minValue = Double(constraint) else {
            return .invalid(reason: "minValue constraint must be a valid number")
        }

        let numericValue: Double
        if let intValue = value as? Int {
            numericValue = Double(intValue)
        } else if let doubleValue = value as? Double {
            numericValue = doubleValue
        } else if let floatValue = value as? Float {
            numericValue = Double(floatValue)
        } else {
            return .invalid(reason: "minValue constraint only applies to numeric types")
        }

        if numericValue < minValue {
            return .invalid(reason: "Value (\(numericValue)) is less than minimum (\(minValue))")
        }

        return .valid
    }

    /// Validates maximum numeric value.
    nonisolated private func validateMaxValue(_ value: Any, constraint: String) -> ValidationResult {
        guard let maxValue = Double(constraint) else {
            return .invalid(reason: "maxValue constraint must be a valid number")
        }

        let numericValue: Double
        if let intValue = value as? Int {
            numericValue = Double(intValue)
        } else if let doubleValue = value as? Double {
            numericValue = doubleValue
        } else if let floatValue = value as? Float {
            numericValue = Double(floatValue)
        } else {
            return .invalid(reason: "maxValue constraint only applies to numeric types")
        }

        if numericValue > maxValue {
            return .invalid(reason: "Value (\(numericValue)) exceeds maximum (\(maxValue))")
        }

        return .valid
    }

    /// Validates pattern matching (regex).
    nonisolated private func validatePattern(_ value: Any, constraint: String) -> ValidationResult {
        let pattern = constraint

        guard let stringValue = value as? String else {
            return .invalid(reason: "pattern constraint only applies to String values")
        }

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(stringValue.startIndex..., in: stringValue)
            let matches = regex.matches(in: stringValue, range: range)

            if matches.isEmpty {
                return .invalid(reason: "Value does not match pattern: \(pattern)")
            }

            return .valid
        } catch {
            return .invalid(reason: "Invalid regex pattern: \(error.localizedDescription)")
        }
    }

    /// Validates against allowed values.
    nonisolated private func validateAllowedValues(_ value: Any, constraint: String) -> ValidationResult {
        // Parse comma-separated list of allowed values
        let allowedValues = constraint.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }

        let valueString = String(describing: value)
        if allowedValues.contains(valueString) {
            return .valid
        }

        return .invalid(reason: "Value is not in allowed values list: \(constraint)")
    }

    /// Validates format (e.g., email, URL, phone).
    nonisolated private func validateFormat(_ value: Any, constraint: String) -> ValidationResult {
        let format = constraint

        guard let stringValue = value as? String else {
            return .invalid(reason: "format constraint only applies to String values")
        }

        switch format.lowercased() {
        case "email":
            return validateEmail(stringValue)
        case "url":
            return validateURL(stringValue)
        case "uuid":
            return validateUUID(stringValue)
        default:
            return .invalid(reason: "Unknown format: \(format)")
        }
    }

    /// Validates required constraint.
    nonisolated private func validateRequired(_ value: Any, constraint: String) -> ValidationResult {
        // Parse boolean from string
        let required = constraint.lowercased() == "true" || constraint == "1"
        guard required else {
            return .valid
        }

        // Check if value is "empty"
        if let stringValue = value as? String, stringValue.isEmpty {
            return .invalid(reason: "Required value is empty")
        }

        if let dataValue = value as? Data, dataValue.isEmpty {
            return .invalid(reason: "Required value is empty")
        }

        if let arrayValue = value as? [Any], arrayValue.isEmpty {
            return .invalid(reason: "Required value is empty")
        }

        return .valid
    }

    /// Validates email format.
    nonisolated private func validateEmail(_ value: String) -> ValidationResult {
        let emailPattern = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"
        let regex = try? NSRegularExpression(pattern: emailPattern, options: .caseInsensitive)
        let range = NSRange(value.startIndex..., in: value)
        let matches = regex?.matches(in: value, range: range) ?? []

        if matches.isEmpty {
            return .invalid(reason: "Invalid email format")
        }

        return .valid
    }

    /// Validates URL format.
    nonisolated private func validateURL(_ value: String) -> ValidationResult {
        guard let url = URL(string: value) else {
            return .invalid(reason: "Invalid URL format")
        }

        // Check that URL has a scheme (http, https, etc.)
        guard url.scheme != nil else {
            return .invalid(reason: "Invalid URL format")
        }

        return .valid
    }

    /// Validates UUID format.
    nonisolated private func validateUUID(_ value: String) -> ValidationResult {
        if UUID(uuidString: value) == nil {
            return .invalid(reason: "Invalid UUID format")
        }
        return .valid
    }
}
