import Foundation

/// Rate limiting strategy for AI service requests.
///
/// `AIRateLimiter` implements a token bucket algorithm to enforce rate limits
/// on requests to AI services, preventing API rate limit errors.
///
/// ## Example
/// ```swift
/// let limiter = AIRateLimiter(
///     maxRequests: 60,
///     timeWindow: 60.0  // 60 requests per minute
/// )
///
/// await limiter.waitForPermission()
/// // Make request...
/// ```
public actor AIRateLimiter {

    /// Maximum number of requests allowed in the time window.
    public let maxRequests: Int

    /// Time window in seconds for the rate limit.
    public let timeWindow: TimeInterval

    /// Current number of available tokens.
    private var tokens: Int

    /// Timestamp of the last token refill.
    private var lastRefillTime: Date

    /// Token refill rate (tokens per second).
    private let refillRate: Double

    /// Queue of waiting tasks with their continuation.
    private var waitQueue: [(continuation: CheckedContinuation<Void, Never>, requestedAt: Date)] = []

    /// Creates a new rate limiter.
    ///
    /// - Parameters:
    ///   - maxRequests: Maximum requests allowed in the time window
    ///   - timeWindow: Time window in seconds (default: 60.0)
    public init(maxRequests: Int, timeWindow: TimeInterval = 60.0) {
        self.maxRequests = maxRequests
        self.timeWindow = timeWindow
        self.tokens = maxRequests
        self.lastRefillTime = Date()
        self.refillRate = Double(maxRequests) / timeWindow
    }

    /// Waits for permission to make a request.
    ///
    /// This method suspends until a token becomes available.
    public func waitForPermission() async {
        refillTokens()

        if tokens > 0 {
            tokens -= 1
            return
        }

        // No tokens available, wait in queue
        await withCheckedContinuation { continuation in
            waitQueue.append((continuation, Date()))
        }
    }

    /// Attempts to acquire permission without waiting.
    ///
    /// - Returns: `true` if permission was granted, `false` if rate limited
    public func tryAcquire() -> Bool {
        refillTokens()

        if tokens > 0 {
            tokens -= 1
            return true
        }

        return false
    }

    /// Refills tokens based on elapsed time.
    private func refillTokens() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRefillTime)

        if elapsed > 0 {
            let tokensToAdd = Int(elapsed * refillRate)

            if tokensToAdd > 0 {
                tokens = min(tokens + tokensToAdd, maxRequests)
                lastRefillTime = now

                // Process waiting queue
                processWaitQueue()
            }
        }
    }

    /// Processes the wait queue and grants permissions.
    private func processWaitQueue() {
        while tokens > 0 && !waitQueue.isEmpty {
            let waiting = waitQueue.removeFirst()
            tokens -= 1
            waiting.continuation.resume()
        }
    }

    /// Returns the current number of available tokens.
    public func availableTokens() -> Int {
        refillTokens()
        return tokens
    }

    /// Returns the estimated wait time in seconds before a token becomes available.
    ///
    /// - Returns: Estimated wait time in seconds, or 0 if tokens are available
    public func estimatedWaitTime() -> TimeInterval {
        refillTokens()

        if tokens > 0 {
            return 0.0
        }

        // Calculate when next token will be available
        let tokensNeeded = 1 - tokens
        return Double(tokensNeeded) / refillRate
    }

    /// Resets the rate limiter to full capacity.
    public func reset() {
        tokens = maxRequests
        lastRefillTime = Date()

        // Resume all waiting tasks
        for waiting in waitQueue {
            waiting.continuation.resume()
        }
        waitQueue.removeAll()
    }

    /// Returns statistics about the rate limiter.
    ///
    /// - Returns: Dictionary with statistics
    public func statistics() -> [String: Any] {
        refillTokens()

        return [
            "available_tokens": tokens,
            "max_requests": maxRequests,
            "time_window_seconds": timeWindow,
            "refill_rate": refillRate,
            "queue_length": waitQueue.count,
            "estimated_wait_time": estimatedWaitTime()
        ]
    }
}

// MARK: - Preset Rate Limiters

extension AIRateLimiter {

    /// Creates a rate limiter for OpenAI's rate limits (tier 1).
    ///
    /// - Returns: A rate limiter configured for OpenAI (500 requests per minute)
    public static func openAI() -> AIRateLimiter {
        return AIRateLimiter(maxRequests: 500, timeWindow: 60.0)
    }

    /// Creates a rate limiter for Anthropic's rate limits.
    ///
    /// - Returns: A rate limiter configured for Anthropic (50 requests per minute)
    public static func anthropic() -> AIRateLimiter {
        return AIRateLimiter(maxRequests: 50, timeWindow: 60.0)
    }

    /// Creates a rate limiter for ElevenLabs' rate limits.
    ///
    /// - Returns: A rate limiter configured for ElevenLabs (300 requests per minute)
    public static func elevenLabs() -> AIRateLimiter {
        return AIRateLimiter(maxRequests: 300, timeWindow: 60.0)
    }

    /// Creates a rate limiter with no limits (for testing or unlimited APIs).
    ///
    /// - Returns: A rate limiter that never blocks
    public static func unlimited() -> AIRateLimiter {
        return AIRateLimiter(maxRequests: Int.max, timeWindow: 1.0)
    }
}
