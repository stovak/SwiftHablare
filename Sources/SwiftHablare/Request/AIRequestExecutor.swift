import Foundation
import SwiftData

// MARK: - ModelContext Sendable Wrapper

/// Unsafe wrapper to allow ModelContext to cross actor boundaries.
/// This is safe when the context is only used within a single task.
fileprivate struct UnsafeModelContextWrapper: @unchecked Sendable {
    let context: ModelContext
}

/// Executes AI service requests with support for rate limiting, caching, and error recovery.
///
/// `AIRequestExecutor` is the primary interface for making requests to AI service providers.
/// It handles request queuing, rate limiting, caching, retry logic, and error recovery.
///
/// ## Example
/// ```swift
/// let executor = AIRequestExecutor(cache: cache)
///
/// let request = AIRequest(
///     prompt: "Generate a haiku",
///     parameters: ["temperature": "0.7"]
/// )
///
/// let response = try await executor.execute(
///     request: request,
///     provider: openAIProvider,
///     context: modelContext
/// )
/// ```
public actor AIRequestExecutor {

    /// Response cache for reducing redundant API calls.
    private let cache: AIResponseCache

    /// Rate limiters per provider ID.
    private var rateLimiters: [String: AIRateLimiter] = [:]

    /// Request retry configuration.
    public var retryConfig: RetryConfiguration

    /// Default timeout for requests in seconds.
    public var defaultTimeout: TimeInterval

    /// Creates a new request executor.
    ///
    /// - Parameters:
    ///   - cache: Response cache (optional, creates new if not provided)
    ///   - retryConfig: Retry configuration (default configuration used if not provided)
    ///   - defaultTimeout: Default request timeout in seconds (default: 30.0)
    public init(
        cache: AIResponseCache? = nil,
        retryConfig: RetryConfiguration = RetryConfiguration(),
        defaultTimeout: TimeInterval = 30.0
    ) {
        self.cache = cache ?? AIResponseCache()
        self.retryConfig = retryConfig
        self.defaultTimeout = defaultTimeout
    }

    /// Executes a single request.
    ///
    /// - Parameters:
    ///   - request: The request to execute
    ///   - provider: The provider to use
    ///   - context: SwiftData model context for persistence
    ///   - rateLimiter: Optional rate limiter (auto-created if not provided)
    /// - Returns: The AI response
    /// - Throws: `AIServiceError` if the request fails
    ///
    /// - Note: ModelContext is not Sendable in Swift 6, but is safe to use within a single task.
    ///         The context must not be shared across tasks.
    public func execute(
        request: AIRequest,
        provider: any AIServiceProvider,
        context: ModelContext,
        rateLimiter: AIRateLimiter? = nil
    ) async throws -> AIResponse {
        // Check cache first if enabled
        if request.useCache {
            if let cached = await checkCache(request: request, providerID: provider.id) {
                return cached
            }
        }

        // Get or create rate limiter
        let limiter: AIRateLimiter
        if let providedLimiter = rateLimiter {
            limiter = providedLimiter
        } else {
            limiter = getRateLimiter(for: provider.id)
        }

        // Wait for rate limit permission
        await limiter.waitForPermission()

        // Execute with retry logic
        // Note: ModelContext crossing is safe here as it stays within the same task
        let wrapper = UnsafeModelContextWrapper(context: context)
        let response = try await executeWithRetry(
            request: request,
            provider: provider,
            contextWrapper: wrapper,
            retryConfig: retryConfig,
            defaultTimeout: defaultTimeout
        )

        // Cache the response if enabled
        if request.useCache {
            await cacheResponse(response, for: request, providerID: provider.id)
        }

        return response
    }

    /// Executes a batch of requests sequentially.
    ///
    /// - Parameters:
    ///   - requests: Array of requests to execute
    ///   - provider: The provider to use
    ///   - context: SwiftData model context
    /// - Returns: Batch response with successes and failures
    ///
    /// - Note: Requests are executed sequentially to avoid ModelContext concurrency issues.
    public func executeBatch(
        requests: [AIRequest],
        provider: any AIServiceProvider,
        context: ModelContext
    ) async -> AIBatchResponse {
        var successes: [AIResponse] = []
        var failures: [(request: AIRequest, error: AIServiceError)] = []

        // Process requests sequentially to avoid ModelContext data races
        for request in requests {
            do {
                let response = try await execute(
                    request: request,
                    provider: provider,
                    context: context
                )
                successes.append(response)
            } catch let error as AIServiceError {
                failures.append((request, error))
            } catch {
                let serviceError = AIServiceError.networkError(error.localizedDescription)
                failures.append((request, serviceError))
            }
        }

        return AIBatchResponse(successes: successes, failures: failures)
    }

    /// Executes a request with automatic retry on failure.
    ///
    /// - Parameters:
    ///   - request: The request to execute
    ///   - provider: The provider to use
    ///   - contextWrapper: Wrapped ModelContext for safe cross-actor use
    /// - Returns: The AI response
    /// - Throws: `AIServiceError` if all retry attempts fail
    ///
    /// - Note: ModelContext is not Sendable but is safe here as it stays within the same task.
    ///         The nonisolated attribute is required because we pass ModelContext to
    ///         non-isolated protocol methods. This is safe as the context is never shared across tasks.
    nonisolated private func executeWithRetry(
        request: AIRequest,
        provider: any AIServiceProvider,
        contextWrapper: UnsafeModelContextWrapper,
        retryConfig: RetryConfiguration,
        defaultTimeout: TimeInterval
    ) async throws -> AIResponse {
        var lastError: Error?
        var attemptNumber = 0

        while attemptNumber <= retryConfig.maxRetries {
            do {
                // Execute using the new Result-based API
                // Convert [String: String] to [String: Any] for protocol compatibility
                let anyParameters: [String: Any] = request.parameters.reduce(into: [:]) { result, pair in
                    result[pair.key] = pair.value
                }
                let result = await provider.generate(
                    prompt: request.prompt,
                    parameters: anyParameters
                )

                // Handle the result
                let responseContent: ResponseContent
                switch result {
                case .success(let content):
                    responseContent = content
                case .failure(let error):
                    throw error
                }

                // Extract data from ResponseContent
                let data: Data
                switch responseContent {
                case .text(let text):
                    data = text.data(using: .utf8) ?? Data()
                case .data(let rawData):
                    data = rawData
                case .image(let imageData, format: _):
                    // Extract just the data, ignore format
                    data = imageData
                case .audio(let audioData, format: _):
                    // Extract just the data, ignore format
                    data = audioData
                case .structured(let dict):
                    // Convert structured data to JSON
                    let anyDict = dict.mapValues { convertSendableValueToAny($0) }
                    if let jsonData = try? JSONSerialization.data(withJSONObject: anyDict, options: []) {
                        data = jsonData
                    } else {
                        data = Data()
                    }
                }

                // Create response
                let response = AIResponse(
                    content: data,
                    providerID: provider.id,
                    finishReason: .completed,
                    metadata: request.metadata,
                    fromCache: false,
                    request: request
                )

                return response

            } catch {
                lastError = error
                attemptNumber += 1

                // Check if we should retry
                if attemptNumber <= retryConfig.maxRetries && shouldRetry(error: error) {
                    // Calculate backoff delay
                    let delay = calculateBackoffDelay(attempt: attemptNumber, retryConfig: retryConfig)
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                } else {
                    break
                }
            }
        }

        // All retries failed
        if let error = lastError {
            throw error
        } else {
            throw AIServiceError.networkError("Request failed after \(attemptNumber) attempts")
        }
    }

    /// Checks if an error should trigger a retry.
    ///
    /// - Parameter error: The error to check
    /// - Returns: `true` if the error is retryable
    nonisolated private func shouldRetry(error: Error) -> Bool {
        guard let serviceError = error as? AIServiceError else {
            // Unknown errors are retryable
            return true
        }

        switch serviceError {
        case .networkError, .rateLimitExceeded, .timeout, .connectionFailed:
            // Network-related errors are retryable
            return true
        case .configurationError, .invalidAPIKey, .missingCredentials, .authenticationFailed:
            // Configuration and auth errors are not retryable
            return false
        case .validationError, .unsupportedOperation, .dataBindingError, .invalidRequest:
            // Validation and logic errors are not retryable
            return false
        case .unexpectedResponseFormat, .dataConversionError:
            // Data format errors are not retryable (structural issues)
            return false
        case .persistenceError, .modelNotFound:
            // Storage errors might be transient, so retry
            return true
        case .providerError:
            // Provider-specific errors may be retryable depending on the code
            // For now, treat as retryable
            return true
        }
    }

    /// Calculates exponential backoff delay for retry attempts.
    ///
    /// - Parameter attempt: The attempt number (1-based)
    /// - Returns: Delay in seconds
    nonisolated private func calculateBackoffDelay(attempt: Int, retryConfig: RetryConfiguration) -> TimeInterval {
        let baseDelay = retryConfig.baseDelay
        let maxDelay = retryConfig.maxDelay

        // Exponential backoff with jitter
        let exponentialDelay = baseDelay * pow(retryConfig.backoffMultiplier, Double(attempt - 1))
        let jitter = Double.random(in: 0...0.1) * exponentialDelay

        return min(exponentialDelay + jitter, maxDelay)
    }

    /// Executes a task with a timeout.
    ///
    /// - Parameters:
    ///   - seconds: Timeout in seconds
    ///   - operation: The async operation to execute
    /// - Returns: The result of the operation
    /// - Throws: `AIServiceError.networkError` if timeout occurs, or any error from the operation
    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the main operation
            group.addTask {
                try await operation()
            }

            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw AIServiceError.networkError("Request timed out after \(seconds) seconds")
            }

            // Return first result (either completion or timeout)
            let result = try await group.next()!

            // Cancel remaining tasks
            group.cancelAll()

            return result
        }
    }

    // MARK: - Cache Management

    /// Checks the cache for a matching request.
    private func checkCache(request: AIRequest, providerID: String) async -> AIResponse? {
        let cacheKey = generateCacheKey(request: request, providerID: providerID)

        if let cachedData = await cache.get(providerId: providerID, prompt: cacheKey, parameters: [:]),
           let data = cachedData.value as? Data {
            return AIResponse(
                content: data,
                providerID: providerID,
                finishReason: .completed,
                metadata: request.metadata,
                fromCache: true,
                request: request
            )
        }

        return nil
    }

    /// Caches a response.
    private func cacheResponse(_ response: AIResponse, for request: AIRequest, providerID: String) async {
        let cacheKey = generateCacheKey(request: request, providerID: providerID)
        await cache.set(
            response.content,
            providerId: providerID,
            prompt: cacheKey,
            parameters: request.parameters
        )
    }

    /// Generates a cache key for a request.
    private func generateCacheKey(request: AIRequest, providerID: String) -> String {
        // Combine prompt and sorted parameters for consistent cache key
        let sortedParams = request.parameters.sorted { $0.key < $1.key }
        let paramsString = sortedParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")

        return "\(providerID):\(request.prompt):\(paramsString)"
    }

    // MARK: - Rate Limiter Management

    /// Gets or creates a rate limiter for a provider.
    private func getRateLimiter(for providerID: String) -> AIRateLimiter {
        if let existing = rateLimiters[providerID] {
            return existing
        }

        // Create default rate limiter
        let limiter = AIRateLimiter(maxRequests: 60, timeWindow: 60.0)
        rateLimiters[providerID] = limiter
        return limiter
    }

    /// Sets a custom rate limiter for a provider.
    ///
    /// - Parameters:
    ///   - limiter: The rate limiter to use
    ///   - providerID: The provider ID
    public func setRateLimiter(_ limiter: AIRateLimiter, for providerID: String) {
        rateLimiters[providerID] = limiter
    }

    /// Clears the cache.
    public func clearCache() async {
        await cache.clear()
    }

    /// Statistics about the executor.
    public struct Statistics: Sendable {
        public let cacheStats: [String: Int]
        public let rateLimiterCount: Int
        public let maxRetries: Int
        public let baseDelay: TimeInterval
        public let maxDelay: TimeInterval
    }

    /// Returns statistics about the executor.
    ///
    /// - Returns: Statistics about the executor
    public func statistics() async -> Statistics {
        return Statistics(
            cacheStats: await cache.statistics(),
            rateLimiterCount: rateLimiters.count,
            maxRetries: retryConfig.maxRetries,
            baseDelay: retryConfig.baseDelay,
            maxDelay: retryConfig.maxDelay
        )
    }
}

