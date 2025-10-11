import Testing
import Foundation
@testable import SwiftHablare

@Suite(.serialized)
struct AIContentValidatorTests {

    // MARK: - Length Validation

    @Test("AIContentValidator validates minimum length")
    func testMinLength() async throws {
        let validator = AIContentValidator()

        // Valid: meets minimum
        try await validator.validate(value: "Hello World", constraints: ["minLength": "5"])

        // Invalid: below minimum
        do {
            try await validator.validate(value: "Hi", constraints: ["minLength": "5"])
            Issue.record("Expected validationError")
        } catch let error as AIServiceError {
            if case .validationError = error {
                // Expected
            } else {
                Issue.record("Expected validationError, got \(error)")
            }
        }
    }

    @Test("AIContentValidator validates maximum length")
    func testMaxLength() async throws {
        let validator = AIContentValidator()

        // Valid: under maximum
        try await validator.validate(value: "Hello", constraints: ["maxLength": "10"])

        // Invalid: exceeds maximum
        do {
            try await validator.validate(value: "This is a very long string", constraints: ["maxLength": "10"])
            Issue.record("Expected validationError")
        } catch let error as AIServiceError {
            if case .validationError = error {
                // Expected
            } else {
                Issue.record("Expected validationError, got \(error)")
            }
        }
    }

    @Test("AIContentValidator validates length for Data")
    func testLengthForData() async throws {
        let validator = AIContentValidator()

        let shortData = Data([1, 2, 3])
        let longData = Data(repeating: 0, count: 100)

        // Valid
        try await validator.validate(value: shortData, constraints: ["minLength": "1", "maxLength": "10"])

        // Invalid: too long
        do {
            try await validator.validate(value: longData, constraints: ["maxLength": "10"])
            Issue.record("Expected validationError")
        } catch let error as AIServiceError {
            if case .validationError = error {
                // Expected
            } else {
                Issue.record("Expected validationError, got \(error)")
            }
        }
    }

    // MARK: - Numeric Value Validation

    @Test("AIContentValidator validates minimum value")
    func testMinValue() async throws {
        let validator = AIContentValidator()

        // Valid
        try await validator.validate(value: 10, constraints: ["minValue": "5.0"])
        try await validator.validate(value: 5.5, constraints: ["minValue": "5.0"])

        // Invalid
        do {
            try await validator.validate(value: 3, constraints: ["minValue": "5.0"])
            Issue.record("Expected validationError")
        } catch let error as AIServiceError {
            if case .validationError = error {
                // Expected
            } else {
                Issue.record("Expected validationError, got \(error)")
            }
        }
    }

    @Test("AIContentValidator validates maximum value")
    func testMaxValue() async throws {
        let validator = AIContentValidator()

        // Valid
        try await validator.validate(value: 5, constraints: ["maxValue": "10.0"])
        try await validator.validate(value: 9.9, constraints: ["maxValue": "10.0"])

        // Invalid
        do {
            try await validator.validate(value: 15, constraints: ["maxValue": "10.0"])
            Issue.record("Expected validationError")
        } catch let error as AIServiceError {
            if case .validationError = error {
                // Expected
            } else {
                Issue.record("Expected validationError, got \(error)")
            }
        }
    }

    // MARK: - Pattern Validation

    @Test("AIContentValidator validates regex patterns")
    func testPattern() async throws {
        let validator = AIContentValidator()

        // Valid: matches email pattern
        let emailPattern = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"
        try await validator.validate(
            value: "test@example.com",
            constraints: ["pattern": emailPattern]
        )

        // Invalid: doesn't match pattern
        do {
            try await validator.validate(
                value: "not an email",
                constraints: ["pattern": emailPattern]
            )
            Issue.record("Expected validationError")
        } catch let error as AIServiceError {
            if case .validationError = error {
                // Expected
            } else {
                Issue.record("Expected validationError, got \(error)")
            }
        }
    }

    // MARK: - Format Validation

    @Test("AIContentValidator validates email format")
    func testEmailFormat() async throws {
        let validator = AIContentValidator()

        // Valid emails
        try await validator.validate(value: "user@example.com", constraints: ["format": "email"])
        try await validator.validate(value: "test.user+tag@domain.co.uk", constraints: ["format": "email"])

        // Invalid emails
        do {
            try await validator.validate(value: "invalid.email", constraints: ["format": "email"])
            Issue.record("Expected validationError")
        } catch let error as AIServiceError {
            if case .validationError = error {
                // Expected
            } else {
                Issue.record("Expected validationError, got \(error)")
            }
        }
    }

    @Test("AIContentValidator validates URL format")
    func testURLFormat() async throws {
        let validator = AIContentValidator()

        // Valid URLs
        try await validator.validate(value: "https://example.com", constraints: ["format": "url"])
        try await validator.validate(value: "http://test.com/path", constraints: ["format": "url"])

        // Invalid URLs
        do {
            try await validator.validate(value: "not a url", constraints: ["format": "url"])
            Issue.record("Expected validationError")
        } catch let error as AIServiceError {
            if case .validationError = error {
                // Expected
            } else {
                Issue.record("Expected validationError, got \(error)")
            }
        }
    }

