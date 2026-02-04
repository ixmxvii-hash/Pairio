// AudioDeviceService.swift
// CoreAudio service for managing multi-output devices

import Foundation
import CoreAudio
import AudioToolbox

/// Errors that can occur during audio device operations
public enum AudioDeviceError: Error, LocalizedError, Sendable {
    case deviceNotFound
    case aggregateCreationFailed
    case propertyQueryFailed(OSStatus)
    case invalidDevice
    case paywallRequired

    public var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "Audio device not found"
        case .aggregateCreationFailed:
            return "Failed to create aggregate device"
        case .propertyQueryFailed(let status):
            return "Property query failed with status: \(status)"
        case .invalidDevice:
            return "Invalid audio device"
        case .paywallRequired:
            return "Your 3-day trial has ended. Upgrade to continue sharing."
        }
    }
}

/// Service for managing audio devices and creating multi-output aggregate devices
/// Automatically restores original output when devices disconnect
@Observable
@MainActor
public final class AudioDeviceService {

    private static let aggregateDeviceName = "Pairio Shared Audio"
    private static let aggregateDeviceUID = "com.loganallen.pairio.aggregate"

    // UserDefaults key for auto-share preference
    private static let autoShareEnabledKey = "com.loganallen.pairio.autoShareEnabled"

    // State tracking for automatic restoration
    private var originalDefaultDeviceID: AudioDeviceID?
    private var originalDefaultSystemDeviceID: AudioDeviceID?
    private var currentAggregateDeviceID: AudioDeviceID?
    private var activeSubDeviceUIDs: Set<String> = []
    private var activeSubDeviceNames: [String: String] = [:] // UID -> Name mapping for notifications
    private var pausedSharedDeviceUIDs: Set<String> = []
    private var pausedSharedDeviceNames: [String: String] = [:]
    private var lastSharingStartedManually: Bool = false
    private var deviceChangeListener: AudioDeviceChangeListener?

    // Track previously seen AirPods for auto-share detection
    private var previouslyConnectedAirPodsUIDs: Set<String> = []

    // Debouncing for device change events
    private var deviceChangeDebounceTask: Task<Void, Never>?

    // Volume change listeners
    private var aggregateVolumeListener: AudioVolumeListener?
    private var subDeviceVolumeListeners: [AudioDeviceID: AudioVolumeListener] = [:]
    private var isUpdatingVolumes = false // Prevent circular updates


    /// Notification service for system notifications
    public let notificationService: NotificationService

    /// Published state for UI binding
    public var isSharingActive: Bool = false
    public var sharingInterrupted: Bool = false
    public var statusMessage: String = ""

    /// Callback when device volumes change (for UI updates)
    public var onDeviceVolumeChanged: (@MainActor (AudioDeviceID, Float) -> Void)?

