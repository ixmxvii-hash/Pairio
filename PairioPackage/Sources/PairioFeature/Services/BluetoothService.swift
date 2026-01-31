// BluetoothService.swift
// CoreBluetooth service for detecting AirPods connections

import Foundation
import CoreBluetooth

/// Service for monitoring Bluetooth device connections, specifically AirPods
@Observable
@MainActor
public final class BluetoothService: NSObject, Sendable {

    public var isBluetoothEnabled: Bool = false
    public var connectedAirPods: [String] = []

    private var centralManager: CBCentralManager?

    public override init() {
        super.init()
    }

    /// Start monitoring Bluetooth state and connections
    public func startMonitoring() {
        centralManager = CBCentralManager(delegate: nil, queue: nil)
        // Note: In production, we'd implement CBCentralManagerDelegate
        // For now, we rely on CoreAudio device discovery for AirPods detection
        updateBluetoothState()
    }

    /// Stop monitoring Bluetooth
    public func stopMonitoring() {
        centralManager = nil
    }

    // MARK: - Private

    private func updateBluetoothState() {
        guard let manager = centralManager else { return }
        isBluetoothEnabled = manager.state == .poweredOn
    }
}

// MARK: - AirPods Detection Utilities

/// Utility enum for AirPods-related helper functions (not tied to MainActor)
public enum DeviceUtils {

    /// Check if a device name indicates AirPods
    public static func isAirPodsDevice(name: String) -> Bool {
        let airPodsKeywords = [
            "airpods",
            "airpods pro",
            "airpods max"
        ]

        let lowercasedName = name.lowercased()
        return airPodsKeywords.contains { lowercasedName.contains($0) }
    }

    /// Get a display icon for the device type
    public static func deviceIcon(for name: String) -> String {
        let lowercasedName = name.lowercased()

        if lowercasedName.contains("airpods max") {
            return "headphones"
        } else if lowercasedName.contains("airpods") {
            return "airpods"
        } else if lowercasedName.contains("macbook") || lowercasedName.contains("imac") {
            // Check Mac devices before generic "speaker" to handle "MacBook Pro Speakers"
            return "laptopcomputer"
        } else if lowercasedName.contains("speaker") || lowercasedName.contains("homepod") {
            return "hifispeaker"
        } else {
            return "speaker.wave.2"
        }
    }
}
