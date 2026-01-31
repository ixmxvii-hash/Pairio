// AboutView.swift
// About window displaying app information and credits

import SwiftUI

/// View displaying app name, version, and credits
@MainActor
public struct AboutView: View {

    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            // App Icon
            Image(systemName: "airpods")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            // App Name
            Text("Pairio")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Version
            Text("Version \(appVersion)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.horizontal, 40)

            // Description
            Text("Share audio to multiple AirPods and Bluetooth devices simultaneously on your Mac.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Divider()
                .padding(.horizontal, 40)

            // Credits
            VStack(spacing: 8) {
                Text("Credits")
                    .font(.headline)

                Text("Developed by Logan Allen")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Link("GitHub", destination: URL(string: "https://github.com/ixmxvii-hash/Pairio")!)
                    .font(.caption)
            }

            Spacer()

            // Copyright
            Text("Copyright 2025 Logan Allen. All rights reserved.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(30)
        .frame(width: 340, height: 420)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - About Window Manager

/// Manager for showing the About window
@MainActor
@Observable
public final class AboutWindowManager {
    public static let shared = AboutWindowManager()

    private var aboutWindow: NSWindow?

    private init() {}

    /// Show the About window
    public func showAboutWindow() {
        // If window exists and is visible, bring to front
        if let window = aboutWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create new window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "About Pairio"
        window.center()
        window.contentView = NSHostingView(rootView: AboutView())
        window.isReleasedWhenClosed = false

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        aboutWindow = window
    }
}

// MARK: - Preview

#Preview {
    AboutView()
}
