//
//  SecureKeychainManagerTests.swift
//  SwiftHablare
//
//  Tests for secure keychain operations
//

import XCTest
@testable import SwiftHablare

final class SecureKeychainManagerTests: XCTestCase {
    var manager: SecureKeychainManager!

    override func setUp() {
        super.setUp()
        manager = SecureKeychainManager.shared
    }

    override func tearDown() {
        // Clean up any test credentials
        try? manager.deleteAllCredentials()
        super.tearDown()
    }

    // MARK: - API Key Tests

    func testSaveAndRetrieveAPIKey() throws {
        let account = "test-openai-\(UUID().uuidString)"
        let apiKey = "sk-test1234567890abcdef"

        // Save
        try manager.saveAPIKey(apiKey, for: account, validate: false)

        // Retrieve
        let retrieved = try manager.getAPIKey(for: account)
        XCTAssertEqual(retrieved.value, apiKey)

        // Cleanup
        try manager.deleteAPIKey(for: account)
    }

    func testSaveAPIKey_WithValidation_Valid() throws {
        let account = "test-openai-validated-\(UUID().uuidString)"
        let apiKey = "sk-test1234567890abcdef"

        XCTAssertNoThrow(try manager.saveAPIKey(apiKey, for: account, validate: true))

        // Cleanup
        try manager.deleteAPIKey(for: account)
    }

    func testSaveAPIKey_WithValidation_Invalid() {
        let account = "test-openai-invalid-\(UUID().uuidString)"
        let invalidKey = "invalid"

        XCTAssertThrowsError(try manager.saveAPIKey(invalidKey, for: account, validate: true))

        // Ensure nothing was saved
        XCTAssertFalse(manager.hasCredential(for: account, type: .apiKey))
    }

    func testUpdateAPIKey() throws {
        let account = "test-update-\(UUID().uuidString)"
        let originalKey = "sk-original1234567890"
        let updatedKey = "sk-updated1234567890"

        // Save original
        try manager.saveAPIKey(originalKey, for: account, validate: false)

        // Verify original
        var retrieved = try manager.getAPIKey(for: account)
        XCTAssertEqual(retrieved.value, originalKey)
        retrieved.clear()

        // Update
        try manager.saveAPIKey(updatedKey, for: account, validate: false)

        // Verify updated
        retrieved = try manager.getAPIKey(for: account)
        XCTAssertEqual(retrieved.value, updatedKey)

        // Cleanup
        try manager.deleteAPIKey(for: account)
    }

    func testDeleteAPIKey() throws {
        let account = "test-delete-\(UUID().uuidString)"
        let apiKey = "sk-test1234567890abcdef"

        // Save
        try manager.saveAPIKey(apiKey, for: account, validate: false)
        XCTAssertTrue(manager.hasCredential(for: account, type: .apiKey))

        // Delete
        try manager.deleteAPIKey(for: account)
        XCTAssertFalse(manager.hasCredential(for: account, type: .apiKey))
    }

    func testDeleteAPIKey_NotFound() {
        let account = "test-nonexistent-\(UUID().uuidString)"

        // Should not throw when deleting non-existent key
        XCTAssertNoThrow(try manager.deleteAPIKey(for: account))
    }

    func testRetrieveAPIKey_NotFound() {
        let account = "test-notfound-\(UUID().uuidString)"

        XCTAssertThrowsError(try manager.getAPIKey(for: account)) { error in
            XCTAssertTrue(error is AICredentialError)
            if case AICredentialError.notFound = error {
                // Expected
            } else {
                XCTFail("Expected notFound error")
            }
        }
    }

    // MARK: - OAuth Token Tests

    func testSaveAndRetrieveOAuthToken() throws {
        let account = "test-oauth-\(UUID().uuidString)"
        let token = "oauth-token-1234567890abcdef"

        // Save
        try manager.saveOAuthToken(token, for: account, validate: false)

        // Retrieve
        let retrieved = try manager.getOAuthToken(for: account)
        XCTAssertEqual(retrieved.value, token)

        // Cleanup
        try manager.deleteOAuthToken(for: account)
    }

