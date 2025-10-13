//
//  TypedDataStorageProviderTests.swift
//  SwiftHablareTests
//
//  Tests for TypedDataStorageProvider protocol and MemoryStorageProvider
//

import XCTest
@testable import SwiftHablare

@available(macOS 15.0, iOS 17.0, *)
final class TypedDataStorageProviderTests: XCTestCase {

    var storage: MemoryStorageProvider!

    override func setUp() async throws {
        storage = MemoryStorageProvider()
    }

    override func tearDown() async throws {
        await storage.clearAll()
        storage = nil
    }

    // MARK: - Storage Area Creation Tests

    func testCreateStorageArea() async throws {
        let requestID = UUID()
        let storageArea = try await storage.createStorageArea(for: requestID)

        XCTAssertEqual(storageArea.requestID, requestID)
        XCTAssertNotNil(storageArea.baseURL)
    }

    func testCreateStorageArea_Idempotent() async throws {
        let requestID = UUID()
        let area1 = try await storage.createStorageArea(for: requestID)
        let area2 = try await storage.createStorageArea(for: requestID)

        XCTAssertEqual(area1.requestID, area2.requestID)
        XCTAssertEqual(area1.baseURL, area2.baseURL)
    }

    func testGetStorageArea_Exists() async throws {
        let requestID = UUID()
        _ = try await storage.createStorageArea(for: requestID)

        let retrieved = await storage.getStorageArea(for: requestID)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.requestID, requestID)
    }

    func testGetStorageArea_NotExists() async {
        let requestID = UUID()
        let retrieved = await storage.getStorageArea(for: requestID)
        XCTAssertNil(retrieved)
    }

    func testRemoveStorageArea() async throws {
        let requestID = UUID()
        _ = try await storage.createStorageArea(for: requestID)

        try await storage.removeStorageArea(for: requestID)

        let retrieved = await storage.getStorageArea(for: requestID)
        XCTAssertNil(retrieved)
    }

    func testRemoveStorageArea_NotExists() async throws {
        let requestID = UUID()
        // Should not throw
        try await storage.removeStorageArea(for: requestID)
    }

    // MARK: - File Attachment Tests

    func testAttachFile() async throws {
        let requestID = UUID()
        let fileID = UUID()
        let storageArea = try await storage.createStorageArea(for: requestID)

        let testData = "Hello, World!".data(using: .utf8)!
        let metadata = ["type": "text", "encoding": "utf-8"]

        try await storage.attachFile(testData, withID: fileID, to: storageArea, metadata: metadata)

        // Verify file was attached
        let files = await storage.listFiles(in: storageArea)
        XCTAssertTrue(files.contains(fileID))
    }

    func testAttachFile_WithoutStorageArea() async {
        let requestID = UUID()
        let fileID = UUID()
        let storageArea = StorageAreaReference(requestID: requestID, baseURL: URL(fileURLWithPath: "/tmp"))

        let testData = "Test".data(using: .utf8)!

        do {
            try await storage.attachFile(testData, withID: fileID, to: storageArea, metadata: [:])
            XCTFail("Should throw storageAreaNotFound error")
        } catch StorageProviderError.storageAreaNotFound(let id) {
            XCTAssertEqual(id, requestID)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRetrieveFile() async throws {
        let requestID = UUID()
        let fileID = UUID()
        let storageArea = try await storage.createStorageArea(for: requestID)

        let testData = "Hello, World!".data(using: .utf8)!
        try await storage.attachFile(testData, withID: fileID, to: storageArea, metadata: [:])

        let retrieved = try await storage.retrieveFile(withID: fileID, from: storageArea)
        XCTAssertEqual(retrieved, testData)
    }

    func testRetrieveFile_NotExists() async throws {
        let requestID = UUID()
        let fileID = UUID()
        let storageArea = try await storage.createStorageArea(for: requestID)

        do {
            _ = try await storage.retrieveFile(withID: fileID, from: storageArea)
            XCTFail("Should throw fileNotFound error")
        } catch StorageProviderError.fileNotFound(let id) {
            XCTAssertEqual(id, fileID)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRemoveFile() async throws {
        let requestID = UUID()
        let fileID = UUID()
        let storageArea = try await storage.createStorageArea(for: requestID)

        let testData = "Test".data(using: .utf8)!
        try await storage.attachFile(testData, withID: fileID, to: storageArea, metadata: [:])

        try await storage.removeFile(withID: fileID, from: storageArea)

        let files = await storage.listFiles(in: storageArea)
        XCTAssertFalse(files.contains(fileID))
    }

    func testRemoveFile_NotExists() async throws {
        let requestID = UUID()
        let fileID = UUID()
        let storageArea = try await storage.createStorageArea(for: requestID)

        // Should not throw
        try await storage.removeFile(withID: fileID, from: storageArea)
    }

    // MARK: - List Operations Tests

    func testListFiles_Empty() async throws {
        let requestID = UUID()
        let storageArea = try await storage.createStorageArea(for: requestID)

        let files = await storage.listFiles(in: storageArea)
        XCTAssertTrue(files.isEmpty)
    }

    func testListFiles_Multiple() async throws {
        let requestID = UUID()
        let storageArea = try await storage.createStorageArea(for: requestID)

        let fileIDs = [UUID(), UUID(), UUID()]
        for fileID in fileIDs {
            let data = "File \(fileID)".data(using: .utf8)!
            try await storage.attachFile(data, withID: fileID, to: storageArea, metadata: [:])
        }

        let files = await storage.listFiles(in: storageArea)
        XCTAssertEqual(files.count, 3)
        for fileID in fileIDs {
            XCTAssertTrue(files.contains(fileID))
        }
    }

    func testListStorageAreas() async throws {
        let requestIDs = [UUID(), UUID(), UUID()]
        for requestID in requestIDs {
            _ = try await storage.createStorageArea(for: requestID)
        }

        let areas = await storage.listStorageAreas()
        XCTAssertEqual(areas.count, 3)
        for requestID in requestIDs {
            XCTAssertTrue(areas.contains(requestID))
        }
    }

    // MARK: - Cleanup Tests

    func testCleanupStorageAreas_NoThreshold() async throws {
        _ = try await storage.createStorageArea(for: UUID())
        _ = try await storage.createStorageArea(for: UUID())

        let removed = try await storage.cleanupStorageAreas(olderThan: nil)
        XCTAssertEqual(removed, 0)

        let areas = await storage.listStorageAreas()
        XCTAssertEqual(areas.count, 2)
    }

    func testCleanupStorageAreas_WithThreshold() async throws {
        // Create areas (they'll have current timestamp)
        let oldRequestID = UUID()
        let newRequestID = UUID()

        _ = try await storage.createStorageArea(for: oldRequestID)

        // Wait a tiny bit
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds

        let threshold = Date()

        _ = try await storage.createStorageArea(for: newRequestID)

        // Clean up areas older than threshold
        let removed = try await storage.cleanupStorageAreas(olderThan: threshold)
        XCTAssertEqual(removed, 1)

        let areas = await storage.listStorageAreas()
        XCTAssertEqual(areas.count, 1)
        XCTAssertTrue(areas.contains(newRequestID))
        XCTAssertFalse(areas.contains(oldRequestID))
    }

    // MARK: - Multiple Storage Areas Tests

    func testMultipleStorageAreas_Isolation() async throws {
        let requestID1 = UUID()
        let requestID2 = UUID()

        let area1 = try await storage.createStorageArea(for: requestID1)
        let area2 = try await storage.createStorageArea(for: requestID2)

        let fileID = UUID()
        let data1 = "Area 1 Data".data(using: .utf8)!
        let data2 = "Area 2 Data".data(using: .utf8)!

        try await storage.attachFile(data1, withID: fileID, to: area1, metadata: [:])
        try await storage.attachFile(data2, withID: fileID, to: area2, metadata: [:])

        let retrieved1 = try await storage.retrieveFile(withID: fileID, from: area1)
        let retrieved2 = try await storage.retrieveFile(withID: fileID, from: area2)

        XCTAssertEqual(retrieved1, data1)
        XCTAssertEqual(retrieved2, data2)
        XCTAssertNotEqual(retrieved1, retrieved2)
    }

    // MARK: - MemoryStorageProvider Specific Tests

    func testTotalSize() async throws {
        let requestID = UUID()
        let storageArea = try await storage.createStorageArea(for: requestID)

        let data1 = Data(count: 100)
        let data2 = Data(count: 200)

        try await storage.attachFile(data1, withID: UUID(), to: storageArea, metadata: [:])
        try await storage.attachFile(data2, withID: UUID(), to: storageArea, metadata: [:])

        let totalSize = await storage.totalSize
        XCTAssertEqual(totalSize, 300)
    }

    func testFileCount() async throws {
        let requestID1 = UUID()
        let requestID2 = UUID()

        let area1 = try await storage.createStorageArea(for: requestID1)
        let area2 = try await storage.createStorageArea(for: requestID2)

        let testData = "Test".data(using: .utf8)!

        try await storage.attachFile(testData, withID: UUID(), to: area1, metadata: [:])
        try await storage.attachFile(testData, withID: UUID(), to: area1, metadata: [:])
        try await storage.attachFile(testData, withID: UUID(), to: area2, metadata: [:])

        let fileCount = await storage.fileCount
        XCTAssertEqual(fileCount, 3)
    }

    func testClearAll() async throws {
        let requestID = UUID()
        let storageArea = try await storage.createStorageArea(for: requestID)

        let testData = "Test".data(using: .utf8)!
        try await storage.attachFile(testData, withID: UUID(), to: storageArea, metadata: [:])

        await storage.clearAll()

        let areas = await storage.listStorageAreas()
        XCTAssertTrue(areas.isEmpty)

        let fileCount = await storage.fileCount
        XCTAssertEqual(fileCount, 0)
    }

    // MARK: - FileAttachment Tests

    func testFileAttachment_Initialization() {
        let requestID = UUID()
        let fileID = UUID()
        let data = "Test".data(using: .utf8)!

        let attachment = FileAttachment(
            fileID: fileID,
            data: data,
            relativePath: "Resources/test.txt",
            mimeType: "text/plain",
            metadata: ["key": "value"],
            requestID: requestID
        )

        XCTAssertEqual(attachment.fileID, fileID)
        XCTAssertEqual(attachment.data, data)
        XCTAssertEqual(attachment.relativePath, "Resources/test.txt")
        XCTAssertEqual(attachment.mimeType, "text/plain")
        XCTAssertEqual(attachment.metadata["key"], "value")
        XCTAssertEqual(attachment.requestID, requestID)
    }

    func testFileAttachment_DefaultValues() {
        let requestID = UUID()
        let data = "Test".data(using: .utf8)!

        let attachment = FileAttachment(
            data: data,
            relativePath: "test.dat",
            mimeType: "application/octet-stream",
            requestID: requestID
        )

        XCTAssertNotNil(attachment.fileID)
        XCTAssertTrue(attachment.metadata.isEmpty)
        XCTAssertNotNil(attachment.createdAt)
    }

    // MARK: - StorageProviderError Tests

    func testStorageProviderError_Descriptions() {
        let storageAreaNotFound = StorageProviderError.storageAreaNotFound(UUID())
        XCTAssertNotNil(storageAreaNotFound.errorDescription)

        let storageAreaAlreadyExists = StorageProviderError.storageAreaAlreadyExists(UUID())
        XCTAssertNotNil(storageAreaAlreadyExists.errorDescription)

        let fileNotFound = StorageProviderError.fileNotFound(UUID())
        XCTAssertNotNil(fileNotFound.errorDescription)

        let fileAlreadyExists = StorageProviderError.fileAlreadyExists(UUID())
        XCTAssertNotNil(fileAlreadyExists.errorDescription)

        let invalidStorageArea = StorageProviderError.invalidStorageArea("test reason")
        XCTAssertNotNil(invalidStorageArea.errorDescription)

        let operationFailed = StorageProviderError.operationFailed("test failure")
        XCTAssertNotNil(operationFailed.errorDescription)
    }
}
