import Foundation

/// Context tracking for a single scene in the screenplay
///
/// Maintains state about which characters have spoken in the current scene,
/// used for determining when character announcements are needed.
public struct SceneContext {
    /// The scene identifier
    public var sceneID: String

    /// Set of normalized character names who have spoken in this scene
    public var charactersWhoHaveSpoken: Set<String> = []

    /// The last character who spoke (normalized name)
    public var lastSpeaker: String?

    public init(sceneID: String = "") {
        self.sceneID = sceneID
    }

    /// Mark a character as having spoken in this scene
    public mutating func markCharacterSpoken(_ name: String) {
        charactersWhoHaveSpoken.insert(name)
    }

    /// Check if a character has already spoken in this scene
    public func hasCharacterSpoken(_ name: String) -> Bool {
        charactersWhoHaveSpoken.contains(name)
    }
}
