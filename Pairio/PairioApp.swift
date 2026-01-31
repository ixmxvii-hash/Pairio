// PairioApp.swift
// Entry point for Pairio - AirPods Audio Sharing for Mac

import SwiftUI
import PairioFeature

@main
struct PairioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Onboarding window
        Window("Welcome to Pairio", id: "onboarding") {
            OnboardingView(isOnboardingComplete: Binding(
                get: { OnboardingManager.shared.hasCompletedOnboarding },
                set: { OnboardingManager.shared.hasCompletedOnboarding = $0 }
            ))
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        // Menu bar extra - always available
        MenuBarExtra("Pairio", systemImage: "wave.3.right") {
            MenuBarContentView()
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let hasCompletedOnboarding = OnboardingManager.shared.hasCompletedOnboarding

        if hasCompletedOnboarding {
            // Apply user's dock preference
            let prefs = PreferencesService()
            prefs.applyDockVisibility(prefs.showInDock)

            // Close onboarding window if it opened
            DispatchQueue.main.async {
                NSApplication.shared.windows
                    .filter { $0.title == "Welcome to Pairio" }
                    .forEach { $0.close() }
            }
        } else {
            // Show in dock during onboarding
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
