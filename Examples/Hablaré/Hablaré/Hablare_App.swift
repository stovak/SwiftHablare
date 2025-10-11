//
//  Hablare_App.swift
//  Hablaré
//
//  Created by TOM STOVALL on 10/5/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import SwiftHablare

@main
struct Hablare_App: App {
    var body: some Scene {
        DocumentGroup(editing: .itemDocument, migrationPlan: Hablare_MigrationPlan.self) {
            ContentView()
        }

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

extension UTType {
    static var itemDocument: UTType {
        UTType(importedAs: "com.example.item-document")
    }
}

struct Hablare_MigrationPlan: SchemaMigrationPlan {
    static var schemas: [VersionedSchema.Type] = [
        Hablare_VersionedSchema.self,
    ]

    static var stages: [MigrationStage] = [
        // Stages of migration between VersionedSchema, if required.
    ]
}

struct Hablare_VersionedSchema: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] = [
        Item.self,
        AudioFile.self,
        VoiceModel.self,
    ]
}
