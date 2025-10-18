//
//  AIRequestStatusTests.swift
//  SwiftHablareTests
//
//  Phase 3: Tests for RequestStatus, TrackedRequest, and RequestStatistics
//

import XCTest
@testable import SwiftHablare

final class AIRequestStatusTests: XCTestCase {

    // MARK: - RequestStatus Tests

    func testRequestStatusPending() {
        // GIVEN
        let status = RequestStatus.pending

        // THEN
        XCTAssertTrue(status.isInProgress)
        XCTAssertFalse(status.isFinished)
        XCTAssertFalse(status.isCompleted)
        XCTAssertFalse(status.isFailed)
        XCTAssertFalse(status.isCancelled)
        XCTAssertNil(status.responseData)
        XCTAssertNil(status.error)
        XCTAssertNil(status.progress)
        XCTAssertEqual(status.description, "Pending")
    }

    func testRequestStatusExecuting() {
        // GIVEN
        let status = RequestStatus.executing(progress: 0.5)

        // THEN
        XCTAssertTrue(status.isInProgress)
        XCTAssertFalse(status.isFinished)
        XCTAssertFalse(status.isCompleted)
        XCTAssertFalse(status.isFailed)
        XCTAssertFalse(status.isCancelled)
        XCTAssertNil(status.responseData)
        XCTAssertNil(status.error)
        XCTAssertEqual(status.progress, 0.5)
        XCTAssertEqual(status.description, "Executing (50%)")
    }

    func testRequestStatusExecutingWithoutProgress() {
        // GIVEN
        let status = RequestStatus.executing(progress: nil)

        // THEN
        XCTAssertTrue(status.isInProgress)
        XCTAssertNil(status.progress)
        XCTAssertEqual(status.description, "Executing")
    }

    func testRequestStatusCompleted() {
        // GIVEN
        let responseData = AIResponseData(
            requestID: UUID(),
            providerID: "test-provider",
            content: .text("Test content"),
            metadata: [:]
        )
        let status = RequestStatus.completed(responseData)

        // THEN
        XCTAssertFalse(status.isInProgress)
        XCTAssertTrue(status.isFinished)
        XCTAssertTrue(status.isCompleted)
        XCTAssertFalse(status.isFailed)
        XCTAssertFalse(status.isCancelled)
        XCTAssertNotNil(status.responseData)
        XCTAssertNil(status.error)
        XCTAssertNil(status.progress)
        XCTAssertEqual(status.description, "Completed")
    }

    func testRequestStatusFailed() {
        // GIVEN
        let error = AIServiceError.networkError("Network failure")
        let status = RequestStatus.failed(error)

        // THEN
        XCTAssertFalse(status.isInProgress)
        XCTAssertTrue(status.isFinished)
        XCTAssertFalse(status.isCompleted)
        XCTAssertTrue(status.isFailed)
        XCTAssertFalse(status.isCancelled)
        XCTAssertNil(status.responseData)
        XCTAssertNotNil(status.error)
        XCTAssertNil(status.progress)
        XCTAssertTrue(status.description.contains("Failed"))
    }

    func testRequestStatusCancelled() {
        // GIVEN
        let status = RequestStatus.cancelled

        // THEN
        XCTAssertFalse(status.isInProgress)
        XCTAssertTrue(status.isFinished)
        XCTAssertFalse(status.isCompleted)
        XCTAssertFalse(status.isFailed)
        XCTAssertTrue(status.isCancelled)
        XCTAssertNil(status.responseData)
        XCTAssertNil(status.error)
        XCTAssertNil(status.progress)
        XCTAssertEqual(status.description, "Cancelled")
    }

    // MARK: - TrackedRequest Tests

    func testTrackedRequestInitialization() {
        // GIVEN
        let request = AIRequest(prompt: "Test prompt")
        let submittedAt = Date()

        // WHEN
        let trackedRequest = TrackedRequest(
            request: request,
            status: .pending,
            providerID: "test-provider",
            submittedAt: submittedAt
        )

        // THEN
        XCTAssertEqual(trackedRequest.id, request.id)
        XCTAssertEqual(trackedRequest.providerID, "test-provider")
        XCTAssertEqual(trackedRequest.submittedAt, submittedAt)
        XCTAssertNil(trackedRequest.startedAt)
        XCTAssertNil(trackedRequest.finishedAt)
        XCTAssertNil(trackedRequest.duration)
    }

