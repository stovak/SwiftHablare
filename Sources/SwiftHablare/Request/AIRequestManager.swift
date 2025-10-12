import Foundation

/// Actor that manages the lifecycle of AI service requests.
///
/// `AIRequestManager` is responsible for:
/// - Tracking requests by UUID from submission through completion
/// - Executing requests in background tasks without ModelContext
/// - Managing request state transitions (pending → executing → completed/failed)
/// - Providing async streams for status observation
/// - Storing completed responses for retrieval by request ID
///
/// This actor ensures thread-safe request management and eliminates race conditions
/// by keeping all SwiftData operations out of the request execution path.
///
/// ## Example
/// ```swift
/// let manager = AIRequestManager()
///
/// // Submit a request
/// let requestID = await manager.submit(request: request, provider: provider)
///
/// // Execute and get response
/// let responseData = try await manager.execute(requestID: requestID)
///
/// // Or observe status changes
/// for await status in manager.statusStream(for: requestID) {
///     print("Status: \(status.description)")
/// }
/// ```
public actor AIRequestManager {

    // MARK: - Properties

    /// Tracked requests indexed by request ID.
    private var trackedRequests: [UUID: TrackedRequest] = [:]

    /// Completed responses indexed by request ID.
    private var responses: [UUID: AIResponseData] = [:]

    /// Providers indexed by request ID.
    private var providers: [UUID: any AIServiceProvider] = [:]

    /// Active execution tasks indexed by request ID.
    private var executionTasks: [UUID: Task<AIResponseData, Error>] = [:]

    /// Status continuations for async streams.
    private var statusContinuations: [UUID: [AsyncStream<RequestStatus>.Continuation]] = [:]

    /// Maximum number of completed responses to keep in memory.
    public var maxCachedResponses: Int = 100

    /// Maximum age of completed responses before cleanup (in seconds).
    public var maxResponseAge: TimeInterval = 3600 // 1 hour

    // MARK: - Initialization

    /// Creates a new request manager.
    ///
    /// - Parameters:
    ///   - maxCachedResponses: Maximum responses to cache (default: 100)
    ///   - maxResponseAge: Maximum age for cached responses in seconds (default: 3600)
    public init(
        maxCachedResponses: Int = 100,
        maxResponseAge: TimeInterval = 3600
    ) {
        self.maxCachedResponses = maxCachedResponses
        self.maxResponseAge = maxResponseAge
    }

    // MARK: - Request Submission

    /// Submits a request for execution.
    ///
    /// The request is queued but not immediately executed. Call `execute(requestID:)`
    /// to begin execution, or use `submitAndExecute(request:provider:)` for immediate execution.
    ///
    /// - Parameters:
    ///   - request: The request to submit
    ///   - provider: The provider to use for execution
    /// - Returns: The request's UUID for tracking
    public func submit(
        request: AIRequest,
        provider: any AIServiceProvider
    ) -> UUID {
        let tracked = TrackedRequest(
            request: request,
            status: .pending,
            providerID: provider.id
        )

        trackedRequests[request.id] = tracked
        providers[request.id] = provider

        // Notify status observers
        notifyStatusChange(for: request.id, status: .pending)

        return request.id
    }

    /// Submits a request and immediately begins execution.
    ///
    /// This is a convenience method that combines submission and execution.
    ///
    /// - Parameters:
    ///   - request: The request to execute
    ///   - provider: The provider to use
    /// - Returns: The response data
    /// - Throws: `AIServiceError` if execution fails
    public func submitAndExecute(
        request: AIRequest,
        provider: any AIServiceProvider
    ) async throws -> AIResponseData {
        let requestID = submit(request: request, provider: provider)
        return try await execute(requestID: requestID)
    }

    // MARK: - Request Execution

    /// Executes a previously submitted request.
    ///
    /// If the request is already executing, this returns the existing task's result.
    /// If the request is already completed, this returns the cached response.
    ///
    /// - Parameter requestID: The UUID of the request to execute
    /// - Returns: The response data
    /// - Throws: `AIServiceError` if execution fails or request not found
    public func execute(requestID: UUID) async throws -> AIResponseData {
        // Check if already completed
        if let response = responses[requestID] {
            return response
        }

        // Check if already executing
        if let existingTask = executionTasks[requestID] {
            return try await existingTask.value
        }

        // Get the tracked request and provider
        guard let tracked = trackedRequests[requestID],
              let provider = providers[requestID] else {
            throw AIServiceError.invalidRequest("Request not found: \(requestID)")
        }

        // Create execution task
        let task = Task<AIResponseData, Error> {
            // Update status to executing
            await updateStatus(for: requestID, status: .executing(progress: nil))

            // Check cancellation before executing
            try Task.checkCancellation()

            // Execute the request
            let result = await provider.generate(
                prompt: tracked.request.prompt,
                parameters: tracked.request.parameters
            )

            // Check cancellation before persisting results
            try Task.checkCancellation()

            // Create response data
            let responseData: AIResponseData
            switch result {
            case .success(let content):
                responseData = AIResponseData(
                    requestID: requestID,
                    providerID: provider.id,
                    content: content,
                    metadata: tracked.request.metadata
                )
            case .failure(let error):
                responseData = AIResponseData(
                    requestID: requestID,
                    providerID: provider.id,
                    error: error,
                    metadata: tracked.request.metadata
                )
            }

            // Store response
            await storeResponse(responseData)

            // Update status
            let finalStatus: RequestStatus = responseData.isSuccess ?
                .completed(responseData) : .failed(responseData.error!)
            await updateStatus(for: requestID, status: finalStatus)

            // Clean up task
            await cleanupTask(for: requestID)

            return responseData
        }

        // Store task
        executionTasks[requestID] = task

        do {
            let response = try await task.value
            return response
        } catch {
            // Convert to AIServiceError if needed
            if let serviceError = error as? AIServiceError {
                throw serviceError
            } else {
                throw AIServiceError.networkError(error.localizedDescription)
            }
        }
    }

    /// Executes a batch of requests sequentially.
    ///
    /// - Parameters:
    ///   - requestIDs: Array of request IDs to execute
    /// - Returns: Array of response data in the same order as request IDs
    public func executeBatch(requestIDs: [UUID]) async -> [Result<AIResponseData, AIServiceError>] {
        var results: [Result<AIResponseData, AIServiceError>] = []

        for requestID in requestIDs {
            do {
                let response = try await execute(requestID: requestID)
                results.append(.success(response))
            } catch let error as AIServiceError {
                results.append(.failure(error))
            } catch {
                results.append(.failure(.networkError(error.localizedDescription)))
            }
        }

        return results
    }

    // MARK: - Request Querying

    /// Gets the current status of a request.
    ///
    /// - Parameter requestID: The request UUID
    /// - Returns: The current status, or nil if request not found
    public func status(for requestID: UUID) -> RequestStatus? {
        return trackedRequests[requestID]?.status
    }

    /// Gets the tracked request information.
    ///
    /// - Parameter requestID: The request UUID
    /// - Returns: The tracked request, or nil if not found
    public func trackedRequest(for requestID: UUID) -> TrackedRequest? {
        return trackedRequests[requestID]
    }

    /// Gets the response data for a completed request.
    ///
    /// - Parameter requestID: The request UUID
    /// - Returns: The response data, or nil if not completed or not found
    public func response(for requestID: UUID) -> AIResponseData? {
        return responses[requestID]
    }

    /// Gets all tracked requests.
    ///
    /// - Returns: Array of all tracked requests
    public func allTrackedRequests() -> [TrackedRequest] {
        return Array(trackedRequests.values)
    }

    /// Gets all tracked requests for a specific provider.
    ///
    /// - Parameter providerID: The provider ID
    /// - Returns: Array of tracked requests for that provider
    public func trackedRequests(forProvider providerID: String) -> [TrackedRequest] {
        return trackedRequests.values.filter { $0.providerID == providerID }
    }

    /// Gets all requests with a specific status.
    ///
    /// - Parameter isInProgress: If true, returns in-progress requests; if false, returns finished requests
    /// - Returns: Array of matching tracked requests
    public func trackedRequests(inProgress isInProgress: Bool) -> [TrackedRequest] {
        return trackedRequests.values.filter { $0.status.isInProgress == isInProgress }
    }

    // MARK: - Status Observation

    /// Creates an async stream for observing status changes.
    ///
    /// - Parameter requestID: The request UUID to observe
    /// - Returns: An async stream of status updates
    ///
    /// ## Example
    /// ```swift
    /// for await status in manager.statusStream(for: requestID) {
    ///     print("Status: \(status.description)")
    ///     if status.isFinished { break }
    /// }
    /// ```
    public func statusStream(for requestID: UUID) -> AsyncStream<RequestStatus> {
        AsyncStream { continuation in
            // Send current status if available
            if let current = trackedRequests[requestID]?.status {
                continuation.yield(current)
            }

            // Store continuation for future updates
            statusContinuations[requestID, default: []].append(continuation)

            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeStatusContinuation(for: requestID, continuation: continuation)
                }
            }
        }
    }

    // MARK: - Request Cancellation

    /// Cancels a request if it's pending or executing.
    ///
    /// - Parameter requestID: The request UUID to cancel
    /// - Returns: true if the request was cancelled, false if it was already finished or not found
    @discardableResult
    public func cancel(requestID: UUID) -> Bool {
        guard let tracked = trackedRequests[requestID],
              tracked.status.isInProgress else {
            return false
        }

        // Cancel execution task if it exists
        executionTasks[requestID]?.cancel()
        executionTasks.removeValue(forKey: requestID)

        // Update status
        updateStatus(for: requestID, status: .cancelled)

        return true
    }

    /// Cancels all in-progress requests.
    ///
    /// - Returns: Number of requests cancelled
    @discardableResult
    public func cancelAll() -> Int {
        let inProgress = trackedRequests.values.filter { $0.status.isInProgress }
        var count = 0

        for tracked in inProgress {
            if cancel(requestID: tracked.id) {
                count += 1
            }
        }

        return count
    }

    // MARK: - Statistics

    /// Returns statistics about tracked requests.
    ///
    /// - Returns: Request statistics
    public func statistics() -> RequestStatistics {
        return RequestStatistics.from(Array(trackedRequests.values))
    }

    /// Returns statistics for a specific provider.
    ///
    /// - Parameter providerID: The provider ID
    /// - Returns: Request statistics for that provider
    public func statistics(forProvider providerID: String) -> RequestStatistics {
        let providerRequests = trackedRequests(forProvider: providerID)
        return RequestStatistics.from(providerRequests)
    }

    // MARK: - Cleanup

    /// Removes a request from tracking.
    ///
    /// This removes the tracked request but keeps the response if completed.
    ///
    /// - Parameter requestID: The request UUID to remove
    public func removeTracking(for requestID: UUID) {
        trackedRequests.removeValue(forKey: requestID)
        providers.removeValue(forKey: requestID)
        executionTasks.removeValue(forKey: requestID)

        // Close any status continuations
        if let continuations = statusContinuations.removeValue(forKey: requestID) {
            for continuation in continuations {
                continuation.finish()
            }
        }
    }

    /// Removes a completed response from the cache.
    ///
    /// - Parameter requestID: The request UUID
    public func removeResponse(for requestID: UUID) {
        responses.removeValue(forKey: requestID)
    }

    /// Clears all completed responses from the cache.
    public func clearResponses() {
        responses.removeAll()
    }

    /// Clears all tracked requests and responses.
    ///
    /// Active executions are cancelled.
    public func clearAll() {
        cancelAll()
        trackedRequests.removeAll()
        responses.removeAll()
        providers.removeAll()
        executionTasks.removeAll()

        // Close all continuations
        for (_, continuations) in statusContinuations {
            for continuation in continuations {
                continuation.finish()
            }
        }
        statusContinuations.removeAll()
    }

    /// Removes old completed responses based on age and cache size limits.
    ///
    /// - Returns: Number of responses removed
    @discardableResult
    public func cleanupOldResponses() -> Int {
        let now = Date()
        var removed = 0

        // Remove responses older than maxResponseAge
        let oldResponses = responses.filter { _, response in
            now.timeIntervalSince(response.receivedAt) > maxResponseAge
        }

        for (requestID, _) in oldResponses {
            removeResponse(for: requestID)
            removed += 1
        }

        // If still over limit, remove oldest responses
        if responses.count > maxCachedResponses {
            let sorted = responses.sorted { $0.value.receivedAt < $1.value.receivedAt }
            let toRemove = responses.count - maxCachedResponses

            for (requestID, _) in sorted.prefix(toRemove) {
                removeResponse(for: requestID)
                removed += 1
            }
        }

        return removed
    }

    // MARK: - Private Helpers

    /// Stores a response and performs cleanup if needed.
    private func storeResponse(_ response: AIResponseData) {
        responses[response.requestID] = response

        // Perform cleanup if needed
        if responses.count > maxCachedResponses {
            cleanupOldResponses()
        }
    }

    /// Updates the status of a request and notifies observers.
    private func updateStatus(for requestID: UUID, status: RequestStatus) {
        guard let tracked = trackedRequests[requestID] else { return }

        let updated = tracked.withStatus(status)
        trackedRequests[requestID] = updated

        notifyStatusChange(for: requestID, status: status)
    }

    /// Notifies status observers of a change.
    private func notifyStatusChange(for requestID: UUID, status: RequestStatus) {
        guard let continuations = statusContinuations[requestID] else { return }

        for continuation in continuations {
            continuation.yield(status)

            // Finish continuations when request is finished
            if status.isFinished {
                continuation.finish()
            }
        }

        // Remove finished continuations
        if status.isFinished {
            statusContinuations.removeValue(forKey: requestID)
        }
    }

    /// Removes a status continuation from tracking.
    private func removeStatusContinuation(
        for requestID: UUID,
        continuation: AsyncStream<RequestStatus>.Continuation
    ) {
        guard var continuations = statusContinuations[requestID] else { return }

        // Note: AsyncStream.Continuation is not a class, so we can't use identity comparison
        // We'll just clear all continuations for this request ID as a workaround
        // In practice, this is fine since termination happens when the stream ends
        statusContinuations.removeValue(forKey: requestID)

        if continuations.isEmpty {
            statusContinuations.removeValue(forKey: requestID)
        } else {
            statusContinuations[requestID] = continuations
        }
    }

    /// Cleans up an execution task after completion.
    private func cleanupTask(for requestID: UUID) {
        executionTasks.removeValue(forKey: requestID)
    }
}

// MARK: - Convenience Extensions

extension AIRequestManager {

    /// Submits and executes a request with a simple interface.
    ///
    /// - Parameters:
    ///   - prompt: The prompt text
    ///   - provider: The provider to use
    ///   - parameters: Request parameters (default: empty)
    ///   - metadata: Request metadata (default: empty)
    /// - Returns: The response data
    /// - Throws: `AIServiceError` if execution fails
    public func generate(
        prompt: String,
        provider: any AIServiceProvider,
        parameters: [String: String] = [:],
        metadata: [String: String] = [:]
    ) async throws -> AIResponseData {
        let request = AIRequest(
            prompt: prompt,
            parameters: parameters,
            metadata: metadata
        )

        return try await submitAndExecute(request: request, provider: provider)
    }
}
