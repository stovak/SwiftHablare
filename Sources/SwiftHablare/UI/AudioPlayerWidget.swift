//
//  AudioPlayerWidget.swift
//  SwiftHablare
//
//  Main audio player widget with provider selection and visualization
//

import SwiftUI
import SwiftData

/// Main audio player widget with provider selection and spectrogram visualization
public struct AudioPlayerWidget: View {
    @ObservedObject var playerManager: AudioPlayerManager
    @ObservedObject var providerManager: VoiceProviderManager
    @Environment(\.modelContext) private var modelContext

    @State private var selectedAudioFile: AudioFile?

    public init(playerManager: AudioPlayerManager, providerManager: VoiceProviderManager) {
        self.playerManager = playerManager
        self.providerManager = providerManager
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header with provider selection
            HStack {
                Text("Audio Player")
                    .font(.headline)

                Spacer()

                ProviderSelectionView(providerManager: providerManager)
            }

            // Spectrogram visualizer
            SpectrogramVisualizerView(playerManager: playerManager)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .systemGray).opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(nsColor: .systemGray), lineWidth: 1)
                )

            // Playback controls
            VStack(spacing: 12) {
                // Progress bar
                HStack(spacing: 8) {
                    Text(formatTime(playerManager.currentTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(nsColor: .systemGray).opacity(0.2))
                                .frame(height: 6)

                            // Progress
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue)
                                .frame(
                                    width: playerManager.duration > 0
                                        ? geometry.size.width * CGFloat(playerManager.currentTime / playerManager.duration)
                                        : 0,
                                    height: 6
                                )
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let seekTime = Double(value.location.x / geometry.size.width) * playerManager.duration
                                    playerManager.seek(to: seekTime)
                                }
                        )
                    }
                    .frame(height: 6)

                    Text(formatTime(playerManager.duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                // Play/Pause button
                HStack(spacing: 20) {
                    Button {
                        playerManager.seek(to: max(0, playerManager.currentTime - 10))
                    } label: {
                        Image(systemName: "gobackward.10")
                            .font(.title2)
                    }
                    .disabled(playerManager.currentAudioFile == nil)

                    Button {
                        playerManager.togglePlayPause()
                    } label: {
                        Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 44))
                    }
                    .disabled(playerManager.currentAudioFile == nil)

                    Button {
                        playerManager.seek(to: min(playerManager.duration, playerManager.currentTime + 10))
                    } label: {
                        Image(systemName: "goforward.10")
                            .font(.title2)
                    }
                    .disabled(playerManager.currentAudioFile == nil)
                }

                // Current audio info
                if let audioFile = playerManager.currentAudioFile {
                    VStack(spacing: 4) {
                        Text(audioFile.text)
                            .font(.subheadline)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 8) {
                            Text(audioFile.providerId.capitalized)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Text("•")
                                .foregroundStyle(.secondary)

                            Text(audioFile.audioFormat.uppercased())
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            if let sampleRate = audioFile.sampleRate {
                                Text("•")
                                    .foregroundStyle(.secondary)
                                Text("\(sampleRate / 1000)kHz")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        )
    }

    /// Play an audio file from the database
    public func play(_ audioFile: AudioFile) {
        do {
            try playerManager.play(audioFile)
        } catch {
            print("Failed to play audio: \(error)")
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Convenience initializer for creating player widget with model context
public extension AudioPlayerWidget {
    static func create(modelContext: ModelContext) -> AudioPlayerWidget {
        let playerManager = AudioPlayerManager()
        let providerManager = VoiceProviderManager(modelContext: modelContext)

        return AudioPlayerWidget(
            playerManager: playerManager,
            providerManager: providerManager
        )
    }
}
