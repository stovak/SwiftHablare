//
//  MemoryStorageProviderTests.swift
//  SwiftHablareTests
//
//  Phase 4: Tests for MemoryStorageProvider
//

import XCTest
@testable import SwiftHablare

@available(macOS 15.0, iOS 17.0, *)
final class MemoryStorageProviderTests: XCTestCase {
    var storage: MemoryStorageProvider!

    override func setUp() {
        storage = MemoryStorageProvider()
    }

    override func tearDown() {
        storage.clearAll()
        storage = nil
    }

    // MARK: - Storage Area Tests

    func testCreateStorageArea() throws {
        // GIVEN
        let requestID = UUID()

        // WHEN
        let storageArea = try storage.createStorageArea(for: requestID)

        // THEN
        XCTAssertEqual(storageArea.requestID, requestID)
        XCTAssertNotNil(storageArea.baseURL)
    }

    func testCreateStorageAreaIdempotent() throws {
        // GIVEN
        let requestID = UUID()

        // WHEN
        let storageArea1 = try storage.createStorageArea(for: requestID)
        let storageArea2 = try storage.createStorageArea(for: requestID)

        // THEN
        XCTAssertEqual(storageArea1.requestID, storageArea2.requestID)
        XCTAssertEqual(storageArea1.baseURL, storageArea2.baseURL)
    }