    func testTrackedRequestWithStatusExecuting() {
        // GIVEN
        let request = AIRequest(prompt: "Test")
        let submittedAt = Date()
        let trackedRequest = TrackedRequest(
            request: request,
            status: .pending,
            providerID: "test-provider",
            submittedAt: submittedAt
        )

        // WHEN
        let executingRequest = trackedRequest.withStatus(.executing(progress: 0.3))

        // THEN
        XCTAssertNotNil(executingRequest.startedAt, "Should set startedAt when status becomes executing")
        XCTAssertNil(executingRequest.finishedAt)
        XCTAssertNotNil(executingRequest.duration, "Should have duration when executing")
    }

    func testTrackedRequestWithStatusCompleted() {
        // GIVEN
        let request = AIRequest(prompt: "Test")
        let responseData = AIResponseData(
            requestID: request.id,
            providerID: "test-provider",
            content: .text("Response"),
            metadata: [:]
        )
        let trackedRequest = TrackedRequest(
            request: request,
            status: .executing(progress: nil),
            providerID: "test-provider",
            submittedAt: Date(),
            startedAt: Date()
        )

        // WHEN
        let completedRequest = trackedRequest.withStatus(.completed(responseData))

        // THEN
        XCTAssertNotNil(completedRequest.finishedAt, "Should set finishedAt when completed")
        XCTAssertNotNil(completedRequest.duration, "Should have duration when completed")
    }

    func testTrackedRequestWithProgress() {
        // GIVEN
        let request = AIRequest(prompt: "Test")
        let trackedRequest = TrackedRequest(
            request: request,
            status: .pending,
            providerID: "test-provider"
        )

        // WHEN
        let progressRequest = trackedRequest.withProgress(0.75)

        // THEN
        if case .executing(let progress) = progressRequest.status {
            XCTAssertEqual(progress, 0.75)
        } else {
            XCTFail("Status should be executing")
        }
    }

    func testTrackedRequestDuration() {
        // GIVEN
        let submittedAt = Date()
        let startedAt = submittedAt.addingTimeInterval(1.0)
        let finishedAt = startedAt.addingTimeInterval(2.0)

        let request = AIRequest(prompt: "Test")
        let responseData = AIResponseData(
            requestID: request.id,
            providerID: "test-provider",
            content: .text("Response"),
            metadata: [:]
        )

        let trackedRequest = TrackedRequest(
            request: request,
            status: .completed(responseData),
            providerID: "test-provider",
            submittedAt: submittedAt,
            startedAt: startedAt,
            finishedAt: finishedAt
        )

        // WHEN
        let duration = trackedRequest.duration

        // THEN
        XCTAssertNotNil(duration)
        XCTAssertEqual(duration!, 3.0, accuracy: 0.1, "Duration should be ~3 seconds from submission to finish")
    }

    // MARK: - RequestStatistics Tests

    func testRequestStatisticsInitialization() {
        // WHEN
        let stats = RequestStatistics(
            totalRequests: 10,
            pendingRequests: 2,
            executingRequests: 1,
            completedRequests: 5,
            failedRequests: 1,
            cancelledRequests: 1,
            averageDuration: 2.5,
            successRate: 0.83
        )

        // THEN
        XCTAssertEqual(stats.totalRequests, 10)
        XCTAssertEqual(stats.pendingRequests, 2)
        XCTAssertEqual(stats.executingRequests, 1)
        XCTAssertEqual(stats.completedRequests, 5)
        XCTAssertEqual(stats.failedRequests, 1)
        XCTAssertEqual(stats.cancelledRequests, 1)
        XCTAssertEqual(stats.averageDuration, 2.5)
        XCTAssertEqual(stats.successRate, 0.83)
    }

    func testRequestStatisticsFromEmptyArray() {
        // GIVEN
        let requests: [TrackedRequest] = []

        // WHEN
        let stats = RequestStatistics.from(requests)

        // THEN
        XCTAssertEqual(stats.totalRequests, 0)
        XCTAssertEqual(stats.pendingRequests, 0)
        XCTAssertEqual(stats.executingRequests, 0)
        XCTAssertEqual(stats.completedRequests, 0)
        XCTAssertEqual(stats.failedRequests, 0)
        XCTAssertEqual(stats.cancelledRequests, 0)
        XCTAssertNil(stats.averageDuration)
        XCTAssertNil(stats.successRate)
    }