    func testSaveOAuthToken_WithValidation_Valid() throws {
        let account = "test-oauth-validated-\(UUID().uuidString)"
        let token = "oauth-token-1234567890abcdef"

        XCTAssertNoThrow(try manager.saveOAuthToken(token, for: account, validate: true))

        // Cleanup
        try manager.deleteOAuthToken(for: account)
    }

    func testSaveOAuthToken_WithValidation_Invalid() {
        let account = "test-oauth-invalid-\(UUID().uuidString)"
        let invalidToken = "short"

        XCTAssertThrowsError(try manager.saveOAuthToken(invalidToken, for: account, validate: true))
        XCTAssertFalse(manager.hasCredential(for: account, type: .oauthToken))
    }

    func testDeleteOAuthToken() throws {
        let account = "test-oauth-delete-\(UUID().uuidString)"
        let token = "oauth-token-1234567890abcdef"

        // Save
        try manager.saveOAuthToken(token, for: account, validate: false)
        XCTAssertTrue(manager.hasCredential(for: account, type: .oauthToken))

        // Delete
        try manager.deleteOAuthToken(for: account)
        XCTAssertFalse(manager.hasCredential(for: account, type: .oauthToken))
    }

    // MARK: - Certificate Tests

    func testSaveAndRetrieveCertificate() throws {
        let account = "test-cert-\(UUID().uuidString)"
        let certData = Data(repeating: 0x42, count: 200)

        // Save
        try manager.saveCertificate(certData, for: account, validate: false)

        // Retrieve
        let retrieved = try manager.getCertificate(for: account)
        XCTAssertEqual(retrieved, certData)

        // Cleanup
        try manager.deleteCertificate(for: account)
    }

    func testSaveCertificate_WithValidation_Valid() throws {
        let account = "test-cert-validated-\(UUID().uuidString)"
        let certData = Data(repeating: 0x42, count: 200)

        XCTAssertNoThrow(try manager.saveCertificate(certData, for: account, validate: true))

        // Cleanup
        try manager.deleteCertificate(for: account)
    }

    func testSaveCertificate_WithValidation_Invalid() {
        let account = "test-cert-invalid-\(UUID().uuidString)"
        let invalidData = Data(repeating: 0x42, count: 50) // Too small

        XCTAssertThrowsError(try manager.saveCertificate(invalidData, for: account, validate: true))
        XCTAssertFalse(manager.hasCredential(for: account, type: .certificate))
    }

    func testDeleteCertificate() throws {
        let account = "test-cert-delete-\(UUID().uuidString)"
        let certData = Data(repeating: 0x42, count: 200)

        // Save
        try manager.saveCertificate(certData, for: account, validate: false)
        XCTAssertTrue(manager.hasCredential(for: account, type: .certificate))

        // Delete
        try manager.deleteCertificate(for: account)
        XCTAssertFalse(manager.hasCredential(for: account, type: .certificate))
    }

    // MARK: - Generic Operations Tests

    func testHasCredential() throws {
        let account = "test-has-\(UUID().uuidString)"
        let apiKey = "sk-test1234567890abcdef"

        XCTAssertFalse(manager.hasCredential(for: account, type: .apiKey))

        try manager.saveAPIKey(apiKey, for: account, validate: false)
        XCTAssertTrue(manager.hasCredential(for: account, type: .apiKey))

        try manager.deleteAPIKey(for: account)
        XCTAssertFalse(manager.hasCredential(for: account, type: .apiKey))
    }

