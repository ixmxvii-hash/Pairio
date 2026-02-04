// PaywallView.swift
// Trial ended upgrade view

import SwiftUI

struct PaywallView: View {
    @State private var paywallService = PaywallService.shared

    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)

            Text("Unlock Pairio Pro")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Your 3-day trial has ended. Upgrade to keep sharing audio to multiple devices.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 6) {
                Label("Multi-device audio sharing", systemImage: "checkmark.circle")
                Label("Favorites and quick switching", systemImage: "checkmark.circle")
                Label("Auto share when devices connect", systemImage: "checkmark.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Not Now") {
                    onDismiss()
                }
                .buttonStyle(.bordered)

                Button("Unlock Pro") {
                    paywallService.isUnlocked = true
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}

#Preview {
    PaywallView(onDismiss: {})
}
