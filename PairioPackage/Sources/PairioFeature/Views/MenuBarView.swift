// MenuBarView.swift
// Menu bar popover UI for Pairio

import SwiftUI
import CoreAudio
import AppKit

/// Main view displayed in the menu bar popover
@MainActor
public struct MenuBarView: View {

    @State private var audioService = AudioDeviceService()
    @State private var preferencesService = PreferencesService()
    @State private var shortcutService = GlobalShortcutService()
    @State private var availableDevices: [AudioDevice] = []
    @State private var selectedDeviceIDs: Set<AudioDeviceID> = []
    @State private var deviceVolumes: [AudioDeviceID: Float] = [:]
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var previousDeviceIDs: Set<AudioDeviceID> = []

    // Favorites UI state
    @State private var showSaveFavoriteSheet = false
    @State private var newFavoriteName = ""

    private let appState = AppStateService.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()

            if isLoading {
                loadingView
            } else if availableDevices.isEmpty {
                emptyStateView
            } else {
                deviceListView
            }

            Divider()

            footerView
        }
        .frame(width: 320)
        .task {
            await loadDevices()
            setupShortcutService()
            // Request notification permissions on first launch
            await audioService.notificationService.requestPermissions()
        }
        .onDisappear {
            shortcutService.stopMonitoring()
        }
        .sheet(isPresented: $showSaveFavoriteSheet) {
            saveFavoriteSheet
        }
    }

    // MARK: - Computed Properties

    private var selectedDevices: [AudioDevice] {
        availableDevices.filter { selectedDeviceIDs.contains($0.id) }
    }

    private var airPodsDevices: [AudioDevice] {
        availableDevices.filter { $0.isAirPods }
    }

    private var otherDevices: [AudioDevice] {
        availableDevices.filter { !$0.isAirPods }
    }

    private var canSaveAsFavorite: Bool {
        selectedDeviceIDs.count >= 2 && !audioService.isSharingActive
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "airpods")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Pairio")
                .font(.headline)

            Spacer()

            if audioService.isSharingActive {
                sharingBadge
            } else if audioService.sharingInterrupted {
                interruptedBadge
            }
        }
        .padding()
    }

    private var sharingBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
            Text("Sharing")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var interruptedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .foregroundStyle(.orange)
            Text("Restored")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Device List

    private var deviceListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Favorites Section
                if !preferencesService.favorites.isEmpty {
                    Section {
                        ForEach(preferencesService.favorites) { favorite in
                            FavoriteRow(
                                favorite: favorite,
                                isAvailable: isFavoriteAvailable(favorite),
                                onSelect: { loadFavorite(favorite) },
                                onDelete: { deleteFavorite(favorite) }
                            )
                        }
                    } header: {
                        sectionHeader("Favorites", icon: "star.fill")
                    }
                }

                if !airPodsDevices.isEmpty {
                    Section {
                        ForEach(airPodsDevices) { device in
                            DeviceRowWithVolume(
                                device: device,
                                isSelected: selectedDeviceIDs.contains(device.id),
                                isSharingActive: audioService.isSharingActive,
                                volume: Binding(
                                    get: { deviceVolumes[device.id] ?? 1.0 },
                                    set: { newVolume in
                                        deviceVolumes[device.id] = newVolume
                                        try? audioService.setDeviceVolume(device.id, volume: newVolume)
                                    }
                                ),
                                canControlVolume: audioService.canControlVolume(device.id),
                                onToggle: { toggleSelection(for: device) }
                            )
                        }
                    } header: {
                        sectionHeader("AirPods", icon: "airpods")
                    }
                }

                if !otherDevices.isEmpty {
                    Section {
                        ForEach(otherDevices) { device in
                            DeviceRowWithVolume(
                                device: device,
                                isSelected: selectedDeviceIDs.contains(device.id),
                                isSharingActive: audioService.isSharingActive,
                                volume: Binding(
                                    get: { deviceVolumes[device.id] ?? 1.0 },
                                    set: { newVolume in
                                        deviceVolumes[device.id] = newVolume
                                        try? audioService.setDeviceVolume(device.id, volume: newVolume)
                                    }
                                ),
                                canControlVolume: audioService.canControlVolume(device.id),
                                onToggle: { toggleSelection(for: device) }
                            )
                        }
                    } header: {
                        sectionHeader("Other Devices", icon: "speaker.wave.2")
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 300)
    }

    private func sectionHeader(_ title: String, icon: String? = nil) -> some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Discovering devices...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(height: 100)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "airpods")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No Audio Devices Found")
                .font(.headline)

            Text("Connect AirPods or other Bluetooth audio devices to share audio.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Refresh") {
                Task { await loadDevices() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(height: 150)
    }

    // MARK: - Footer

    private var footerView: some View {
        VStack(spacing: 8) {
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            if !audioService.statusMessage.isEmpty {
                Text(audioService.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            // Main action row
            HStack {
                Button {
                    Task { await loadDevices() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(audioService.isSharingActive)
                .help("Refresh devices")

                Spacer()

                // Save as Favorite button
                if canSaveAsFavorite {
                    Button {
                        newFavoriteName = ""
                        showSaveFavoriteSheet = true
                    } label: {
                        Image(systemName: "star")
                    }
                    .buttonStyle(.borderless)
                    .help("Save as Favorite")
                }

                shareButton
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Bottom menu bar
            HStack(spacing: 16) {
                Button {
                    AboutWindowManager.shared.showAboutWindow()
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.borderless)
                .help("About Pairio")

                Button {
                    SettingsWindowManager.shared.showSettingsWindow(
                        notificationService: audioService.notificationService,
                        shortcutDescription: shortcutService.shortcutDescription
                    )
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("Settings")

                Spacer()

                Text(shortcutService.shortcutDescription)
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.borderless)
                .help("Quit Pairio")
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
    }

    private var shareButton: some View {
        Button(action: toggleSharing) {
            HStack(spacing: 4) {
                Image(systemName: audioService.isSharingActive ? "stop.fill" : "play.fill")
                Text(audioService.isSharingActive ? "Stop Sharing" : "Start Sharing")
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(audioService.isSharingActive ? .red : .accentColor)
        .disabled(selectedDeviceIDs.count < 2 && !audioService.isSharingActive)
    }

    // MARK: - Save Favorite Sheet

    private var saveFavoriteSheet: some View {
        VStack(spacing: 16) {
            Text("Save Favorite")
                .font(.headline)

            Text("Save this device combination for quick access")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Name (e.g., Movie Night)", text: $newFavoriteName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    showSaveFavoriteSheet = false
                }
                .buttonStyle(.bordered)

                Button("Save") {
                    saveFavorite()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newFavoriteName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 280)
    }

    // MARK: - Actions

    private func toggleSelection(for device: AudioDevice) {
        guard !audioService.isSharingActive else { return }

        if selectedDeviceIDs.contains(device.id) {
            selectedDeviceIDs.remove(device.id)
        } else {
            selectedDeviceIDs.insert(device.id)
        }

        // Save selection for auto-restore
        saveCurrentSelection()
    }

    private func loadDevices() async {
        isLoading = true
        errorMessage = nil

        do {
            let devices = try audioService.getOutputDevices()
            let newDeviceIDs = Set(devices.map { $0.id })

            // Check for newly connected AirPods
            let newAirPods = devices.filter { device in
                device.isAirPods && !previousDeviceIDs.contains(device.id)
            }

            // Show popup for newly connected AirPods
            for airPod in newAirPods {
                ConnectionPopupManager.shared.showPopup(
                    deviceName: airPod.name,
                    batteryLevel: nil, // We don't have battery info from CoreAudio
                    isConnecting: false
                )
            }

            previousDeviceIDs = newDeviceIDs
            availableDevices = devices

            // Load volumes for all devices
            for device in devices {
                if let volume = audioService.getDeviceVolume(device.id) {
                    deviceVolumes[device.id] = volume
                }
            }

            // Restore last selection if enabled and nothing is selected yet
            if selectedDeviceIDs.isEmpty && preferencesService.autoRestoreLastSelection {
                restoreLastSelection()
            }

            // Clean up any selected devices that no longer exist
            selectedDeviceIDs = selectedDeviceIDs.intersection(newDeviceIDs)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func toggleSharing() {
        if audioService.isSharingActive {
            stopSharing()
        } else {
            startSharing()
        }
    }

    private func startSharing() {
        errorMessage = nil

        guard selectedDevices.count >= 2 else {
            errorMessage = "Select at least 2 devices to share audio"
            return
        }

        do {
            _ = try audioService.startSharing(with: selectedDevices)
            appState.isSharingActive = true
            // Save selection when sharing starts successfully
            saveCurrentSelection()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stopSharing() {
        audioService.stopSharing()
        appState.isSharingActive = false
        // Refresh device list after stopping
        Task { await loadDevices() }
    }

    private func setupShortcutService() {
        shortcutService.onShortcutTriggered = { [self] in
            // Only toggle if we have enough devices selected or sharing is active
            if audioService.isSharingActive || selectedDeviceIDs.count >= 2 {
                toggleSharing()
            }
        }
        shortcutService.startMonitoring()
    }

    // MARK: - Preferences & Favorites

    private func saveCurrentSelection() {
        let selectedUIDs = selectedDevices.map { $0.uid }
        preferencesService.saveLastSelection(deviceUIDs: selectedUIDs)
    }

    private func restoreLastSelection() {
        let savedUIDs = Set(preferencesService.lastSelectedDeviceUIDs)
        guard !savedUIDs.isEmpty else { return }

        // Find devices matching the saved UIDs
        let matchingDevices = availableDevices.filter { savedUIDs.contains($0.uid) }

        // Only restore if we found at least 2 matching devices
        if matchingDevices.count >= 2 {
            selectedDeviceIDs = Set(matchingDevices.map { $0.id })
        }
    }

    private func saveFavorite() {
        let trimmedName = newFavoriteName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let deviceUIDs = selectedDevices.map { $0.uid }
        preferencesService.addFavorite(name: trimmedName, deviceUIDs: deviceUIDs)

        showSaveFavoriteSheet = false
        newFavoriteName = ""
    }

    private func loadFavorite(_ favorite: DeviceFavorite) {
        guard !audioService.isSharingActive else { return }

        let favoriteUIDs = Set(favorite.deviceUIDs)

        // Find devices matching the favorite's UIDs
        let matchingDevices = availableDevices.filter { favoriteUIDs.contains($0.uid) }

        // Update selection
        selectedDeviceIDs = Set(matchingDevices.map { $0.id })

        // Save as last selection
        saveCurrentSelection()
    }

    private func deleteFavorite(_ favorite: DeviceFavorite) {
        preferencesService.removeFavorite(id: favorite.id)
    }

    private func isFavoriteAvailable(_ favorite: DeviceFavorite) -> Bool {
        let favoriteUIDs = Set(favorite.deviceUIDs)
        let availableUIDs = Set(availableDevices.map { $0.uid })

        // A favorite is available if at least 2 of its devices are currently available
        let matchCount = favoriteUIDs.intersection(availableUIDs).count
        return matchCount >= 2
    }
}

// MARK: - Favorite Row

private struct FavoriteRow: View {
    let favorite: DeviceFavorite
    let isAvailable: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.body)
                .foregroundStyle(isAvailable ? .yellow : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(favorite.name)
                    .font(.body)
                    .foregroundStyle(isAvailable ? .primary : .secondary)
                    .lineLimit(1)

                Text("\(favorite.deviceUIDs.count) devices")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isAvailable {
                Button("Load") {
                    onSelect()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text("Unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .confirmationDialog(
                "Delete Favorite?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    onDelete()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \"\(favorite.name)\"?")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.yellow.opacity(isAvailable ? 0.1 : 0.05))
        )
    }
}

// MARK: - Device Row with Volume Control

private struct DeviceRowWithVolume: View {
    let device: AudioDevice
    let isSelected: Bool
    let isSharingActive: Bool
    @Binding var volume: Float
    let canControlVolume: Bool
    let onToggle: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                Image(systemName: DeviceUtils.deviceIcon(for: device.name))
                    .font(.title3)
                    .foregroundStyle(device.isAirPods ? .blue : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if device.isConnected {
                        HStack(spacing: 4) {
                            Text("Connected")
                                .font(.caption2)
                                .foregroundStyle(.green)

                            if isSharingActive && isSelected {
                                Text("• Sharing")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }

                Spacer()

                // Volume expand button - always active for selected devices
                if canControlVolume && isSelected {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "speaker.wave.2.fill" : "speaker.wave.2")
                            .font(.body)
                            .foregroundStyle(isExpanded ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }

                // Selection toggle - disabled during sharing
                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .disabled(isSharingActive)
                .opacity(isSharingActive ? 0.5 : 1.0)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())

            // Volume slider (expanded)
            if isExpanded && isSelected && canControlVolume {
                VStack(spacing: 8) {
                    Divider()
                        .padding(.horizontal, 12)

                    HStack(spacing: 12) {
                        Image(systemName: "speaker.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Slider(value: $volume, in: 0...1)
                            .tint(.accentColor)

                        Image(systemName: "speaker.wave.3.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(Int(volume * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
    }
}

// MARK: - Preview

#Preview {
    MenuBarView()
        .frame(width: 320, height: 450)
}