    func testListAccounts() throws {
        let account1 = "test-list-1-\(UUID().uuidString)"
        let account2 = "test-list-2-\(UUID().uuidString)"

        // Save multiple API keys
        try manager.saveAPIKey("sk-test1234567890", for: account1, validate: false)
        try manager.saveAPIKey("sk-test0987654321", for: account2, validate: false)

        let accounts = manager.listAccounts(for: .apiKey)
        XCTAssertTrue(accounts.contains(account1))
        XCTAssertTrue(accounts.contains(account2))

        // Cleanup
        try manager.deleteAPIKey(for: account1)
        try manager.deleteAPIKey(for: account2)
    }

    func testListAccounts_Empty() {
        let accounts = manager.listAccounts(for: .custom)
        // Should return empty array for type with no credentials
        XCTAssertTrue(accounts.isEmpty || accounts.allSatisfy { $0.contains("test-") })
    }

    func testDeleteAllCredentials() throws {
        let account1 = "test-all-1-\(UUID().uuidString)"
        let account2 = "test-all-2-\(UUID().uuidString)"

        // Save different types of credentials
        try manager.saveAPIKey("sk-test1234567890", for: account1, validate: false)
        try manager.saveOAuthToken("oauth-token-1234567890", for: account2, validate: false)

        XCTAssertTrue(manager.hasCredential(for: account1, type: .apiKey))
        XCTAssertTrue(manager.hasCredential(for: account2, type: .oauthToken))

        // Delete all
        try manager.deleteAllCredentials()

        XCTAssertFalse(manager.hasCredential(for: account1, type: .apiKey))
        XCTAssertFalse(manager.hasCredential(for: account2, type: .oauthToken))
    }

    // MARK: - Isolation Tests

    func testCredentialTypeIsolation() throws {
        let account = "test-isolation-\(UUID().uuidString)"
        let apiKey = "sk-test1234567890abcdef"
        let oauthToken = "oauth-token-1234567890abcdef"

        // Clean up any existing credentials for this account first
        try? manager.deleteAPIKey(for: account)
        try? manager.deleteOAuthToken(for: account)

        // Save both API key and OAuth token for same account
        try manager.saveAPIKey(apiKey, for: account, validate: false)
        try manager.saveOAuthToken(oauthToken, for: account, validate: false)

        // Both should exist independently
        XCTAssertTrue(manager.hasCredential(for: account, type: .apiKey))
        XCTAssertTrue(manager.hasCredential(for: account, type: .oauthToken))

        // Retrieve and verify they're different
        let retrievedKey = try manager.getAPIKey(for: account)
        let retrievedToken = try manager.getOAuthToken(for: account)

        XCTAssertEqual(retrievedKey.value, apiKey)
        XCTAssertEqual(retrievedToken.value, oauthToken)
        XCTAssertNotEqual(retrievedKey.value, retrievedToken.value)

        // Delete API key shouldn't affect OAuth token
        try manager.deleteAPIKey(for: account)
        XCTAssertFalse(manager.hasCredential(for: account, type: .apiKey))
        XCTAssertTrue(manager.hasCredential(for: account, type: .oauthToken))

        // Cleanup
        try manager.deleteOAuthToken(for: account)
    }

    // MARK: - Memory Security Tests

    func testSecureStringClearing() {
        let secureString = SecureString("sensitive-data")
        XCTAssertEqual(secureString.value, "sensitive-data")

        secureString.clear()
        XCTAssertEqual(secureString.value, "")
    }

    func testSecureStringAutoClear() throws {
        let account = "test-autoclear-\(UUID().uuidString)"
        let apiKey = "sk-test1234567890abcdef"

        try manager.saveAPIKey(apiKey, for: account, validate: false)

        // Retrieve in a scope
        do {
            let secureString = try manager.getAPIKey(for: account)
            XCTAssertEqual(secureString.value, apiKey)
            // secureString goes out of scope here and should clear
        }

        // Can still retrieve again (data is in keychain)
        let retrieved = try manager.getAPIKey(for: account)
        XCTAssertEqual(retrieved.value, apiKey)

        // Cleanup
        try manager.deleteAPIKey(for: account)
    }
}
