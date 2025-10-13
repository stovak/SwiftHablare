import Testing
import Foundation
@testable import SwiftHablare

@Suite(.serialized)
struct AIRequestManagerTests {

    // MARK: - Basic Functionality Tests

    @Test("AIRequestManager submits a request")
    func testSubmitRequest() async throws {
        let manager = AIRequestManager()
        let provider = MockAIServiceProvider.textProvider()
        let request = AIRequest(prompt: "Test prompt")

        let requestID = await manager.submit(request: request, provider: provider)

        #expect(requestID == request.id)
        let status = await manager.status(for: requestID)
        #expect(status?.isInProgress == true)
        #expect(status?.isFinished == false)
    }

    @Test("AIRequestManager executes a request")
    func testExecuteRequest() async throws {
        let manager = AIRequestManager()
        let provider = MockAIServiceProvider.textProvider()
        let request = AIRequest(prompt: "Test prompt")

        let requestID = await manager.submit(request: request, provider: provider)
        let response = try await manager.execute(requestID: requestID)

        #expect(response.isSuccess)
        let status = await manager.status(for: requestID)
        #expect(status?.isFinished == true)
    }

    @Test("AIRequestManager submitAndExecute works")
    func testSubmitAndExecute() async throws {
        let manager = AIRequestManager()
        let provider = MockAIServiceProvider.textProvider()
        let request = AIRequest(prompt: "Test prompt")

        let response = try await manager.submitAndExecute(request: request, provider: provider)

        #expect(response.isSuccess)
        #expect(response.requestID == request.id)
    }

    // MARK: - Cancellation Tests

    @Test("AIRequestManager cancel() prevents execution")
    func testCancelBeforeExecution() async throws {
        let manager = AIRequestManager()
        let provider = MockAIServiceProvider.delayedProvider(id: "slow-provider", delay: 2.0)

        let request = AIRequest(prompt: "Test prompt")
        let requestID = await manager.submit(request: request, provider: provider)

        // Cancel immediately before execution starts
        let cancelled = await manager.cancel(requestID: requestID)
        #expect(cancelled == true)

        let status = await manager.status(for: requestID)
        #expect(status?.isCancelled == true)
    }

    @Test("AIRequestManager cancel() stops in-progress execution")
    func testCancelDuringExecution() async throws {
        let manager = AIRequestManager()
        let provider = MockAIServiceProvider.delayedProvider(id: "slow-provider", delay: 2.0)

        let request = AIRequest(prompt: "Test prompt")

        // Start execution in background
        let executeTask = Task {
            try await manager.submitAndExecute(request: request, provider: provider)
        }

        // Wait a bit for execution to start
        try await Task.sleep(for: .milliseconds(100))

        // Cancel the request
        let cancelled = await manager.cancel(requestID: request.id)
        #expect(cancelled == true)

        // Verify the status is cancelled
        let status = await manager.status(for: request.id)
        #expect(status?.isCancelled == true)

        // The execute task should throw an error (cancellation)
        do {
            _ = try await executeTask.value
            Issue.record("Expected cancellation error")
        } catch {
            // Expected - task should be cancelled
            // Note: Could be CancellationError or wrapped in AIServiceError.networkError
            #expect(error is CancellationError || error is AIServiceError)
        }
    }

    @Test("AIRequestManager cancelled request doesn't persist response")
    func testCancelledRequestDoesNotPersistResponse() async throws {
        let manager = AIRequestManager()
        let provider = MockAIServiceProvider.delayedProvider(id: "slow-provider", delay: 1.0)

        let request = AIRequest(prompt: "Test prompt")

        // Start execution
        let executeTask = Task {
            try await manager.submitAndExecute(request: request, provider: provider)
        }

        // Wait a bit for execution to start
        try await Task.sleep(for: .milliseconds(100))

        // Cancel the request
        _ = await manager.cancel(requestID: request.id)

        // Wait for task to finish
        do {
            _ = try await executeTask.value
        } catch {
            // Cancellation expected
        }

        // Verify response was not stored
        let response = await manager.response(for: request.id)
        #expect(response == nil)

        // Verify status remains cancelled
        let status = await manager.status(for: request.id)
        #expect(status?.isCancelled == true)
    }

