// LaunchAtLoginService.swift
// Service for managing Launch at Login functionality using SMAppService

import Foundation
import ServiceManagement

/// Service for managing Launch at Login preference using SMAppService
@Observable
@MainActor
public final class LaunchAtLoginService {

    /// Whether the app is set to launch at login
    public var isEnabled: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            setLaunchAtLogin(enabled: newValue)
        }
    }

    /// The current status of the launch at login registration
    public var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    /// Error message if registration fails
    public var errorMessage: String?

    public init() {}

    // MARK: - Private

    private func setLaunchAtLogin(enabled: Bool) {
        errorMessage = nil

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
