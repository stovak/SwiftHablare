# Screenplay Speech UI & Workflow Design

## Document Purpose

This document defines the user interface and workflow architecture for the screenplay-to-speech system in SwiftHablare.

**Version**: 1.0
**Date**: 2025-10-16

---

## Requirements Summary

### Core Workflows

1. **Generate SpeakableItems Task**
   - Triggerable task with progress bar
   - Runs on @MainActor
   - Iterates GuionElements
   - Creates SpeakableItem records (no audio)

2. **Generate Audio Task**
   - Triggerable task with progress bar
   - Iterates SpeakableItems
   - Generates audio using selected provider/voice/settings

3. **Tabbed Interface**
   - Voice-to-Character mapping
   - Character-to-Voice mapping
   - Generated Audio list
   - Export (placeholder)

4. **Audio Playback**
   - List of generated audio in SpeakableItem order
   - Player widget at top

---

## Architecture Overview

### Component Hierarchy

```
ScreenplaySpeechView (Main Container)
├── TabView
│   ├── VoiceToCharacterMappingView
│   ├── CharacterToVoiceMapingView
│   ├── GeneratedAudioListView
│   │   ├── AudioPlayerWidget (top)
│   │   └── SpeakableItemsListView (ordered)
│   └── ExportView (placeholder)
│
└── TaskProgressOverlay (modal)
    ├── SpeakableItemGenerationTask
    └── AudioGenerationTask
```

---

## Task Architecture

### 1. ScreenplayProcessingTask (Actor)

**Purpose**: Manages long-running tasks with progress tracking on @MainActor.

```swift
import SwiftUI
import SwiftData
import Observation

/// Base protocol for screenplay processing tasks
@MainActor
protocol ScreenplayTask {
    var progress: TaskProgress { get }
    func execute() async throws
    func cancel()
}

/// Progress tracking model
@Observable
@MainActor
class TaskProgress {
    var currentStep: Int = 0
    var totalSteps: Int = 0
    var currentMessage: String = ""
    var isRunning: Bool = false
    var isCancelled: Bool = false
    var error: Error?

    var progressFraction: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentStep) / Double(totalSteps)
    }

    var progressPercentage: Int {
        Int(progressFraction * 100)
    }
}

/// Main task coordinator
@Observable
@MainActor
class ScreenplayTaskCoordinator {
    var currentTask: (any ScreenplayTask)?
    var taskHistory: [TaskHistoryEntry] = []

    func runTask(_ task: any ScreenplayTask) async {
        currentTask = task

        let startTime = Date()
        do {
            try await task.execute()

            taskHistory.append(TaskHistoryEntry(
                name: String(describing: type(of: task)),
                startTime: startTime,
                endTime: Date(),
                success: true
            ))
        } catch {
            task.progress.error = error

            taskHistory.append(TaskHistoryEntry(
                name: String(describing: type(of: task)),
                startTime: startTime,
                endTime: Date(),
                success: false,
                error: error
            ))
        }

        // Clear after 2 seconds to allow UI to show completion
        try? await Task.sleep(for: .seconds(2))
        if currentTask?.progress.isRunning == false {
            currentTask = nil
        }
    }

    func cancelCurrentTask() {
        currentTask?.cancel()
    }
}

struct TaskHistoryEntry: Identifiable {
    let id = UUID()
    let name: String
    let startTime: Date
    let endTime: Date
    let success: Bool
    let error: Error?

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}
```

---

### 2. SpeakableItemGenerationTask

**Purpose**: Generate SpeakableItems from GuionElements.

