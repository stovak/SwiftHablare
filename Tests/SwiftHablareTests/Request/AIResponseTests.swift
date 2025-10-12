import Testing
import Foundation
@testable import SwiftHablare

struct AIResponseTests {

    @Test("AIResponse initializes with minimal parameters")
    func testMinimalInitialization() {
        let content = "Test response".data(using: .utf8)!
        let response = AIResponse(
            content: content,
            providerID: "test-provider"
        )

        #expect(response.content == content)
        #expect(response.providerID == "test-provider")
        #expect(response.model == nil)
        #expect(response.finishReason == .completed)
        #expect(response.usage == nil)
        #expect(response.metadata.isEmpty)
        #expect(response.fromCache == false)
        #expect(response.request == nil)
        #expect(response.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    @Test("AIResponse initializes with all parameters")
    func testFullInitialization() {
        let content = "Test response".data(using: .utf8)!
        let usage = AIResponse.Usage(
            promptTokens: 10,
            completionTokens: 20,
            totalTokens: 30,
            cost: 0.001
        )
        let metadata = ["temperature": "0.7"]
        let request = AIRequest(prompt: "Test prompt")

        let response = AIResponse(
            content: content,
            providerID: "test-provider",
            model: "gpt-4",
            finishReason: .completed,
            usage: usage,
            metadata: metadata,
            fromCache: true,
            request: request
        )

        #expect(response.content == content)
        #expect(response.providerID == "test-provider")
        #expect(response.model == "gpt-4")
        #expect(response.finishReason == .completed)
        #expect(response.usage?.promptTokens == 10)
        #expect(response.usage?.completionTokens == 20)
        #expect(response.usage?.totalTokens == 30)
        #expect(response.usage?.cost == 0.001)
        #expect(response.metadata == metadata)
        #expect(response.fromCache == true)
        #expect(response.request?.prompt == "Test prompt")
    }

    @Test("AIResponse asString converts content to string")
    func testAsString() {
        let content = "Hello, World!".data(using: .utf8)!
        let response = AIResponse(
            content: content,
            providerID: "test"
        )

        let string = response.asString()

        #expect(string == "Hello, World!")
    }

    @Test("AIResponse asString returns nil for invalid UTF-8")
    func testAsStringInvalidUTF8() {
        let content = Data([0xFF, 0xFE, 0xFD]) // Invalid UTF-8
        let response = AIResponse(
            content: content,
            providerID: "test"
        )

        let string = response.asString()

        #expect(string == nil)
    }

    @Test("AIResponse decode JSON content")
    func testDecodeJSON() throws {
        struct TestData: Codable, Equatable {
            let message: String
            let count: Int
        }

        let testData = TestData(message: "Hello", count: 42)
        let content = try JSONEncoder().encode(testData)

        let response = AIResponse(
            content: content,
            providerID: "test"
        )

        let decoded: TestData = try response.decode()

        #expect(decoded == testData)
    }

    @Test("AIResponse decode throws on invalid JSON")
    func testDecodeInvalidJSON() {
        struct TestData: Codable {
            let message: String
        }

        let content = "Not JSON".data(using: .utf8)!
        let response = AIResponse(
            content: content,
            providerID: "test"
        )

        #expect(throws: DecodingError.self) {
            let _: TestData = try response.decode()
        }
    }

    @Test("AIResponse FinishReason all cases")
    func testFinishReasonCases() {
        #expect(AIResponse.FinishReason.completed.rawValue == "completed")
        #expect(AIResponse.FinishReason.lengthLimit.rawValue == "length_limit")
        #expect(AIResponse.FinishReason.contentFilter.rawValue == "content_filter")
        #expect(AIResponse.FinishReason.stopSequence.rawValue == "stop_sequence")
        #expect(AIResponse.FinishReason.cancelled.rawValue == "cancelled")
        #expect(AIResponse.FinishReason.error.rawValue == "error")
        #expect(AIResponse.FinishReason.unknown.rawValue == "unknown")
    }

    @Test("AIResponse Usage initializes with all fields")
    func testUsageFullInitialization() {
        let usage = AIResponse.Usage(
            promptTokens: 100,
            completionTokens: 200,
            totalTokens: 300,
            cost: 0.05
        )

        #expect(usage.promptTokens == 100)
        #expect(usage.completionTokens == 200)
        #expect(usage.totalTokens == 300)
        #expect(usage.cost == 0.05)
    }

    @Test("AIResponse Usage initializes with minimal fields")
    func testUsageMinimalInitialization() {
        let usage = AIResponse.Usage()

        #expect(usage.promptTokens == nil)
        #expect(usage.completionTokens == nil)
        #expect(usage.totalTokens == nil)
        #expect(usage.cost == nil)
    }