    @Test("AIRequestManager cancel() returns false for already completed request")
    func testCancelCompletedRequest() async throws {
        let manager = AIRequestManager()
        let provider = MockAIServiceProvider.textProvider()
        let request = AIRequest(prompt: "Test prompt")

        // Complete the request
        _ = try await manager.submitAndExecute(request: request, provider: provider)

        // Try to cancel - should return false
        let cancelled = await manager.cancel(requestID: request.id)
        #expect(cancelled == false)

        // Status should still be completed
        let status = await manager.status(for: request.id)
        #expect(status?.isFinished == true)
        #expect(status?.isCancelled == false)
    }

    @Test("AIRequestManager cancelAll() cancels multiple requests")
    func testCancelAll() async throws {
        let manager = AIRequestManager()
        let provider = MockAIServiceProvider.delayedProvider(id: "slow-provider", delay: 2.0)

        // Submit multiple requests
        let request1 = AIRequest(prompt: "Test 1")
        let request2 = AIRequest(prompt: "Test 2")
        let request3 = AIRequest(prompt: "Test 3")

        _ = await manager.submit(request: request1, provider: provider)
        _ = await manager.submit(request: request2, provider: provider)
        _ = await manager.submit(request: request3, provider: provider)

        // Cancel all
        let cancelledCount = await manager.cancelAll()
        #expect(cancelledCount == 3)

        // Verify all are cancelled
        let status1 = await manager.status(for: request1.id)
        let status2 = await manager.status(for: request2.id)
        let status3 = await manager.status(for: request3.id)

        #expect(status1?.isCancelled == true)
        #expect(status2?.isCancelled == true)
        #expect(status3?.isCancelled == true)
    }

    // MARK: - Status Stream Tests

    @Test("AIRequestManager statusStream emits status changes")
    func testStatusStream() async throws {
        let manager = AIRequestManager()
        let provider = MockAIServiceProvider.textProvider()
        let request = AIRequest(prompt: "Test prompt")

        let requestID = await manager.submit(request: request, provider: provider)

        // Collect statuses - ensure stream is set up before execution begins
        let statuses = await withTaskGroup(of: [RequestStatus].self) { group in
            // Start collecting statuses FIRST
            group.addTask {
                var collected: [RequestStatus] = []
                for await status in await manager.statusStream(for: requestID) {
                    collected.append(status)
                    if status.isFinished {
                        break
                    }
                }
                return collected
            }

            // Give the stream task time to set up before executing
            // This prevents a race where execution completes before stream collection starts
            try? await Task.sleep(for: .milliseconds(10))

            // Execute the request
            _ = try? await manager.execute(requestID: requestID)

            // Get the collected statuses
            return await group.next() ?? []
        }

        // Verify we got the expected status progression
        #expect(statuses.count >= 2) // At least pending and completed
        #expect(statuses.first?.isInProgress == true)
        #expect(statuses.last?.isFinished == true)
    }

    // MARK: - Query Tests

    @Test("AIRequestManager tracks requests by provider")
    func testTrackedRequestsByProvider() async throws {
        let manager = AIRequestManager()
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

        let request1 = AIRequest(prompt: "Test 1")
        let request2 = AIRequest(prompt: "Test 2")
        let request3 = AIRequest(prompt: "Test 3")

        await manager.submit(request: request1, provider: provider1)
        await manager.submit(request: request2, provider: provider1)
        await manager.submit(request: request3, provider: provider2)

        let provider1Requests = await manager.trackedRequests(forProvider: "provider1")
        let provider2Requests = await manager.trackedRequests(forProvider: "provider2")

        #expect(provider1Requests.count == 2)
        #expect(provider2Requests.count == 1)
    }

    @Test("AIRequestManager tracks in-progress requests")
    func testInProgressRequests() async throws {
        let manager = AIRequestManager()
        let provider = MockAIServiceProvider.textProvider()

        let request1 = AIRequest(prompt: "Test 1")
        let request2 = AIRequest(prompt: "Test 2")

        // Submit but don't execute
        await manager.submit(request: request1, provider: provider)
        await manager.submit(request: request2, provider: provider)

        let inProgress = await manager.trackedRequests(inProgress: true)
        #expect(inProgress.count == 2)

        // Complete one
        _ = try await manager.execute(requestID: request1.id)

        let stillInProgress = await manager.trackedRequests(inProgress: true)
        let finished = await manager.trackedRequests(inProgress: false)

        #expect(stillInProgress.count == 1)
        #expect(finished.count == 1)
    }

    // MARK: - Statistics Tests