```swift
@MainActor
class SpeakableItemGenerationTask: ScreenplayTask {
    let context: ModelContext
    let document: GuionDocumentModel
    let rulesProvider: SpeechLogicRulesProvider
    let progress: TaskProgress

    private var task: Task<Void, Error>?

    init(
        context: ModelContext,
        document: GuionDocumentModel,
        rulesProvider: SpeechLogicRulesProvider = SpeechLogicRulesV1_0()
    ) {
        self.context = context
        self.document = document
        self.rulesProvider = rulesProvider
        self.progress = TaskProgress()
    }

    func execute() async throws {
        progress.isRunning = true
        progress.isCancelled = false
        progress.error = nil

        task = Task {
            let elements = document.elements
            progress.totalSteps = elements.count
            progress.currentMessage = "Preparing to process \(elements.count) elements..."

            // Small delay for UI to update
            try await Task.sleep(for: .milliseconds(100))

            var generatedItems: [SpeakableItem] = []
            var sceneContext = SceneContext()
            var index = 0

            while index < elements.count && !progress.isCancelled {
                let element = elements[index]

                // Check for cancellation
                try Task.checkCancellation()

                // Update progress
                progress.currentStep = index + 1
                progress.currentMessage = "Processing: \(element.elementType) - \(element.elementText.prefix(50))..."

                // Scene boundary - reset context
                if element.elementType == "Scene Heading" {
                    sceneContext = SceneContext(sceneID: element.sceneId ?? "unknown")

                    if let item = processSceneHeading(element, orderIndex: index) {
                        generatedItems.append(item)
                        context.insert(item)
                    }
                    index += 1
                    continue
                }

                // Dialogue block
                if element.elementType == "Character" {
                    let (dialogueItems, consumed) = processDialogueBlock(
                        startIndex: index,
                        elements: elements,
                        context: &sceneContext
                    )
                    for item in dialogueItems {
                        generatedItems.append(item)
                        context.insert(item)
                    }
                    index += consumed
                    continue
                }

                // Single element
                if let item = processSingleElement(element, orderIndex: index) {
                    generatedItems.append(item)
                    context.insert(item)
                }

                index += 1

                // Periodic save to avoid memory buildup
                if index % 50 == 0 {
                    try context.save()
                }
            }

            // Final save
            progress.currentMessage = "Saving \(generatedItems.count) speakable items..."
            try context.save()

            progress.currentMessage = "Complete! Generated \(generatedItems.count) speakable items."
            progress.isRunning = false
        }

        try await task?.value
    }

    func cancel() {
        progress.isCancelled = true
        task?.cancel()
        progress.isRunning = false
    }

    // MARK: - Processing Methods

    private func processDialogueBlock(
        startIndex: Int,
        elements: [GuionElementModel],
        context: inout SceneContext
    ) -> (items: [SpeakableItem], consumed: Int) {
        var index = startIndex

        guard index < elements.count,
              elements[index].elementType == "Character" else {
            return ([], 1)
        }

        let characterElement = elements[index]
        let rawCharacterName = characterElement.elementText
        let normalizedName = normalizeCharacterName(rawCharacterName)
        index += 1

        // Skip parenthetical
        if index < elements.count && elements[index].elementType == "Parenthetical" {
            index += 1
        }

        // Collect dialogue lines
        var dialogueLines: [String] = []
        while index < elements.count && elements[index].elementType == "Dialogue" {
            dialogueLines.append(elements[index].elementText)
            index += 1
        }

        guard !dialogueLines.isEmpty else {
            return ([], index - startIndex)
        }

        let combinedDialogue = dialogueLines.joined(separator: " ")
        let isFirstTimeInScene = !context.hasCharacterSpoken(normalizedName)

        let speakableText: String
        if isFirstTimeInScene {
            speakableText = "\(rawCharacterName) says: \(combinedDialogue)"
        } else {
            speakableText = combinedDialogue
        }

        let item = SpeakableItem(
            orderIndex: startIndex,
            sourceElementID: characterElement.sceneId ?? "unknown",
            sourceElementType: "Dialogue",
            sceneID: context.sceneID,
            speakableText: speakableText,
            characterName: normalizedName,
            rawCharacterName: rawCharacterName,
            ruleVersion: rulesProvider.version,
            includesCharacterAnnouncement: isFirstTimeInScene,
            toneHint: .character
        )

        context.markCharacterSpoken(normalizedName)
        context.lastSpeaker = normalizedName

        return ([item], index - startIndex)
    }

    private func processSceneHeading(_ element: GuionElementModel, orderIndex: Int) -> SpeakableItem? {
        var text = element.elementText

        if let lighting = element.locationLighting,
           let scene = element.locationScene {
            let lightingText = lighting == "INT" ? "Interior" : (lighting == "EXT" ? "Exterior" : lighting)
            let timeOfDay = element.locationTimeOfDay ?? ""
            text = "\(lightingText). \(scene). \(timeOfDay)."
        } else {
            text = text
                .replacingOccurrences(of: "INT.", with: "Interior.")
                .replacingOccurrences(of: "EXT.", with: "Exterior.")
        }

        return SpeakableItem(
            orderIndex: orderIndex,
            sourceElementID: element.sceneId ?? "unknown",
            sourceElementType: "Scene Heading",
            sceneID: element.sceneId,
            speakableText: text,
            ruleVersion: rulesProvider.version,
            toneHint: .narrative
        )
    }

    private func processSingleElement(_ element: GuionElementModel, orderIndex: Int) -> SpeakableItem? {
        let nonSpeakableTypes: Set<String> = [
            "Parenthetical", "Transition", "Note", "Boneyard",
            "Synopsis", "Section Heading", "Page Break"
        ]

        guard !nonSpeakableTypes.contains(element.elementType) else {
            return nil
        }

        guard element.elementType == "Action" else {
            return nil
        }

        return SpeakableItem(
            orderIndex: orderIndex,
            sourceElementID: element.sceneId ?? "unknown",
            sourceElementType: element.elementType,
            sceneID: element.sceneId,
            speakableText: element.elementText,
            ruleVersion: rulesProvider.version,
            toneHint: .narrative
        )
    }

    private func normalizeCharacterName(_ rawName: String) -> String {
        let withoutParens = rawName.replacingOccurrences(of: /\s*\([^)]+\)\s*/, with: "")
        return withoutParens.trimmingCharacters(in: .whitespaces).lowercased()
    }
}

// MARK: - Scene Context

struct SceneContext {
    var sceneID: String
    var charactersWhoHaveSpoken: Set<String> = []
    var lastSpeaker: String?

    init(sceneID: String = "") {
        self.sceneID = sceneID
    }

    mutating func markCharacterSpoken(_ name: String) {
        charactersWhoHaveSpoken.insert(name)
    }

    func hasCharacterSpoken(_ name: String) -> Bool {
        charactersWhoHaveSpoken.contains(name)
    }
}

// MARK: - Speech Logic Protocol

protocol SpeechLogicRulesProvider {
    var version: String { get }
}

struct SpeechLogicRulesV1_0: SpeechLogicRulesProvider {
    let version = "1.0"
}
```

