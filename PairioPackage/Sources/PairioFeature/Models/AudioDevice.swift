// AudioDevice.swift
// Model representing an audio output device

import Foundation
import CoreAudio

/// Represents an audio output device (AirPods, speakers, etc.)
public struct AudioDevice: Identifiable, Hashable, Sendable {
    public let id: AudioDeviceID
    public let name: String
    public let uid: String
    public let isAirPods: Bool
    public let isConnected: Bool

    public init(
        id: AudioDeviceID,
        name: String,
        uid: String,
        isAirPods: Bool,
        isConnected: Bool
    ) {
        self.id = id
        self.name = name
        self.uid = uid
        self.isAirPods = isAirPods
        self.isConnected = isConnected
    }
}

/// Represents a multi-output aggregate device
public struct AggregateDevice: Identifiable, Sendable {
    public let id: AudioDeviceID
    public let name: String
    public let subDevices: [AudioDevice]

    public init(id: AudioDeviceID, name: String, subDevices: [AudioDevice]) {
        self.id = id
        self.name = name
        self.subDevices = subDevices
    }
}
