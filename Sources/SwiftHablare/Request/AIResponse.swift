import Foundation

/// A response from an AI service.
///
/// `AIResponse` encapsulates the result of an AI service request, including
/// the generated content, metadata, and provider information.
///
/// ## Example
/// ```swift
/// let response = AIResponse(
///     content: generatedData,
///     provider: provider.id,
///     model: "gpt-4",
///     finishReason: .completed
/// )
/// ```
public struct AIResponse: Sendable {

    /// The generated content data.
    public let content: Data

    /// The ID of the provider that generated this response.
    public let providerID: String

    /// The model used to generate the response (if available).
    public let model: String?

    /// The reason the generation finished.
    public let finishReason: FinishReason

    /// Unique identifier for this response.
    public let id: UUID

    /// Timestamp when the response was received.
    public let receivedAt: Date

    /// Usage statistics for this request (if available).
    public let usage: Usage?

    /// Additional metadata from the provider.
    public let metadata: [String: String]

    /// Whether this response came from cache.
    public let fromCache: Bool

    /// The original request that generated this response.
    public let request: AIRequest?

    /// Creates a new AI response.
    ///
    /// - Parameters:
    ///   - content: The generated content data
    ///   - providerID: ID of the provider
    ///   - model: Model used (optional)
    ///   - finishReason: Reason generation finished
    ///   - usage: Usage statistics (optional)
    ///   - metadata: Additional metadata
    ///   - fromCache: Whether from cache (default: false)
    ///   - request: Original request (optional)
    public init(
        content: Data,
        providerID: String,
        model: String? = nil,
        finishReason: FinishReason = .completed,
        usage: Usage? = nil,
        metadata: [String: String] = [:],
        fromCache: Bool = false,
        request: AIRequest? = nil
    ) {
        self.content = content
        self.providerID = providerID
        self.model = model
        self.finishReason = finishReason
        self.id = UUID()
        self.receivedAt = Date()
        self.usage = usage
        self.metadata = metadata
        self.fromCache = fromCache
        self.request = request
    }

    /// Converts the response content to a string.
    ///
    /// - Returns: String representation of the content, or nil if not valid UTF-8
    public func asString() -> String? {
        return String(data: content, encoding: .utf8)
    }

    /// Converts the response content to a specific type.
    ///
    /// - Returns: The decoded object
    /// - Throws: `DecodingError` if decoding fails
    public func decode<T: Decodable>() throws -> T {
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: content)
    }
}

// MARK: - Supporting Types

extension AIResponse {

    /// Reason why the generation finished.
    public enum FinishReason: String, Sendable {
        /// Generation completed successfully.
        case completed

        /// Generation stopped due to length limit.
        case lengthLimit = "length_limit"

        /// Generation stopped due to content filter.
        case contentFilter = "content_filter"

        /// Generation stopped by explicit stop sequence.
        case stopSequence = "stop_sequence"

        /// Generation stopped by user cancellation.
        case cancelled

        /// Generation stopped due to error.
        case error

        /// Unknown finish reason.
        case unknown
    }

    /// Usage statistics for the request.
    public struct Usage: Sendable {
        /// Number of tokens in the prompt.
        public let promptTokens: Int?

        /// Number of tokens in the completion.
        public let completionTokens: Int?

        /// Total number of tokens used.
        public let totalTokens: Int?

        /// Cost of the request (if available).
        public let cost: Decimal?

        /// Creates usage statistics.
        ///
        /// - Parameters:
        ///   - promptTokens: Prompt token count
        ///   - completionTokens: Completion token count
        ///   - totalTokens: Total token count
        ///   - cost: Request cost
        public init(
            promptTokens: Int? = nil,
            completionTokens: Int? = nil,
            totalTokens: Int? = nil,
            cost: Decimal? = nil
        ) {
            self.promptTokens = promptTokens
            self.completionTokens = completionTokens
            self.totalTokens = totalTokens
            self.cost = cost
        }
    }
}

// MARK: - Batch Response

/// A collection of responses from a batch request.
///
/// `AIBatchResponse` groups multiple responses together and tracks
/// successes, failures, and partial failures.
public struct AIBatchResponse: Sendable {

    /// Successfully completed responses.
    public let successes: [AIResponse]

    /// Failed requests with their errors.
    public let failures: [(request: AIRequest, error: AIServiceError)]

    /// Timestamp when the batch completed.
    public let completedAt: Date

    /// Total number of requests in the batch.
    public var totalRequests: Int {
        return successes.count + failures.count
    }

    /// Success rate (0.0 to 1.0).
    public var successRate: Double {
        guard totalRequests > 0 else { return 0.0 }
        return Double(successes.count) / Double(totalRequests)
    }

    /// Creates a new batch response.
    ///
    /// - Parameters:
    ///   - successes: Successful responses
    ///   - failures: Failed requests with errors
    public init(
        successes: [AIResponse],
        failures: [(request: AIRequest, error: AIServiceError)] = []
    ) {
        self.successes = successes
        self.failures = failures
        self.completedAt = Date()
    }

    /// Whether all requests in the batch succeeded.
    public var allSucceeded: Bool {
        return failures.isEmpty
    }

    /// Whether any requests succeeded.
    public var anySucceeded: Bool {
        return !successes.isEmpty
    }

    /// Whether all requests failed.
    public var allFailed: Bool {
        return successes.isEmpty
    }
}