// MARK: - Retry Configuration

extension AIRequestExecutor {

    /// Configuration for request retry behavior.
    public struct RetryConfiguration: Sendable {
        /// Maximum number of retry attempts.
        public let maxRetries: Int

        /// Base delay in seconds before first retry.
        public let baseDelay: TimeInterval

        /// Maximum delay in seconds between retries.
        public let maxDelay: TimeInterval

        /// Multiplier for exponential backoff.
        public let backoffMultiplier: Double

        /// Creates a retry configuration.
        ///
        /// - Parameters:
        ///   - maxRetries: Maximum retry attempts (default: 3)
        ///   - baseDelay: Base delay in seconds (default: 1.0)
        ///   - maxDelay: Maximum delay in seconds (default: 60.0)
        ///   - backoffMultiplier: Backoff multiplier (default: 2.0)
        public init(
            maxRetries: Int = 3,
            baseDelay: TimeInterval = 1.0,
            maxDelay: TimeInterval = 60.0,
            backoffMultiplier: Double = 2.0
        ) {
            self.maxRetries = maxRetries
            self.baseDelay = baseDelay
            self.maxDelay = maxDelay
            self.backoffMultiplier = backoffMultiplier
        }

        /// No retries configuration.
        public static let noRetries = RetryConfiguration(maxRetries: 0)

        /// Aggressive retry configuration (more attempts, faster backoff).
        public static let aggressive = RetryConfiguration(
            maxRetries: 5,
            baseDelay: 0.5,
            maxDelay: 30.0,
            backoffMultiplier: 1.5
        )

        /// Conservative retry configuration (fewer attempts, slower backoff).
        public static let conservative = RetryConfiguration(
            maxRetries: 2,
            baseDelay: 2.0,
            maxDelay: 120.0,
            backoffMultiplier: 3.0
        )
    }
}

// MARK: - Helper Functions

/// Converts a SendableValue to Any for JSON serialization.
private func convertSendableValueToAny(_ value: SendableValue) -> Any {
    switch value {
    case .string(let s):
        return s
    case .int(let i):
        return i
    case .double(let d):
        return d
    case .bool(let b):
        return b
    case .null:
        return NSNull()
    case .array(let arr):
        return arr.map { convertSendableValueToAny($0) }
    case .dictionary(let dict):
        return dict.mapValues { convertSendableValueToAny($0) }
    }
}
