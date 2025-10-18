//
//  ProviderSelectionView.swift
//  SwiftHablare
//
//  Provider selection dropdown component
//

import SwiftUI

/// Provider selection dropdown view
public struct ProviderSelectionView: View {
    @ObservedObject var providerManager: VoiceProviderManager

    public init(providerManager: VoiceProviderManager) {
        self.providerManager = providerManager
    }

    public var body: some View {
        Menu {
            ForEach(providerManager.getRegisteredProviders()) { providerInfo in
                Button {
                    providerManager.switchProvider(to: providerInfo.id)
                } label: {
                    HStack {
                        Text(providerInfo.displayName)
                        if providerManager.currentProviderId == providerInfo.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 14))
                Text(currentProviderDisplayName)
                    .font(.system(size: 14, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .systemGray).opacity(0.1))
            )
        }
    }

    /// Get the display name of the current provider
    private var currentProviderDisplayName: String {
        providerManager.getCurrentProvider()?.displayName ?? "No Provider"
    }
}