    @Test("AIResponse Usage initializes with partial fields")
    func testUsagePartialInitialization() {
        let usage = AIResponse.Usage(
            promptTokens: 50,
            completionTokens: 75
        )

        #expect(usage.promptTokens == 50)
        #expect(usage.completionTokens == 75)
        #expect(usage.totalTokens == nil)
        #expect(usage.cost == nil)
    }

    @Test("AIResponse is Sendable")
    func testSendable() async {
        let content = "Test".data(using: .utf8)!
        let response = AIResponse(
            content: content,
            providerID: "test"
        )

        await Task {
            // Should compile without warnings
            let _ = response.content
        }.value
    }

    // MARK: - AIBatchResponse Tests

    @Test("AIBatchResponse initializes with successes only")
    func testBatchResponseSuccessesOnly() {
        let response1 = AIResponse(
            content: "Test 1".data(using: .utf8)!,
            providerID: "test"
        )
        let response2 = AIResponse(
            content: "Test 2".data(using: .utf8)!,
            providerID: "test"
        )

        let batch = AIBatchResponse(successes: [response1, response2])

        #expect(batch.successes.count == 2)
        #expect(batch.failures.isEmpty)
        #expect(batch.totalRequests == 2)
        #expect(batch.successRate == 1.0)
        #expect(batch.allSucceeded == true)
        #expect(batch.anySucceeded == true)
        #expect(batch.allFailed == false)
    }

    @Test("AIBatchResponse initializes with failures")
    func testBatchResponseWithFailures() {
        let response = AIResponse(
            content: "Test".data(using: .utf8)!,
            providerID: "test"
        )
        let request = AIRequest(prompt: "Failed request")
        let error = AIServiceError.networkError("Connection failed")

        let batch = AIBatchResponse(
            successes: [response],
            failures: [(request, error)]
        )

        #expect(batch.successes.count == 1)
        #expect(batch.failures.count == 1)
        #expect(batch.totalRequests == 2)
        #expect(batch.successRate == 0.5)
        #expect(batch.allSucceeded == false)
        #expect(batch.anySucceeded == true)
        #expect(batch.allFailed == false)
    }

    @Test("AIBatchResponse all failures")
    func testBatchResponseAllFailures() {
        let request1 = AIRequest(prompt: "Request 1")
        let request2 = AIRequest(prompt: "Request 2")
        let error = AIServiceError.networkError("Failed")

        let batch = AIBatchResponse(
            successes: [],
            failures: [(request1, error), (request2, error)]
        )

        #expect(batch.successes.isEmpty)
        #expect(batch.failures.count == 2)
        #expect(batch.totalRequests == 2)
        #expect(batch.successRate == 0.0)
        #expect(batch.allSucceeded == false)
        #expect(batch.anySucceeded == false)
        #expect(batch.allFailed == true)
    }

    @Test("AIBatchResponse empty batch")
    func testBatchResponseEmpty() {
        let batch = AIBatchResponse(successes: [], failures: [])

        #expect(batch.totalRequests == 0)
        #expect(batch.successRate == 0.0)
        #expect(batch.allSucceeded == true) // Vacuously true
        #expect(batch.anySucceeded == false)
        #expect(batch.allFailed == true) // Vacuously true
    }

    @Test("AIBatchResponse success rate calculation")
    func testBatchResponseSuccessRate() {
        let responses = (0..<7).map { i in
            AIResponse(
                content: "Test \(i)".data(using: .utf8)!,
                providerID: "test"
            )
        }

        let failures = (0..<3).map { i in
            (
                AIRequest(prompt: "Failed \(i)"),
                AIServiceError.networkError("Error")
            )
        }

        let batch = AIBatchResponse(successes: responses, failures: failures)

        #expect(batch.totalRequests == 10)
        #expect(batch.successRate == 0.7)
    }

    @Test("AIBatchResponse completedAt is set")
    func testBatchResponseCompletedAt() {
        let before = Date()
        let batch = AIBatchResponse(successes: [], failures: [])
        let after = Date()

        #expect(batch.completedAt >= before)
        #expect(batch.completedAt <= after)
    }

    @Test("AIBatchResponse is Sendable")
    func testBatchResponseSendable() async {
        let response = AIResponse(
            content: "Test".data(using: .utf8)!,
            providerID: "test"
        )
        let batch = AIBatchResponse(successes: [response])

        await Task {
            // Should compile without warnings
            let _ = batch.successRate
        }.value
    }
}
