import Foundation

/// A template for generating prompts with variable substitution.
///
/// `AIPromptTemplate` allows you to create reusable prompt templates with placeholders
/// that can be filled in with dynamic values at runtime.
///
/// ## Example
/// ```swift
/// let template = AIPromptTemplate(
///     template: "Generate a {{style}} product description for {{product}}",
///     defaultValues: ["style": "professional"]
/// )
///
/// let prompt = try template.render(variables: ["product": "laptop"])
/// // Result: "Generate a professional product description for laptop"
/// ```
public struct AIPromptTemplate: Sendable {

    /// The template string with placeholders in {{variable}} format.
    public let template: String

    /// Default values for template variables.
    public let defaultValues: [String: String]

    /// Regex pattern for matching template variables.
    private static let variablePattern = try! NSRegularExpression(
        pattern: "\\{\\{\\s*([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\}\\}",
        options: []
    )

    /// Creates a new prompt template.
    ///
    /// - Parameters:
    ///   - template: The template string with {{variable}} placeholders
    ///   - defaultValues: Default values for variables (default: empty)
    public init(template: String, defaultValues: [String: String] = [:]) {
        self.template = template
        self.defaultValues = defaultValues
    }

    /// Renders the template with the provided variables.
    ///
    /// Variables are merged with default values, with provided values taking precedence.
    ///
    /// - Parameter variables: Variable values to substitute
    /// - Returns: The rendered template string
    /// - Throws: `AIServiceError.validationError` if required variables are missing
    public func render(variables: [String: String] = [:]) throws -> String {
        // Merge provided variables with defaults
        var allVariables = defaultValues
        allVariables.merge(variables) { _, new in new }

        // Find all variable references in the template
        let nsString = template as NSString
        let matches = Self.variablePattern.matches(
            in: template,
            options: [],
            range: NSRange(location: 0, length: nsString.length)
        )

        // Build set of required variables
        var requiredVariables = Set<String>()
        for match in matches {
            let varNameRange = match.range(at: 1)
            let varName = nsString.substring(with: varNameRange)
            requiredVariables.insert(varName)
        }

        // Check for missing required variables
        let missingVariables = requiredVariables.subtracting(Set(allVariables.keys))
        if !missingVariables.isEmpty {
            throw AIServiceError.validationError(
                "Missing required template variables: \(missingVariables.sorted().joined(separator: ", "))"
            )
        }

        // Perform substitution
        var result = template
        for (key, value) in allVariables {
            let placeholder = "{{\(key)}}"
            let placeholderWithSpaces = "{{ \(key) }}"
            result = result.replacingOccurrences(of: placeholder, with: value)
            result = result.replacingOccurrences(of: placeholderWithSpaces, with: value)
        }

        return result
    }

    /// Extracts all variable names from the template.
    ///
    /// - Returns: Set of variable names found in the template
    public func extractVariables() -> Set<String> {
        let nsString = template as NSString
        let matches = Self.variablePattern.matches(
            in: template,
            options: [],
            range: NSRange(location: 0, length: nsString.length)
        )

        var variables = Set<String>()
        for match in matches {
            let varNameRange = match.range(at: 1)
            let varName = nsString.substring(with: varNameRange)
            variables.insert(varName)
        }

        return variables
    }

    /// Validates that all required variables can be satisfied.
    ///
    /// - Parameter variables: Variables to validate against
    /// - Returns: `true` if all required variables are present, `false` otherwise
    public func validate(variables: [String: String]) -> Bool {
        let required = extractVariables()
        let provided = Set(defaultValues.keys).union(Set(variables.keys))
        return required.isSubset(of: provided)
    }

    /// Creates a request from this template with the provided variables.
    ///
    /// - Parameters:
    ///   - variables: Variable values to substitute
    ///   - parameters: Additional request parameters
    ///   - timeout: Optional timeout for the request
    ///   - useCache: Whether to use cached responses
    /// - Returns: An `AIRequest` with the rendered prompt
    /// - Throws: `AIServiceError.validationError` if required variables are missing
    public func createRequest(
        variables: [String: String] = [:],
        parameters: [String: String] = [:],
        timeout: TimeInterval? = nil,
        useCache: Bool = true
    ) throws -> AIRequest {
        let prompt = try render(variables: variables)

        return AIRequest(
            prompt: prompt,
            parameters: parameters,
            timeout: timeout,
            useCache: useCache,
            metadata: ["template_variables": variables.map { "\($0.key)=\($0.value)" }.joined(separator: ",")]
        )
    }
}

// MARK: - Convenience Initializers

extension AIPromptTemplate {

    /// Creates a simple template from a prompt string.
    ///
    /// - Parameter prompt: The prompt string (may contain {{variables}})
    /// - Returns: A new prompt template
    public static func simple(_ prompt: String) -> AIPromptTemplate {
        return AIPromptTemplate(template: prompt)
    }

    /// Creates a template for a specific use case with common variables.
    ///
    /// - Parameters:
    ///   - template: The template string
    ///   - commonVariables: Common variable names and their default values
    /// - Returns: A new prompt template
    public static func withDefaults(
        _ template: String,
        commonVariables: [String: String]
    ) -> AIPromptTemplate {
        return AIPromptTemplate(template: template, defaultValues: commonVariables)
    }
}