---

### 3. AudioGenerationTask

**Purpose**: Generate audio for SpeakableItems using selected voice/provider.

```swift
@MainActor
class AudioGenerationTask: ScreenplayTask {
    let context: ModelContext
    let items: [SpeakableItem]
    let voiceSettings: VoiceGenerationSettings
    let audioRequestor: any AudioRequestorProtocol
    let progress: TaskProgress

    private var task: Task<Void, Error>?

    init(
        context: ModelContext,
        items: [SpeakableItem],
        voiceSettings: VoiceGenerationSettings,
        audioRequestor: any AudioRequestorProtocol
    ) {
        self.context = context
        self.items = items
        self.voiceSettings = voiceSettings
        self.audioRequestor = audioRequestor
        self.progress = TaskProgress()
    }

    func execute() async throws {
        progress.isRunning = true
        progress.isCancelled = false
        progress.error = nil

        task = Task {
            progress.totalSteps = items.count
            progress.currentMessage = "Preparing to generate audio for \(items.count) items..."

            try await Task.sleep(for: .milliseconds(100))

            var successCount = 0
            var failureCount = 0

            for (index, item) in items.enumerated() {
                guard !progress.isCancelled else { break }

                try Task.checkCancellation()

                progress.currentStep = index + 1
                progress.currentMessage = "Generating audio \(index + 1)/\(items.count): \(item.speakableText.prefix(50))..."

                // Update item status
                item.status = .audioQueued
                try context.save()

                do {
                    // Check TTS character limit
                    let maxChars = voiceSettings.maxCharacters
                    var textToSpeak = item.speakableText

                    if textToSpeak.count > maxChars {
                        progress.currentMessage = "Warning: Text exceeds limit, truncating..."
                        textToSpeak = String(textToSpeak.prefix(maxChars))
                    }

                    // Generate audio
                    item.status = .audioGenerating
                    try context.save()

                    let audioRecord = try await audioRequestor.generateAudio(
                        text: textToSpeak,
                        voice: voiceSettings.voiceID,
                        settings: voiceSettings
                    )

                    // Create SpeakableAudio linking record
                    let speakableAudio = SpeakableAudio(
                        hablareAudioID: audioRecord.id,
                        providerName: voiceSettings.providerName,
                        voiceID: voiceSettings.voiceID,
                        voiceName: voiceSettings.voiceName,
                        audioFormat: voiceSettings.audioFormat,
                        characterCount: textToSpeak.count
                    )

                    item.audioVersions.append(speakableAudio)
                    item.activeAudioID = speakableAudio.id
                    item.status = .audioComplete
                    item.updatedAt = Date()

                    context.insert(speakableAudio)
                    try context.save()

                    successCount += 1

                } catch {
                    item.status = .audioFailed
                    try context.save()
                    failureCount += 1
                    print("Failed to generate audio for item \(item.id): \(error)")
                }

                // Rate limiting pause
                if index < items.count - 1 {
                    try await Task.sleep(for: .milliseconds(200))
                }
            }

            progress.currentMessage = "Complete! \(successCount) succeeded, \(failureCount) failed."
            progress.isRunning = false
        }

        try await task?.value
    }

    func cancel() {
        progress.isCancelled = true
        task?.cancel()
        progress.isRunning = false
    }
}

// MARK: - Supporting Types

struct VoiceGenerationSettings {
    let providerName: String
    let voiceID: String
    let voiceName: String?
    let audioFormat: String
    let maxCharacters: Int

    // Provider-specific settings (can be extended)
    var temperature: Double?
    var speed: Double?
    var stability: Double?
    var clarity: Double?
}

protocol AudioRequestorProtocol {
    func generateAudio(
        text: String,
        voice: String,
        settings: VoiceGenerationSettings
    ) async throws -> GeneratedAudioRecord
}

struct GeneratedAudioRecord {
    let id: UUID
    let audioData: Data
    let duration: TimeInterval?
}
```