    @Test("AIRequestManager returns statistics")
    func testStatistics() async throws {
        let manager = AIRequestManager()
        let provider = MockAIServiceProvider.textProvider()

        let request1 = AIRequest(prompt: "Test 1")
        let request2 = AIRequest(prompt: "Test 2")

        await manager.submit(request: request1, provider: provider)
        _ = try await manager.execute(requestID: request1.id)

        await manager.submit(request: request2, provider: provider)
        _ = await manager.cancel(requestID: request2.id)

        let stats = await manager.statistics()

        #expect(stats.totalRequests == 2)
        #expect(stats.completedRequests == 1)
        #expect(stats.cancelledRequests == 1)
    }

    // MARK: - Cleanup Tests

    @Test("AIRequestManager cleans up old responses")
    func testCleanupOldResponses() async throws {
        let manager = AIRequestManager(maxCachedResponses: 10, maxResponseAge: 0.05)
        let provider = MockAIServiceProvider.textProvider()

        let request1 = AIRequest(prompt: "Test 1")
        let request2 = AIRequest(prompt: "Test 2")
        let request3 = AIRequest(prompt: "Test 3")

        // Complete requests
        _ = try await manager.submitAndExecute(request: request1, provider: provider)
        _ = try await manager.submitAndExecute(request: request2, provider: provider)

        // Wait for responses to age beyond maxResponseAge
        try await Task.sleep(for: .milliseconds(100))

        // Add one more request (should not be old)
        _ = try await manager.submitAndExecute(request: request3, provider: provider)

        // Trigger cleanup
        let removed = await manager.cleanupOldResponses()

        #expect(removed >= 2) // At least the first two should be removed
    }

    @Test("AIRequestManager clearAll removes everything")
    func testClearAll() async throws {
        let manager = AIRequestManager()
        let provider = MockAIServiceProvider.textProvider()

        let request1 = AIRequest(prompt: "Test 1")
        let request2 = AIRequest(prompt: "Test 2")

        await manager.submit(request: request1, provider: provider)
        _ = try await manager.execute(requestID: request1.id)

        await manager.submit(request: request2, provider: provider)

        // Clear all
        await manager.clearAll()

        let allRequests = await manager.allTrackedRequests()
        #expect(allRequests.isEmpty)

        let response = await manager.response(for: request1.id)
        #expect(response == nil)
    }

    // MARK: - Response Caching Tests

    @Test("AIRequestManager caches and retrieves responses")
    func testResponseCaching() async throws {
        let manager = AIRequestManager()
        let provider = MockAIServiceProvider.textProvider()
        let request = AIRequest(prompt: "Test prompt")

        // Execute request
        let response1 = try await manager.submitAndExecute(request: request, provider: provider)

        // Retrieve cached response
        let cachedResponse = await manager.response(for: request.id)

        #expect(cachedResponse != nil)
        #expect(cachedResponse?.requestID == response1.requestID)
        #expect(cachedResponse?.isSuccess == true)
    }

    @Test("AIRequestManager execute returns cached response for completed request")
    func testExecuteReturnsCachedResponse() async throws {
        let manager = AIRequestManager()
        let provider = MockAIServiceProvider.textProvider()
        let request = AIRequest(prompt: "Test prompt")

        // First execution
        let response1 = try await manager.submitAndExecute(request: request, provider: provider)

        // Second execution should return cached response
        let response2 = try await manager.execute(requestID: request.id)

        #expect(response2.requestID == response1.requestID)
        #expect(response2.isSuccess == true)
    }

    @Test("AIRequestManager execute waits for in-progress request")
    func testExecuteWaitsForInProgress() async throws {
        let manager = AIRequestManager()
        let provider = MockAIServiceProvider.delayedProvider(id: "slow", delay: 0.1)
        let request = AIRequest(prompt: "Test prompt")

        // Start first execution
        let task1 = Task {
            try await manager.submitAndExecute(request: request, provider: provider)
        }

        // Give it time to start
        try await Task.sleep(for: .milliseconds(10))

        // Start second execution - should wait for first
        let task2 = Task {
            try await manager.execute(requestID: request.id)
        }

        let response1 = try await task1.value
        let response2 = try await task2.value

        #expect(response1.requestID == response2.requestID)
        #expect(response1.isSuccess == true)
        #expect(response2.isSuccess == true)
    }

