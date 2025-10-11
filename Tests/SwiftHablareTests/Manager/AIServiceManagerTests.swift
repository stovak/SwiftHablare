import Testing
import SwiftData
import Foundation
@testable import SwiftHablare

@Suite(.serialized)
struct AIServiceManagerTests {

    // MARK: - Test Setup

    /// Creates a fresh manager instance for isolated testing.
    func createManager() -> AIServiceManager {
        // Note: Cannot use shared instance for tests as it's persistent
        // For now, we'll test the shared instance with cleanup
        return AIServiceManager.shared
    }

    /// Test model for SwiftData integration.
    @Model
    final class TestArticle {
        var title: String = ""
        var content: String = ""

        init(title: String = "", content: String = "") {
            self.title = title
            self.content = content
        }
    }

    // MARK: - Registration Tests

    @Test("AIServiceManager can register a provider")
    func testProviderRegistration() async throws {
        let manager = createManager()
        await manager.unregisterAll()

        let provider = MockAIServiceProvider.textProvider()

        try await manager.register(provider: provider)

        let retrieved = await manager.provider(withID: provider.id)
        #expect(retrieved != nil)
        #expect(retrieved?.id == provider.id)
        #expect(retrieved?.displayName == provider.displayName)

        await manager.unregisterAll()
    }

    @Test("AIServiceManager can register multiple providers")
    func testMultipleProviderRegistration() async throws {
        let manager = createManager()
        await manager.unregisterAll()

        // Wait for cleanup to complete
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        let textProvider = MockAIServiceProvider.textProvider()
        let imageProvider = MockAIServiceProvider.imageProvider()
        let audioProvider = MockAIServiceProvider.audioProvider()

        try await manager.register(provider: textProvider)
        try await manager.register(provider: imageProvider)
        try await manager.register(provider: audioProvider)

        let count = await manager.providerCount()
        #expect(count == 3)

        await manager.unregisterAll()
    }

    @Test("AIServiceManager registerAll() works correctly")
    func testRegisterAll() async throws {
        let manager = createManager()
        await manager.unregisterAll()

        let providers = [
            MockAIServiceProvider.textProvider(),
            MockAIServiceProvider.imageProvider(),
            MockAIServiceProvider.audioProvider()
        ]

        try await manager.registerAll(providers: providers)

        let count = await manager.providerCount()
        #expect(count == 3)

        await manager.unregisterAll()
    }

    @Test("AIServiceManager replaces existing provider with same ID")
    func testProviderReplacement() async throws {
        let manager = createManager()
        await manager.unregisterAll()

        let provider1 = MockAIServiceProvider.textProvider()
        try await manager.register(provider: provider1)

        // Register another provider with same ID
        let provider2 = MockAIServiceProvider(
            id: provider1.id, // Same ID
            displayName: "Updated Provider",
            capabilities: [.textGeneration],
            requiresAPIKey: false
        )
        try await manager.register(provider: provider2)

        let count = await manager.providerCount()
        #expect(count == 1)

        let retrieved = await manager.provider(withID: provider1.id)
        #expect(retrieved?.displayName == "Updated Provider")

        await manager.unregisterAll()
    }

    // MARK: - Unregistration Tests

    @Test("AIServiceManager can unregister a provider")
    func testProviderUnregistration() async throws {
        let manager = createManager()
        await manager.unregisterAll()

        let provider = MockAIServiceProvider.textProvider()
        try await manager.register(provider: provider)

        #expect(await manager.isRegistered(providerID: provider.id))

        await manager.unregister(providerID: provider.id)

        #expect(await !manager.isRegistered(providerID: provider.id))
        #expect(await manager.provider(withID: provider.id) == nil)

        await manager.unregisterAll()
    }

    @Test("AIServiceManager unregisterAll() removes all providers")
    func testUnregisterAll() async throws {
        let manager = createManager()
        await manager.unregisterAll()

        let providers = [
            MockAIServiceProvider.textProvider(),
            MockAIServiceProvider.imageProvider(),
            MockAIServiceProvider.audioProvider()
        ]

        try await manager.registerAll(providers: providers)
        #expect(await manager.providerCount() == 3)

        await manager.unregisterAll()
        #expect(await manager.providerCount() == 0)
    }

