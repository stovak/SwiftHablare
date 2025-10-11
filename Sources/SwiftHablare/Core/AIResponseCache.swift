import Foundation
import SwiftData
import CryptoKit

/// In-memory cache for AI-generated responses to avoid duplicate API calls.
///
/// The cache uses a combination of provider ID, prompt, and parameters to generate
/// cache keys. Cached responses expire after a configurable time period.
///
/// ## Example
/// ```swift
/// let cache = AIResponseCache()
///
/// // Check cache before making API call
/// if let cached = await cache.get(providerId: "openai", prompt: "Hello", parameters: [:]) {
///     return cached
/// }
///
/// // Make API call and cache result
/// let response = try await provider.generate(...)
/// await cache.set(response, providerId: "openai", prompt: "Hello", parameters: [:])
/// ```
@available(macOS 15.0, iOS 17.0, *)
public actor AIResponseCache {

    // MARK: - Types

    /// A cached response entry.
    private struct CacheEntry: Sendable {
        let value: AnySendable
        let timestamp: Date
        let providerId: String
        let prompt: String
        let parameters: [String: String]

        /// Checks if this entry has expired.
        func isExpired(after duration: TimeInterval) -> Bool {
            return Date().timeIntervalSince(timestamp) > duration
        }
    }

    /// Type-erased Sendable wrapper for cache values.
    public struct AnySendable: @unchecked Sendable {
        public let value: Any

        public init(_ value: Any) {
            self.value = value
        }
    }

    // MARK: - Properties

    /// The cache storage.
    private var cache: [String: CacheEntry] = [:]

    /// Maximum number of entries in the cache.
    private let maxEntries: Int

    /// Time-to-live for cache entries (in seconds).
    private let ttl: TimeInterval

    /// Whether caching is enabled.
    private var isEnabled: Bool

    // MARK: - Initialization

    /// Creates a new response cache.
    ///
    /// - Parameters:
    ///   - maxEntries: Maximum number of entries to store (default: 100)
    ///   - ttl: Time-to-live for entries in seconds (default: 3600 = 1 hour)
    ///   - enabled: Whether caching is enabled (default: true)
    public init(maxEntries: Int = 100, ttl: TimeInterval = 3600, enabled: Bool = true) {
        self.maxEntries = maxEntries
        self.ttl = ttl
        self.isEnabled = enabled
    }

    // MARK: - Cache Operations

    /// Retrieves a cached response if available and not expired.
    ///
    /// - Parameters:
    ///   - providerId: The provider ID
    ///   - prompt: The prompt text
    ///   - parameters: The request parameters (only String values supported for Sendable compliance)
    /// - Returns: The cached value wrapped in AnySendable, or nil if not found or expired
    public func get(providerId: String, prompt: String, parameters: [String: String]) -> AnySendable? {
        guard isEnabled else { return nil }

        let key = generateKey(providerId: providerId, prompt: prompt, parameters: parameters)

        guard let entry = cache[key] else {
            return nil
        }

        // Check if expired
        if entry.isExpired(after: ttl) {
            cache.removeValue(forKey: key)
            return nil
        }

        return entry.value
    }

    /// Stores a value in the cache.
    ///
    /// - Parameters:
    ///   - value: The value to cache
    ///   - providerId: The provider ID
    ///   - prompt: The prompt text
    ///   - parameters: The request parameters (only String values supported for Sendable compliance)
    public func set(_ value: Any, providerId: String, prompt: String, parameters: [String: String]) {
        guard isEnabled else { return }

        let key = generateKey(providerId: providerId, prompt: prompt, parameters: parameters)

        let entry = CacheEntry(
            value: AnySendable(value),
            timestamp: Date(),
            providerId: providerId,
            prompt: prompt,
            parameters: parameters
        )

        cache[key] = entry

        // Evict oldest entries if cache is full
        if cache.count > maxEntries {
            evictOldest()
        }
    }

    /// Invalidates all cached entries for a specific provider.
    ///
    /// - Parameter providerId: The provider ID
    public func invalidate(providerId: String) {
        cache = cache.filter { $0.value.providerId != providerId }
    }

    /// Invalidates all cached entries matching a specific prompt.
    ///
    /// - Parameter prompt: The prompt text
    public func invalidate(prompt: String) {
        cache = cache.filter { $0.value.prompt != prompt }
    }

    /// Clears all cached entries.
    public func clear() {
        cache.removeAll()
    }

    /// Returns the number of entries in the cache.
    public func count() -> Int {
        return cache.count
    }

    /// Enables or disables caching.
    ///
    /// - Parameter enabled: Whether to enable caching
    public func setEnabled(_ enabled: Bool) {
        self.isEnabled = enabled
        if !enabled {
            clear()
        }
    }

    /// Returns cache statistics.
    ///
    /// - Returns: Dictionary with cache statistics
    public func statistics() -> [String: Int] {
        return [
            "total_entries": cache.count,
            "max_entries": maxEntries,
            "ttl_seconds": Int(ttl)
        ]
    }

    // MARK: - Private Methods

    /// Generates a cache key from provider ID, prompt, and parameters.
    private func generateKey(providerId: String, prompt: String, parameters: [String: String]) -> String {
        // Create a deterministic string representation
        var components: [String] = [providerId, prompt]

        // Sort parameters by key for deterministic hashing
        let sortedKeys = parameters.keys.sorted()
        for key in sortedKeys {
            let value = parameters[key] ?? ""
            components.append("\(key)=\(value)")
        }

        let combined = components.joined(separator: "|")

        // Hash the combined string
        let data = Data(combined.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Evicts the oldest cache entries to maintain the max entries limit.
    private func evictOldest() {
        let entriesToRemove = cache.count - maxEntries
        guard entriesToRemove > 0 else { return }

        // Sort by timestamp and remove oldest
        let sorted = cache.sorted { $0.value.timestamp < $1.value.timestamp }
        for (key, _) in sorted.prefix(entriesToRemove) {
            cache.removeValue(forKey: key)
        }
    }
}