---

## Voice-Character Mapping Models

### CharacterVoiceMapping SwiftData Model

```swift
import SwiftData
import Foundation

/// Maps characters to voices for screenplay speech generation
@Model
public final class CharacterVoiceMapping {
    // MARK: - Identity

    public var id: UUID

    /// The screenplay document this mapping belongs to
    public var screenplayID: String

    // MARK: - Character Information

    /// Normalized character name (e.g., "john")
    public var characterName: String

    /// Display name for UI (e.g., "JOHN", "JOHN (V.O.)")
    public var displayName: String

    /// All known aliases for this character
    public var aliases: [String]

    // MARK: - Voice Assignment

    /// Selected voice ID for this character
    public var voiceID: String?

    /// Voice provider (e.g., "ElevenLabs", "Apple")
    public var providerName: String?

    /// Human-readable voice name
    public var voiceName: String?

    /// Voice gender (for automatic matching)
    public var voiceGender: String?  // "male", "female", "neutral"

    // MARK: - Metadata

    /// Number of dialogue items for this character
    public var dialogueCount: Int

    /// Auto-assigned vs. manually set
    public var isManuallyAssigned: Bool

    /// Notes about this character
    public var notes: String?

    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        screenplayID: String,
        characterName: String,
        displayName: String,
        aliases: [String] = [],
        voiceID: String? = nil,
        providerName: String? = nil,
        voiceName: String? = nil,
        voiceGender: String? = nil,
        dialogueCount: Int = 0,
        isManuallyAssigned: Bool = false,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.screenplayID = screenplayID
        self.characterName = characterName
        self.displayName = displayName
        self.aliases = aliases
        self.voiceID = voiceID
        self.providerName = providerName
        self.voiceName = voiceName
        self.voiceGender = voiceGender
        self.dialogueCount = dialogueCount
        self.isManuallyAssigned = isManuallyAssigned
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Helper to generate character mappings from SpeakableItems
@MainActor
class CharacterMappingGenerator {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func generateMappings(for screenplayID: String) throws -> [CharacterVoiceMapping] {
        // Fetch all dialogue items for this screenplay
        let descriptor = FetchDescriptor<SpeakableItem>(
            predicate: #Predicate { item in
                item.sourceElementType == "Dialogue" &&
                item.sourceElementID.contains(screenplayID)
            }
        )
        let dialogueItems = try context.fetch(descriptor)

        // Group by character
        var characterGroups: [String: [SpeakableItem]] = [:]
        for item in dialogueItems {
            guard let charName = item.characterName else { continue }
            characterGroups[charName, default: []].append(item)
        }

        // Create mappings
        var mappings: [CharacterVoiceMapping] = []
        for (characterName, items) in characterGroups {
            // Get display name from first item
            let displayName = items.first?.rawCharacterName ?? characterName.uppercased()

            // Collect all unique raw names as aliases
            let aliases = Set(items.compactMap { $0.rawCharacterName })

            let mapping = CharacterVoiceMapping(
                screenplayID: screenplayID,
                characterName: characterName,
                displayName: displayName,
                aliases: Array(aliases),
                dialogueCount: items.count
            )

            context.insert(mapping)
            mappings.append(mapping)
        }

        try context.save()
        return mappings
    }
}
```

