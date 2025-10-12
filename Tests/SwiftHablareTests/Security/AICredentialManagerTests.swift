//
//  AICredentialManagerTests.swift
//  SwiftHablare
//
//  Tests for thread-safe credential management
//

import XCTest
@testable import SwiftHablare

final class AICredentialManagerTests: XCTestCase {
    var manager: AICredentialManager!

    override func setUp() async throws {
        try await super.setUp()
        manager = AICredentialManager()
        try await manager.deleteAll()
    }

    override func tearDown() async throws {
        try await manager.deleteAll()
        try await super.tearDown()
    }

    // MARK: - Store and Retrieve Tests

    func testStoreAndRetrieveCredential() async throws {
        let credential = AICredential(
            providerID: "openai",
            type: .apiKey,
            name: "Test API Key"
        )
        let value = SecureString("sk-test1234567890abcdef")

        try await manager.store(credential: credential, value: value)

        let retrieved = try await manager.retrieve(providerID: "openai", type: .apiKey)
        XCTAssertEqual(retrieved.value, "sk-test1234567890abcdef")
    }

    func testStoreCredential_AlreadyExists() async throws {
        let credential = AICredential(
            providerID: "anthropic",
            type: .apiKey,
            name: "Test Key"
        )
        let value1 = SecureString("sk-ant-test12345678")
        let value2 = SecureString("sk-ant-different123")

        try await manager.store(credential: credential, value: value1)

        // Storing again should throw
        await XCTAssertThrowsErrorAsync(
            try await manager.store(credential: credential, value: value2)
        ) { error in
            XCTAssertTrue(error is AICredentialError)
            if case AICredentialError.alreadyExists = error {
                // Expected
            } else {
                XCTFail("Expected alreadyExists error")
            }
        }
    }

    func testRetrieveCredential_NotFound() async throws {
        await XCTAssertThrowsErrorAsync(
            try await manager.retrieve(providerID: "nonexistent", type: .apiKey)
        ) { error in
            if case AICredentialError.notFound = error {
                // Expected
            } else {
                XCTFail("Expected notFound error")
            }
        }
    }

    func testRetrieveCredential_Expired() async throws {
        let pastDate = Date().addingTimeInterval(-86400)
        let credential = AICredential(
            providerID: "expired",
            type: .apiKey,
            name: "Expired Key",
            expiresAt: pastDate
        )
        let value = SecureString("sk-expired12345678")

        try await manager.store(credential: credential, value: value)

        await XCTAssertThrowsErrorAsync(
            try await manager.retrieve(providerID: "expired", type: .apiKey)
        ) { error in
            if case AICredentialError.expired = error {
                // Expected
            } else {
                XCTFail("Expected expired error")
            }
        }
    }

    // MARK: - Update Tests

    func testUpdateCredential() async throws {
        let credential = AICredential(
            providerID: "openai",
            type: .apiKey,
            name: "Test Key"
        )
        let originalValue = SecureString("sk-original1234567")
        let updatedValue = SecureString("sk-updated1234567")

        try await manager.store(credential: credential, value: originalValue)

        var retrieved = try await manager.retrieve(providerID: "openai", type: .apiKey)
        XCTAssertEqual(retrieved.value, "sk-original1234567")

        try await manager.update(providerID: "openai", type: .apiKey, value: updatedValue)

        retrieved = try await manager.retrieve(providerID: "openai", type: .apiKey)
        XCTAssertEqual(retrieved.value, "sk-updated1234567")
    }

    func testUpdateCredential_NotFound() async throws {
        let value = SecureString("sk-test1234567890")

        await XCTAssertThrowsErrorAsync(
            try await manager.update(providerID: "nonexistent", type: .apiKey, value: value)
        ) { error in
            if case AICredentialError.notFound = error {
                // Expected
            } else {
                XCTFail("Expected notFound error")
            }
        }
    }

    // MARK: - Delete Tests

    func testDeleteCredential() async throws {
        let credential = AICredential(
            providerID: "elevenlabs",
            type: .apiKey,
            name: "Test Key"
        )
        let value = SecureString("0123456789abcdef0123456789abcdef")

        try await manager.store(credential: credential, value: value)
        let hasBefore = await manager.has(providerID: "elevenlabs", type: .apiKey)
        XCTAssertTrue(hasBefore)

        try await manager.delete(providerID: "elevenlabs", type: .apiKey)
        let hasAfter = await manager.has(providerID: "elevenlabs", type: .apiKey)
        XCTAssertFalse(hasAfter)
    }

    func testDeleteCredential_NotFound() async throws {
        // Should not throw when deleting non-existent credential
        await XCTAssertNoThrowAsync(
            try await manager.delete(providerID: "nonexistent", type: .apiKey)
        )
    }

    // MARK: - Metadata Tests

