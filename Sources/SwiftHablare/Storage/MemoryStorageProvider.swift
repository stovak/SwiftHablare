//
//  MemoryStorageProvider.swift
//  SwiftHablare
//
//  In-memory implementation of TypedDataStorageProvider for testing
//

import Foundation

/// In-memory storage provider for testing and temporary storage.
///
/// This implementation stores all data in memory with thread-safe access.
/// Useful for testing, previews, and scenarios where persistence is not needed.
///
/// ## Usage
/// ```swift
/// let storage = MemoryStorageProvider()
/// let storageArea = try storage.createStorageArea(for: requestID)
/// try storage.attachFile(data, withID: fileID, to: storageArea, metadata: [:])
/// ```
@available(macOS 15.0, iOS 17.0, *)
public final class MemoryStorageProvider: TypedDataStorageProvider {

    // MARK: - Private Storage

    private let lock = NSLock()
    private var storageAreas: [UUID: StorageAreaReference] = [:]
    private var files: [UUID: [UUID: Data]] = [:]  // [requestID: [fileID: data]]
    private var metadata: [UUID: [UUID: [String: String]]] = [:]  // [requestID: [fileID: metadata]]
    private var creationDates: [UUID: Date] = [:]

    // MARK: - Initialization

    /// Creates a new in-memory storage provider
    public init() {}

    // MARK: - TypedDataStorageProvider

    public func createStorageArea(for requestID: UUID) throws -> StorageAreaReference {
        // Check if already exists
        if let existing = storageAreas[requestID] {
            return existing
        }

        // Create temporary directory for this storage area
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftHablare")
            .appendingPathComponent(requestID.uuidString)

        let storageArea = StorageAreaReference(
            requestID: requestID,
            baseURL: tempDir
        )

        storageAreas[requestID] = storageArea

        // Initialize storage structures
        files[requestID] = [:]
        metadata[requestID] = [:]
        creationDates[requestID] = Date()

        return storageArea
    }

    public func getStorageArea(for requestID: UUID) -> StorageAreaReference? {
        return storageAreas[requestID]
    }

    public func removeStorageArea(for requestID: UUID) throws {
        guard storageAreas[requestID] != nil else {
            return  // Silently succeed if not found
        }

        storageAreas.removeValue(forKey: requestID)
        files.removeValue(forKey: requestID)
        metadata.removeValue(forKey: requestID)
        creationDates.removeValue(forKey: requestID)
    }

    public func attachFile(
        _ data: Data,
        withID fileID: UUID,
        to storageArea: StorageAreaReference,
        metadata fileMetadata: [String: String]
    ) throws {
        let requestID = storageArea.requestID

        // Verify storage area exists
        guard storageAreas[requestID] != nil else {
            throw StorageProviderError.storageAreaNotFound(requestID)
        }

        // Store file data
        if files[requestID] == nil {
            files[requestID] = [:]
        }
        files[requestID]?[fileID] = data

        // Store metadata
        if metadata[requestID] == nil {
            metadata[requestID] = [:]
        }
        metadata[requestID]?[fileID] = fileMetadata
    }

    public func retrieveFile(
        withID fileID: UUID,
        from storageArea: StorageAreaReference
    ) throws -> Data {
        let requestID = storageArea.requestID

        guard let fileData = files[requestID]?[fileID] else {
            throw StorageProviderError.fileNotFound(fileID)
        }

        return fileData
    }

    public func removeFile(
        withID fileID: UUID,
        from storageArea: StorageAreaReference
    ) throws {
        let requestID = storageArea.requestID

        files[requestID]?.removeValue(forKey: fileID)
        metadata[requestID]?.removeValue(forKey: fileID)
    }

    public func listFiles(in storageArea: StorageAreaReference) -> [UUID] {
        let requestID = storageArea.requestID
        if let requestFiles = files[requestID] {
            return Array(requestFiles.keys)
        }
        return []
    }

    public func listStorageAreas() -> [UUID] {
        return Array(storageAreas.keys)
    }

    public func cleanupStorageAreas(olderThan date: Date?) throws -> Int {
        guard let threshold = date else {
            return 0
        }

        var removedCount = 0

        let areasToRemove = creationDates.filter { $0.value < threshold }.map { $0.key }

        for requestID in areasToRemove {
            try removeStorageArea(for: requestID)
            removedCount += 1
        }

        return removedCount
    }

    // MARK: - Utility Methods

    /// Returns the total size of all stored data
    public var totalSize: Int {
        files.values.reduce(0) { total, requestFiles in
            total + requestFiles.values.reduce(0) { $0 + $1.count }
        }
    }

    /// Returns the number of files stored across all storage areas
    public var fileCount: Int {
        files.values.reduce(0) { $0 + $1.count }
    }

    /// Clears all storage (useful for testing)
    public func clearAll() {
        storageAreas.removeAll()
        files.removeAll()
        metadata.removeAll()
        creationDates.removeAll()
    }
}
