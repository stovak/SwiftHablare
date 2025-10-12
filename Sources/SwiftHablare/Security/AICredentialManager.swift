//
//  AICredentialManager.swift
//  SwiftHablare
//
//  Thread-safe credential management with lifecycle support
//

import Foundation

/// Thread-safe actor for managing AI service credentials
public actor AICredentialManager {
    /// Shared instance
    public static let shared = AICredentialManager()

    private let keychainManager: SecureKeychainManager
    private var credentials: [String: AICredential] = [:]

    /// Initialize with custom keychain manager (mainly for testing)
    public init(keychainManager: SecureKeychainManager = .shared) {
        self.keychainManager = keychainManager
    }

    // MARK: - Credential Operations

    /// Store a new credential
    /// - Parameters:
    ///   - credential: The credential metadata to store
    ///   - value: The sensitive credential value (API key, token, etc.)
    /// - Throws: AICredentialError if the credential already exists or storage fails
    public func store(credential: AICredential, value: SecureString) throws {
        let key = credentialKey(providerID: credential.providerID, type: credential.type)

        // Check if credential already exists
        if credentials[key] != nil {
            throw AICredentialError.alreadyExists
        }

        // Validate and store in keychain based on type
        switch credential.type {
        case .apiKey:
            try keychainManager.saveAPIKey(value.value, for: key, validate: true)

        case .oauthToken:
            try keychainManager.saveOAuthToken(value.value, for: key, validate: true)

        case .certificate:
            guard let data = value.value.data(using: .utf8) else {
                throw AICredentialError.invalidFormat("Unable to encode certificate data")
            }
            try keychainManager.saveCertificate(data, for: key, validate: true)

        case .custom:
            // For custom types, store as API key without validation
            try keychainManager.saveAPIKey(value.value, for: key, validate: false)
        }

        // Store metadata
        credentials[key] = credential

        // Clear the secure string
        value.clear()
    }

    /// Update an existing credential
    /// - Parameters:
    ///   - providerID: The provider identifier
    ///   - type: The credential type
    ///   - value: The new credential value
    /// - Throws: AICredentialError if credential not found or update fails
    public func update(providerID: String, type: AICredentialType, value: SecureString) throws {
        let key = credentialKey(providerID: providerID, type: type)

        guard var credential = credentials[key] else {
            throw AICredentialError.notFound
        }

        // Update in keychain based on type
        switch type {
        case .apiKey:
            try keychainManager.saveAPIKey(value.value, for: key, validate: true)

        case .oauthToken:
            try keychainManager.saveOAuthToken(value.value, for: key, validate: true)

        case .certificate:
            guard let data = value.value.data(using: .utf8) else {
                throw AICredentialError.invalidFormat("Unable to encode certificate data")
            }
            try keychainManager.saveCertificate(data, for: key, validate: true)

        case .custom:
            try keychainManager.saveAPIKey(value.value, for: key, validate: false)
        }

        // Update metadata
        credential.updatedAt = Date()
        credentials[key] = credential

        // Clear the secure string
        value.clear()
    }

    /// Retrieve a credential value
    /// - Parameters:
    ///   - providerID: The provider identifier
    ///   - type: The credential type
    /// - Returns: The credential value as a SecureString
    /// - Throws: AICredentialError if credential not found, expired, or retrieval fails
    public func retrieve(providerID: String, type: AICredentialType) throws -> SecureString {
        let key = credentialKey(providerID: providerID, type: type)

        guard let credential = credentials[key] else {
            throw AICredentialError.notFound
        }

        // Check if expired
        guard !credential.isExpired else {
            throw AICredentialError.expired
        }

        // Retrieve from keychain based on type
        switch type {
        case .apiKey:
            return try keychainManager.getAPIKey(for: key)

        case .oauthToken:
            return try keychainManager.getOAuthToken(for: key)

        case .certificate:
            let data = try keychainManager.getCertificate(for: key)
            guard let value = String(data: data, encoding: .utf8) else {
                throw AICredentialError.invalidFormat("Unable to decode certificate data")
            }
            return SecureString(value)

        case .custom:
            return try keychainManager.getAPIKey(for: key)
        }
    }

    /// Delete a credential
    /// - Parameters:
    ///   - providerID: The provider identifier
    ///   - type: The credential type
    /// - Throws: AICredentialError if deletion fails
    public func delete(providerID: String, type: AICredentialType) throws {
        let key = credentialKey(providerID: providerID, type: type)

        // Delete from keychain based on type
        switch type {
        case .apiKey:
            try keychainManager.deleteAPIKey(for: key)

        case .oauthToken:
            try keychainManager.deleteOAuthToken(for: key)

        case .certificate:
            try keychainManager.deleteCertificate(for: key)

        case .custom:
            try keychainManager.deleteAPIKey(for: key)
        }

        // Remove metadata
        credentials.removeValue(forKey: key)
    }

    /// Get credential metadata (without sensitive value)
    /// - Parameters:
    ///   - providerID: The provider identifier
    ///   - type: The credential type
    /// - Returns: The credential metadata
    /// - Throws: AICredentialError if credential not found
    public func getMetadata(providerID: String, type: AICredentialType) throws -> AICredential {
        let key = credentialKey(providerID: providerID, type: type)

        guard let credential = credentials[key] else {
            throw AICredentialError.notFound
        }

        return credential
    }

    /// Check if a credential exists
    /// - Parameters:
    ///   - providerID: The provider identifier
    ///   - type: The credential type
    /// - Returns: True if the credential exists, false otherwise
    public func has(providerID: String, type: AICredentialType) -> Bool {
        let key = credentialKey(providerID: providerID, type: type)
        return credentials[key] != nil && keychainManager.hasCredential(for: key, type: type)
    }

    /// List all credentials for a provider
    /// - Parameter providerID: The provider identifier
    /// - Returns: Array of credential metadata
    public func list(for providerID: String) -> [AICredential] {
        return credentials.values.filter { $0.providerID == providerID }
    }

    /// List all credentials
    /// - Returns: Array of all credential metadata
    public func listAll() -> [AICredential] {
        return Array(credentials.values)
    }

    // MARK: - Credential Lifecycle

    /// Update expiration date for a credential
    /// - Parameters:
    ///   - providerID: The provider identifier
    ///   - type: The credential type
    ///   - expiresAt: New expiration date (nil for no expiration)
    /// - Throws: AICredentialError if credential not found
    public func updateExpiration(providerID: String, type: AICredentialType, expiresAt: Date?) throws {
        let key = credentialKey(providerID: providerID, type: type)

        guard var credential = credentials[key] else {
            throw AICredentialError.notFound
        }

        credential.expiresAt = expiresAt
        credential.updatedAt = Date()
        credentials[key] = credential
    }

    /// Get credentials that are expiring soon
    /// - Parameter days: Number of days to look ahead (default: 7)
    /// - Returns: Array of credentials expiring within the specified days
    public func getExpiringSoon(days: Int = 7) -> [AICredential] {
        let cutoffDate = Date().addingTimeInterval(TimeInterval(days * 86400))

        return credentials.values.filter { credential in
            guard let expiresAt = credential.expiresAt else { return false }
            return expiresAt <= cutoffDate && !credential.isExpired
        }
    }

    /// Get expired credentials
    /// - Returns: Array of expired credentials
    public func getExpired() -> [AICredential] {
        return credentials.values.filter { $0.isExpired }
    }

    /// Validate a credential format without making API calls
    /// - Parameters:
    ///   - value: The credential value to validate
    ///   - providerID: The provider identifier
    ///   - type: The credential type
    /// - Throws: AICredentialError if validation fails
    public func validateFormat(value: String, providerID: String, type: AICredentialType) throws {
        switch type {
        case .apiKey:
            try AICredentialValidator.validateAPIKey(value, for: providerID)

        case .oauthToken:
            try AICredentialValidator.validateOAuthToken(value)

        case .certificate:
            guard let data = value.data(using: .utf8) else {
                throw AICredentialError.invalidFormat("Unable to encode certificate data")
            }
            try AICredentialValidator.validateCertificate(data)

        case .custom:
            // No validation for custom types
            break
        }
    }

    /// Clear expired credentials
    /// - Returns: Number of credentials cleared
    /// - Throws: AICredentialError if deletion fails
    @discardableResult
    public func clearExpired() throws -> Int {
        let expiredCreds = getExpired()

        for credential in expiredCreds {
            try delete(providerID: credential.providerID, type: credential.type)
        }

        return expiredCreds.count
    }

    /// Delete all credentials
    /// - Throws: AICredentialError if deletion fails
    public func deleteAll() throws {
        try keychainManager.deleteAllCredentials()
        credentials.removeAll()
    }

    // MARK: - Private Helpers

    private func credentialKey(providerID: String, type: AICredentialType) -> String {
        return "\(providerID):\(type.rawValue)"
    }
}