---

## UI Views

### 1. Main Tabbed Interface

```swift
import SwiftUI
import SwiftData

public struct ScreenplaySpeechView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    @State private var taskCoordinator = ScreenplayTaskCoordinator()

    let screenplay: GuionDocumentModel

    public init(screenplay: GuionDocumentModel) {
        self.screenplay = screenplay
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Screenplay Speech: \(screenplay.filename ?? "Untitled")")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                // Task control buttons
                HStack(spacing: 12) {
                    Button {
                        triggerSpeakableItemGeneration()
                    } label: {
                        Label("Generate Items", systemImage: "wand.and.stars")
                    }
                    .disabled(taskCoordinator.currentTask != nil)

                    Button {
                        triggerAudioGeneration()
                    } label: {
                        Label("Generate Audio", systemImage: "waveform")
                    }
                    .disabled(taskCoordinator.currentTask != nil)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Tabbed content
            TabView(selection: $selectedTab) {
                VoiceToCharacterMappingView(screenplayID: screenplay.filename ?? "")
                    .tabItem {
                        Label("Voice → Character", systemImage: "person.wave.2")
                    }
                    .tag(0)

                CharacterToVoiceMappingView(screenplayID: screenplay.filename ?? "")
                    .tabItem {
                        Label("Character → Voice", systemImage: "person.crop.circle.badge.checkmark")
                    }
                    .tag(1)

                GeneratedAudioListView(screenplayID: screenplay.filename ?? "")
                    .tabItem {
                        Label("Generated Audio", systemImage: "list.bullet.rectangle")
                    }
                    .tag(2)

                ExportView()
                    .tabItem {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .tag(3)
            }
        }
        .overlay {
            if let currentTask = taskCoordinator.currentTask {
                TaskProgressOverlay(task: currentTask) {
                    taskCoordinator.cancelCurrentTask()
                }
            }
        }
    }

    private func triggerSpeakableItemGeneration() {
        let task = SpeakableItemGenerationTask(
            context: modelContext,
            document: screenplay
        )

        Task {
            await taskCoordinator.runTask(task)
        }
    }

    private func triggerAudioGeneration() {
        // Fetch all items needing audio
        let descriptor = FetchDescriptor<SpeakableItem>(
            predicate: #Predicate { $0.status == .textGenerated },
            sortBy: [SortDescriptor(\.orderIndex)]
        )

        guard let items = try? modelContext.fetch(descriptor),
              !items.isEmpty else {
            print("No items need audio generation")
            return
        }

        // TODO: Get voice settings from UI
        let settings = VoiceGenerationSettings(
            providerName: "ElevenLabs",
            voiceID: "default-voice",
            voiceName: "Default",
            audioFormat: "mp3",
            maxCharacters: 5000
        )

        // TODO: Get appropriate audio requestor
        // let requestor = ElevenLabsAudioRequestor()

        // let task = AudioGenerationTask(
        //     context: modelContext,
        //     items: items,
        //     voiceSettings: settings,
        //     audioRequestor: requestor
        // )
        //
        // Task {
        //     await taskCoordinator.runTask(task)
        // }
    }
}
```

---

### 2. Task Progress Overlay

```swift
struct TaskProgressOverlay: View {
    let task: any ScreenplayTask
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // Progress card
            VStack(spacing: 20) {
                // Title
                Text("Processing")
                    .font(.title2)
                    .fontWeight(.semibold)

                // Progress bar
                VStack(spacing: 8) {
                    ProgressView(value: task.progress.progressFraction) {
                        HStack {
                            Text("\(task.progress.progressPercentage)%")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text("\(task.progress.currentStep) / \(task.progress.totalSteps)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .progressViewStyle(.linear)

                    Text(task.progress.currentMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }

                // Cancel button
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.2), radius: 20)
            )
            .frame(width: 400)
        }
    }
}
```

