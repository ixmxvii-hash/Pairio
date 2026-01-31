// SettingsView.swift
// Settings panel for Pairio preferences

import SwiftUI
import AppKit

/// Settings view displayed in a separate window
struct SettingsView: View {
    @State private var launchAtLoginService = LaunchAtLoginService()
    @State private var preferencesService = PreferencesService()
    let notificationService: NotificationService
    let shortcutDescription: String

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { launchAtLoginService.isEnabled },
                    set: { launchAtLoginService.isEnabled = $0 }
                )) {
                    Label("Launch at Login", systemImage: "arrow.right.circle")
                }

                Toggle(isOn: Binding(
                    get: { preferencesService.showInDock },
                    set: { preferencesService.showInDock = $0 }
                )) {
                    Label("Show in Dock", systemImage: "dock.rectangle")
                }

                Toggle(isOn: Binding(
                    get: { preferencesService.autoRestoreLastSelection },
                    set: { preferencesService.autoRestoreLastSelection = $0 }
                )) {
                    Label("Remember Last Selection", systemImage: "arrow.clockwise")
                }

                Toggle(isOn: Binding(
                    get: { notificationService.notificationsEnabled },
                    set: { notificationService.notificationsEnabled = $0 }
                )) {
                    Label("Notifications", systemImage: "bell")
                }
            } header: {
                Text("General")
            }

            Section {
                HStack {
                    Label("Toggle Sharing", systemImage: "keyboard")
                    Spacer()
                    Text(shortcutDescription)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.secondary.opacity(0.2))
                        )
                }
            } header: {
                Text("Keyboard Shortcut")
            }

            Section {
                if let error = launchAtLoginService.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 320, height: 260)
    }
}

/// Manager for showing the settings window
@MainActor
public final class SettingsWindowManager {
    public static let shared = SettingsWindowManager()

    private var settingsWindow: NSWindow?

    private init() {}

    public func showSettingsWindow(notificationService: NotificationService, shortcutDescription: String) {
        if let existingWindow = settingsWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(
            notificationService: notificationService,
            shortcutDescription: shortcutDescription
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Pairio Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }
}
