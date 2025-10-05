//
//  TextGenerationWidget.swift
//  SwiftHablare
//
//  Widget for generating audio from text input
//

import SwiftUI
import SwiftData

public struct TextGenerationWidget: View {
    @ObservedObject var providerManager: VoiceProviderManager
    let modelContext: ModelContext
    let selectedVoice: Voice?
    let onAudioGenerated: (AudioFile) -> Void

    @State private var textInput: String = ""
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var characterCount: Int = 0

    private let maxCharacters = 250

    public init(
        providerManager: VoiceProviderManager,
        modelContext: ModelContext,
        selectedVoice: Voice?,
        onAudioGenerated: @escaping (AudioFile) -> Void
    ) {
        self.providerManager = providerManager
        self.modelContext = modelContext
        self.selectedVoice = selectedVoice
        self.onAudioGenerated = onAudioGenerated
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("Generate Audio")
                .font(.headline)

            // Text input field
            VStack(alignment: .leading, spacing: 4) {
                TextField("Enter text to convert to speech...", text: $textInput, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(3...5)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .onChange(of: textInput) { oldValue, newValue in
                        // Enforce character limit
                        if newValue.count > maxCharacters {
                            textInput = String(newValue.prefix(maxCharacters))
                        }
                        characterCount = textInput.count
                    }

                // Character counter
                HStack {
                    Text("\(characterCount)/\(maxCharacters) characters")
                        .font(.caption2)
                        .foregroundStyle(characterCount >= maxCharacters ? .red : .secondary)

                    Spacer()
                }
            }

            // Action buttons and status
            HStack {
                Button(action: generateAudio) {
                    HStack(spacing: 6) {
                        if isGenerating {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "play.circle.fill")
                        }
                        Text(isGenerating ? "Generating..." : "Generate")
                    }
                    .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .disabled(textInput.isEmpty || isGenerating || !providerManager.isCurrentProviderConfigured())

                if !textInput.isEmpty && !isGenerating {
                    Button(action: clearInput) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Configuration warning
                if !providerManager.isCurrentProviderConfigured() {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                        Text("Configure API key")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                }
            }

            // Error message
            if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    private func generateAudio() {
        guard !textInput.isEmpty else { return }
        guard let voice = selectedVoice else {
            errorMessage = "Please select a voice"
            return
        }

        Task {
            isGenerating = true
            errorMessage = nil

            do {
                // Generate and cache audio in SwiftData
                let audioFile = try await providerManager.generateAndCacheAudio(
                    text: textInput,
                    voiceId: voice.id,
                    providerId: providerManager.currentProviderType.rawValue
                )

                // Notify parent that audio was generated
                onAudioGenerated(audioFile)

                // Clear input on success
                textInput = ""
                characterCount = 0

            } catch {
                errorMessage = "Failed: \(error.localizedDescription)"
            }

            isGenerating = false
        }
    }

    private func clearInput() {
        textInput = ""
        characterCount = 0
        errorMessage = nil
    }
}

#Preview {
    let context = try! ModelContext(ModelContainer(for: AudioFile.self, VoiceModel.self))
    let providerManager = VoiceProviderManager(modelContext: context)

    return TextGenerationWidget(
        providerManager: providerManager,
        modelContext: context,
        selectedVoice: nil,
        onAudioGenerated: { _ in }
    )
    .frame(width: 500)
    .padding()
}
