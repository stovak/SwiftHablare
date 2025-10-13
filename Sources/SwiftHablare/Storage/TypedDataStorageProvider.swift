//
//  TypedDataStorageProvider.swift
//  SwiftHablare
//
//  Storage protocol for typed data management
//

import Foundation

/// Protocol for managing storage of typed AI-generated data.
///
/// Types conforming to this protocol can manage the lifecycle of typed data files,
/// including creation, retrieval, and cleanup. This allows documents, databases,
/// or other storage mechanisms to handle typed data in their own way.
///
/// ## Usage
/// ```swift
/// class MyDocument: TypedDataStorageProvider {
///     func createStorageArea(for requestID: UUID) throws -> StorageAreaReference {
///         let bundleURL = documentsDirectory.appendingPathComponent("\(requestID).guion")
///         return StorageAreaReference(requestID: requestID, bundleURL: bundleURL)
///     }
///
///     func attachFile(
///         _ data: Data,
///         withID fileID: UUID,
///         to storageArea: StorageAreaReference,
///         metadata: [String: String]
///     ) throws {
///         let fileURL = storageArea.resourcesDirectory.appendingPathComponent("\(fileID).dat")
///         try data.write(to: fileURL)
///     }
/// }
/// ```
@available(macOS 15.0, iOS 17.0, *)
public protocol TypedDataStorageProvider {

    // MARK: - Storage Area Management

    /// Creates a new storage area for a request.
    ///
    /// This method should create the necessary directory structure and
    /// return a reference that can be used to access the storage area.
    ///
    /// - Parameter requestID: Unique identifier for the request
    /// - Returns: Reference to the created storage area
    /// - Throws: Storage errors if creation fails
    func createStorageArea(for requestID: UUID) throws -> StorageAreaReference

    /// Retrieves an existing storage area for a request.
    ///
    /// - Parameter requestID: Unique identifier for the request
    /// - Returns: Reference to the storage area, or nil if not found
    func getStorageArea(for requestID: UUID) -> StorageAreaReference?

    /// Removes a storage area and all its contents.
    ///
    /// - Parameter requestID: Unique identifier for the request
    /// - Throws: Storage errors if removal fails
    func removeStorageArea(for requestID: UUID) throws

    // MARK: - File Management

    /// Attaches a file to a storage area.
    ///
    /// Stores the provided data in the storage area with the given identifier
    /// and optional metadata.
    ///
    /// - Parameters:
    ///   - data: Binary data to store
    ///   - fileID: Unique identifier for the file
    ///   - storageArea: Storage area to store the file in
    ///   - metadata: Optional metadata associated with the file
    /// - Throws: Storage errors if attachment fails
    func attachFile(
        _ data: Data,
        withID fileID: UUID,
        to storageArea: StorageAreaReference,
        metadata: [String: String]
    ) throws

    /// Retrieves file data from a storage area.
    ///
    /// - Parameters:
    ///   - fileID: Unique identifier for the file
    ///   - storageArea: Storage area containing the file
    /// - Returns: The file data
    /// - Throws: Storage errors if retrieval fails
    func retrieveFile(
        withID fileID: UUID,
        from storageArea: StorageAreaReference
    ) throws -> Data

    /// Removes a file from a storage area.
    ///
    /// - Parameters:
    ///   - fileID: Unique identifier for the file
    ///   - storageArea: Storage area containing the file
    /// - Throws: Storage errors if removal fails
    func removeFile(
        withID fileID: UUID,
        from storageArea: StorageAreaReference
    ) throws

    // MARK: - Query Methods

    /// Lists all files in a storage area.
    ///
    /// - Parameter storageArea: Storage area to query
    /// - Returns: Array of file identifiers
    func listFiles(in storageArea: StorageAreaReference) -> [UUID]

    /// Lists all storage areas managed by this provider.
    ///
    /// - Returns: Array of request identifiers
    func listStorageAreas() -> [UUID]

    // MARK: - Maintenance

    /// Performs cleanup of orphaned or expired storage areas.
    ///
    /// Implementations can use this to remove storage areas that are no longer
    /// needed, such as those older than a certain age or exceeding size limits.
    ///
    /// - Parameter olderThan: Optional date threshold for cleanup
    /// - Returns: Number of storage areas removed
    @discardableResult
    func cleanupStorageAreas(olderThan date: Date?) throws -> Int
}

// MARK: - Default Implementations

@available(macOS 15.0, iOS 17.0, *)
extension TypedDataStorageProvider {

    /// Default implementation: no cleanup threshold
    public func cleanupStorageAreas(olderThan date: Date? = nil) throws -> Int {
        return 0
    }
}

// MARK: - Storage Errors

/// Errors that can occur during storage operations
@available(macOS 15.0, iOS 17.0, *)
public enum StorageProviderError: Error, LocalizedError {
    case storageAreaNotFound(UUID)
    case storageAreaAlreadyExists(UUID)
    case fileNotFound(UUID)
    case fileAlreadyExists(UUID)
    case invalidStorageArea(String)
    case operationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .storageAreaNotFound(let id):
            return "Storage area not found: \(id)"
        case .storageAreaAlreadyExists(let id):
            return "Storage area already exists: \(id)"
        case .fileNotFound(let id):
            return "File not found: \(id)"
        case .fileAlreadyExists(let id):
            return "File already exists: \(id)"
        case .invalidStorageArea(let reason):
            return "Invalid storage area: \(reason)"
        case .operationFailed(let reason):
            return "Storage operation failed: \(reason)"
        }
    }
}

// MARK: - File Attachment Structure

/// Represents a file attachment ready for storage.
///
/// This structure is used to pass file information between the requestor
/// and the storage provider.
@available(macOS 15.0, iOS 17.0, *)
public struct FileAttachment {
    /// Unique identifier for the file
    public let fileID: UUID

    /// Binary data to store
    public let data: Data

    /// Relative path within storage area (e.g., "Resources/audio.mp3")
    public let relativePath: String

    /// MIME type of the file
    public let mimeType: String

    /// Optional metadata
    public let metadata: [String: String]

    /// Parent request identifier
    public let requestID: UUID

    /// When the attachment was created
    public let createdAt: Date

    /// Creates a file attachment
    ///
    /// - Parameters:
    ///   - fileID: Unique identifier for the file
    ///   - data: Binary data to store
    ///   - relativePath: Relative path within storage area
    ///   - mimeType: MIME type of the file
    ///   - metadata: Optional metadata
    ///   - requestID: Parent request identifier
    ///   - createdAt: Creation timestamp (defaults to now)
    public init(
        fileID: UUID = UUID(),
        data: Data,
        relativePath: String,
        mimeType: String,
        metadata: [String: String] = [:],
        requestID: UUID,
        createdAt: Date = Date()
    ) {
        self.fileID = fileID
        self.data = data
        self.relativePath = relativePath
        self.mimeType = mimeType
        self.metadata = metadata
        self.requestID = requestID
        self.createdAt = createdAt
    }
}