    /// When enabled, automatically starts sharing when 2+ AirPods are connected
    public var autoShareEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoShareEnabled, forKey: Self.autoShareEnabledKey)
            if autoShareEnabled {
                startAutoShareListener()
                if !isSharingActive {
                    checkAndAutoStartSharing()
                }
            }
        }
    }

    public init(notificationService: NotificationService = NotificationService()) {
        self.notificationService = notificationService
        self.autoShareEnabled = UserDefaults.standard.bool(forKey: Self.autoShareEnabledKey)

        // Clean up any stale aggregate device left from a prior session
        try? destroyExistingAggregateDevice()

        // Initialize previously connected AirPods to avoid auto-sharing on app launch
        // Only auto-share when a NEW device connects while the app is running
        initializePreviouslyConnectedAirPods()

        // Start listening for device changes if auto-share is enabled
        if autoShareEnabled {
            startAutoShareListener()
        }
    }

    /// Initialize the set of currently connected AirPods to prevent auto-share on app launch
    private func initializePreviouslyConnectedAirPods() {
        if let devices = try? getOutputDevices() {
            previouslyConnectedAirPodsUIDs = Set(devices.filter { $0.isAirPods }.map { $0.uid })
        }
    }

    /// Start listening for device changes for auto-share functionality
    private func startAutoShareListener() {
        guard deviceChangeListener == nil else { return }

        deviceChangeListener = AudioDeviceChangeListener { [weak self] in
            Task { @MainActor in
                self?.handleDeviceChange()
            }
        }
        deviceChangeListener?.startListening()
    }

    // MARK: - Device Discovery

    /// Get all available output devices (excludes our own aggregate device)
    public func getOutputDevices() throws -> [AudioDevice] {
        try getOutputDevices(includeAggregate: false)
    }

    private func getOutputDevices(includeAggregate: Bool) throws -> [AudioDevice] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else {
            throw AudioDeviceError.propertyQueryFailed(status)
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )

        guard status == noErr else {
            throw AudioDeviceError.propertyQueryFailed(status)
        }

        return deviceIDs.compactMap { deviceID -> AudioDevice? in
            let name = getDeviceName(deviceID: deviceID) ?? "Unknown Device"
            let uid = getDeviceUID(deviceID: deviceID) ?? UUID().uuidString

            // Skip our own aggregate device
            if !includeAggregate && uid == Self.aggregateDeviceUID {
                return nil
            }

            // Check if device has output capabilities
            let isAirPlay = isAirPlayDevice(deviceID: deviceID)
            let hasOutputs = hasOutputStreams(deviceID: deviceID)

            // Include device if it has outputs OR is AirPlay (AirPlay devices might not show streams immediately)
            guard hasOutputs || isAirPlay else { return nil }

            let isAirPods = name.lowercased().contains("airpods")

            return AudioDevice(
                id: deviceID,
                name: name,
                uid: uid,
                isAirPods: isAirPods,
                isConnected: true
            )
        }
    }

    // MARK: - Sharing Control

    /// Start sharing audio to multiple devices
    public func startSharing(with devices: [AudioDevice], isManual: Bool = true) throws -> AggregateDevice {
        guard PaywallService.shared.isAccessAllowed else {
            throw AudioDeviceError.paywallRequired
        }

        guard devices.count >= 2 else {
            throw AudioDeviceError.invalidDevice
        }

        lastSharingStartedManually = isManual
        pausedSharedDeviceUIDs = []
        pausedSharedDeviceNames = [:]

        // Store original output before we change anything
        originalDefaultDeviceID = try getDefaultOutputDevice()
        originalDefaultSystemDeviceID = try? getDefaultSystemOutputDevice()
        activeSubDeviceUIDs = Set(devices.map { $0.uid })

        // Store device names for notifications when they disconnect
        activeSubDeviceNames = Dictionary(uniqueKeysWithValues: devices.map { ($0.uid, $0.name) })

        // Align devices to a common sample rate when possible
        let preferredSampleRate = chooseCommonSampleRate(for: devices)
        if let preferredSampleRate = preferredSampleRate {
            for device in devices {
                try? setNominalSampleRate(device.id, rate: preferredSampleRate)
            }
        }

        // Clean up any existing Pairio aggregate device
        try? destroyExistingAggregateDevice()

        // Create the new aggregate device
        let aggregate = try createAggregateDevice(from: devices)
        currentAggregateDeviceID = aggregate.id

        if let preferredSampleRate = preferredSampleRate {
            try? setNominalSampleRate(aggregate.id, rate: preferredSampleRate)
        }

        // Set as default output
        try setDefaultOutputDevices(aggregate.id)

        // Start listening for device changes
        startDeviceChangeListener()

        // Start listening for volume changes
        startVolumeListeners(aggregateID: aggregate.id, subDeviceIDs: devices.map { $0.id })

        isSharingActive = true
        sharingInterrupted = false
        statusMessage = "Sharing to \(devices.count) devices"

        // Send notification
        notificationService.notifySharingStarted(deviceCount: devices.count)

        return aggregate
    }

    /// Stop sharing and restore original output
    /// - Parameter disconnectedDeviceName: Optional name of the device that triggered the stop (for notifications)
    /// - Parameter shouldAutoResume: Whether to attempt auto-resume when devices reconnect
    public func stopSharing(disconnectedDeviceName: String? = nil, shouldAutoResume: Bool = false) {
        guard isSharingActive || currentAggregateDeviceID != nil else { return }

        let wasSharing = isSharingActive

        if shouldAutoResume && lastSharingStartedManually {
            pausedSharedDeviceUIDs = activeSubDeviceUIDs
            pausedSharedDeviceNames = activeSubDeviceNames
        } else {
            pausedSharedDeviceUIDs = []
            pausedSharedDeviceNames = [:]
        }

        // Stop listening for changes only if auto-share and auto-resume are disabled
        if !autoShareEnabled && pausedSharedDeviceUIDs.isEmpty {
            deviceChangeListener?.stopListening()
            deviceChangeListener = nil
        }

        // Stop volume listeners
        stopVolumeListeners()

        // Restore original output device
        if let originalID = originalDefaultDeviceID {
            // Verify the original device still exists before restoring
            if deviceExists(deviceID: originalID) {
                try? setDefaultOutputDevice(originalID)
            } else {
                // Original device gone, try to find a reasonable fallback
                restoreToFallbackDevice()
            }
        }
        if let originalSystemID = originalDefaultSystemDeviceID, deviceExists(deviceID: originalSystemID) {
            try? setDefaultSystemOutputDevice(originalSystemID)
        }

        // Destroy the aggregate device
        if let aggregateID = currentAggregateDeviceID {
            _ = AudioHardwareDestroyAggregateDevice(aggregateID)
        }

        // Reset state
        originalDefaultDeviceID = nil
        originalDefaultSystemDeviceID = nil
        currentAggregateDeviceID = nil
        activeSubDeviceUIDs = []
        activeSubDeviceNames = [:]
        isSharingActive = false
        sharingInterrupted = false
        statusMessage = ""

        // Re-initialize previously connected AirPods so auto-share can trigger again
        // when a new device connects after manually stopping
        if pausedSharedDeviceUIDs.isEmpty {
            initializePreviouslyConnectedAirPods()
        }

        // Send appropriate notification
        if wasSharing {
            if let deviceName = disconnectedDeviceName {
                notificationService.notifyDeviceDisconnected(deviceName: deviceName)
            } else {
                notificationService.notifySharingStopped()
            }
        }
    }

    // MARK: - Device Change Handling

    private func startDeviceChangeListener() {
        deviceChangeListener = AudioDeviceChangeListener { [weak self] in
            Task { @MainActor in
                self?.handleDeviceChange()
            }
        }
        deviceChangeListener?.startListening()
    }

    private func handleDeviceChange() {
        // Cancel any pending device change handling
        deviceChangeDebounceTask?.cancel()

        // Debounce device changes to avoid querying devices in transitional states
        deviceChangeDebounceTask = Task { @MainActor in
            // Wait for the audio system to stabilize
            try? await Task.sleep(for: .milliseconds(300))

            guard !Task.isCancelled else { return }

            await performDeviceChangeCheck()
        }
    }

    private func performDeviceChangeCheck() async {
        // Try to auto-resume a paused manual session first
        if !isSharingActive {
            if attemptAutoResumeIfPossible() {
                return
            }
            if autoShareEnabled {
                checkAndAutoStartSharing()
            }
            return
        }

        guard isSharingActive else { return }

        // Check if any of our sub-devices disappeared
        let currentDeviceUIDs = Set((try? getOutputDevices())?.map { $0.uid } ?? [])
        let missingDevices = activeSubDeviceUIDs.subtracting(currentDeviceUIDs)

        if !missingDevices.isEmpty {
            // Find the name of the first disconnected device for the notification
            let disconnectedDeviceName = missingDevices.compactMap { activeSubDeviceNames[$0] }.first

            // A device we were sharing to has disconnected
            sharingInterrupted = true
            statusMessage = "Device disconnected - restoring audio"

            // Automatically stop sharing and restore, keep resume state for manual sessions
            stopSharing(disconnectedDeviceName: disconnectedDeviceName, shouldAutoResume: true)
        }
    }

    private func attemptAutoResumeIfPossible() -> Bool {
        guard !pausedSharedDeviceUIDs.isEmpty else { return false }

        do {
            let devices = try getOutputDevices()
            let resumeDevices = devices.filter { pausedSharedDeviceUIDs.contains($0.uid) }

            guard resumeDevices.count == pausedSharedDeviceUIDs.count else { return false }

            statusMessage = "Resuming share..."
            _ = try startSharing(with: resumeDevices, isManual: true)
            return true
        } catch {
            statusMessage = "Auto-resume failed: \(error.localizedDescription)"
            return false
        }
    }

    /// Checks if auto-share conditions are met and starts sharing automatically
    private func checkAndAutoStartSharing() {
        guard autoShareEnabled, !isSharingActive else { return }

        do {
            let devices = try getOutputDevices(includeAggregate: true)
            let connectedAirPods = devices.filter { $0.isAirPods }
            let currentAirPodsUIDs = Set(connectedAirPods.map { $0.uid })

            // Check if a new AirPods has connected (not seen before in this session)
            let newlyConnected = currentAirPodsUIDs.subtracting(previouslyConnectedAirPodsUIDs)

            // Notify about newly connected devices
            for uid in newlyConnected {
                if let device = connectedAirPods.first(where: { $0.uid == uid }) {
                    notificationService.notifyNewDeviceConnected(deviceName: device.name)
                }
            }

            // Update tracking
            previouslyConnectedAirPodsUIDs = currentAirPodsUIDs

            // Only auto-start if there are 2+ AirPods AND a new one just connected
            guard connectedAirPods.count >= 2, !newlyConnected.isEmpty else { return }

            // Start sharing with all connected AirPods
            statusMessage = "Auto-starting share with \(connectedAirPods.count) AirPods"
            _ = try startSharing(with: connectedAirPods, isManual: false)
        } catch {
            statusMessage = "Auto-share failed: \(error.localizedDescription)"
        }
    }

    private func deviceExists(deviceID: AudioDeviceID) -> Bool {
        getDeviceName(deviceID: deviceID) != nil
    }

    private func restoreToFallbackDevice() {
        // Try to find the built-in speakers or any available output
        guard let devices = try? getOutputDevices() else { return }

        // Prefer built-in output
        let fallback = devices.first { device in
            let name = device.name.lowercased()
            return name.contains("built-in") || name.contains("macbook") || name.contains("speaker")
        } ?? devices.first

        if let fallback = fallback {
            try? setDefaultOutputDevices(fallback.id)
        }
    }

    // MARK: - Aggregate Device Management

    private func createAggregateDevice(from devices: [AudioDevice]) throws -> AggregateDevice {
        // Create sub-device list with drift compensation enabled for all non-master devices
        // The first device is the master (clock source), others get drift compensation
        let subDevices: [[String: Any]] = devices.enumerated().map { index, device in
            var subDevice: [String: Any] = [
                kAudioSubDeviceUIDKey as String: device.uid
            ]

            // Enable drift compensation for non-master devices (index > 0)
            // This helps keep audio in sync when devices have slightly different clock rates
            if index > 0 {
                subDevice[kAudioSubDeviceDriftCompensationKey as String] = true
            }

            return subDevice
        }

        // Use the first device as the clock source (master clock)
        // All other devices will drift-compensate relative to this clock
        let clockSourceUID = devices[0].uid

        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey as String: Self.aggregateDeviceName,
            kAudioAggregateDeviceUIDKey as String: Self.aggregateDeviceUID,
            kAudioAggregateDeviceSubDeviceListKey as String: subDevices,
            kAudioAggregateDeviceMainSubDeviceKey as String: clockSourceUID,
            kAudioAggregateDeviceClockDeviceKey as String: clockSourceUID,
            kAudioAggregateDeviceIsPrivateKey as String: false,
            kAudioAggregateDeviceIsStackedKey as String: true
        ]

        var aggregateDeviceID: AudioDeviceID = 0
        let status = AudioHardwareCreateAggregateDevice(
            description as CFDictionary,
            &aggregateDeviceID
        )

        guard status == noErr else {
            throw AudioDeviceError.aggregateCreationFailed
        }

        return AggregateDevice(
            id: aggregateDeviceID,
            name: Self.aggregateDeviceName,
            subDevices: devices
        )
    }

    private func destroyExistingAggregateDevice() throws {
        let devices = try getOutputDevices()
        for device in devices where device.uid == Self.aggregateDeviceUID {
            let status = AudioHardwareDestroyAggregateDevice(device.id)
            if status != noErr {
                throw AudioDeviceError.propertyQueryFailed(status)
            }
        }
    }

    /// Set the default output device
    public func setDefaultOutputDevice(_ deviceID: AudioDeviceID) throws {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var mutableDeviceID = deviceID
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &mutableDeviceID
        )

        guard status == noErr else {
            throw AudioDeviceError.propertyQueryFailed(status)
        }
    }

    /// Set the default system output device (system sounds)
    public func setDefaultSystemOutputDevice(_ deviceID: AudioDeviceID) throws {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var mutableDeviceID = deviceID
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &mutableDeviceID
        )

        guard status == noErr else {
            throw AudioDeviceError.propertyQueryFailed(status)
        }
    }

    /// Set both default output and system output devices
    public func setDefaultOutputDevices(_ deviceID: AudioDeviceID) throws {
        try setDefaultOutputDevice(deviceID)
        try setDefaultSystemOutputDevice(deviceID)
    }

    /// Get the current default output device
    public func getDefaultOutputDevice() throws -> AudioDeviceID {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )

        guard status == noErr else {
            throw AudioDeviceError.propertyQueryFailed(status)
        }

        return deviceID
    }

    /// Get the current default system output device
    public func getDefaultSystemOutputDevice() throws -> AudioDeviceID {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )

        guard status == noErr else {
            throw AudioDeviceError.propertyQueryFailed(status)
        }

        return deviceID
    }

    // MARK: - Volume Control

    /// Get the volume of a device (0.0 to 1.0)
    public func getDeviceVolume(_ deviceID: AudioDeviceID) -> Float? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        if AudioObjectHasProperty(deviceID, &propertyAddress) {
            var volume: Float32 = 0
            var dataSize = UInt32(MemoryLayout<Float32>.size)

            let status = AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &dataSize,
                &volume
            )

            return status == noErr ? volume : nil
        }

        if let virtualVolume = getVirtualMasterVolume(deviceID) {
            return virtualVolume
        }

        // Try channel 1
        propertyAddress.mElement = 1
        guard AudioObjectHasProperty(deviceID, &propertyAddress) else { return nil }

        var volume: Float32 = 0
        var dataSize = UInt32(MemoryLayout<Float32>.size)

        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &volume
        )

        return status == noErr ? volume : nil
    }

    /// Set the volume of a device (0.0 to 1.0)
    public func setDeviceVolume(_ deviceID: AudioDeviceID, volume: Float) throws {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let clampedVolume = max(0, min(1, volume))

        if AudioObjectHasProperty(deviceID, &propertyAddress) {
            var mutableVolume = clampedVolume
            let status = AudioObjectSetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                UInt32(MemoryLayout<Float32>.size),
                &mutableVolume
            )

            if status != noErr {
                throw AudioDeviceError.propertyQueryFailed(status)
            }
            return
        }

        if hasVirtualMasterVolume(deviceID) {
            try setVirtualMasterVolume(deviceID, volume: clampedVolume)
            return
        }

        // Try setting both channels
        propertyAddress.mElement = 1
        try setChannelVolume(deviceID, channel: 1, volume: clampedVolume)
        try setChannelVolume(deviceID, channel: 2, volume: clampedVolume)
    }

    private func setChannelVolume(_ deviceID: AudioDeviceID, channel: UInt32, volume: Float) throws {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: channel
        )

        guard AudioObjectHasProperty(deviceID, &propertyAddress) else { return }

        var mutableVolume = max(0, min(1, volume))
        let status = AudioObjectSetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            UInt32(MemoryLayout<Float32>.size),
            &mutableVolume
        )

        if status != noErr {
            throw AudioDeviceError.propertyQueryFailed(status)
        }
    }

    /// Check if device volume can be controlled
    public func canControlVolume(_ deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        if AudioObjectHasProperty(deviceID, &propertyAddress) {
            return true
        }

        if hasVirtualMasterVolume(deviceID) {
            return true
        }

        // Check channel 1
        propertyAddress.mElement = 1
        return AudioObjectHasProperty(deviceID, &propertyAddress)
    }

    /// Adjust volume for all active sub-devices by a delta (e.g. keyboard volume keys)
    public func adjustActiveDeviceVolumes(step: Float) {
        guard isSharingActive, !activeSubDeviceUIDs.isEmpty else { return }

        isUpdatingVolumes = true
        defer { isUpdatingVolumes = false }

        // Get all active sub-devices
        let devices = (try? getOutputDevices()) ?? []
        let activeDevices = devices.filter { activeSubDeviceUIDs.contains($0.uid) }

        // Adjust volume for each sub-device individually
        // This ensures keyboard volume keys work even if aggregate device doesn't support volume
        for device in activeDevices where canControlVolume(device.id) {
            let currentVolume = getDeviceVolume(device.id) ?? 1.0
            let newVolume = max(0, min(1, currentVolume + step))
            try? setDeviceVolume(device.id, volume: newVolume)

            // Notify UI of the change
            onDeviceVolumeChanged?(device.id, newVolume)
        }
    }

    // MARK: - Volume Listeners

    /// Start listening to volume changes on aggregate and sub-devices
    private func startVolumeListeners(aggregateID: AudioDeviceID, subDeviceIDs: [AudioDeviceID]) {
        // Stop any existing listeners first
        stopVolumeListeners()

        // Listen to aggregate device volume changes (for Mac keyboard volume keys)
        aggregateVolumeListener = AudioVolumeListener(deviceID: aggregateID) { [weak self] deviceID, newVolume in
            Task { @MainActor in
                self?.handleAggregateVolumeChange(deviceID: deviceID, newVolume: newVolume)
            }
        }
        aggregateVolumeListener?.startListening()

        // Listen to each sub-device volume changes (for AirPods digital crown)
        for subDeviceID in subDeviceIDs {
            let listener = AudioVolumeListener(deviceID: subDeviceID) { [weak self] deviceID, newVolume in
                Task { @MainActor in
                    self?.handleSubDeviceVolumeChange(deviceID: deviceID, newVolume: newVolume)
                }
            }
            listener.startListening()
            subDeviceVolumeListeners[subDeviceID] = listener
        }
    }

    /// Stop all volume listeners
    private func stopVolumeListeners() {
        aggregateVolumeListener?.stopListening()
        aggregateVolumeListener = nil

        for listener in subDeviceVolumeListeners.values {
            listener.stopListening()
        }
        subDeviceVolumeListeners.removeAll()
    }

    /// Handle volume changes on the aggregate device (Mac keyboard volume keys)
    private func handleAggregateVolumeChange(deviceID: AudioDeviceID, newVolume: Float) {
        guard !isUpdatingVolumes else { return }
        // Mac volume keys control the aggregate device
        // CoreAudio automatically propagates this to sub-devices

        // Notify UI to refresh all sub-device volumes
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let devices = (try? self.getOutputDevices()) ?? []
            let activeDevices = devices.filter { self.activeSubDeviceUIDs.contains($0.uid) }

            for device in activeDevices {
                if let volume = self.getDeviceVolume(device.id) {
                    self.onDeviceVolumeChanged?(device.id, volume)
                }
            }
        }
    }

    /// Handle volume changes on individual sub-devices (AirPods digital crown)
    private func handleSubDeviceVolumeChange(deviceID: AudioDeviceID, newVolume: Float) {
        guard !isUpdatingVolumes else { return }

        // When a user changes volume on an individual AirPod (e.g., digital crown),
        // we want that change to ONLY affect that specific device, not the others
        // Notify UI to update just this device's volume
        onDeviceVolumeChanged?(deviceID, newVolume)
    }

    // MARK: - Private Helpers

    private func chooseCommonSampleRate(for devices: [AudioDevice]) -> Double? {
        let preferredRates: [Double] = [48_000, 44_100, 32_000, 16_000]

        for rate in preferredRates {
            if devices.allSatisfy({ deviceSupportsSampleRate(deviceID: $0.id, rate: rate) }) {
                return rate
            }
        }

        return nil
    }

    private func deviceSupportsSampleRate(deviceID: AudioDeviceID, rate: Double) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyAvailableNominalSampleRates,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectHasProperty(deviceID, &propertyAddress) else {
            return false
        }

        var dataSize: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard sizeStatus == noErr else { return false }

        let rangeCount = Int(dataSize) / MemoryLayout<AudioValueRange>.size
        var ranges = [AudioValueRange](repeating: AudioValueRange(mMinimum: 0, mMaximum: 0), count: rangeCount)

        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &ranges
        )

        guard status == noErr else { return false }

        return ranges.contains { rate >= $0.mMinimum && rate <= $0.mMaximum }
    }

    private func setNominalSampleRate(_ deviceID: AudioDeviceID, rate: Double) throws {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectHasProperty(deviceID, &propertyAddress) else { return }

        var mutableRate = rate
        let status = AudioObjectSetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            UInt32(MemoryLayout<Double>.size),
            &mutableRate
        )

        guard status == noErr else {
            throw AudioDeviceError.propertyQueryFailed(status)
        }
    }

    private func isAirPlayDevice(deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectHasProperty(deviceID, &propertyAddress) else { return false }

        var transportType: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &transportType
        )

        return status == noErr && transportType == kAudioDeviceTransportTypeAirPlay
    }

    private func hasVirtualMasterVolume(_ deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        return AudioObjectHasProperty(deviceID, &propertyAddress)
    }

    private func getVirtualMasterVolume(_ deviceID: AudioDeviceID) -> Float? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectHasProperty(deviceID, &propertyAddress) else { return nil }

        var volume: Float32 = 0
        var dataSize = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &volume
        )

        return status == noErr ? volume : nil
    }

    private func setVirtualMasterVolume(_ deviceID: AudioDeviceID, volume: Float) throws {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectHasProperty(deviceID, &propertyAddress) else { return }

        var mutableVolume = max(0, min(1, volume))
        let status = AudioObjectSetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            UInt32(MemoryLayout<Float32>.size),
            &mutableVolume
        )

        guard status == noErr else {
            throw AudioDeviceError.propertyQueryFailed(status)
        }
    }

    private func hasOutputStreams(deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        // First check if the property exists
        guard AudioObjectHasProperty(deviceID, &propertyAddress) else {
            return false
        }

        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        return status == noErr && dataSize > 0
    }

    private func getDeviceName(deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        // Check if the property exists before querying
        guard AudioObjectHasProperty(deviceID, &propertyAddress) else {
            return nil
        }

        var name: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)

        let status = withUnsafeMutablePointer(to: &name) { namePtr in
            AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &dataSize,
                namePtr
            )
        }

        guard status == noErr, let unmanagedName = name else {
            return nil
        }

        return unmanagedName.takeRetainedValue() as String
    }

    private func getDeviceUID(deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        // Check if the property exists before querying
        guard AudioObjectHasProperty(deviceID, &propertyAddress) else {
            return nil
        }

        var uid: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)

        let status = withUnsafeMutablePointer(to: &uid) { uidPtr in
            AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &dataSize,
                uidPtr
            )
        }

        guard status == noErr, let unmanagedUID = uid else {
            return nil
        }

        return unmanagedUID.takeRetainedValue() as String
    }
}