    func testGetStorageArea() throws {
        // GIVEN
        let requestID = UUID()
        let created = try storage.createStorageArea(for: requestID)

        // WHEN
        let retrieved = storage.getStorageArea(for: requestID)

        // THEN
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.requestID, created.requestID)
    }

    func testGetStorageAreaNonExistent() {
        // GIVEN
        let requestID = UUID()

        // WHEN
        let retrieved = storage.getStorageArea(for: requestID)

        // THEN
        XCTAssertNil(retrieved)
    }

    func testRemoveStorageArea() throws {
        // GIVEN
        let requestID = UUID()
        _ = try storage.createStorageArea(for: requestID)

        // WHEN
        try storage.removeStorageArea(for: requestID)

        // THEN
        let retrieved = storage.getStorageArea(for: requestID)
        XCTAssertNil(retrieved)
    }

    func testRemoveNonExistentStorageArea() throws {
        // GIVEN
        let requestID = UUID()

        // WHEN/THEN - Should not throw
        try storage.removeStorageArea(for: requestID)
    }

    func testListStorageAreas() throws {
        // GIVEN
        let requestID1 = UUID()
        let requestID2 = UUID()
        _ = try storage.createStorageArea(for: requestID1)
        _ = try storage.createStorageArea(for: requestID2)

        // WHEN
        let areas = storage.listStorageAreas()

        // THEN
        XCTAssertEqual(areas.count, 2)
        XCTAssertTrue(areas.contains(requestID1))
        XCTAssertTrue(areas.contains(requestID2))
    }

    // MARK: - File Operations Tests

    func testAttachFile() throws {
        // GIVEN
        let requestID = UUID()
        let fileID = UUID()
        let storageArea = try storage.createStorageArea(for: requestID)
        let fileData = Data("test data".utf8)
        let metadata = ["filename": "test.txt", "type": "text"]

        // WHEN
        try storage.attachFile(fileData, withID: fileID, to: storageArea, metadata: metadata)

        // THEN
        let retrieved = try storage.retrieveFile(withID: fileID, from: storageArea)
        XCTAssertEqual(retrieved, fileData)
    }

    func testAttachFileToNonExistentStorageArea() throws {
        // GIVEN
        let requestID = UUID()
        let fileID = UUID()
        let storageArea = StorageAreaReference(
            requestID: requestID,
            baseURL: FileManager.default.temporaryDirectory
        )
        let fileData = Data("test".utf8)

        // WHEN/THEN
        XCTAssertThrowsError(try storage.attachFile(fileData, withID: fileID, to: storageArea, metadata: [:]))
    }

    func testRetrieveFile() throws {
        // GIVEN
        let requestID = UUID()
        let fileID = UUID()
        let storageArea = try storage.createStorageArea(for: requestID)
        let fileData = Data("test data".utf8)
        try storage.attachFile(fileData, withID: fileID, to: storageArea, metadata: [:])

        // WHEN
        let retrieved = try storage.retrieveFile(withID: fileID, from: storageArea)

        // THEN
        XCTAssertEqual(retrieved, fileData)
    }

    func testRetrieveNonExistentFile() throws {
        // GIVEN
        let requestID = UUID()
        let fileID = UUID()
        let storageArea = try storage.createStorageArea(for: requestID)

        // WHEN/THEN
        XCTAssertThrowsError(try storage.retrieveFile(withID: fileID, from: storageArea))
    }

    func testRemoveFile() throws {
        // GIVEN
        let requestID = UUID()
        let fileID = UUID()
        let storageArea = try storage.createStorageArea(for: requestID)
        let fileData = Data("test".utf8)
        try storage.attachFile(fileData, withID: fileID, to: storageArea, metadata: [:])

        // WHEN
        try storage.removeFile(withID: fileID, from: storageArea)

        // THEN
        XCTAssertThrowsError(try storage.retrieveFile(withID: fileID, from: storageArea))
    }

    func testListFiles() throws {
        // GIVEN
        let requestID = UUID()
        let fileID1 = UUID()
        let fileID2 = UUID()
        let storageArea = try storage.createStorageArea(for: requestID)
        try storage.attachFile(Data("data1".utf8), withID: fileID1, to: storageArea, metadata: [:])
        try storage.attachFile(Data("data2".utf8), withID: fileID2, to: storageArea, metadata: [:])

        // WHEN
        let files = storage.listFiles(in: storageArea)

        // THEN
        XCTAssertEqual(files.count, 2)
        XCTAssertTrue(files.contains(fileID1))
        XCTAssertTrue(files.contains(fileID2))
    }

    func testListFilesEmptyStorageArea() throws {
        // GIVEN
        let requestID = UUID()
        let storageArea = try storage.createStorageArea(for: requestID)

        // WHEN
        let files = storage.listFiles(in: storageArea)

        // THEN
        XCTAssertEqual(files.count, 0)
    }

    // MARK: - Cleanup Tests

    func testCleanupStorageAreasOlderThan() throws {
        // GIVEN
        let oldDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let recentDate = Date()

        let requestID1 = UUID()
        let requestID2 = UUID()
        _ = try storage.createStorageArea(for: requestID1)
        _ = try storage.createStorageArea(for: requestID2)

        // WHEN - Clean up areas older than 30 minutes ago
        let threshold = Date().addingTimeInterval(-1800)
        let removedCount = try storage.cleanupStorageAreas(olderThan: threshold)

        // THEN - All areas are recent, so nothing should be removed
        XCTAssertEqual(removedCount, 0)
        XCTAssertEqual(storage.listStorageAreas().count, 2)
    }

    func testCleanupStorageAreasWithNilDate() throws {
        // GIVEN
        let requestID = UUID()
        _ = try storage.createStorageArea(for: requestID)

        // WHEN
        let removedCount = try storage.cleanupStorageAreas(olderThan: nil)

        // THEN
        XCTAssertEqual(removedCount, 0)
    }

    // MARK: - Utility Methods Tests

    func testTotalSize() throws {
        // GIVEN
        let requestID = UUID()
        let storageArea = try storage.createStorageArea(for: requestID)
        let data1 = Data("test data 1".utf8)
        let data2 = Data("test data 2 longer".utf8)
        try storage.attachFile(data1, withID: UUID(), to: storageArea, metadata: [:])
        try storage.attachFile(data2, withID: UUID(), to: storageArea, metadata: [:])

        // WHEN
        let totalSize = storage.totalSize

        // THEN
        XCTAssertEqual(totalSize, data1.count + data2.count)
    }

    func testFileCount() throws {
        // GIVEN
        let requestID1 = UUID()
        let requestID2 = UUID()
        let storageArea1 = try storage.createStorageArea(for: requestID1)
        let storageArea2 = try storage.createStorageArea(for: requestID2)

        try storage.attachFile(Data("data1".utf8), withID: UUID(), to: storageArea1, metadata: [:])
        try storage.attachFile(Data("data2".utf8), withID: UUID(), to: storageArea1, metadata: [:])
        try storage.attachFile(Data("data3".utf8), withID: UUID(), to: storageArea2, metadata: [:])

        // WHEN
        let count = storage.fileCount

        // THEN
        XCTAssertEqual(count, 3)
    }

    func testClearAll() throws {
        // GIVEN
        let requestID1 = UUID()
        let requestID2 = UUID()
        let storageArea1 = try storage.createStorageArea(for: requestID1)
        let storageArea2 = try storage.createStorageArea(for: requestID2)
        try storage.attachFile(Data("data1".utf8), withID: UUID(), to: storageArea1, metadata: [:])
        try storage.attachFile(Data("data2".utf8), withID: UUID(), to: storageArea2, metadata: [:])

        // WHEN
        storage.clearAll()

        // THEN
        XCTAssertEqual(storage.listStorageAreas().count, 0)
        XCTAssertEqual(storage.fileCount, 0)
        XCTAssertEqual(storage.totalSize, 0)
    }

    // MARK: - Multiple Storage Area Tests

    func testMultipleStorageAreasWithSameFiles() throws {
        // GIVEN
        let requestID1 = UUID()
        let requestID2 = UUID()
        let fileID = UUID()
        let storageArea1 = try storage.createStorageArea(for: requestID1)
        let storageArea2 = try storage.createStorageArea(for: requestID2)
        let data1 = Data("data for area 1".utf8)
        let data2 = Data("data for area 2".utf8)

        // WHEN - Same fileID used in different storage areas
        try storage.attachFile(data1, withID: fileID, to: storageArea1, metadata: [:])
        try storage.attachFile(data2, withID: fileID, to: storageArea2, metadata: [:])

        // THEN - Each area should have its own copy
        let retrieved1 = try storage.retrieveFile(withID: fileID, from: storageArea1)
        let retrieved2 = try storage.retrieveFile(withID: fileID, from: storageArea2)
        XCTAssertEqual(retrieved1, data1)
        XCTAssertEqual(retrieved2, data2)
    }
}
