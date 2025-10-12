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

        // Collect statuses
        let statuses = await withTaskGroup(of: [RequestStatus].self) { group in
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
}
