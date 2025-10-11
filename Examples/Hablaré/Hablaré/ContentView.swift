//
//  ContentView.swift
//  Hablaré
//
//  Created by TOM STOVALL on 10/5/25.
//

import SwiftUI
import SwiftData
import SwiftHablare

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @StateObject private var playerManager = AudioPlayerManager()
    @StateObject private var providerManager: VoiceProviderManager
    @State private var errorMessage: String?
    @State private var selectedVoice: Voice?

    init() {
        // We need to initialize providerManager with a temporary context
        // It will be properly updated in the body with the environment context
        let context = ModelContext(try! ModelContainer(for: Item.self, AudioFile.self, VoiceModel.self))
        _providerManager = StateObject(wrappedValue: VoiceProviderManager(modelContext: context))
    }

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                    } label: {
                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .toolbar {
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
                ToolbarItem {
                    Button(action: { showSettings() }) {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
        } detail: {
            VStack(spacing: 20) {
                // Voice Provider Selection Widget
                VoiceProviderWidget(providerManager: providerManager)
                    .padding(.horizontal)
                    .padding(.top)

                // Voice Picker Widget
                VoicePickerWidget.withBinding(
                    providerManager: providerManager,
                    selection: $selectedVoice
                )
                .padding(.horizontal)

                // Text Generation Widget
                TextGenerationWidget(
                    providerManager: providerManager,
                    modelContext: modelContext,
                    selectedVoice: selectedVoice,
                    onAudioGenerated: { audioFile in
                        // Automatically play the generated audio
                        do {
                            try playerManager.play(audioFile)
                        } catch {
                            errorMessage = "Failed to play: \(error.localizedDescription)"
                        }
                    }
                )
                .padding(.horizontal)

                // Audio Player Widget
                AudioPlayerWidget(
                    playerManager: playerManager,
                    providerManager: providerManager
                )
                .padding()

                Spacer()
            }
            .padding()
        }
        .onAppear {
            // Update providerManager with the actual modelContext from environment
            let updatedManager = VoiceProviderManager(modelContext: modelContext)
            providerManager.currentProviderType = updatedManager.currentProviderType
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }

    private func showSettings() {
        #if os(macOS)
        // On macOS, open Settings window
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        #else
        // On iOS, we would present a sheet - placeholder for now
        print("Settings would open here on iOS")
        #endif
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