---

### 3. Character-to-Voice Mapping View

```swift
struct CharacterToVoiceMappingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var mappings: [CharacterVoiceMapping]
    @Query private var voices: [Voice]  // From SwiftHablare

    let screenplayID: String

    init(screenplayID: String) {
        self.screenplayID = screenplayID
        _mappings = Query(
            filter: #Predicate<CharacterVoiceMapping> { mapping in
                mapping.screenplayID == screenplayID
            },
            sort: [SortDescriptor(\.dialogueCount, order: .reverse)]
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Character Voice Assignments")
                    .font(.headline)

                Spacer()

                Button {
                    generateMappings()
                } label: {
                    Label("Auto-Detect Characters", systemImage: "person.2.badge.gearshape")
                }
            }
            .padding()

            Divider()

            // Mappings list
            if mappings.isEmpty {
                ContentUnavailableView(
                    "No Characters Found",
                    systemImage: "person.slash",
                    description: Text("Generate SpeakableItems first, then use Auto-Detect Characters")
                )
            } else {
                List {
                    ForEach(mappings) { mapping in
                        CharacterMappingRow(mapping: mapping, availableVoices: voices)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private func generateMappings() {
        let generator = CharacterMappingGenerator(context: modelContext)
        do {
            let mappings = try generator.generateMappings(for: screenplayID)
            print("Generated \(mappings.count) character mappings")
        } catch {
            print("Failed to generate mappings: \(error)")
        }
    }
}

struct CharacterMappingRow: View {
    @Bindable var mapping: CharacterVoiceMapping
    let availableVoices: [Voice]

    var body: some View {
        HStack(spacing: 16) {
            // Character info
            VStack(alignment: .leading, spacing: 4) {
                Text(mapping.displayName)
                    .font(.headline)

                HStack(spacing: 4) {
                    Image(systemName: "text.bubble")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("\(mapping.dialogueCount) lines")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 150, alignment: .leading)

            // Voice picker
            Picker("Voice", selection: $mapping.voiceID) {
                Text("No voice assigned")
                    .tag(nil as String?)

                ForEach(availableVoices) { voice in
                    HStack {
                        Text(voice.name)
                        if let gender = voice.gender {
                            Text("(\(gender))")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(voice.id as String?)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 250)

            // Manual indicator
            if mapping.isManuallyAssigned {
                Image(systemName: "hand.point.up.left.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 8)
    }
}
```

---

### 4. Voice-to-Character Mapping View

```swift
struct VoiceToCharacterMappingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var voices: [Voice]
    @Query private var mappings: [CharacterVoiceMapping]

    let screenplayID: String

    init(screenplayID: String) {
        self.screenplayID = screenplayID
        _mappings = Query(
            filter: #Predicate<CharacterVoiceMapping> { mapping in
                mapping.screenplayID == screenplayID
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Voice Character Assignments")
                    .font(.headline)

                Spacer()
            }
            .padding()

            Divider()

            // Voices list
            if voices.isEmpty {
                ContentUnavailableView(
                    "No Voices Available",
                    systemImage: "waveform.slash",
                    description: Text("Configure voice providers first")
                )
            } else {
                List {
                    ForEach(voices) { voice in
                        VoiceMappingRow(
                            voice: voice,
                            assignedCharacters: charactersForVoice(voice.id)
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private func charactersForVoice(_ voiceID: String) -> [CharacterVoiceMapping] {
        mappings.filter { $0.voiceID == voiceID }
    }
}

struct VoiceMappingRow: View {
    let voice: Voice
    let assignedCharacters: [CharacterVoiceMapping]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Voice info
            HStack {
                Text(voice.name)
                    .font(.headline)

                if let gender = voice.gender {
                    Text(gender.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            // Assigned characters
            if assignedCharacters.isEmpty {
                Text("Not assigned to any character")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 8) {
                    ForEach(assignedCharacters) { mapping in
                        Text(mapping.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}
```

---

### 5. Generated Audio List View

