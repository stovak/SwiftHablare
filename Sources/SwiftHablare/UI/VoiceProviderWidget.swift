//
//  VoiceProviderWidget.swift
//  SwiftHablare
//
//  Voice provider selection widget for choosing between available TTS providers
//

import SwiftUI
import SwiftData

/// Voice provider widget that displays available voice providers for selection
public struct VoiceProviderWidget: View {
    @ObservedObject var providerManager: VoiceProviderManager

    public init(providerManager: VoiceProviderManager) {
        self.providerManager = providerManager
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("Voice Provider")
                .font(.headline)

            // Provider list
            VStack(spacing: 8) {
                ForEach(VoiceProviderType.allCases, id: \.self) { providerType in
                    ProviderRow(
                        providerType: providerType,
                        isSelected: providerManager.currentProviderType == providerType,
                        isConfigured: isProviderConfigured(providerType)
                    )
                    .onTapGesture {
                        providerManager.switchProvider(to: providerType)
                    }
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

    /// Check if a provider is configured
    private func isProviderConfigured(_ providerType: VoiceProviderType) -> Bool {
        guard let provider = providerManager.getProvider(for: providerType.rawValue) else {
            return false
        }
        return provider.isConfigured()
    }
}

/// Row view for displaying a voice provider in the widget
struct ProviderRow: View {
    let providerType: VoiceProviderType
    let isSelected: Bool
    let isConfigured: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Provider icon
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundStyle(isSelected ? .blue : .secondary)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(isSelected ? Color.blue.opacity(0.15) : Color.gray.opacity(0.1))
                )

            // Provider info
            VStack(alignment: .leading, spacing: 4) {
                Text(providerType.displayName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .medium)

                HStack(spacing: 4) {
                    // Configuration status
                    Image(systemName: isConfigured ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(isConfigured ? .green : .orange)

                    Text(isConfigured ? "Configured" : "Not configured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1.5)
        )
    }

    /// Icon name for the provider
    private var iconName: String {
        switch providerType {
        case .elevenlabs:
            return "waveform.circle.fill"
        case .apple:
            return "speaker.wave.3.fill"
        }
    }
}

// MARK: - Preview
#Preview {
    VStack {
        VoiceProviderWidget(
            providerManager: VoiceProviderManager(
                modelContext: PreviewContainer.previewModelContext
            )
        )
        .frame(width: 400)
    }
    .padding()
}

// Helper for preview
private struct PreviewContainer {
    static var previewModelContext: ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: VoiceModel.self, AudioFile.self,
            configurations: config
        )
        return ModelContext(container)
    }
}
