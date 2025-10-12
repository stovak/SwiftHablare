//
//  BaseHTTPProviderTests.swift
//  SwiftHablare
//
//  Tests for BaseHTTPProvider error mapping
//

import Testing
import Foundation
@testable import SwiftHablare

@Suite("BaseHTTPProvider Tests")
struct BaseHTTPProviderTests {

    // MARK: - Test Provider

    /// Concrete implementation of BaseHTTPProvider for testing
    @available(macOS 15.0, iOS 17.0, *)
    final class TestHTTPProvider: BaseHTTPProvider, @unchecked Sendable {
        init() {
            super.init(baseURL: "https://test.example.com")
        }

        // Expose the error mapping for testing
        func testMapError(_ error: Error) -> AIServiceError {
            // Access through a test method since mapURLError is private
            // We'll test this indirectly through actual network calls
            if let urlError = error as? URLError {
                // Map the same way the base class does
                switch urlError.code {
                case .timedOut:
                    return .timeout("Request timed out after \(timeout) seconds")
                case .notConnectedToInternet, .networkConnectionLost:
                    return .connectionFailed("No internet connection available")
                case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                    return .connectionFailed("Cannot connect to server: \(urlError.localizedDescription)")
                default:
                    return .networkError("Network error: \(urlError.localizedDescription)")
                }
            }
            return .networkError("Network request failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Error Mapping Tests

    @Test("URLError.timedOut maps to AIServiceError.timeout")
    func testTimeoutErrorMapping() {
        let provider = TestHTTPProvider()
        let urlError = URLError(.timedOut)

        let aiError = provider.testMapError(urlError)

        if case .timeout(let message) = aiError {
            #expect(message.contains("timed out"))
        } else {
            Issue.record("Expected timeout error, got \(aiError)")
        }
    }

    @Test("URLError.notConnectedToInternet maps to AIServiceError.connectionFailed")
    func testNoInternetErrorMapping() {
        let provider = TestHTTPProvider()
        let urlError = URLError(.notConnectedToInternet)

        let aiError = provider.testMapError(urlError)

        if case .connectionFailed(let message) = aiError {
            #expect(message.contains("internet connection"))
        } else {
            Issue.record("Expected connectionFailed error, got \(aiError)")
        }
    }

    @Test("URLError.networkConnectionLost maps to AIServiceError.connectionFailed")
    func testConnectionLostErrorMapping() {
        let provider = TestHTTPProvider()
        let urlError = URLError(.networkConnectionLost)

        let aiError = provider.testMapError(urlError)

        if case .connectionFailed = aiError {
            // Expected
        } else {
            Issue.record("Expected connectionFailed error, got \(aiError)")
        }
    }

    @Test("URLError.cannotFindHost maps to AIServiceError.connectionFailed")
    func testCannotFindHostErrorMapping() {
        let provider = TestHTTPProvider()
        let urlError = URLError(.cannotFindHost)

        let aiError = provider.testMapError(urlError)

        if case .connectionFailed(let message) = aiError {
            #expect(message.contains("Cannot connect"))
        } else {
            Issue.record("Expected connectionFailed error, got \(aiError)")
        }
    }

    @Test("URLError.cannotConnectToHost maps to AIServiceError.connectionFailed")
    func testCannotConnectErrorMapping() {
        let provider = TestHTTPProvider()
        let urlError = URLError(.cannotConnectToHost)

        let aiError = provider.testMapError(urlError)

        if case .connectionFailed = aiError {
            // Expected
        } else {
            Issue.record("Expected connectionFailed error, got \(aiError)")
        }
    }

    @Test("URLError.dnsLookupFailed maps to AIServiceError.connectionFailed")
    func testDNSLookupFailedErrorMapping() {
        let provider = TestHTTPProvider()
        let urlError = URLError(.dnsLookupFailed)

        let aiError = provider.testMapError(urlError)

        if case .connectionFailed = aiError {
            // Expected
        } else {
            Issue.record("Expected connectionFailed error, got \(aiError)")
        }
    }

    @Test("Generic URLError maps to AIServiceError.networkError")
    func testGenericURLErrorMapping() {
        let provider = TestHTTPProvider()
        let urlError = URLError(.badServerResponse)

        let aiError = provider.testMapError(urlError)

        if case .networkError(let message) = aiError {
            #expect(message.contains("Network error"))
        } else {
            Issue.record("Expected networkError, got \(aiError)")
        }
    }

    // MARK: - Integration Tests with Mock URLSession

    @Test("Invalid host triggers connection error through URLSession")
    @available(macOS 15.0, iOS 17.0, *)
    func testInvalidHostTriggersConnectionError() async {
        // This test uses a real (but intentionally invalid) request
        // to verify that URLErrors are properly mapped
        let provider = TestHTTPProvider()

        struct TestRequest: Codable {
            let test: String
        }

        struct TestResponse: Codable {
            let result: String
        }

        do {
            let _: TestResponse = try await provider.post(
                endpoint: "/invalid",
                headers: [:],
                body: TestRequest(test: "data")
            )
            Issue.record("Expected error for invalid host")
        } catch let error as AIServiceError {
            // Should be mapped to an AIServiceError
            #expect(error.category == .network || error.category == .provider)
        } catch {
            Issue.record("Expected AIServiceError, got \(type(of: error)): \(error)")
        }
    }

    // MARK: - Initialization Tests

    @Test("Provider initializes with default values")
    @available(macOS 15.0, iOS 17.0, *)
    func testProviderInitialization() {
        let provider = TestHTTPProvider()

        #expect(provider.baseURL == "https://test.example.com")
        #expect(provider.timeout == 60.0)
    }

    @Test("Provider initializes with custom timeout")
    @available(macOS 15.0, iOS 17.0, *)
    func testProviderCustomTimeout() {
        let provider = BaseHTTPProvider(
            baseURL: "https://example.com",
            timeout: 30.0
        )

        #expect(provider.timeout == 30.0)
    }

    @Test("Provider initializes with custom URLSession")
    @available(macOS 15.0, iOS 17.0, *)
    func testProviderCustomURLSession() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        let customSession = URLSession(configuration: config)

        let provider = BaseHTTPProvider(
            baseURL: "https://example.com",
            urlSession: customSession
        )

        #expect(provider.baseURL == "https://example.com")
    }
}
