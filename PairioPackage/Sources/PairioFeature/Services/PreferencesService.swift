// PreferencesService.swift
// Service for persisting user preferences and favorites

import Foundation
import AppKit

/// Service for managing user preferences and device favorites
/// Uses UserDefaults for persistence
@Observable
@MainActor
public final class PreferencesService: Sendable {

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let lastSelectedDeviceUIDs = "lastSelectedDeviceUIDs"
        static let favorites = "favorites"
        static let autoRestoreLastSelection = "autoRestoreLastSelection"
        static let showInDock = "showInDock"
    }

    // MARK: - Properties

    private let defaults: UserDefaults

    /// The last selected device UIDs (for auto-restore on launch)
    public var lastSelectedDeviceUIDs: [String] {
        get { defaults.stringArray(forKey: Keys.lastSelectedDeviceUIDs) ?? [] }
        set { defaults.set(newValue, forKey: Keys.lastSelectedDeviceUIDs) }
    }

    /// Whether to automatically restore the last device selection on launch
    public var autoRestoreLastSelection: Bool {
        get { defaults.bool(forKey: Keys.autoRestoreLastSelection) }
        set { defaults.set(newValue, forKey: Keys.autoRestoreLastSelection) }
    }

    /// Whether to show the app icon in the Dock
    public var showInDock: Bool {
        get { defaults.bool(forKey: Keys.showInDock) }
        set {
            defaults.set(newValue, forKey: Keys.showInDock)
            applyDockVisibility(newValue)
        }
    }

    /// Apply the dock visibility setting
    public func applyDockVisibility(_ show: Bool) {
        if show {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    /// Saved device favorites
    public var favorites: [DeviceFavorite] {
        get { loadFavorites() }
        set { saveFavorites(newValue) }
    }

    // MARK: - Initialization

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Set default for auto-restore if not already set
        if defaults.object(forKey: Keys.autoRestoreLastSelection) == nil {
            defaults.set(true, forKey: Keys.autoRestoreLastSelection)
        }
    }

    // MARK: - Last Selection Management

    /// Save the current device selection for auto-restore
    public func saveLastSelection(deviceUIDs: [String]) {
        lastSelectedDeviceUIDs = deviceUIDs
    }

    /// Clear the saved last selection
    public func clearLastSelection() {
        lastSelectedDeviceUIDs = []
    }

    // MARK: - Favorites Management

    /// Add a new favorite with the given name and device UIDs
    @discardableResult
    public func addFavorite(name: String, deviceUIDs: [String]) -> DeviceFavorite {
        let favorite = DeviceFavorite(name: name, deviceUIDs: deviceUIDs)
        var currentFavorites = favorites
        currentFavorites.append(favorite)
        favorites = currentFavorites
        return favorite
    }

    /// Remove a favorite by its ID
    public func removeFavorite(id: UUID) {
        var currentFavorites = favorites
        currentFavorites.removeAll { $0.id == id }
        favorites = currentFavorites
    }

    /// Update a favorite's name
    public func renameFavorite(id: UUID, newName: String) {
        var currentFavorites = favorites
        if let index = currentFavorites.firstIndex(where: { $0.id == id }) {
            currentFavorites[index] = DeviceFavorite(
                id: currentFavorites[index].id,
                name: newName,
                deviceUIDs: currentFavorites[index].deviceUIDs,
                createdAt: currentFavorites[index].createdAt
            )
            favorites = currentFavorites
        }
    }

    /// Update a favorite's device UIDs
    public func updateFavoriteDevices(id: UUID, deviceUIDs: [String]) {
        var currentFavorites = favorites
        if let index = currentFavorites.firstIndex(where: { $0.id == id }) {
            currentFavorites[index] = DeviceFavorite(
                id: currentFavorites[index].id,
                name: currentFavorites[index].name,
                deviceUIDs: deviceUIDs,
                createdAt: currentFavorites[index].createdAt
            )
            favorites = currentFavorites
        }
    }

    /// Check if a favorite with the given name already exists
    public func favoriteExists(named name: String) -> Bool {
        favorites.contains { $0.name.lowercased() == name.lowercased() }
    }

    /// Get a favorite by name (case-insensitive)
    public func favorite(named name: String) -> DeviceFavorite? {
        favorites.first { $0.name.lowercased() == name.lowercased() }
    }

    // MARK: - Private Helpers

    private func loadFavorites() -> [DeviceFavorite] {
        guard let data = defaults.data(forKey: Keys.favorites) else {
            return []
        }

        do {
            return try JSONDecoder().decode([DeviceFavorite].self, from: data)
        } catch {
            return []
        }
    }

    private func saveFavorites(_ favorites: [DeviceFavorite]) {
        do {
            let data = try JSONEncoder().encode(favorites)
            defaults.set(data, forKey: Keys.favorites)
        } catch {
            // Silently fail - preferences are not critical
        }
    }
}
