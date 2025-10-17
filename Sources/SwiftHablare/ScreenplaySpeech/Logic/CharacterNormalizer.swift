import Foundation

/// Normalizes character names from their screenplay representation to a consistent format.
///
/// This handles common screenplay modifiers like (V.O.), (O.S.), and (CONT'D), as well
/// as case normalization and whitespace handling.
public final class CharacterNormalizer {

    /// User-defined aliases for mapping character variations to normalized names
    /// Example: ["YOUNG JOHN": "john", "JOHN (V.O.)": "john"]
    public var userDefinedAliases: [String: String] = [:]

    public init() {}

    /// Normalize a character name from its screenplay representation
    ///
    /// - Parameter rawName: The raw character name from the screenplay (e.g., "JOHN (V.O.)")
    /// - Returns: Normalized character name (e.g., "john")
    public func normalize(_ rawName: String) -> String {
        // Check user-defined aliases first
        if let alias = userDefinedAliases[rawName] {
            return alias
        }

        // Remove common screenplay modifiers
        // Matches patterns like (V.O.), (O.S.), (CONT'D), etc.
        let pattern = #/\s*\([^)]+\)\s*/#
        let withoutModifiers = rawName.replacing(pattern, with: "")

        // Trim whitespace and lowercase for consistency
        let normalized = withoutModifiers
            .trimmingCharacters(in: CharacterSet.whitespaces)
            .lowercased()

        return normalized
    }
}
