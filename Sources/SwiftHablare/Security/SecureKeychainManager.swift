//
//  SecureKeychainManager.swift
//  SwiftHablare
//
//  Enhanced keychain manager with validation and secure memory handling
//

import Foundation
import Security

/// Enhanced keychain manager with support for multiple credential types and validation
public final class SecureKeychainManager: Sendable {
    public static let shared = SecureKeychainManager()

    private let service = "io.stovak.SwiftHablare"
    private let accessGroup: String? = nil

    private init() {}

    // MARK: - API Key Operations

    /// Save an API key securely to the keychain
    /// - Parameters:
    ///   - key: The API key to save
    ///   - account: The account identifier (typically provider ID)
    ///   - validate: Whether to validate the key format before saving
    /// - Throws: AICredentialError if validation fails or keychain operation fails
    public func saveAPIKey(_ key: String, for account: String, validate: Bool = true) throws {
        // Validate format if requested
        if validate {
            try AICredentialValidator.validateAPIKey(key, for: account)
        }

        guard let data = key.data(using: .utf8) else {
            throw AICredentialError.invalidFormat("Unable to encode API key")
        }

        try saveData(data, for: account, type: .apiKey)
    }

    /// Retrieve an API key from the keychain
    /// - Parameter account: The account identifier
    /// - Returns: The API key as a SecureString
    /// - Throws: AICredentialError if key not found or retrieval fails
    public func getAPIKey(for account: String) throws -> SecureString {
        let data = try getData(for: account, type: .apiKey)

        guard let key = String(data: data, encoding: .utf8) else {
            throw AICredentialError.invalidFormat("Unable to decode API key")
        }

        return SecureString(key)
    }

    /// Delete an API key from the keychain
    /// - Parameter account: The account identifier
    /// - Throws: AICredentialError if deletion fails
    public func deleteAPIKey(for account: String) throws {
        try deleteData(for: account, type: .apiKey)
    }

    // MARK: - OAuth Token Operations

    /// Save an OAuth token securely to the keychain
    /// - Parameters:
    ///   - token: The OAuth token to save
    ///   - account: The account identifier
    ///   - validate: Whether to validate the token format before saving
    /// - Throws: AICredentialError if validation fails or keychain operation fails
    public func saveOAuthToken(_ token: String, for account: String, validate: Bool = true) throws {
        // Validate format if requested
        if validate {
            try AICredentialValidator.validateOAuthToken(token)
        }

        guard let data = token.data(using: .utf8) else {
            throw AICredentialError.invalidFormat("Unable to encode OAuth token")
        }

        try saveData(data, for: account, type: .oauthToken)
    }

    /// Retrieve an OAuth token from the keychain
    /// - Parameter account: The account identifier
    /// - Returns: The OAuth token as a SecureString
    /// - Throws: AICredentialError if token not found or retrieval fails
    public func getOAuthToken(for account: String) throws -> SecureString {
        let data = try getData(for: account, type: .oauthToken)

        guard let token = String(data: data, encoding: .utf8) else {
            throw AICredentialError.invalidFormat("Unable to decode OAuth token")
        }

        return SecureString(token)
    }

    /// Delete an OAuth token from the keychain
    /// - Parameter account: The account identifier
    /// - Throws: AICredentialError if deletion fails
    public func deleteOAuthToken(for account: String) throws {
        try deleteData(for: account, type: .oauthToken)
    }

    // MARK: - Certificate Operations

    /// Save certificate data securely to the keychain
    /// - Parameters:
    ///   - data: The certificate data to save
    ///   - account: The account identifier
    ///   - validate: Whether to validate the certificate data before saving
    /// - Throws: AICredentialError if validation fails or keychain operation fails
    public func saveCertificate(_ data: Data, for account: String, validate: Bool = true) throws {
        // Validate if requested
        if validate {
            try AICredentialValidator.validateCertificate(data)
        }

        try saveData(data, for: account, type: .certificate)
    }

    /// Retrieve certificate data from the keychain
    /// - Parameter account: The account identifier
    /// - Returns: The certificate data
    /// - Throws: AICredentialError if certificate not found or retrieval fails
    public func getCertificate(for account: String) throws -> Data {
        return try getData(for: account, type: .certificate)
    }

    /// Delete certificate data from the keychain
    /// - Parameter account: The account identifier
    /// - Throws: AICredentialError if deletion fails
    public func deleteCertificate(for account: String) throws {
        try deleteData(for: account, type: .certificate)
    }

    // MARK: - Generic Operations

