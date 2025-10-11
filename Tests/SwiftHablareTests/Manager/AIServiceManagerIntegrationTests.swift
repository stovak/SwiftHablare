import Testing
import SwiftData
import Foundation
@testable import SwiftHablare

@Suite(.serialized)
struct AIServiceManagerIntegrationTests {

    // MARK: - Test Model

    @Model
    final class TestProduct {
        var name: String = ""
        var productDescription: String = ""
        var price: Double = 0.0

        init(name: String = "", productDescription: String = "", price: Double = 0.0) {
            self.name = name
            self.productDescription = productDescription
            self.price = price
        }
    }

    // MARK: - Lifecycle Tests

    @Test("Provider lifecycle: register → query → use → unregister")
    func testProviderLifecycle() async throws {
        let manager = AIServiceManager.shared
        await manager.unregisterAll()

        // 1. Register
        let provider = MockAIServiceProvider.textProvider()
        try await manager.register(provider: provider)

        // 2. Query
        let retrieved = await manager.provider(withID: provider.id)
        #expect(retrieved != nil)

        // 3. Use
        let result = try await retrieved!.generate(
            prompt: "Test",
            parameters: [:],
            context: try ModelContext(ModelContainer(for: TestProduct.self))
        )
        #expect(!result.isEmpty)

        // 4. Unregister
        await manager.unregister(providerID: provider.id)
        #expect(await manager.provider(withID: provider.id) == nil)

        await manager.unregisterAll()
    }

    @Test("Multiple providers can be registered and queried simultaneously")
    func testMultipleProvidersSimultaneously() async throws {
        let manager = AIServiceManager.shared
        await manager.unregisterAll()

        let providers = [
            MockAIServiceProvider(id: "provider-1", displayName: "Provider 1", capabilities: [.textGeneration], requiresAPIKey: false),
            MockAIServiceProvider(id: "provider-2", displayName: "Provider 2", capabilities: [.imageGeneration], requiresAPIKey: false),
            MockAIServiceProvider(id: "provider-3", displayName: "Provider 3", capabilities: [.audioGeneration], requiresAPIKey: false),
            MockAIServiceProvider(id: "provider-4", displayName: "Provider 4", capabilities: [.textGeneration, .imageGeneration], requiresAPIKey: false)
        ]

        try await manager.registerAll(providers: providers)

        // All should be registered
        #expect(await manager.providerCount() == 4)

        // Query by different capabilities
        let textProviders = await manager.providers(withCapability: .textGeneration)
        #expect(textProviders.count == 2) // provider-1 and provider-4

        let imageProviders = await manager.providers(withCapability: .imageGeneration)
        #expect(imageProviders.count == 2) // provider-2 and provider-4

        let audioProviders = await manager.providers(withCapability: .audioGeneration)
        #expect(audioProviders.count == 1) // provider-3

        await manager.unregisterAll()
    }

    @Test("Provider replacement updates all indices correctly")
    func testProviderReplacementUpdatesIndices() async throws {
        let manager = AIServiceManager.shared
        await manager.unregisterAll()

        // Register provider with text capability
        let provider1 = MockAIServiceProvider(
            id: "test-provider",
            displayName: "Provider 1",
            capabilities: [.textGeneration],
            requiresAPIKey: false
        )
        try await manager.register(provider: provider1)

        // Verify it's queryable by text capability
        var textProviders = await manager.providers(withCapability: .textGeneration)
        #expect(textProviders.count == 1)

        var imageProviders = await manager.providers(withCapability: .imageGeneration)
        #expect(imageProviders.isEmpty)

        // Replace with provider having image capability instead
        let provider2 = MockAIServiceProvider(
            id: "test-provider", // Same ID
            displayName: "Provider 2",
            capabilities: [.imageGeneration], // Different capability
            requiresAPIKey: false
        )
        try await manager.register(provider: provider2)

        // Should now be queryable by image capability, not text
        textProviders = await manager.providers(withCapability: .textGeneration)
        #expect(textProviders.isEmpty)

        imageProviders = await manager.providers(withCapability: .imageGeneration)
        #expect(imageProviders.count == 1)

        await manager.unregisterAll()
    }

    // MARK: - Complex Query Tests

