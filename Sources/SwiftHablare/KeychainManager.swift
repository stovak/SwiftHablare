//
//  KeychainManager.swift
//  SwiftHablare
//
//  Secure storage manager for API keys using Keychain
//

import Foundation
import Security

/// Secure storage manager for API keys using macOS/iOS Keychain
public final class KeychainManager: Sendable {
    public static let shared = KeychainManager()

    private let service = "io.stovak.SwiftHablare"

    private init() {}

    /// Save API key to keychain
    public func saveAPIKey(_ key: String, for account: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        // Delete any existing key first
        try? deleteAPIKey(for: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unableToSave(status: status)
        }
    }

    /// Retrieve API key from keychain
    public func getAPIKey(for account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw KeychainError.notFound
        }

        guard let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return key
    }

    /// Delete API key from keychain
    public func deleteAPIKey(for account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete(status: status)
        }
    }

    /// Check if API key exists
    public func hasAPIKey(for account: String) -> Bool {
        do {
            _ = try getAPIKey(for: account)
            return true
        } catch {
            return false
        }
    }

    /// Get obfuscated version of API key for display
    public func getObfuscatedAPIKey(for account: String) -> String {
        guard let key = try? getAPIKey(for: account) else {
            return "Not set"
        }

        let length = key.count
        if length <= 8 {
            return String(repeating: "•", count: length)
        }

        let prefix = key.prefix(4)
        let suffix = key.suffix(4)
        let middle = String(repeating: "•", count: max(8, length - 8))

        return "\(prefix)\(middle)\(suffix)"
    }
}

public enum KeychainError: LocalizedError {
    case invalidData
    case notFound
    case unableToSave(status: OSStatus)
    case unableToDelete(status: OSStatus)

    public var errorDescription: String? {
        switch self {
        case .invalidData:
            return "The data is invalid"
        case .notFound:
            return "The item was not found in the keychain"
        case .unableToSave(let status):
            return "Unable to save to keychain (status: \(status))"
        case .unableToDelete(let status):
            return "Unable to delete from keychain (status: \(status))"
        }
    }
}