    @Test("AIServiceManager unregister() with non-existent ID is safe")
    func testUnregisterNonExistentProvider() async throws {
        let manager = createManager()
        await manager.unregisterAll()

        // Wait for cleanup to complete
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Should not crash or throw
        await manager.unregister(providerID: "non-existent-provider")

        #expect(await manager.providerCount() == 0)
    }

    // MARK: - Query Tests

    @Test("AIServiceManager can query by provider ID")
    func testQueryByID() async throws {
        let manager = createManager()
        await manager.unregisterAll()

        let provider = MockAIServiceProvider.textProvider()
        try await manager.register(provider: provider)

        let retrieved = await manager.provider(withID: provider.id)
        #expect(retrieved != nil)
        #expect(retrieved?.id == provider.id)

        await manager.unregisterAll()
    }

    @Test("AIServiceManager returns nil for unknown provider ID")
    func testQueryUnknownID() async {
        let manager = createManager()
        await manager.unregisterAll()

        let retrieved = await manager.provider(withID: "unknown-provider")
        #expect(retrieved == nil)
    }

    @Test("AIServiceManager can query all providers")
    func testQueryAllProviders() async throws {
        let manager = createManager()
        await manager.unregisterAll()

        let providers = [
            MockAIServiceProvider.textProvider(),
            MockAIServiceProvider.imageProvider(),
            MockAIServiceProvider.audioProvider()
        ]

        try await manager.registerAll(providers: providers)

        let allProviders = await manager.allProviders()
        #expect(allProviders.count == 3)

        await manager.unregisterAll()
    }

    // MARK: - Capability Query Tests

    @Test("AIServiceManager can query providers by capability")
    func testQueryByCapability() async throws {
        let manager = createManager()
        await manager.unregisterAll()

        let textProvider = MockAIServiceProvider.textProvider()
        let imageProvider = MockAIServiceProvider.imageProvider()

        try await manager.register(provider: textProvider)
        try await manager.register(provider: imageProvider)

        let textProviders = await manager.providers(withCapability: .textGeneration)
        #expect(textProviders.count == 1)
        #expect(textProviders.first?.id == textProvider.id)

        let imageProviders = await manager.providers(withCapability: .imageGeneration)
        #expect(imageProviders.count == 1)
        #expect(imageProviders.first?.id == imageProvider.id)

        await manager.unregisterAll()
    }

    @Test("AIServiceManager can query providers by multiple capabilities")
    func testQueryByMultipleCapabilities() async throws {
        let manager = createManager()
        await manager.unregisterAll()

        // Provider supporting multiple capabilities
        let multiCapProvider = MockAIServiceProvider(
            id: "multi-cap",
            displayName: "Multi Capability Provider",
            capabilities: [.textGeneration, .imageGeneration],
            requiresAPIKey: false
        )

        let textOnly = MockAIServiceProvider.textProvider()

        try await manager.register(provider: multiCapProvider)
        try await manager.register(provider: textOnly)

        let multiCapProviders = await manager.providers(
            withCapabilities: [.textGeneration, .imageGeneration]
        )

        #expect(multiCapProviders.count == 1)
        #expect(multiCapProviders.first?.id == multiCapProvider.id)

        await manager.unregisterAll()
    }

    @Test("AIServiceManager hasProvider(withCapability:) works correctly")
    func testHasProviderWithCapability() async throws {
        let manager = createManager()
        await manager.unregisterAll()

        #expect(await !manager.hasProvider(withCapability: .textGeneration))

        let textProvider = MockAIServiceProvider.textProvider()
        try await manager.register(provider: textProvider)

        #expect(await manager.hasProvider(withCapability: .textGeneration))
        #expect(await !manager.hasProvider(withCapability: .imageGeneration))

        await manager.unregisterAll()
    }

    // MARK: - Model Type Query Tests

    @Test("AIServiceManager can query providers by model type name")
    func testQueryByModelTypeName() async throws {
        let manager = createManager()
        await manager.unregisterAll()

        let provider = MockAIServiceProvider(
            id: "model-provider",
            displayName: "Model Provider",
            capabilities: [.textGeneration],
            supportedDataStructures: [
                .model(TestArticle.self, properties: [
                    .property(\TestArticle.title, name: "title")
                ])
            ],
            requiresAPIKey: false
        )

        try await manager.register(provider: provider)

        let modelTypeName = String(describing: TestArticle.self)
        let providers = await manager.providers(forModelType: modelTypeName)

        #expect(providers.count == 1)
        #expect(providers.first?.id == provider.id)

        await manager.unregisterAll()
    }