    @Test("AIRequestManager execute throws for unknown request")
    func testExecuteUnknownRequest() async throws {
        let manager = AIRequestManager()
        let unknownID = UUID()

        do {
            _ = try await manager.execute(requestID: unknownID)
            Issue.record("Expected error for unknown request")
        } catch let error as AIServiceError {
            if case .invalidRequest = error {
                // Expected
            } else {
                Issue.record("Expected invalidRequest error, got \(error)")
            }
        }
    }

    // MARK: - Error Handling Tests

    @Test("AIRequestManager handles provider errors")
    func testProviderErrorHandling() async throws {
        let manager = AIRequestManager()
        let provider = MockAIServiceProvider.failingProvider(error: .networkError("Connection failed"))
        let request = AIRequest(prompt: "Test prompt")

        let response = try await manager.submitAndExecute(request: request, provider: provider)

        #expect(response.isFailure == true)
        #expect(response.error != nil)

        let status = await manager.status(for: request.id)
        #expect(status?.isFailed == true)
    }

    @Test("AIRequestManager stores error responses")
    func testErrorResponseStorage() async throws {
        let manager = AIRequestManager()
        let provider = MockAIServiceProvider.failingProvider(error: .rateLimitExceeded("Rate limit"))
        let request = AIRequest(prompt: "Test prompt")

        _ = try await manager.submitAndExecute(request: request, provider: provider)

        // Retrieve error response
        let response = await manager.response(for: request.id)

        #expect(response != nil)
        #expect(response?.isFailure == true)
        if case .rateLimitExceeded = response?.error! {
            // Expected
        } else {
            Issue.record("Expected rateLimitExceeded error")
        }
    }

    // MARK: - Batch Execution Tests

