// PairioFeature.swift
// Public exports for the Pairio feature module

@_exported import SwiftUI

// MARK: - Public Views
public typealias MenuBarContentView = MenuBarView

// MARK: - Public Services
public typealias AudioService = AudioDeviceService
public typealias BTService = BluetoothService
public typealias AppState = AppStateService
public typealias LaunchService = LaunchAtLoginService
public typealias ShortcutService = GlobalShortcutService
public typealias Notifications = NotificationService
public typealias Preferences = PreferencesService

// MARK: - Public Models
public typealias Favorite = DeviceFavorite

// MARK: - Public Managers
public typealias PopupManager = ConnectionPopupManager
public typealias AboutManager = AboutWindowManager
public typealias SettingsManager = SettingsWindowManager
public typealias Onboarding = OnboardingManager
