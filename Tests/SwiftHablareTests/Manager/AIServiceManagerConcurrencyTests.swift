import Testing
import SwiftData
import Foundation
@testable import SwiftHablare

@Suite(.serialized)
struct AIServiceManagerConcurrencyTests {

    // MARK: - Concurrent Registration Tests

    @Test("AIServiceManager handles concurrent registration safely")
    func testConcurrentRegistration() async throws {
        let manager = AIServiceManager.shared
        await manager.unregisterAll()

        // Wait a bit longer to ensure cleanup completes in CI
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Register 50 providers concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    let provider = MockAIServiceProvider(
                        id: "provider-\(i)",
                        displayName: "Provider \(i)",
                        capabilities: [.textGeneration],
                        requiresAPIKey: false
                    )
                    do {
                        try await manager.register(provider: provider)
                    } catch {
                        // Ignore errors for concurrent registration stress test
                    }
                }
            }
        }

        let count = await manager.providerCount()
        #expect(count == 50)

        await manager.unregisterAll()
    }

    @Test("AIServiceManager handles concurrent unregistration safely")
    func testConcurrentUnregistration() async throws {
        let manager = AIServiceManager.shared
        await manager.unregisterAll()

        // Wait a bit longer to ensure cleanup completes in CI
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Register providers first
        let providers = (0..<50).map { i in
            MockAIServiceProvider(
                id: "provider-\(i)",
                displayName: "Provider \(i)",
                capabilities: [.textGeneration],
                requiresAPIKey: false
            )
        }

        for provider in providers {
            try await manager.register(provider: provider)
        }

        // Wait a bit to ensure all registrations are fully complete
        try await Task.sleep(nanoseconds: 20_000_000) // 20ms

        let countBefore = await manager.providerCount()
        #expect(countBefore == 50)

        // Unregister all concurrently
        await withTaskGroup(of: Void.self) { group in
            for provider in providers {
                group.addTask {
                    await manager.unregister(providerID: provider.id)
                }
            }
        }

        let count = await manager.providerCount()
        #expect(count == 0)
    }

    @Test("AIServiceManager handles concurrent mixed operations safely")
    func testConcurrentMixedOperations() async throws {
        let manager = AIServiceManager.shared
        await manager.unregisterAll()

        // Perform mixed operations concurrently
        await withTaskGroup(of: Void.self) { group in
            // Registrations
            for i in 0..<20 {
                group.addTask {
                    let provider = MockAIServiceProvider(
                        id: "provider-\(i)",
                        displayName: "Provider \(i)",
                        capabilities: [.textGeneration],
                        requiresAPIKey: false
                    )
                    try? await manager.register(provider: provider)
                }
            }

            // Queries
            for _ in 0..<20 {
                group.addTask {
                    let _ = await manager.allProviders()
                    let _ = await manager.providers(withCapability: .textGeneration)
                }
            }

            // Statistics
            for _ in 0..<10 {
                group.addTask {
                    let _ = await manager.statistics()
                    let _ = await manager.providerCount()
                }
            }
        }

        // System should remain consistent
        let finalCount = await manager.providerCount()
        #expect(finalCount >= 0)
        #expect(finalCount <= 20)

        await manager.unregisterAll()
    }

    @Test("AIServiceManager handles concurrent queries safely")
    func testConcurrentQueries() async throws {
        let manager = AIServiceManager.shared
        await manager.unregisterAll()

        // Register some providers
        try await manager.registerAll(providers: [
            MockAIServiceProvider.textProvider(),
            MockAIServiceProvider.imageProvider(),
            MockAIServiceProvider.audioProvider()
        ])

        // Perform many concurrent queries
        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    let providers = await manager.allProviders()
                    return providers.count
                }

                group.addTask {
                    let providers = await manager.providers(withCapability: .textGeneration)
                    return providers.count
                }

                group.addTask {
                    return await manager.providerCount()
                }
            }

            // All queries should return consistent results
            for await count in group {
                #expect(count >= 0)
                #expect(count <= 3)
            }
        }

        await manager.unregisterAll()
    }

    // MARK: - Registration/Unregistration Race Conditions

    @Test("AIServiceManager handles registration/unregistration races")
    func testRegistrationUnregistrationRace() async throws {
        let manager = AIServiceManager.shared
        await manager.unregisterAll()

        let providerID = "race-provider"

        // Concurrently register and unregister the same provider
        await withTaskGroup(of: Void.self) { group in
            // Register repeatedly
            for _ in 0..<50 {
                group.addTask {
                    let provider = MockAIServiceProvider(
                        id: providerID,
                        displayName: "Race Provider",
                        capabilities: [.textGeneration],
                        requiresAPIKey: false
                    )
                    try? await manager.register(provider: provider)
                }
            }

            // Unregister repeatedly
            for _ in 0..<50 {
                group.addTask {
                    await manager.unregister(providerID: providerID)
                }
            }
        }

        // Final state should be consistent (either registered or not)
        let isRegistered = await manager.isRegistered(providerID: providerID)
        if isRegistered {
            let provider = await manager.provider(withID: providerID)
            #expect(provider != nil)
        } else {
            let provider = await manager.provider(withID: providerID)
            #expect(provider == nil)
        }

        await manager.unregisterAll()
    }

    // MARK: - Index Consistency Under Concurrency

    @Test("AIServiceManager maintains index consistency under concurrent access")
    func testIndexConsistencyUnderConcurrency() async throws {
        let manager = AIServiceManager.shared
        await manager.unregisterAll()

        // Register and unregister providers concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<30 {
                group.addTask {
                    let provider = MockAIServiceProvider(
                        id: "provider-\(i)",
                        displayName: "Provider \(i)",
                        capabilities: [.textGeneration, .imageGeneration],
                        requiresAPIKey: false
                    )
                    try? await manager.register(provider: provider)

                    // Immediately unregister half of them
                    if i % 2 == 0 {
                        await manager.unregister(providerID: provider.id)
                    }
                }
            }
        }

        // Verify indices are consistent
        let textProviders = await manager.providers(withCapability: .textGeneration)
        let imageProviders = await manager.providers(withCapability: .imageGeneration)
        let allProviders = await manager.allProviders()

        // Text and image provider counts should match all providers (both support both capabilities)
        #expect(textProviders.count == allProviders.count)
        #expect(imageProviders.count == allProviders.count)

        // Verify each provider is actually queryable
        for provider in allProviders {
            let retrieved = await manager.provider(withID: provider.id)
            #expect(retrieved != nil)
        }

        await manager.unregisterAll()
    }

    // MARK: - Performance Under Load

    @Test("AIServiceManager handles high concurrent load")
    func testPerformanceUnderLoad() async throws {
        let manager = AIServiceManager.shared
        await manager.unregisterAll()

        // Wait a tiny bit to ensure cleanup completes
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Register 100 providers concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let provider = MockAIServiceProvider(
                        id: "provider-\(i)",
                        displayName: "Provider \(i)",
                        capabilities: [.textGeneration],
                        requiresAPIKey: false
                    )
                    do {
                        try await manager.register(provider: provider)
                    } catch {
                        // Ignore errors for concurrent registration stress test
                    }
                }
            }
        }

        // Verify all providers were registered successfully
        let registeredCount = await manager.providerCount()
        #expect(registeredCount == 100)

        // Perform 1000 concurrent queries - verify functional correctness, not timing
        var queryCounts: [Int] = []
        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<1000 {
                group.addTask {
                    let providers = await manager.providers(withCapability: .textGeneration)
                    return providers.count
                }
            }

            for await count in group {
                queryCounts.append(count)
            }
        }

        // All queries should return consistent results (100 providers)
        #expect(queryCounts.allSatisfy { $0 == 100 })

        // Verify final state is still correct
        let finalCount = await manager.providerCount()
        #expect(finalCount == 100)

        await manager.unregisterAll()
    }

    // MARK: - Singleton Consistency

    @Test("AIServiceManager shared instance is consistent across concurrent access")
    func testSharedInstanceConsistency() async throws {
        let manager1 = AIServiceManager.shared
        let manager2 = AIServiceManager.shared

        await manager1.unregisterAll()

        let provider = MockAIServiceProvider.textProvider()
        try await manager1.register(provider: provider)

        // Both references should see the same provider
        let count1 = await manager1.providerCount()
        let count2 = await manager2.providerCount()

        #expect(count1 == count2)
        #expect(count1 == 1)

        let retrieved1 = await manager1.provider(withID: provider.id)
        let retrieved2 = await manager2.provider(withID: provider.id)

        #expect(retrieved1 != nil)
        #expect(retrieved2 != nil)

        await manager1.unregisterAll()

        #expect(await manager2.providerCount() == 0)
    }
}
