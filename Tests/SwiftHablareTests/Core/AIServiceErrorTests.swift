import Testing
import Foundation
@testable import SwiftHablare

struct AIServiceErrorTests {

    @Test("Error descriptions are correct")
    func testErrorDescriptions() {
        let configError = AIServiceError.configurationError("Config issue")
        #expect(configError.errorDescription == "Config issue")

        let networkError = AIServiceError.networkError("Network failed")
        #expect(networkError.errorDescription == "Network failed")

        let rateLimitError = AIServiceError.rateLimitExceeded("Too many requests", retryAfter: 60)
        #expect(rateLimitError.errorDescription == "Too many requests")
    }

    @Test("Error categories are correct")
    func testErrorCategories() {
        #expect(AIServiceError.configurationError("test").category == .configuration)
        #expect(AIServiceError.invalidAPIKey("test").category == .configuration)
        #expect(AIServiceError.missingCredentials("test").category == .configuration)

        #expect(AIServiceError.networkError("test").category == .network)
        #expect(AIServiceError.timeout("test").category == .network)
        #expect(AIServiceError.connectionFailed("test").category == .network)

        #expect(AIServiceError.providerError("test").category == .provider)
        #expect(AIServiceError.rateLimitExceeded("test").category == .provider)
        #expect(AIServiceError.authenticationFailed("test").category == .provider)
        #expect(AIServiceError.invalidRequest("test").category == .provider)

        #expect(AIServiceError.validationError("test").category == .data)
        #expect(AIServiceError.unexpectedResponseFormat("test").category == .data)
        #expect(AIServiceError.dataConversionError("test").category == .data)

        #expect(AIServiceError.persistenceError("test").category == .storage)
        #expect(AIServiceError.modelNotFound("test").category == .storage)
    }

    @Test("Recoverable errors are identified correctly")
    func testRecoverability() {
        // Recoverable errors
        #expect(AIServiceError.timeout("test").isRecoverable == true)
        #expect(AIServiceError.connectionFailed("test").isRecoverable == true)
        #expect(AIServiceError.networkError("test").isRecoverable == true)
        #expect(AIServiceError.rateLimitExceeded("test").isRecoverable == true)

        // Non-recoverable errors
        #expect(AIServiceError.configurationError("test").isRecoverable == false)
        #expect(AIServiceError.invalidAPIKey("test").isRecoverable == false)
        #expect(AIServiceError.authenticationFailed("test").isRecoverable == false)
        #expect(AIServiceError.validationError("test").isRecoverable == false)
        #expect(AIServiceError.persistenceError("test").isRecoverable == false)
    }

    @Test("Retry delays are correct")
    func testRetryDelays() {
        // Rate limit with specific retry time
        let rateLimitError = AIServiceError.rateLimitExceeded("test", retryAfter: 120)
        #expect(rateLimitError.retryDelay == 120)

        // Rate limit without retry time
        let rateLimitNoRetry = AIServiceError.rateLimitExceeded("test")
        #expect(rateLimitNoRetry.retryDelay == nil)

        // Timeout has default retry
        let timeoutError = AIServiceError.timeout("test")
        #expect(timeoutError.retryDelay == 5.0)

        // Connection failed has default retry
        let connectionError = AIServiceError.connectionFailed("test")
        #expect(connectionError.retryDelay == 5.0)

        // Network error has shorter retry
        let networkError = AIServiceError.networkError("test")
        #expect(networkError.retryDelay == 2.0)

        // Non-recoverable errors have no retry delay
        let configError = AIServiceError.configurationError("test")
        #expect(configError.retryDelay == nil)
    }

    @Test("Localized error properties work")
    func testLocalizedError() {
        let error = AIServiceError.configurationError("Config issue")

        #expect(error.localizedDescription == "Config issue")
        #expect(error.failureReason == "Provider is not properly configured")
        #expect(error.recoverySuggestion == "Check your provider configuration and API key in settings")
    }

    @Test("Provider error with code")
    func testProviderErrorWithCode() {
        let error = AIServiceError.providerError("API error", code: "ERR_500")

        #expect(error.errorDescription == "API error")
        #expect(error.category == .provider)

        // Verify code is preserved
        if case .providerError(_, let code) = error {
            #expect(code == "ERR_500")
        } else {
            Issue.record("Expected providerError case")
        }
    }

    @Test("Error description formatting")
    func testErrorDescription() {
        let error = AIServiceError.configurationError("Test message")
        let description = error.description

        #expect(description.contains("AIServiceError"))
        #expect(description.contains("configuration"))
        #expect(description.contains("Test message"))
    }

    @Test("All error categories are unique")
    func testErrorCategoryUniqueness() {
        let categories: Set<ErrorCategory> = [
            .configuration,
            .network,
            .provider,
            .data,
            .storage
        ]

        #expect(categories.count == 5)
    }

    @Test("Error can be thrown and caught")
    func testErrorThrowingAndCatching() async throws {
        func throwingFunction() throws {
            throw AIServiceError.configurationError("Test error")
        }

        do {
            try throwingFunction()
            Issue.record("Should have thrown error")
        } catch let error as AIServiceError {
            #expect(error.errorDescription == "Test error")
            #expect(error.category == .configuration)
        } catch {
            Issue.record("Wrong error type caught")
        }
    }

    @Test("Async error handling works")
    func testAsyncErrorHandling() async {
        func asyncThrowingFunction() async throws -> String {
            throw AIServiceError.networkError("Network failed")
        }

        do {
            _ = try await asyncThrowingFunction()
            Issue.record("Should have thrown error")
        } catch let error as AIServiceError {
            #expect(error.category == .network)
            #expect(error.isRecoverable == true)
        } catch {
            Issue.record("Wrong error type caught")
        }
    }

    @Test("Recovery suggestions are helpful")
    func testRecoverySuggestions() {
        let configError = AIServiceError.configurationError("test")
        #expect(configError.recoverySuggestion?.contains("configuration") == true)

        let networkError = AIServiceError.networkError("test")
        #expect(networkError.recoverySuggestion?.contains("connection") == true)

        let rateLimitError = AIServiceError.rateLimitExceeded("test", retryAfter: 60)
        #expect(rateLimitError.recoverySuggestion?.contains("60") == true)

        let authError = AIServiceError.authenticationFailed("test")
        #expect(authError.recoverySuggestion?.contains("API key") == true)
    }

    @Test("Error is Sendable")
    func testSendable() async {
        let error = AIServiceError.networkError("test")

        await Task {
            // Should compile without warnings due to Sendable conformance
            let _ = error.errorDescription
        }.value
    }

    @Test("Errors with same parameters are equal")
    func testErrorEquality() {
        // Note: Swift enums with associated values use structural equality
        let error1 = AIServiceError.configurationError("test")
        let error2 = AIServiceError.configurationError("test")
        let error3 = AIServiceError.configurationError("different")

        // These are not directly comparable with ==, but we can match them
        if case .configurationError(let msg1) = error1,
           case .configurationError(let msg2) = error2 {
            #expect(msg1 == msg2)
        }

        if case .configurationError(let msg1) = error1,
           case .configurationError(let msg3) = error3 {
            #expect(msg1 != msg3)
        }
    }
}