// MARK: - Audio Device Change Listener

/// Listens for CoreAudio device configuration changes
private final class AudioDeviceChangeListener: @unchecked Sendable {
    private let onChange: @Sendable () -> Void
    private var isListening = false

    init(onChange: @escaping @Sendable () -> Void) {
        self.onChange = onChange
    }

    deinit {
        stopListening()
    }

    func startListening() {
        guard !isListening else { return }

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main,
            listenerBlock
        )

        isListening = status == noErr
    }

    func stopListening() {
        guard isListening else { return }

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main,
            listenerBlock
        )

        isListening = false
    }

    private lazy var listenerBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        self?.onChange()
    }
}

// MARK: - Audio Volume Listener

/// Listens for volume changes on a specific audio device
private final class AudioVolumeListener: @unchecked Sendable {
    private let deviceID: AudioDeviceID
    private let onVolumeChange: @Sendable (AudioDeviceID, Float) -> Void
    private var isListening = false

    init(deviceID: AudioDeviceID, onVolumeChange: @escaping @Sendable (AudioDeviceID, Float) -> Void) {
        self.deviceID = deviceID
        self.onVolumeChange = onVolumeChange
    }

    deinit {
        stopListening()
    }

    func startListening() {
        guard !isListening else { return }

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        // Try listening to main volume
        var status = AudioObjectAddPropertyListenerBlock(
            deviceID,
            &propertyAddress,
            DispatchQueue.main,
            listenerBlock
        )

        if status != noErr {
            // If main volume doesn't exist, try virtual master volume
            propertyAddress.mSelector = kAudioHardwareServiceDeviceProperty_VirtualMainVolume
            status = AudioObjectAddPropertyListenerBlock(
                deviceID,
                &propertyAddress,
                DispatchQueue.main,
                listenerBlock
            )
        }

        if status != noErr {
            // Try channel 1 as fallback
            propertyAddress.mSelector = kAudioDevicePropertyVolumeScalar
            propertyAddress.mElement = 1
            status = AudioObjectAddPropertyListenerBlock(
                deviceID,
                &propertyAddress,
                DispatchQueue.main,
                listenerBlock
            )
        }

        isListening = status == noErr
    }