    func testGetMetadata() async throws {
        let credential = AICredential(
            providerID: "anthropic",
            type: .apiKey,
            name: "Production Key",
            description: "Main API key",
            metadata: ["environment": "production"]
        )
        let value = SecureString("sk-ant-test12345678")

        try await manager.store(credential: credential, value: value)

        let metadata = try await manager.getMetadata(providerID: "anthropic", type: .apiKey)
        XCTAssertEqual(metadata.providerID, "anthropic")
        XCTAssertEqual(metadata.name, "Production Key")
        XCTAssertEqual(metadata.description, "Main API key")
        XCTAssertEqual(metadata.metadata["environment"], "production")
    }

    func testGetMetadata_NotFound() async throws {
        await XCTAssertThrowsErrorAsync(
            try await manager.getMetadata(providerID: "nonexistent", type: .apiKey)
        ) { error in
            if case AICredentialError.notFound = error {
                // Expected
            } else {
                XCTFail("Expected notFound error")
            }
        }
    }

    // MARK: - Has Tests

    func testHasCredential() async throws {
        let hasInitial = await manager.has(providerID: "openai", type: .apiKey)
        XCTAssertFalse(hasInitial)

        let credential = AICredential(
            providerID: "openai",
            type: .apiKey,
            name: "Test Key"
        )
        let value = SecureString("sk-test1234567890")

        try await manager.store(credential: credential, value: value)
        let hasAfterStore = await manager.has(providerID: "openai", type: .apiKey)
        XCTAssertTrue(hasAfterStore)
    }

    // MARK: - List Tests

    func testListCredentialsForProvider() async throws {
        // Store multiple credential types for same provider
        let apiKeyCredential = AICredential(
            providerID: "openai",
            type: .apiKey,
            name: "API Key"
        )
        let oauthCredential = AICredential(
            providerID: "openai",
            type: .oauthToken,
            name: "OAuth Token"
        )

        try await manager.store(credential: apiKeyCredential, value: SecureString("sk-test1234567890"))
        try await manager.store(credential: oauthCredential, value: SecureString("oauth-token-1234567890"))

        let credentials = await manager.list(for: "openai")
        XCTAssertEqual(credentials.count, 2)
        XCTAssertTrue(credentials.contains { $0.type == .apiKey })
        XCTAssertTrue(credentials.contains { $0.type == .oauthToken })
    }

    func testListAllCredentials() async throws {
        let credential1 = AICredential(providerID: "openai", type: .apiKey, name: "Key 1")
        let credential2 = AICredential(providerID: "anthropic", type: .apiKey, name: "Key 2")
        let credential3 = AICredential(providerID: "elevenlabs", type: .apiKey, name: "Key 3")

        try await manager.store(credential: credential1, value: SecureString("sk-test1"))
        try await manager.store(credential: credential2, value: SecureString("sk-ant-test2"))
        try await manager.store(credential: credential3, value: SecureString("01234567890123456789012345678901"))

        let allCredentials = await manager.listAll()
        XCTAssertGreaterThanOrEqual(allCredentials.count, 3)
    }

    // MARK: - Expiration Tests

    func testUpdateExpiration() async throws {
        let credential = AICredential(
            providerID: "openai",
            type: .apiKey,
            name: "Test Key"
        )
        let value = SecureString("sk-test1234567890")

        try await manager.store(credential: credential, value: value)

        let futureDate = Date().addingTimeInterval(86400 * 30)
        try await manager.updateExpiration(providerID: "openai", type: .apiKey, expiresAt: futureDate)

        let metadata = try await manager.getMetadata(providerID: "openai", type: .apiKey)
        XCTAssertNotNil(metadata.expiresAt)
        XCTAssertTrue(metadata.isValid)
        XCTAssertFalse(metadata.isExpired)
    }

    func testGetExpiringSoon() async throws {
        let soonDate = Date().addingTimeInterval(86400 * 5) // 5 days
        let laterDate = Date().addingTimeInterval(86400 * 30) // 30 days

        let expiringSoon = AICredential(
            providerID: "expiring-soon",
            type: .apiKey,
            name: "Expiring Soon",
            expiresAt: soonDate
        )
        let expiringLater = AICredential(
            providerID: "expiring-later",
            type: .apiKey,
            name: "Expiring Later",
            expiresAt: laterDate
        )

        try await manager.store(credential: expiringSoon, value: SecureString("sk-soon12345678"))
        try await manager.store(credential: expiringLater, value: SecureString("sk-later12345678"))

        let expiring = await manager.getExpiringSoon(days: 7)
        XCTAssertTrue(expiring.contains { $0.providerID == "expiring-soon" })
        XCTAssertFalse(expiring.contains { $0.providerID == "expiring-later" })
    }

