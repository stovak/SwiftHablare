//
//  BaseHTTPProvider.swift
//  SwiftHablare
//
//  Base HTTP client for AI service providers
//

import Foundation

/// Base class providing HTTP networking functionality for AI service providers.
///
/// This class provides common HTTP request functionality including:
/// - JSON encoding/decoding
/// - Error handling
/// - Request configuration
/// - Retry logic (future)
///
/// Providers should subclass this and implement provider-specific API logic.
@available(macOS 15.0, iOS 17.0, *)
open class BaseHTTPProvider: @unchecked Sendable {
    /// HTTP client for making requests
    private let urlSession: URLSession

    /// API base URL
    public let baseURL: String

    /// Default request timeout
    public let timeout: TimeInterval

    /// Initialize with custom configuration
    /// - Parameters:
    ///   - baseURL: Base URL for API requests
    ///   - timeout: Request timeout in seconds (default: 60)
    ///   - urlSession: Custom URLSession (default: shared)
    public init(
        baseURL: String,
        timeout: TimeInterval = 60.0,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.urlSession = urlSession
    }

    /// Make a JSON POST request
    /// - Parameters:
    ///   - endpoint: API endpoint (appended to baseURL)
    ///   - headers: HTTP headers
    ///   - body: Request body (will be JSON encoded)
    /// - Returns: Decoded response or throws error
    public func post<Request: Encodable, Response: Decodable>(
        endpoint: String,
        headers: [String: String],
        body: Request
    ) async throws -> Response {
        // Build URL
        guard let url = URL(string: baseURL + endpoint) else {
            throw AIServiceError.configurationError("Invalid URL: \(baseURL + endpoint)")
        }

        // Create request
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"

        // Set headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Encode body
        let encoder = JSONEncoder()
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw AIServiceError.configurationError("Failed to encode request body: \(error.localizedDescription)")
        }

        // Execute request with error mapping
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw mapURLError(error)
        }

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.networkError("Invalid response type")
        }

        // Handle error responses
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to decode error response
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"

            switch httpResponse.statusCode {
            case 401:
                throw AIServiceError.authenticationFailed("Authentication failed: \(errorMessage)")
            case 429:
                throw AIServiceError.rateLimitExceeded("Rate limit exceeded: \(errorMessage)")
            case 400...499:
                throw AIServiceError.invalidRequest("Invalid request (\(httpResponse.statusCode)): \(errorMessage)")
            case 500...599:
                throw AIServiceError.providerError("Server error (\(httpResponse.statusCode)): \(errorMessage)")
            default:
                throw AIServiceError.networkError("HTTP error \(httpResponse.statusCode): \(errorMessage)")
            }
        }

        // Decode response
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw AIServiceError.dataConversionError("Failed to decode response: \(error.localizedDescription)")
        }
    }

    /// Make a GET request
    /// - Parameters:
    ///   - endpoint: API endpoint
    ///   - headers: HTTP headers
    /// - Returns: Decoded response or throws error
    public func get<Response: Decodable>(
        endpoint: String,
        headers: [String: String]
    ) async throws -> Response {
        // Build URL
        guard let url = URL(string: baseURL + endpoint) else {
            throw AIServiceError.configurationError("Invalid URL: \(baseURL + endpoint)")
        }

        // Create request
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"

        // Set headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Execute request with error mapping
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw mapURLError(error)
        }

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.networkError("Invalid response type")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.networkError("HTTP error \(httpResponse.statusCode): \(errorMessage)")
        }

        // Decode response
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw AIServiceError.dataConversionError("Failed to decode response: \(error.localizedDescription)")
        }
    }

    // MARK: - Error Mapping

    /// Maps URLError to AIServiceError for consistent error handling.
    ///
    /// This ensures that all network errors are presented using the framework's
    /// unified error model, regardless of the underlying URLSession error.
    ///
    /// - Parameter error: The error thrown by URLSession
    /// - Returns: Mapped AIServiceError
    private func mapURLError(_ error: Error) -> AIServiceError {
        // If it's already an AIServiceError, pass it through
        if let aiError = error as? AIServiceError {
            return aiError
        }

        // Map URLError codes to AIServiceError
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return .timeout("Request timed out after \(timeout) seconds")

            case .notConnectedToInternet, .networkConnectionLost:
                return .connectionFailed("No internet connection available")

            case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return .connectionFailed("Cannot connect to server: \(urlError.localizedDescription)")

            case .secureConnectionFailed, .serverCertificateUntrusted, .clientCertificateRejected:
                return .connectionFailed("Secure connection failed: \(urlError.localizedDescription)")

            case .cancelled:
                return .networkError("Request was cancelled")

            case .badURL, .unsupportedURL:
                return .configurationError("Invalid URL: \(urlError.localizedDescription)")

            case .dataNotAllowed, .internationalRoamingOff:
                return .connectionFailed("Data connection not available: \(urlError.localizedDescription)")

            default:
                return .networkError("Network error: \(urlError.localizedDescription) (code: \(urlError.code.rawValue))")
            }
        }

        // For any other error type, wrap as network error
        return .networkError("Network request failed: \(error.localizedDescription)")
    }
}