    func testRequestStatisticsFromMixedRequests() {
        // GIVEN
        let responseData = AIResponseData(
            requestID: UUID(),
            providerID: "provider1",
            content: .text("Response"),
            metadata: [:]
        )

        let baseDate = Date()

        let requests = [
            // Completed request with duration
            TrackedRequest(
                request: AIRequest(prompt: "Test 1"),
                status: .completed(responseData),
                providerID: "provider1",
                submittedAt: baseDate,
                startedAt: baseDate.addingTimeInterval(0.5),
                finishedAt: baseDate.addingTimeInterval(2.5)
            ),
            // Failed request
            TrackedRequest(
                request: AIRequest(prompt: "Test 2"),
                status: .failed(.networkError("Error")),
                providerID: "provider1",
                submittedAt: baseDate
            ),
            // Pending request
            TrackedRequest(
                request: AIRequest(prompt: "Test 3"),
                status: .pending,
                providerID: "provider1",
                submittedAt: baseDate
            ),
            // Executing request
            TrackedRequest(
                request: AIRequest(prompt: "Test 4"),
                status: .executing(progress: 0.5),
                providerID: "provider1",
                submittedAt: baseDate
            ),
            // Cancelled request
            TrackedRequest(
                request: AIRequest(prompt: "Test 5"),
                status: .cancelled,
                providerID: "provider1",
                submittedAt: baseDate
            ),
            // Another completed request
            TrackedRequest(
                request: AIRequest(prompt: "Test 6"),
                status: .completed(responseData),
                providerID: "provider1",
                submittedAt: baseDate,
                startedAt: baseDate.addingTimeInterval(0.5),
                finishedAt: baseDate.addingTimeInterval(4.5)
            )
        ]

        // WHEN
        let stats = RequestStatistics.from(requests)

        // THEN
        XCTAssertEqual(stats.totalRequests, 6)
        XCTAssertEqual(stats.completedRequests, 2)
        XCTAssertEqual(stats.failedRequests, 1)
        XCTAssertEqual(stats.executingRequests, 1)
        XCTAssertEqual(stats.cancelledRequests, 1)

        // Average duration: (2.5 + 4.5) / 2 = 3.5
        XCTAssertNotNil(stats.averageDuration)
        XCTAssertEqual(stats.averageDuration!, 3.5, accuracy: 0.1)

        // Success rate: 2 completed / (2 completed + 1 failed) = 2/3 ≈ 0.667
        XCTAssertNotNil(stats.successRate)
        XCTAssertEqual(stats.successRate!, 0.667, accuracy: 0.01)
    }

    func testRequestStatisticsSuccessRateAllCompleted() {
        // GIVEN
        let responseData = AIResponseData(
            requestID: UUID(),
            providerID: "provider1",
            content: .text("Response"),
            metadata: [:]
        )

        let requests = [
            TrackedRequest(
                request: AIRequest(prompt: "Test 1"),
                status: .completed(responseData),
                providerID: "provider1"
            ),
            TrackedRequest(
                request: AIRequest(prompt: "Test 2"),
                status: .completed(responseData),
                providerID: "provider1"
            )
        ]

        // WHEN
        let stats = RequestStatistics.from(requests)

        // THEN
        XCTAssertEqual(stats.successRate, 1.0, "Success rate should be 100%")
    }

    func testRequestStatisticsSuccessRateAllFailed() {
        // GIVEN
        let requests = [
            TrackedRequest(
                request: AIRequest(prompt: "Test 1"),
                status: .failed(.networkError("Error")),
                providerID: "provider1"
            ),
            TrackedRequest(
                request: AIRequest(prompt: "Test 2"),
                status: .failed(.networkError("Error")),
                providerID: "provider1"
            )
        ]

        // WHEN
        let stats = RequestStatistics.from(requests)

        // THEN
        XCTAssertEqual(stats.successRate, 0.0, "Success rate should be 0%")
    }

    func testRequestStatisticsSuccessRateExcludesPendingAndCancelled() {
        // GIVEN
        let responseData = AIResponseData(
            requestID: UUID(),
            providerID: "provider1",
            content: .text("Response"),
            metadata: [:]
        )

        let requests = [
            TrackedRequest(
                request: AIRequest(prompt: "Test 1"),
                status: .completed(responseData),
                providerID: "provider1"
            ),
            TrackedRequest(
                request: AIRequest(prompt: "Test 2"),
                status: .pending,
                providerID: "provider1"
            ),
            TrackedRequest(
                request: AIRequest(prompt: "Test 3"),
                status: .cancelled,
                providerID: "provider1"
            )
        ]

        // WHEN
        let stats = RequestStatistics.from(requests)

        // THEN
        // Success rate only considers completed/failed: 1 completed / (1 completed + 0 failed) = 100%
        XCTAssertEqual(stats.successRate, 1.0, "Success rate should only consider finished requests")
    }
}
