//
//  TestHelpers.swift
//  SwiftHablare
//
//  Test utilities and helpers
//

import Foundation
import SwiftData

/// Test utilities for consistent test setup
public enum TestHelpers {
    /// Creates a ModelConfiguration suitable for testing
    /// - Returns: A ModelConfiguration that uses in-memory storage or a writable temp directory
    public static func testModelConfiguration() -> ModelConfiguration {
        // Use in-memory storage for tests to avoid permission issues in CI
        return ModelConfiguration(isStoredInMemoryOnly: true)
    }

    /// Creates a ModelConfiguration with a temporary directory for persistence testing
    /// - Returns: A ModelConfiguration that writes to a writable temporary directory
    public static func testModelConfigurationWithStorage() -> ModelConfiguration {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftHablareTests-\(UUID().uuidString)")

        // Create the directory if needed
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        return ModelConfiguration(url: tempDir)
    }

    /// Creates a ModelContainer for testing with the specified models
    /// - Parameter modelTypes: The model types to include in the container
    /// - Returns: A ModelContainer configured for testing
    public static func testContainer<T: PersistentModel>(for modelType: T.Type) throws -> ModelContainer {
        let config = testModelConfiguration()
        return try ModelContainer(for: modelType, configurations: config)
    }

    /// Creates a ModelContainer for testing with multiple model types
    /// - Parameter modelTypes: The model types to include in the container
    /// - Returns: A ModelContainer configured for testing
    public static func testContainer(for modelTypes: any PersistentModel.Type...) throws -> ModelContainer {
        let config = testModelConfiguration()
        let schema = Schema(modelTypes)
        return try ModelContainer(for: schema, configurations: config)
    }

    /// Cleans up temporary test directories
    /// - Parameter url: The URL to clean up (optional, cleans all test directories if nil)
    public static func cleanupTestStorage(at url: URL? = nil) {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory

        if let url = url {
            try? fm.removeItem(at: url)
        } else {
            // Clean up all SwiftHablareTests directories
            if let contents = try? fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
                for url in contents where url.lastPathComponent.hasPrefix("SwiftHablareTests-") {
                    try? fm.removeItem(at: url)
                }
            }
        }
    }
}
