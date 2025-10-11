import Testing
import Foundation
@testable import SwiftHablare

@Suite(.serialized)
struct AIResponseCacheTests {

    // MARK: - Basic Cache Operations

    @Test("AIResponseCache stores and retrieves values")
    func testStoreAndRetrieve() async {
        let cache = AIResponseCache()

        let testValue = "Test Response"
        await cache.set(testValue, providerId: "openai", prompt: "Hello", parameters: [:])

        let retrieved = await cache.get(providerId: "openai", prompt: "Hello", parameters: [:])
        #expect(retrieved?.value as? String == testValue)
    }

    @Test("AIResponseCache returns nil for non-existent entries")
    func testGetNonExistent() async {
        let cache = AIResponseCache()

        let retrieved = await cache.get(providerId: "openai", prompt: "NonExistent", parameters: [:])
        #expect(retrieved == nil)
    }

    @Test("AIResponseCache overwrites existing entries")
    func testOverwriteEntry() async {
        let cache = AIResponseCache()

        await cache.set("First", providerId: "openai", prompt: "Test", parameters: [:])
        await cache.set("Second", providerId: "openai", prompt: "Test", parameters: [:])

        let retrieved = await cache.get(providerId: "openai", prompt: "Test", parameters: [:])
        #expect(retrieved?.value as? String == "Second")
    }

    // MARK: - Cache Keys

    @Test("AIResponseCache differentiates by provider ID")
    func testDifferentiateByProvider() async {
        let cache = AIResponseCache()

        await cache.set("OpenAI Response", providerId: "openai", prompt: "Test", parameters: [:])
        await cache.set("Anthropic Response", providerId: "anthropic", prompt: "Test", parameters: [:])

        let openaiValue = await cache.get(providerId: "openai", prompt: "Test", parameters: [:])
        let anthropicValue = await cache.get(providerId: "anthropic", prompt: "Test", parameters: [:])

        #expect(openaiValue?.value as? String == "OpenAI Response")
        #expect(anthropicValue?.value as? String == "Anthropic Response")
    }

    @Test("AIResponseCache differentiates by prompt")
    func testDifferentiateByPrompt() async {
        let cache = AIResponseCache()

        await cache.set("Response 1", providerId: "openai", prompt: "Prompt 1", parameters: [:])
        await cache.set("Response 2", providerId: "openai", prompt: "Prompt 2", parameters: [:])

        let value1 = await cache.get(providerId: "openai", prompt: "Prompt 1", parameters: [:])
        let value2 = await cache.get(providerId: "openai", prompt: "Prompt 2", parameters: [:])

        #expect(value1?.value as? String == "Response 1")
        #expect(value2?.value as? String == "Response 2")
    }

    @Test("AIResponseCache differentiates by parameters")
    func testDifferentiateByParameters() async {
        let cache = AIResponseCache()

        await cache.set("Low Temp", providerId: "openai", prompt: "Test", parameters: ["temperature": "0.3"])
        await cache.set("High Temp", providerId: "openai", prompt: "Test", parameters: ["temperature": "0.9"])

        let lowTemp = await cache.get(providerId: "openai", prompt: "Test", parameters: ["temperature": "0.3"])
        let highTemp = await cache.get(providerId: "openai", prompt: "Test", parameters: ["temperature": "0.9"])

        #expect(lowTemp?.value as? String == "Low Temp")
        #expect(highTemp?.value as? String == "High Temp")
    }

    // MARK: - Expiration

    @Test("AIResponseCache expires old entries")
    func testExpiration() async throws {
        let cache = AIResponseCache(maxEntries: 100, ttl: 0.1, enabled: true) // 0.1 second TTL

        await cache.set("Test Value", providerId: "openai", prompt: "Test", parameters: [:])

        // Immediately should be available
        var retrieved = await cache.get(providerId: "openai", prompt: "Test", parameters: [:])
        #expect(retrieved?.value as? String == "Test Value")

        // Wait for expiration
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms

        // Should be expired
        retrieved = await cache.get(providerId: "openai", prompt: "Test", parameters: [:])
        #expect(retrieved == nil)
    }

    // MARK: - Size Limits

    @Test("AIResponseCache evicts oldest entries when full")
    func testEviction() async {
        let cache = AIResponseCache(maxEntries: 3, ttl: 3600, enabled: true)

        // Add 4 entries (max is 3)
        await cache.set("Value 1", providerId: "provider1", prompt: "Test", parameters: [:])
        await cache.set("Value 2", providerId: "provider2", prompt: "Test", parameters: [:])
        await cache.set("Value 3", providerId: "provider3", prompt: "Test", parameters: [:])
        await cache.set("Value 4", providerId: "provider4", prompt: "Test", parameters: [:])

        // Oldest (Value 1) should be evicted
        let value1 = await cache.get(providerId: "provider1", prompt: "Test", parameters: [:])
        let value4 = await cache.get(providerId: "provider4", prompt: "Test", parameters: [:])

        #expect(value1 == nil)
        #expect(value4?.value as? String == "Value 4")

        // Check count
        let count = await cache.count()
        #expect(count == 3)
    }

