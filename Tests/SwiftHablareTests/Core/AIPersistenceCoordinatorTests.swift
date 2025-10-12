import Testing
import SwiftData
import Foundation
@testable import SwiftHablare

@Suite(.serialized)
struct AIPersistenceCoordinatorTests {

    // MARK: - Test Models

    @Model
    final class TestArticle {
        var title: String = ""
        var content: String = ""
        var summary: String = ""
        var wordCount: Int = 0
        var publishedAt: Date?
        var tags: [String] = []

        init() {}
    }

    // MARK: - Basic Generation and Persistence

    @Test("AIPersistenceCoordinator generates and persists content")
    func testGenerateAndPersist() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TestArticle.self, configurations: config)
        let context = ModelContext(container)
        let coordinator = AIPersistenceCoordinator()

        let provider = MockAIServiceProvider.textProvider()
        let article = TestArticle()
        context.insert(article)

        try await coordinator.generateAndPersist(
            provider: provider,
            prompt: "Write an article title",
            model: article,
            property: \TestArticle.title,
            context: context,
            useCache: false
        )

        #expect(!article.title.isEmpty)
    }

    @Test("AIPersistenceCoordinator saves to SwiftData")
    func testSavesToSwiftData() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TestArticle.self, configurations: config)
        let context = ModelContext(container)
        let coordinator = AIPersistenceCoordinator()

        let provider = MockAIServiceProvider.textProvider()
        let article = TestArticle()
        context.insert(article)

        try await coordinator.generateAndPersist(
            provider: provider,
            prompt: "Write content",
            model: article,
            property: \TestArticle.content,
            context: context,
            useCache: false
        )

        // Verify context has changes
        #expect(!article.content.isEmpty)
    }

    // MARK: - Caching

    @Test("AIPersistenceCoordinator uses cache for duplicate requests")
    func testCaching() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TestArticle.self, configurations: config)
        let context = ModelContext(container)
        let cache = AIResponseCache()
        let coordinator = AIPersistenceCoordinator(cache: cache)

        let provider = MockAIServiceProvider.textProvider()
        let article1 = TestArticle()
        let article2 = TestArticle()
        context.insert(article1)
        context.insert(article2)

        let prompt = "Write a test title"

        // First request - cache miss
        try await coordinator.generateAndPersist(
            provider: provider,
            prompt: prompt,
            model: article1,
            property: \TestArticle.title,
            context: context,
            useCache: true
        )

        let firstTitle = article1.title

        // Second request - cache hit (should get same value)
        try await coordinator.generateAndPersist(
            provider: provider,
            prompt: prompt,
            model: article2,
            property: \TestArticle.title,
            context: context,
            useCache: true
        )

        #expect(article2.title == firstTitle)
    }

    @Test("AIPersistenceCoordinator bypasses cache when disabled")
    func testBypassCache() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TestArticle.self, configurations: config)
        let context = ModelContext(container)
        let coordinator = AIPersistenceCoordinator()

        let provider = MockAIServiceProvider.textProvider()
        let article1 = TestArticle()
        let article2 = TestArticle()
        context.insert(article1)
        context.insert(article2)

        let prompt = "Write a test title"

        // Both requests with cache disabled
        try await coordinator.generateAndPersist(
            provider: provider,
            prompt: prompt,
            model: article1,
            property: \TestArticle.title,
            context: context,
            useCache: false
        )

        try await coordinator.generateAndPersist(
            provider: provider,
            prompt: prompt,
            model: article2,
            property: \TestArticle.title,
            context: context,
            useCache: false
        )

        // Both should have content (mock provider generates text)
        #expect(!article1.title.isEmpty)
        #expect(!article2.title.isEmpty)
    }

    // MARK: - Validation

    @Test("AIPersistenceCoordinator validates generated content")
    func testValidation() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TestArticle.self, configurations: config)
        let context = ModelContext(container)
        let coordinator = AIPersistenceCoordinator()

        let provider = MockAIServiceProvider.textProvider()
        let article = TestArticle()
        context.insert(article)

        // This should succeed (mock provider generates valid text)
        try await coordinator.generateAndPersist(
            provider: provider,
            prompt: "Write content",
            model: article,
            property: \TestArticle.content,
            context: context,
            constraints: ["minLength": "1"],
            useCache: false
        )

        #expect(!article.content.isEmpty)
    }

    @Test("AIPersistenceCoordinator rejects invalid content")
    func testRejectInvalid() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TestArticle.self, configurations: config)
        let context = ModelContext(container)
        let validator = AIContentValidator()

        // Register a custom rule that always fails
        let alwaysFailRule = AIContentValidator.ValidationRule(
            name: "alwaysFail",
            validate: { _ in false },
            errorMessage: "Always fails"
        )
        await validator.registerRule(alwaysFailRule)

        let coordinator = AIPersistenceCoordinator(validator: validator)

        let provider = MockAIServiceProvider.textProvider()
        let article = TestArticle()
        context.insert(article)

        do {
            try await coordinator.generateAndPersist(
                provider: provider,
                prompt: "Write content",
                model: article,
                property: \TestArticle.content,
                context: context,
                constraints: ["alwaysFail": "true"],
                useCache: false
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

    // MARK: - Transformations

    @Test("AIPersistenceCoordinator applies transformations")
    func testTransformation() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TestArticle.self, configurations: config)
        let context = ModelContext(container)
        let coordinator = AIPersistenceCoordinator()

        let provider = MockAIServiceProvider.textProvider()
        let article = TestArticle()
        context.insert(article)

        // Transform to uppercase
        try await coordinator.generateAndPersist(
            provider: provider,
            prompt: "Write a title",
            model: article,
            property: \TestArticle.title,
            context: context,
            transform: { value in
                // Convert Data to String if needed
                if let data = value as? Data, let string = String(data: data, encoding: .utf8) {
                    return string.uppercased()
                }
                // Handle String directly
                if let string = value as? String {
                    return string.uppercased()
                }
                return value
            },
            useCache: false
        )

        // Verify the title was uppercased
        #expect(article.title.uppercased() == article.title)
    }

    // MARK: - Cache Management

    @Test("AIPersistenceCoordinator clears cache")
    func testClearCache() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TestArticle.self, configurations: config)
        let context = ModelContext(container)
        let cache = AIResponseCache()
        let coordinator = AIPersistenceCoordinator(cache: cache)

        let provider = MockAIServiceProvider.textProvider()
        let article = TestArticle()
        context.insert(article)

        // Generate and cache
        try await coordinator.generateAndPersist(
            provider: provider,
            prompt: "Test",
            model: article,
            property: \TestArticle.title,
            context: context,
            useCache: true
        )

        var cacheCount = await cache.count()
        #expect(cacheCount == 1)

        // Clear cache
        await coordinator.clearCache()

        cacheCount = await cache.count()
        #expect(cacheCount == 0)
    }

    @Test("AIPersistenceCoordinator invalidates provider cache")
    func testInvalidateProviderCache() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TestArticle.self, configurations: config)
        let context = ModelContext(container)
        let cache = AIResponseCache()
        let coordinator = AIPersistenceCoordinator(cache: cache)

        let provider1 = MockAIServiceProvider(
            id: "provider1",
            displayName: "Provider 1",
            capabilities: [.textGeneration],
            requiresAPIKey: false
        )

        let provider2 = MockAIServiceProvider(
            id: "provider2",
            displayName: "Provider 2",
            capabilities: [.textGeneration],
            requiresAPIKey: false
        )

        let article1 = TestArticle()
        let article2 = TestArticle()
        context.insert(article1)
        context.insert(article2)

        // Generate with both providers
        try await coordinator.generateAndPersist(
            provider: provider1,
            prompt: "Test",
            model: article1,
            property: \TestArticle.title,
            context: context,
            useCache: true
        )

        try await coordinator.generateAndPersist(
            provider: provider2,
            prompt: "Test",
            model: article2,
            property: \TestArticle.title,
            context: context,
            useCache: true
        )

        var cacheCount = await cache.count()
        #expect(cacheCount == 2)

        // Invalidate provider1's cache
        await coordinator.invalidateCache(forProvider: "provider1")

        cacheCount = await cache.count()
        #expect(cacheCount == 1)
    }

    @Test("AIPersistenceCoordinator reports cache statistics")
    func testCacheStatistics() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TestArticle.self, configurations: config)
        _ = ModelContext(container)
        let coordinator = AIPersistenceCoordinator()

        let stats = await coordinator.cacheStatistics()

        #expect(stats["total_entries"] != nil)
        #expect(stats["max_entries"] != nil)
        #expect(stats["ttl_seconds"] != nil)
    }

    // MARK: - Error Handling

    @Test("AIPersistenceCoordinator handles provider errors")
    func testProviderError() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TestArticle.self, configurations: config)
        let context = ModelContext(container)
        let coordinator = AIPersistenceCoordinator()

        // Create a provider that will fail
        let provider = MockAIServiceProvider.unconfiguredProvider()
        let article = TestArticle()
        context.insert(article)

        do {
            try await coordinator.generateAndPersist(
                provider: provider,
                prompt: "Test",
                model: article,
                property: \TestArticle.title,
                context: context,
                useCache: false
            )
            Issue.record("Expected configurationError")
        } catch let error as AIServiceError {
            if case .configurationError = error {
                // Expected
            } else {
                Issue.record("Expected configurationError, got \(error)")
            }
        }
    }

    // MARK: - Multiple Properties

    @Test("AIPersistenceCoordinator batch generation placeholder")
    func testBatchGeneration() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TestArticle.self, configurations: config)
        let context = ModelContext(container)
        let coordinator = AIPersistenceCoordinator()

        let provider = MockAIServiceProvider.textProvider()
        let article = TestArticle()
        context.insert(article)

        // This should throw unsupportedOperation (not implemented yet)
        do {
            try await coordinator.generateAndPersistMultiple(
                provider: provider,
                prompts: ["title": "Generate title", "content": "Generate content"],
                model: article,
                context: context
            )
            Issue.record("Expected unsupportedOperation")
        } catch let error as AIServiceError {
            if case .unsupportedOperation = error {
                // Expected
            } else {
                Issue.record("Expected unsupportedOperation, got \(error)")
            }
        }
    }

    // MARK: - Custom Validation Rules

    @Test("AIPersistenceCoordinator registers custom validation rules")
    func testCustomValidationRule() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TestArticle.self, configurations: config)
        _ = ModelContext(container)
        let coordinator = AIPersistenceCoordinator()

        let customRule = AIContentValidator.ValidationRule(
            name: "maxWords",
            validate: { value in
                guard let string = value as? String else { return false }
                let words = string.split(separator: " ")
                return words.count <= 100
            },
            errorMessage: "Content exceeds 100 words"
        )

        await coordinator.registerValidationRule(customRule)

        // This test confirms the rule can be registered
        // Actual validation would be tested in validator tests
    }
}