    /// Check if a credential exists for the given account and type
    /// - Parameters:
    ///   - account: The account identifier
    ///   - type: The credential type
    /// - Returns: True if the credential exists, false otherwise
    public func hasCredential(for account: String, type: AICredentialType) -> Bool {
        do {
            _ = try getData(for: account, type: type)
            return true
        } catch {
            return false
        }
    }

    /// List all accounts with credentials of a specific type
    /// - Parameter type: The credential type
    /// - Returns: Array of account identifiers
    public func listAccounts(for type: AICredentialType) -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrLabel as String: type.rawValue,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }

        let suffix = ":\(type.rawValue)"
        return items.compactMap { item in
            guard let uniqueAccount = item[kSecAttrAccount as String] as? String else {
                return nil
            }
            // Strip the type suffix to get the original account name
            if uniqueAccount.hasSuffix(suffix) {
                return String(uniqueAccount.dropLast(suffix.count))
            }
            return uniqueAccount
        }
    }

    /// Delete all credentials
    /// - Throws: AICredentialError if deletion fails
    public func deleteAllCredentials() throws {
        // List all items first, then delete them one by one
        // This is more reliable than trying to delete in bulk
        let listQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        let listStatus = SecItemCopyMatching(listQuery as CFDictionary, &result)

        // If no items found, that's fine
        guard listStatus == errSecSuccess || listStatus == errSecItemNotFound else {
            throw AICredentialError.keychainError("Unable to list credentials (status: \(listStatus))")
        }

        // If no items, we're done
        guard listStatus == errSecSuccess, let items = result as? [[String: Any]] else {
            return
        }

        // Delete each item individually
        for item in items {
            guard let account = item[kSecAttrAccount as String] as? String,
                  let label = item[kSecAttrLabel as String] as? String else {
                continue
            }

            var deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecAttrLabel as String: label,
                kSecAttrSynchronizable as String: false
            ]

            if let accessGroup = item[kSecAttrAccessGroup as String] as? String {
                deleteQuery[kSecAttrAccessGroup as String] = accessGroup
            }

            let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
            // Ignore individual failures as long as we try to delete everything
            _ = deleteStatus
        }
    }

    // MARK: - Private Helpers

    /// Create a unique account identifier by combining the account and type
    /// This is necessary because keychain uniqueness is based on (class, service, account)
    /// and does not include the label attribute
    private func makeUniqueAccount(_ account: String, type: AICredentialType) -> String {
        return "\(account):\(type.rawValue)"
    }

    private func saveData(_ data: Data, for account: String, type: AICredentialType) throws {
        let uniqueAccount = makeUniqueAccount(account, type: type)

        // Build the query for this credential
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: uniqueAccount,
            kSecAttrLabel as String: type.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: false // Don't sync credentials to iCloud
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        // Try to add the item
        let addStatus = SecItemAdd(query as CFDictionary, nil)

        if addStatus == errSecSuccess {
            // Successfully added
            return
        } else if addStatus == errSecDuplicateItem {
            // Item exists, update it instead
            var searchQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: uniqueAccount,
                kSecAttrLabel as String: type.rawValue,
                kSecAttrSynchronizable as String: false
            ]

            if let accessGroup {
                searchQuery[kSecAttrAccessGroup as String] = accessGroup
            }

            let updateAttributes: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
            ]

            let updateStatus = SecItemUpdate(searchQuery as CFDictionary, updateAttributes as CFDictionary)

            guard updateStatus == errSecSuccess else {
                throw AICredentialError.keychainError("Unable to update credential (status: \(updateStatus))")
            }
        } else {
            throw AICredentialError.keychainError("Unable to save credential (status: \(addStatus))")
        }
    }

    private func getData(for account: String, type: AICredentialType) throws -> Data {
        let uniqueAccount = makeUniqueAccount(account, type: type)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: uniqueAccount,
            kSecAttrLabel as String: type.rawValue,
            kSecAttrSynchronizable as String: false,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw AICredentialError.notFound
        }

        guard let data = result as? Data else {
            throw AICredentialError.invalidFormat("Unable to retrieve credential data")
        }

        return data
    }

    private func deleteData(for account: String, type: AICredentialType) throws {
        let uniqueAccount = makeUniqueAccount(account, type: type)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: uniqueAccount,
            kSecAttrLabel as String: type.rawValue,
            kSecAttrSynchronizable as String: false
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AICredentialError.keychainError("Unable to delete credential (status: \(status))")
        }
    }
}