    @Test("AIServiceManager can query providers by model type")
    func testQueryByModelType() async throws {
        let manager = createManager()
        await manager.unregisterAll()

        let provider = MockAIServiceProvider(
            id: "model-provider",
            displayName: "Model Provider",
            capabilities: [.textGeneration],
            supportedDataStructures: [
                .model(TestArticle.self, properties: [
                    .property(\TestArticle.title, name: "title")
                ])
            ],
            requiresAPIKey: false
        )

        try await manager.register(provider: provider)

        let providers = await manager.providers(forModel: TestArticle.self)

        #expect(providers.count == 1)
        #expect(providers.first?.id == provider.id)

        await manager.unregisterAll()
    }

    // MARK: - Statistics Tests

    @Test("AIServiceManager providerCount() is accurate")
    func testProviderCount() async throws {
        let manager = createManager()
        await manager.unregisterAll()

        #expect(await manager.providerCount() == 0)

        try await manager.register(provider: MockAIServiceProvider.textProvider())
        #expect(await manager.providerCount() == 1)

        try await manager.register(provider: MockAIServiceProvider.imageProvider())
        #expect(await manager.providerCount() == 2)

        await manager.unregisterAll()
        #expect(await manager.providerCount() == 0)
    }

    @Test("AIServiceManager statistics() provides accurate data")
    func testStatistics() async throws {
        let manager = createManager()
        await manager.unregisterAll()

        try await manager.register(provider: MockAIServiceProvider.textProvider())
        try await manager.register(provider: MockAIServiceProvider.imageProvider())

        let stats = await manager.statistics()

        #expect(stats["total_providers"] == 2)
        #expect(stats["capability_textGeneration"] == 1)
        #expect(stats["capability_imageGeneration"] == 1)

        await manager.unregisterAll()
    }

    // MARK: - Validation Tests

    @Test("AIServiceManager validates provider configuration on registration")
    func testConfigurationValidation() async throws {
        let manager = createManager()
        await manager.unregisterAll()

        let unconfiguredProvider = MockAIServiceProvider.unconfiguredProvider()

        do {
            try await manager.register(provider: unconfiguredProvider)
            Issue.record("Expected configuration error")
        } catch let error as AIServiceError {
            if case .configurationError = error {
                // Expected
            } else {
                Issue.record("Expected configurationError, got \(error)")
            }
        }

        await manager.unregisterAll()
    }

    // MARK: - Index Consistency Tests

    @Test("AIServiceManager maintains consistent capability index")
    func testCapabilityIndexConsistency() async throws {
        let manager = createManager()
        await manager.unregisterAll()

        let provider = MockAIServiceProvider.textProvider()
        try await manager.register(provider: provider)

        // Provider should be queryable by capability
        let providers = await manager.providers(withCapability: .textGeneration)
        #expect(providers.count == 1)

        // After unregistration, capability index should be clean
        await manager.unregister(providerID: provider.id)

        let providersAfter = await manager.providers(withCapability: .textGeneration)
        #expect(providersAfter.isEmpty)

        await manager.unregisterAll()
    }

    @Test("AIServiceManager maintains consistent model type index")
    func testModelTypeIndexConsistency() async throws {
        let manager = createManager()
        await manager.unregisterAll()

        let provider = MockAIServiceProvider(
            id: "model-provider",
            displayName: "Model Provider",
            capabilities: [.textGeneration],
            supportedDataStructures: [
                .model(TestArticle.self, properties: [])
            ],
            requiresAPIKey: false
        )

        try await manager.register(provider: provider)

        // Provider should be queryable by model type
        let providers = await manager.providers(forModel: TestArticle.self)
        #expect(providers.count == 1)

        // After unregistration, model type index should be clean
        await manager.unregister(providerID: provider.id)

        let providersAfter = await manager.providers(forModel: TestArticle.self)
        #expect(providersAfter.isEmpty)

        await manager.unregisterAll()
    }
}