    // MARK: - Invalidation

    @Test("AIResponseCache invalidates by provider")
    func testInvalidateByProvider() async {
        let cache = AIResponseCache()

        await cache.set("Response 1", providerId: "openai", prompt: "Test 1", parameters: [:])
        await cache.set("Response 2", providerId: "openai", prompt: "Test 2", parameters: [:])
        await cache.set("Response 3", providerId: "anthropic", prompt: "Test 3", parameters: [:])

        await cache.invalidate(providerId: "openai")

        let value1 = await cache.get(providerId: "openai", prompt: "Test 1", parameters: [:])
        let value2 = await cache.get(providerId: "openai", prompt: "Test 2", parameters: [:])
        let value3 = await cache.get(providerId: "anthropic", prompt: "Test 3", parameters: [:])

        #expect(value1 == nil)
        #expect(value2 == nil)
        #expect(value3?.value as? String == "Response 3")
    }

    @Test("AIResponseCache invalidates by prompt")
    func testInvalidateByPrompt() async {
        let cache = AIResponseCache()

        await cache.set("Response 1", providerId: "openai", prompt: "Test Prompt", parameters: [:])
        await cache.set("Response 2", providerId: "anthropic", prompt: "Test Prompt", parameters: [:])
        await cache.set("Response 3", providerId: "openai", prompt: "Other Prompt", parameters: [:])

        await cache.invalidate(prompt: "Test Prompt")

        let value1 = await cache.get(providerId: "openai", prompt: "Test Prompt", parameters: [:])
        let value2 = await cache.get(providerId: "anthropic", prompt: "Test Prompt", parameters: [:])
        let value3 = await cache.get(providerId: "openai", prompt: "Other Prompt", parameters: [:])

        #expect(value1 == nil)
        #expect(value2 == nil)
        #expect(value3?.value as? String == "Response 3")
    }

    @Test("AIResponseCache clears all entries")
    func testClear() async {
        let cache = AIResponseCache()

        await cache.set("Response 1", providerId: "openai", prompt: "Test 1", parameters: [:])
        await cache.set("Response 2", providerId: "anthropic", prompt: "Test 2", parameters: [:])

        var count = await cache.count()
        #expect(count == 2)

        await cache.clear()

        count = await cache.count()
        #expect(count == 0)

        let value1 = await cache.get(providerId: "openai", prompt: "Test 1", parameters: [:])
        #expect(value1 == nil)
    }

    // MARK: - Enable/Disable

    @Test("AIResponseCache can be disabled")
    func testDisableCache() async {
        let cache = AIResponseCache(enabled: false)

        await cache.set("Test Value", providerId: "openai", prompt: "Test", parameters: [:])

        let retrieved = await cache.get(providerId: "openai", prompt: "Test", parameters: [:])
        #expect(retrieved == nil)
    }

    @Test("AIResponseCache can be dynamically disabled")
    func testDynamicallyDisable() async {
        let cache = AIResponseCache(enabled: true)

        await cache.set("Test Value", providerId: "openai", prompt: "Test", parameters: [:])

        var retrieved = await cache.get(providerId: "openai", prompt: "Test", parameters: [:])
        #expect(retrieved?.value as? String == "Test Value")

        // Disable cache
        await cache.setEnabled(false)

        // Setting disabled should clear cache
        let count = await cache.count()
        #expect(count == 0)

        // New sets should not work
        await cache.set("New Value", providerId: "openai", prompt: "Test", parameters: [:])
        retrieved = await cache.get(providerId: "openai", prompt: "Test", parameters: [:])
        #expect(retrieved == nil)
    }

    // MARK: - Statistics

    @Test("AIResponseCache reports statistics")
    func testStatistics() async {
        let cache = AIResponseCache(maxEntries: 50, ttl: 7200)

        await cache.set("Value 1", providerId: "openai", prompt: "Test 1", parameters: [:])
        await cache.set("Value 2", providerId: "anthropic", prompt: "Test 2", parameters: [:])

        let stats = await cache.statistics()

        #expect(stats["total_entries"] == 2)
        #expect(stats["max_entries"] == 50)
        #expect(stats["ttl_seconds"] == 7200)
    }

    // MARK: - Complex Value Types

    @Test("AIResponseCache stores complex types")
    func testComplexTypes() async {
        let cache = AIResponseCache()

        let testData = Data("Test".utf8)
        await cache.set(testData, providerId: "openai", prompt: "Test", parameters: [:])

        let retrieved = await cache.get(providerId: "openai", prompt: "Test", parameters: [:])
        #expect(retrieved?.value as? Data == testData)
    }

    @Test("AIResponseCache stores dictionaries")
    func testDictionaries() async {
        let cache = AIResponseCache()

        let testDict: [String: Any] = ["key": "value", "number": 42]
        await cache.set(testDict, providerId: "openai", prompt: "Test", parameters: [:])

        let retrieved = await cache.get(providerId: "openai", prompt: "Test", parameters: [:])
        #expect(retrieved != nil)
    }
}