    func stopListening() {
        guard isListening else { return }

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        // Try removing from main volume
        AudioObjectRemovePropertyListenerBlock(
            deviceID,
            &propertyAddress,
            DispatchQueue.main,
            listenerBlock
        )

        // Try removing from virtual master volume
        propertyAddress.mSelector = kAudioHardwareServiceDeviceProperty_VirtualMainVolume
        AudioObjectRemovePropertyListenerBlock(
            deviceID,
            &propertyAddress,
            DispatchQueue.main,
            listenerBlock
        )

        // Try removing from channel 1
        propertyAddress.mSelector = kAudioDevicePropertyVolumeScalar
        propertyAddress.mElement = 1
        AudioObjectRemovePropertyListenerBlock(
            deviceID,
            &propertyAddress,
            DispatchQueue.main,
            listenerBlock
        )

        isListening = false
    }

    private func getCurrentVolume() -> Float? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        if AudioObjectHasProperty(deviceID, &propertyAddress) {
            var volume: Float32 = 0
            var dataSize = UInt32(MemoryLayout<Float32>.size)

            let status = AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &dataSize,
                &volume
            )

            if status == noErr {
                return volume
            }
        }

        // Try virtual master volume
        propertyAddress.mSelector = kAudioHardwareServiceDeviceProperty_VirtualMainVolume
        if AudioObjectHasProperty(deviceID, &propertyAddress) {
            var volume: Float32 = 0
            var dataSize = UInt32(MemoryLayout<Float32>.size)

            let status = AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &dataSize,
                &volume
            )

            if status == noErr {
                return volume
            }
        }

        // Try channel 1
        propertyAddress.mSelector = kAudioDevicePropertyVolumeScalar
        propertyAddress.mElement = 1
        if AudioObjectHasProperty(deviceID, &propertyAddress) {
            var volume: Float32 = 0
            var dataSize = UInt32(MemoryLayout<Float32>.size)

            let status = AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &dataSize,
                &volume
            )

            if status == noErr {
                return volume
            }
        }

        return nil
    }

    private lazy var listenerBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        guard let self = self, let volume = self.getCurrentVolume() else { return }
        self.onVolumeChange(self.deviceID, volume)
    }
}