    @Test("Complex capability query with multiple providers")
    func testComplexCapabilityQuery() async throws {
        let manager = AIServiceManager.shared
        await manager.unregisterAll()

        let providers = [
            MockAIServiceProvider(id: "text-only", displayName: "Text Only", capabilities: [.textGeneration], requiresAPIKey: false),
            MockAIServiceProvider(id: "image-only", displayName: "Image Only", capabilities: [.imageGeneration], requiresAPIKey: false),
            MockAIServiceProvider(id: "text-image", displayName: "Text & Image", capabilities: [.textGeneration, .imageGeneration], requiresAPIKey: false),
            MockAIServiceProvider(id: "text-audio", displayName: "Text & Audio", capabilities: [.textGeneration, .audioGeneration], requiresAPIKey: false),
            MockAIServiceProvider(id: "all-three", displayName: "All Three", capabilities: [.textGeneration, .imageGeneration, .audioGeneration], requiresAPIKey: false)
        ]

        try await manager.registerAll(providers: providers)

        // Query for text + image
        let textImageProviders = await manager.providers(withCapabilities: [.textGeneration, .imageGeneration])
        #expect(textImageProviders.count == 2) // text-image and all-three

        // Query for all three
        let allThreeProviders = await manager.providers(withCapabilities: [.textGeneration, .imageGeneration, .audioGeneration])
        #expect(allThreeProviders.count == 1) // all-three

        // Query for text only (single capability)
        let textProviders = await manager.providers(withCapabilities: [.textGeneration])
        #expect(textProviders.count == 4) // All except image-only

        await manager.unregisterAll()
    }

    @Test("Model type query with multiple providers")
    func testModelTypeQuery() async throws {
        let manager = AIServiceManager.shared
        await manager.unregisterAll()

        let provider1 = MockAIServiceProvider(
            id: "provider-1",
            displayName: "Provider 1",
            capabilities: [.textGeneration],
            supportedDataStructures: [
                .model(TestProduct.self, properties: [
                    .property(\TestProduct.name, name: "name"),
                    .property(\TestProduct.productDescription, name: "productDescription")
                ])
            ],
            requiresAPIKey: false
        )

        let provider2 = MockAIServiceProvider(
            id: "provider-2",
            displayName: "Provider 2",
            capabilities: [.textGeneration],
            supportedDataStructures: [
                .model(TestProduct.self, properties: [
                    .property(\TestProduct.productDescription, name: "productDescription")
                ])
            ],
            requiresAPIKey: false
        )

        let provider3 = MockAIServiceProvider(
            id: "provider-3",
            displayName: "Provider 3",
            capabilities: [.textGeneration],
            supportedDataStructures: [], // No model support
            requiresAPIKey: false
        )

        try await manager.registerAll(providers: [provider1, provider2, provider3])

        let productProviders = await manager.providers(forModel: TestProduct.self)
        #expect(productProviders.count == 2) // provider-1 and provider-2

        await manager.unregisterAll()
    }

    // MARK: - Edge Cases

    @Test("Empty capability array returns all providers")
    func testEmptyCapabilityArray() async throws {
        let manager = AIServiceManager.shared
        await manager.unregisterAll()

        let providers = [
            MockAIServiceProvider.textProvider(),
            MockAIServiceProvider.imageProvider()
        ]

        try await manager.registerAll(providers: providers)

        let allProviders = await manager.providers(withCapabilities: [])
        #expect(allProviders.count == 2)

        await manager.unregisterAll()
    }

    @Test("Query for non-existent capability returns empty array")
    func testNonExistentCapabilityQuery() async throws {
        let manager = AIServiceManager.shared
        await manager.unregisterAll()

        try await manager.register(provider: MockAIServiceProvider.textProvider())

        let providers = await manager.providers(withCapability: .imageGeneration)
        #expect(providers.isEmpty)

        await manager.unregisterAll()
    }

    @Test("Query for non-existent model type returns empty array")
    func testNonExistentModelTypeQuery() async {
        let manager = AIServiceManager.shared
        await manager.unregisterAll()

        let providers = await manager.providers(forModelType: "NonExistentModel")
        #expect(providers.isEmpty)
    }

    // MARK: - Statistics Integration

    @Test("Statistics reflect accurate provider state")
    func testStatisticsAccuracy() async throws {
        let manager = AIServiceManager.shared
        await manager.unregisterAll()

        // Add diverse providers
        let providers = [
            MockAIServiceProvider(id: "p1", displayName: "P1", capabilities: [.textGeneration], requiresAPIKey: false),
            MockAIServiceProvider(id: "p2", displayName: "P2", capabilities: [.textGeneration, .imageGeneration], requiresAPIKey: false),
            MockAIServiceProvider(id: "p3", displayName: "P3", capabilities: [.audioGeneration], requiresAPIKey: false)
        ]

        try await manager.registerAll(providers: providers)

        let stats = await manager.statistics()

        #expect(stats["total_providers"] == 3)
        #expect(stats["capability_textGeneration"] == 2)
        #expect(stats["capability_imageGeneration"] == 1)
        #expect(stats["capability_audioGeneration"] == 1)

        await manager.unregisterAll()
    }
}
