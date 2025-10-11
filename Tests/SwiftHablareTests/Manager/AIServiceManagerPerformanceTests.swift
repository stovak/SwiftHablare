import Testing
import SwiftData
import Foundation
@testable import SwiftHablare

/// Performance tests for AIServiceManager.
///
/// These tests measure performance characteristics and are tracked separately
/// from functional tests. They do not fail builds but report metrics for tracking.
@Suite(.serialized, .tags(.performance))
struct AIServiceManagerPerformanceTests {

    // MARK: - Performance Metrics Output

    /// Writes performance metrics in JSON format for GitHub Actions tracking.
    private func recordPerformanceMetric(
        name: String,
        value: Double,
        unit: String,
        lowerIsBetter: Bool = true
    ) {
        let metric = PerformanceMetric(
            name: name,
            value: value,
            unit: unit,
            lowerIsBetter: lowerIsBetter
        )

        // Write to stdout in a format that can be parsed by CI
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(metric),
           let json = String(data: data, encoding: .utf8) {
            print("PERFORMANCE_METRIC: \(json)")
        }
    }

    // MARK: - Performance Tests

    @Test("Measures concurrent registration performance", .tags(.performance))
    func measureConcurrentRegistration() async throws {
        let manager = AIServiceManager.shared
        await manager.unregisterAll()

        // Wait for cleanup
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        let providerCount = 100
        let startTime = ContinuousClock.now

        // Register providers concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<providerCount {
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
        }

        let duration = ContinuousClock.now - startTime
        let durationMs = Double(duration.components.attoseconds) / 1_000_000_000_000_000

        // Record metrics
        recordPerformanceMetric(
            name: "concurrent_registration_100_providers",
            value: durationMs,
            unit: "ms",
            lowerIsBetter: true
        )

        recordPerformanceMetric(
            name: "concurrent_registration_avg_per_provider",
            value: durationMs / Double(providerCount),
            unit: "ms",
            lowerIsBetter: true
        )

        // Verify correctness (but don't fail on performance)
        let count = await manager.providerCount()
        #expect(count == providerCount)

        await manager.unregisterAll()
    }

    @Test("Measures concurrent query performance", .tags(.performance))
    func measureConcurrentQueries() async throws {
        let manager = AIServiceManager.shared
        await manager.unregisterAll()

        // Register test providers
        let providers = [
            MockAIServiceProvider.textProvider(),
            MockAIServiceProvider.imageProvider(),
            MockAIServiceProvider.audioProvider()
        ]
        try await manager.registerAll(providers: providers)

        let queryCount = 1000
        let startTime = ContinuousClock.now

        // Perform concurrent queries
        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<queryCount {
                group.addTask {
                    let providers = await manager.providers(withCapability: .textGeneration)
                    return providers.count
                }
            }

            // Consume results
            for await _ in group {}
        }

        let duration = ContinuousClock.now - startTime
        let durationMs = Double(duration.components.attoseconds) / 1_000_000_000_000_000

        // Record metrics
        recordPerformanceMetric(
            name: "concurrent_queries_1000_queries",
            value: durationMs,
            unit: "ms",
            lowerIsBetter: true
        )

        recordPerformanceMetric(
            name: "concurrent_queries_avg_per_query",
            value: durationMs / Double(queryCount),
            unit: "ms",
            lowerIsBetter: true
        )

        await manager.unregisterAll()
    }

    @Test("Measures high load performance with mixed operations", .tags(.performance))
    func measureHighLoadMixedOperations() async throws {
        let manager = AIServiceManager.shared
        await manager.unregisterAll()

        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        let startTime = ContinuousClock.now

        // Perform mixed operations
        await withTaskGroup(of: Void.self) { group in
            // 100 registrations
            for i in 0..<100 {
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

            // 1000 queries
            for _ in 0..<1000 {
                group.addTask {
                    let _ = await manager.providers(withCapability: .textGeneration)
                }
            }

            // 100 statistics calls
            for _ in 0..<100 {
                group.addTask {
                    let _ = await manager.statistics()
                }
            }
        }

        let duration = ContinuousClock.now - startTime
        let durationMs = Double(duration.components.attoseconds) / 1_000_000_000_000_000

        // Record metrics
        recordPerformanceMetric(
            name: "high_load_mixed_operations",
            value: durationMs,
            unit: "ms",
            lowerIsBetter: true
        )

        // Verify system remained consistent
        let finalCount = await manager.providerCount()
        #expect(finalCount >= 0)
        #expect(finalCount <= 100)

        await manager.unregisterAll()
    }
}

// MARK: - Performance Metric Model

/// Represents a performance metric for tracking.
struct PerformanceMetric: Codable, Sendable {
    let name: String
    let value: Double
    let unit: String
    let lowerIsBetter: Bool
}

// MARK: - Test Tags

extension Tag {
    @Tag static var performance: Self
}