```swift
struct GeneratedAudioListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var speakableItems: [SpeakableItem]
    @State private var playerManager = AudioPlayerManager()

    let screenplayID: String

    init(screenplayID: String) {
        self.screenplayID = screenplayID
        _speakableItems = Query(
            filter: #Predicate<SpeakableItem> { item in
                item.sourceElementID.contains(screenplayID)
            },
            sort: [SortDescriptor(\.orderIndex)]
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Audio player at top
            AudioPlayerWidget(
                playerManager: playerManager,
                providerManager: VoiceProviderManager(modelContext: modelContext)
            )
            .padding()

            Divider()

            // Items list
            if speakableItems.isEmpty {
                ContentUnavailableView(
                    "No Speakable Items",
                    systemImage: "text.bubble",
                    description: Text("Generate SpeakableItems first")
                )
            } else {
                List {
                    ForEach(speakableItems) { item in
                        SpeakableItemRow(item: item) {
                            playItem(item)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private func playItem(_ item: SpeakableItem) {
        guard let activeAudioID = item.activeAudioID,
              let activeAudio = item.audioVersions.first(where: { $0.id == activeAudioID }) else {
            print("No audio available for item")
            return
        }

        // Fetch Hablare audio record
        let descriptor = FetchDescriptor<GeneratedAudioRecord>(
            predicate: #Predicate { $0.id == activeAudio.hablareAudioID }
        )

        guard let audioRecord = try? modelContext.fetch(descriptor).first else {
            print("Audio record not found")
            return
        }

        // TODO: Play audio via playerManager
        // playerManager.play(audioRecord)
    }
}

struct SpeakableItemRow: View {
    let item: SpeakableItem
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            statusIcon
                .frame(width: 24)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Speakable text
                Text(item.speakableText)
                    .font(.body)
                    .lineLimit(2)

                // Metadata
                HStack(spacing: 8) {
                    if let character = item.characterName {
                        Label(character.capitalized, systemImage: "person")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Label(item.sourceElementType, systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if item.includesCharacterAnnouncement {
                        Image(systemName: "speaker.wave.1")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }

            Spacer()

            // Play button
            if item.status == .audioComplete {
                Button {
                    onPlay()
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .textGenerated:
            Image(systemName: "circle.dashed")
                .foregroundStyle(.secondary)
        case .audioQueued:
            Image(systemName: "clock")
                .foregroundStyle(.orange)
        case .audioGenerating:
            ProgressView()
                .controlSize(.small)
        case .audioComplete:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .audioFailed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }
}
```

---

### 6. Export View (Placeholder)

```swift
struct ExportView: View {
    var body: some View {
        ContentUnavailableView(
            "Export",
            systemImage: "square.and.arrow.up",
            description: Text("Export functionality coming soon")
        )
    }
}
```

---

## Summary

### Components Implemented

1. ✅ **Task Architecture**
   - `ScreenplayTask` protocol
   - `TaskProgress` observable model
   - `ScreenplayTaskCoordinator` for task management
   - `SpeakableItemGenerationTask` with progress
   - `AudioGenerationTask` with progress

2. ✅ **Data Models**
   - `CharacterVoiceMapping` SwiftData model
   - `CharacterMappingGenerator` utility

3. ✅ **UI Views**
   - `ScreenplaySpeechView` (main tabbed container)
   - `TaskProgressOverlay` (modal progress UI)
   - `CharacterToVoiceMappingView`
   - `VoiceToCharacterMappingView`
   - `GeneratedAudioListView`
   - `ExportView` (placeholder)

4. ✅ **Integration**
   - Existing `AudioPlayerWidget` reused
   - SwiftHablare voice/provider infrastructure
   - SpeakableItem/SpeakableAudio models

---

## Next Steps

1. Implement missing audio requestor protocol adapter
2. Add voice settings configuration UI
3. Implement audio playback integration
4. Add export functionality (audiobook, ZIP, etc.)
5. Add batch regeneration features
6. Add character alias editing
7. Add voice preview/testing

---

## Integration with Sample App

**Note**: The UI components defined in this document are integrated into the Hablare sample application as the right-side tabbed palette. See [SAMPLE_APP_DESIGN.md](SAMPLE_APP_DESIGN.md) for the complete split-view architecture.

**Sample App Layout**:
```
┌────────────────────────────────────────────┐
│  Left Pane          │  Right Pane          │
│  SwiftGuion         │  ScreenplaySpeechView│
│  Screenplay Editor  │  (This Document)     │
└────────────────────────────────────────────┘
```

---

## Change Log

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-10-16 | Initial UI/workflow design |
| 1.1 | 2025-10-16 | Added sample app integration note |
