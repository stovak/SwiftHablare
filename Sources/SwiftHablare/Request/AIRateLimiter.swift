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

    /// Queue of waiting task continuations.
    private var waitQueue: [CheckedContinuation<Void, Never>] = []

    /// Task responsible for waking queued callers when tokens become available.
    private var scheduledRefillTask: Task<Void, Never>?

    /// Minimum delay between scheduled refill checks to avoid busy waiting.
    private let minimumSchedulerInterval: TimeInterval = 0.01

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
            waitQueue.append(continuation)
            scheduleRefillIfNeeded()
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

        scheduleRefillIfNeeded()
        return false
    }

    /// Refills tokens based on elapsed time.
    private func refillTokens() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRefillTime)

        // Unlimited limiters simply reset to full capacity without performing
        // arithmetic that can overflow on platforms without 128-bit doubles.
        if maxRequests == Int.max {
            tokens = maxRequests
            lastRefillTime = now
            processWaitQueue()
            return
        }

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
            let continuation = waitQueue.removeFirst()
            tokens -= 1
            continuation.resume()
        }

        if tokens == 0 && !waitQueue.isEmpty {
            scheduleRefillIfNeeded()
        }
    }

    /// Schedules a future refill attempt when callers are waiting for tokens.
    private func scheduleRefillIfNeeded() {
        guard !waitQueue.isEmpty else { return }
        guard scheduledRefillTask == nil else { return }
        guard maxRequests != Int.max else { return }

        let delay = max(nextTokenDelay(), minimumSchedulerInterval)
        let nanoseconds = Self.nanoseconds(from: delay)

        scheduledRefillTask = Task { [self] in
            if nanoseconds > 0 {
                try? await Task.sleep(nanoseconds: nanoseconds)
            }
            await self.handleScheduledRefill()
        }
    }

    /// Handles a scheduled refill timer firing.
    private func handleScheduledRefill() async {
        scheduledRefillTask = nil

        if Task.isCancelled {
            return
        }

        refillTokens()
    }

    /// Calculates the delay until the next token should become available.
    private func nextTokenDelay() -> TimeInterval {
        if refillRate <= 0 {
            return max(timeWindow, minimumSchedulerInterval)
        }

        let safeMaxRequests = max(1, maxRequests)
        let timePerToken = max(timeWindow, minimumSchedulerInterval) / Double(safeMaxRequests)
        let elapsed = Date().timeIntervalSince(lastRefillTime)
        let remaining = timePerToken - elapsed

        if remaining.isFinite && remaining > 0 {
            return remaining
        }

        return timePerToken
    }

    /// Converts a `TimeInterval` to nanoseconds with overflow protection.
    private static func nanoseconds(from timeInterval: TimeInterval) -> UInt64 {
        guard timeInterval.isFinite, timeInterval > 0 else { return 0 }

        let maxInterval = TimeInterval(UInt64.max) / 1_000_000_000.0
        let clamped = min(timeInterval, maxInterval)
        return UInt64(clamped * 1_000_000_000.0)
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
        scheduledRefillTask?.cancel()
        scheduledRefillTask = nil

        for continuation in waitQueue {
            continuation.resume()
        }
        waitQueue.removeAll()
    }

    /// Statistics about the rate limiter.
    public struct Statistics: Sendable {
        public let availableTokens: Int
        public let maxRequests: Int
        public let timeWindowSeconds: TimeInterval
        public let refillRate: Double
        public let queueLength: Int
        public let estimatedWaitTime: TimeInterval
    }

    /// Returns statistics about the rate limiter.
    ///
    /// - Returns: Statistics about the rate limiter
    public func statistics() -> Statistics {
        refillTokens()

        return Statistics(
            availableTokens: tokens,
            maxRequests: maxRequests,
            timeWindowSeconds: timeWindow,
            refillRate: refillRate,
            queueLength: waitQueue.count,
            estimatedWaitTime: estimatedWaitTime()
        )
    }

    deinit {
        scheduledRefillTask?.cancel()
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