    @Test("AIContentValidator validates UUID format")
    func testUUIDFormat() async throws {
        let validator = AIContentValidator()

        // Valid UUID
        let uuid = UUID().uuidString
        try await validator.validate(value: uuid, constraints: ["format": "uuid"])

        // Invalid UUID
        do {
            try await validator.validate(value: "not-a-uuid", constraints: ["format": "uuid"])
            Issue.record("Expected validationError")
        } catch let error as AIServiceError {
            if case .validationError = error {
                // Expected
            } else {
                Issue.record("Expected validationError, got \(error)")
            }
        }
    }

    // MARK: - Required Validation

    @Test("AIContentValidator validates required constraint")
    func testRequired() async throws {
        let validator = AIContentValidator()

        // Valid: non-empty
        try await validator.validate(value: "Hello", constraints: ["required": "true"])

        // Invalid: empty string
        do {
            try await validator.validate(value: "", constraints: ["required": "true"])
            Issue.record("Expected validationError")
        } catch let error as AIServiceError {
            if case .validationError = error {
                // Expected
            } else {
                Issue.record("Expected validationError, got \(error)")
            }
        }

        // Invalid: empty data
        do {
            try await validator.validate(value: Data(), constraints: ["required": "true"])
            Issue.record("Expected validationError")
        } catch let error as AIServiceError {
            if case .validationError = error {
                // Expected
            } else {
                Issue.record("Expected validationError, got \(error)")
            }
        }
    }

    // MARK: - Allowed Values Validation

    @Test("AIContentValidator validates allowed values")
    func testAllowedValues() async throws {
        let validator = AIContentValidator()

        // Valid: in allowed list
        try await validator.validate(value: "red", constraints: ["allowedValues": "red, green, blue"])

        // Invalid: not in allowed list
        do {
            try await validator.validate(value: "yellow", constraints: ["allowedValues": "red, green, blue"])
            Issue.record("Expected validationError")
        } catch let error as AIServiceError {
            if case .validationError = error {
                // Expected
            } else {
                Issue.record("Expected validationError, got \(error)")
            }
        }
    }

    // MARK: - Multiple Constraints

    @Test("AIContentValidator validates multiple constraints")
    func testMultipleConstraints() async throws {
        let validator = AIContentValidator()

        // Valid: passes all constraints
        try await validator.validate(
            value: "Hello World",
            constraints: [
                "minLength": "5",
                "maxLength": "20",
                "required": "true"
            ]
        )

        // Invalid: fails one constraint
        do {
            try await validator.validate(
                value: "Hi",
                constraints: [
                    "minLength": "5",
                    "maxLength": "20"
                ]
            )
            Issue.record("Expected validationError")
        } catch let error as AIServiceError {
            if case .validationError = error {
                // Expected
            } else {
                Issue.record("Expected validationError, got \(error)")
            }
        }
    }

    // MARK: - Custom Rules

    @Test("AIContentValidator supports custom rules")
    func testCustomRules() async throws {
        let validator = AIContentValidator()

        // Register custom rule
        let customRule = AIContentValidator.ValidationRule(
            name: "isUppercase",
            validate: { value in
                guard let string = value as? String else { return false }
                return string == string.uppercased()
            },
            errorMessage: "Value must be uppercase"
        )

        await validator.registerRule(customRule)

        // Valid: uppercase
        try await validator.validate(value: "HELLO", constraints: ["isUppercase": "true"])

        // Invalid: not uppercase
        do {
            try await validator.validate(value: "hello", constraints: ["isUppercase": "true"])
            Issue.record("Expected validationError")
        } catch let error as AIServiceError {
            if case .validationError = error {
                // Expected
            } else {
                Issue.record("Expected validationError, got \(error)")
            }
        }
    }

    @Test("AIContentValidator can unregister custom rules")
    func testUnregisterCustomRules() async throws {
        let validator = AIContentValidator()

        let customRule = AIContentValidator.ValidationRule(
            name: "testRule",
            validate: { _ in true },
            errorMessage: "Test rule"
        )

        await validator.registerRule(customRule)
        await validator.unregisterRule(name: "testRule")

        // Should not apply the rule after unregistering
        try await validator.validate(value: "test", constraints: ["testRule": "true"])
    }

    // MARK: - Edge Cases

    @Test("AIContentValidator handles empty constraints")
    func testEmptyConstraints() async throws {
        let validator = AIContentValidator()

        // Should pass with no constraints
        try await validator.validate(value: "Any value", constraints: [:])
    }

    @Test("AIContentValidator handles unknown constraints gracefully")
    func testUnknownConstraints() async throws {
        let validator = AIContentValidator()

        // Should ignore unknown constraints
        try await validator.validate(value: "test", constraints: ["unknownConstraint": "value"])
    }

    @Test("AIContentValidator validates zero-length strings against maxLength")
    func testZeroLengthString() async throws {
        let validator = AIContentValidator()

        try await validator.validate(value: "", constraints: ["maxLength": "10"])
    }
}