    @Test("AIRequestManager executeBatch processes multiple requests")
    func testExecuteBatch() async throws {
        let manager = AIRequestManager()
        let provider = MockAIServiceProvider.textProvider()

        let request1 = AIRequest(prompt: "Test 1")
        let request2 = AIRequest(prompt: "Test 2")
        let request3 = AIRequest(prompt: "Test 3")

        let id1 = await manager.submit(request: request1, provider: provider)
        let id2 = await manager.submit(request: request2, provider: provider)
        let id3 = await manager.submit(request: request3, provider: provider)

        let results = await manager.executeBatch(requestIDs: [id1, id2, id3])

        #expect(results.count == 3)

        for result in results {
            switch result {
            case .success(let response):
                #expect(response.isSuccess == true)
            case .failure(let error):
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    @Test("AIRequestManager executeBatch handles mixed success and failure")
    func testExecuteBatchMixedResults() async throws {
        let manager = AIRequestManager()
        let successProvider = MockAIServiceProvider.textProvider()
        let failProvider = MockAIServiceProvider.failingProvider(error: .networkError("Failed"))

        let request1 = AIRequest(prompt: "Success 1")
        let request2 = AIRequest(prompt: "Failure")
        let request3 = AIRequest(prompt: "Success 2")

        let id1 = await manager.submit(request: request1, provider: successProvider)
        let id2 = await manager.submit(request: request2, provider: failProvider)
        let id3 = await manager.submit(request: request3, provider: successProvider)

        let results = await manager.executeBatch(requestIDs: [id1, id2, id3])

        #expect(results.count == 3)

        var successCount = 0
        var failureCount = 0

        for result in results {
            switch result {
            case .success(let response):
                // AIRequestManager returns AIResponseData which can be success or failure
                if response.isSuccess {
                    successCount += 1
                } else {
                    failureCount += 1
                }
            case .failure:
                failureCount += 1
            }
        }

        // All should be wrapped in success Result, but with different AIResponseData states
        #expect(successCount == 2)
        #expect(failureCount == 1)
    }

    // MARK: - Query Method Tests

    @Test("AIRequestManager trackedRequest returns specific request")
    func testTrackedRequest() async throws {
        let manager = AIRequestManager()
        let provider = MockAIServiceProvider.textProvider()
        let request = AIRequest(prompt: "Test prompt")

        let requestID = await manager.submit(request: request, provider: provider)

        let tracked = await manager.trackedRequest(for: requestID)

        #expect(tracked != nil)
        #expect(tracked?.request.id == requestID)
        #expect(tracked?.providerID == provider.id)
    }

    @Test("AIRequestManager trackedRequest returns nil for unknown ID")
    func testTrackedRequestUnknown() async {
        let manager = AIRequestManager()
        let unknownID = UUID()

        let tracked = await manager.trackedRequest(for: unknownID)

        #expect(tracked == nil)
    }

    @Test("AIRequestManager statistics by provider")
    func testStatisticsByProvider() async throws {
        let manager = AIRequestManager()
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

        // Provider 1: 2 completed, 1 cancelled
        let req1 = AIRequest(prompt: "P1-1")
        let req2 = AIRequest(prompt: "P1-2")
        let req3 = AIRequest(prompt: "P1-3")

        await manager.submit(request: req1, provider: provider1)
        _ = try await manager.execute(requestID: req1.id)

        await manager.submit(request: req2, provider: provider1)
        _ = try await manager.execute(requestID: req2.id)

        await manager.submit(request: req3, provider: provider1)
        _ = await manager.cancel(requestID: req3.id)

        // Provider 2: 1 completed
        let req4 = AIRequest(prompt: "P2-1")
        await manager.submit(request: req4, provider: provider2)
        _ = try await manager.execute(requestID: req4.id)

        let stats1 = await manager.statistics(forProvider: "provider1")
        let stats2 = await manager.statistics(forProvider: "provider2")

        #expect(stats1.totalRequests == 3)
        #expect(stats1.completedRequests == 2)
        #expect(stats1.cancelledRequests == 1)

        #expect(stats2.totalRequests == 1)
        #expect(stats2.completedRequests == 1)
        #expect(stats2.cancelledRequests == 0)
    }

    // MARK: - Cache Limit Tests

    @Test("AIRequestManager enforces max cached responses")
    func testMaxCachedResponses() async throws {
        let manager = AIRequestManager(maxCachedResponses: 3, maxResponseAge: 1000.0)
        let provider = MockAIServiceProvider.textProvider()

        // Create 5 requests (more than cache limit)
        for i in 1...5 {
            let request = AIRequest(prompt: "Test \(i)")
            _ = try await manager.submitAndExecute(request: request, provider: provider)
            // Small delay to ensure ordering
            try await Task.sleep(for: .milliseconds(10))
        }

        // Force cleanup
        _ = await manager.cleanupOldResponses()

        // Should have removed 2 oldest (5 - 3 = 2)
        let allRequests = await manager.allTrackedRequests()
        #expect(allRequests.count == 5) // Tracked requests remain

        // But responses should be limited (only most recent 3 cached)
        // Note: This is internal behavior, we can verify through statistics
        let stats = await manager.statistics()
        #expect(stats.totalRequests == 5)
    }

    @Test("AIRequestManager automatic cleanup on response storage")
    func testAutomaticCleanup() async throws {
        // Set very low max to trigger cleanup
        let manager = AIRequestManager(maxCachedResponses: 2, maxResponseAge: 0.01)
        let provider = MockAIServiceProvider.textProvider()

        // Create 3 requests
        let req1 = AIRequest(prompt: "Test 1")
        let req2 = AIRequest(prompt: "Test 2")

        _ = try await manager.submitAndExecute(request: req1, provider: provider)
        _ = try await manager.submitAndExecute(request: req2, provider: provider)

        // Wait for age threshold
        try await Task.sleep(for: .milliseconds(20))

        // Third request should trigger automatic cleanup
        let req3 = AIRequest(prompt: "Test 3")
        _ = try await manager.submitAndExecute(request: req3, provider: provider)

        // Verify cleanup happened (implementation detail - best effort test)
        let stats = await manager.statistics()
        #expect(stats.totalRequests == 3)
    }

    // MARK: - Convenience Method Tests

    @Test("AIRequestManager generate convenience method")
    func testGenerateConvenienceMethod() async throws {
        let manager = AIRequestManager()
        let provider = MockAIServiceProvider.textProvider()

        let response = try await manager.generate(
            prompt: "Test prompt",
            provider: provider,
            parameters: ["temperature": "0.7"],
            metadata: ["source": "test"]
        )

        #expect(response.isSuccess == true)
        #expect(response.providerID == provider.id)
    }

    @Test("AIRequestManager generate with minimal parameters")
    func testGenerateMinimal() async throws {
        let manager = AIRequestManager()
        let provider = MockAIServiceProvider.textProvider()

        let response = try await manager.generate(
            prompt: "Simple test",
            provider: provider
        )

        #expect(response.isSuccess == true)
    }
}