    func testGetExpired() async throws {
        let pastDate = Date().addingTimeInterval(-86400) // Yesterday
        let futureDate = Date().addingTimeInterval(86400 * 30) // 30 days

        let expiredCredential = AICredential(
            providerID: "expired",
            type: .apiKey,
            name: "Expired",
            expiresAt: pastDate
        )
        let validCredential = AICredential(
            providerID: "valid",
            type: .apiKey,
            name: "Valid",
            expiresAt: futureDate
        )

        try await manager.store(credential: expiredCredential, value: SecureString("sk-expired123456"))
        try await manager.store(credential: validCredential, value: SecureString("sk-valid1234567"))

        let expired = await manager.getExpired()
        XCTAssertTrue(expired.contains { $0.providerID == "expired" })
        XCTAssertFalse(expired.contains { $0.providerID == "valid" })
    }

    func testClearExpired() async throws {
        let pastDate = Date().addingTimeInterval(-86400)

        let expiredCredential = AICredential(
            providerID: "expired",
            type: .apiKey,
            name: "Expired",
            expiresAt: pastDate
        )

        try await manager.store(credential: expiredCredential, value: SecureString("sk-expired123456"))

        let hasBefore = await manager.has(providerID: "expired", type: .apiKey)
        XCTAssertTrue(hasBefore)

        let count = try await manager.clearExpired()
        XCTAssertEqual(count, 1)
        let hasAfter = await manager.has(providerID: "expired", type: .apiKey)
        XCTAssertFalse(hasAfter)
    }

    // MARK: - Validation Tests

    func testValidateFormat_APIKey_Valid() async throws {
        await XCTAssertNoThrowAsync(
            try await manager.validateFormat(
                value: "sk-test1234567890",
                providerID: "openai",
                type: .apiKey
            )
        )
    }

    func testValidateFormat_APIKey_Invalid() async throws {
        await XCTAssertThrowsErrorAsync(
            try await manager.validateFormat(
                value: "invalid",
                providerID: "openai",
                type: .apiKey
            )
        )
    }

    func testValidateFormat_OAuthToken_Valid() async throws {
        await XCTAssertNoThrowAsync(
            try await manager.validateFormat(
                value: "oauth-token-1234567890",
                providerID: "custom",
                type: .oauthToken
            )
        )
    }

    func testValidateFormat_OAuthToken_Invalid() async throws {
        await XCTAssertThrowsErrorAsync(
            try await manager.validateFormat(
                value: "short",
                providerID: "custom",
                type: .oauthToken
            )
        )
    }

    // MARK: - Delete All Tests

    func testDeleteAll() async throws {
        let credential1 = AICredential(providerID: "openai", type: .apiKey, name: "Key 1")
        let credential2 = AICredential(providerID: "anthropic", type: .apiKey, name: "Key 2")

        try await manager.store(credential: credential1, value: SecureString("sk-test1"))
        try await manager.store(credential: credential2, value: SecureString("sk-ant-test2"))

        let hasOpenAI = await manager.has(providerID: "openai", type: .apiKey)
        let hasAnthropic = await manager.has(providerID: "anthropic", type: .apiKey)
        XCTAssertTrue(hasOpenAI)
        XCTAssertTrue(hasAnthropic)

        try await manager.deleteAll()

        let hasOpenAIAfter = await manager.has(providerID: "openai", type: .apiKey)
        let hasAnthropicAfter = await manager.has(providerID: "anthropic", type: .apiKey)
        let count = await manager.listAll().count
        XCTAssertFalse(hasOpenAIAfter)
        XCTAssertFalse(hasAnthropicAfter)
        XCTAssertEqual(count, 0)
    }

    // MARK: - Concurrency Tests

    func testConcurrentAccess() async throws {
        let credential = AICredential(
            providerID: "concurrent",
            type: .apiKey,
            name: "Concurrent Test"
        )
        let value = SecureString("sk-concurrent1234")

        try await manager.store(credential: credential, value: value)

        // Perform concurrent reads
        let testManager = manager!
        let results = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for _ in 0..<10 {
                group.addTask {
                    do {
                        let retrieved = try await testManager.retrieve(providerID: "concurrent", type: .apiKey)
                        return retrieved.value == "sk-concurrent1234"
                    } catch {
                        return false
                    }
                }
            }

            var results: [Bool] = []
            for await success in group {
                results.append(success)
            }
            return results
        }

        let successCount = results.filter { $0 }.count
        XCTAssertEqual(successCount, 10)
    }
}

// MARK: - Test Helpers

extension XCTestCase {
    func XCTAssertThrowsErrorAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ errorHandler: (_ error: Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expression did not throw error", file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }

    func XCTAssertNoThrowAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
        } catch {
            XCTFail("Expression threw error: \(error)", file: file, line: line)
        }
    }
}
