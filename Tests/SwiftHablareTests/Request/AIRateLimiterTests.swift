import Testing
import Foundation
@testable import SwiftHablare

struct AIRateLimiterTests {

    @Test("AIRateLimiter initializes with correct configuration")
    func testInitialization() async {
        let limiter = AIRateLimiter(maxRequests: 100, timeWindow: 60.0)

        let tokens = await limiter.availableTokens()
        let stats = await limiter.statistics()

        #expect(tokens == 100)
        #expect(stats.maxRequests == 100)
        #expect(stats.timeWindowSeconds == 60.0)
    }

    @Test("AIRateLimiter grants permission when tokens available")
    func testGrantsPermission() async {
        let limiter = AIRateLimiter(maxRequests: 10, timeWindow: 60.0)

        let tokensBefore = await limiter.availableTokens()
        await limiter.waitForPermission()
        let tokensAfter = await limiter.availableTokens()

        #expect(tokensBefore == 10)
        #expect(tokensAfter == 9)
    }

    @Test("AIRateLimiter tryAcquire succeeds when tokens available")
    func testTryAcquireSuccess() async {
        let limiter = AIRateLimiter(maxRequests: 10, timeWindow: 60.0)

        let granted = await limiter.tryAcquire()

        #expect(granted == true)
        #expect(await limiter.availableTokens() == 9)
    }

    @Test("AIRateLimiter tryAcquire fails when no tokens available")
    func testTryAcquireFails() async {
        let limiter = AIRateLimiter(maxRequests: 1, timeWindow: 60.0)

        _ = await limiter.tryAcquire()
        let granted = await limiter.tryAcquire()

        #expect(granted == false)
        #expect(await limiter.availableTokens() == 0)
    }

    @Test("AIRateLimiter refills tokens over time")
    func testTokenRefill() async {
        let limiter = AIRateLimiter(maxRequests: 10, timeWindow: 1.0) // 10 tokens per second

        // Use all tokens
        for _ in 0..<10 {
            _ = await limiter.tryAcquire()
        }

        #expect(await limiter.availableTokens() == 0)

        // Wait for refill
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        let tokensAfter = await limiter.availableTokens()
        #expect(tokensAfter >= 1) // Should have refilled at least 1 token
    }

    @Test("AIRateLimiter doesn't exceed max tokens")
    func testMaxTokensLimit() async {
        let limiter = AIRateLimiter(maxRequests: 5, timeWindow: 1.0)

        // Wait for potential overfill
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        let tokens = await limiter.availableTokens()
        #expect(tokens <= 5) // Should not exceed max
    }

    @Test("AIRateLimiter handles concurrent requests")
    func testConcurrentRequests() async {
        let limiter = AIRateLimiter(maxRequests: 10, timeWindow: 60.0)

        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    await limiter.waitForPermission()
                    return true
                }
            }

            var completed = 0
            for await _ in group {
                completed += 1
            }

            #expect(completed == 5)
        }

        #expect(await limiter.availableTokens() == 5)
    }

    @Test("AIRateLimiter waits when no tokens available")
    func testWaitForPermission() async {
        let limiter = AIRateLimiter(maxRequests: 2, timeWindow: 1.0) // 2 tokens per second

        // Use all tokens
        await limiter.waitForPermission()
        await limiter.waitForPermission()

        #expect(await limiter.availableTokens() == 0)

        // This should wait for refill
        let startTime = Date()
        await limiter.waitForPermission()
        let elapsed = Date().timeIntervalSince(startTime)

        #expect(elapsed > 0.1) // Should have waited
    }

    @Test("AIRateLimiter reset restores full capacity")
    func testReset() async {
        let limiter = AIRateLimiter(maxRequests: 10, timeWindow: 60.0)

        // Use some tokens
        for _ in 0..<5 {
            _ = await limiter.tryAcquire()
        }

        #expect(await limiter.availableTokens() == 5)

        await limiter.reset()

        #expect(await limiter.availableTokens() == 10)
    }

    @Test("AIRateLimiter estimatedWaitTime returns zero with tokens")
    func testEstimatedWaitTimeWithTokens() async {
        let limiter = AIRateLimiter(maxRequests: 10, timeWindow: 60.0)

        let waitTime = await limiter.estimatedWaitTime()

        #expect(waitTime == 0.0)
    }

    @Test("AIRateLimiter estimatedWaitTime calculates delay")
    func testEstimatedWaitTimeNoTokens() async {
        let limiter = AIRateLimiter(maxRequests: 60, timeWindow: 60.0) // 1 per second

        // Use all tokens
        for _ in 0..<60 {
            _ = await limiter.tryAcquire()
        }

        let waitTime = await limiter.estimatedWaitTime()

        #expect(waitTime > 0.0)
        #expect(waitTime <= 2.0) // Should be around 1 second
    }

    @Test("AIRateLimiter statistics reflect current state")
    func testStatistics() async {
        let limiter = AIRateLimiter(maxRequests: 100, timeWindow: 60.0)

        // Use some tokens
        for _ in 0..<25 {
            _ = await limiter.tryAcquire()
        }

        let stats = await limiter.statistics()

        #expect(stats.availableTokens == 75)
        #expect(stats.maxRequests == 100)
        #expect(stats.timeWindowSeconds == 60.0)
        #expect(stats.queueLength == 0)
    }

    @Test("AIRateLimiter openAI preset configuration")
    func testOpenAIPreset() async {
        let limiter = AIRateLimiter.openAI()

        let stats = await limiter.statistics()

        #expect(stats.maxRequests == 500)
        #expect(stats.timeWindowSeconds == 60.0)
    }

    @Test("AIRateLimiter anthropic preset configuration")
    func testAnthropicPreset() async {
        let limiter = AIRateLimiter.anthropic()

        let stats = await limiter.statistics()

        #expect(stats.maxRequests == 50)
        #expect(stats.timeWindowSeconds == 60.0)
    }

    @Test("AIRateLimiter elevenLabs preset configuration")
    func testElevenLabsPreset() async {
        let limiter = AIRateLimiter.elevenLabs()

        let stats = await limiter.statistics()

        #expect(stats.maxRequests == 300)
        #expect(stats.timeWindowSeconds == 60.0)
    }

    @Test("AIRateLimiter unlimited preset never blocks")
    func testUnlimitedPreset() async {
        let limiter = AIRateLimiter.unlimited()

        // Try to acquire many tokens
        for _ in 0..<1000 {
            let granted = await limiter.tryAcquire()
            #expect(granted == true)
        }

        let tokens = await limiter.availableTokens()
        #expect(tokens > 0) // Should still have tokens
    }

    @Test("AIRateLimiter handles rapid sequential requests")
    func testRapidSequentialRequests() async {
        let limiter = AIRateLimiter(maxRequests: 100, timeWindow: 60.0)

        for i in 0..<50 {
            let granted = await limiter.tryAcquire()
            #expect(granted == true)
            #expect(await limiter.availableTokens() == 100 - (i + 1))
        }
    }

    @Test("AIRateLimiter queue length increases when waiting")
    func testQueueLength() async {
        let limiter = AIRateLimiter(maxRequests: 1, timeWindow: 10.0) // Very slow refill

        // Use the one token
        _ = await limiter.tryAcquire()

        // Start tasks that will wait
        let task1 = Task {
            await limiter.waitForPermission()
        }

        let task2 = Task {
            await limiter.waitForPermission()
        }

        // Give tasks time to queue
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        let stats = await limiter.statistics()

        #expect(stats.queueLength > 0) // Should have waiting tasks

        // Reset to release waiting tasks
        await limiter.reset()

        await task1.value
        await task2.value
    }

    @Test("AIRateLimiter is Sendable")
    func testSendable() async {
        let limiter = AIRateLimiter(maxRequests: 10, timeWindow: 60.0)

        await Task {
            // Should compile without warnings
            await limiter.waitForPermission()
        }.value
    }
}
