// PairioFeatureTests.swift
// Tests for PairioFeature module

import Testing
import CoreAudio
@testable import PairioFeature

@Suite("AudioDevice Model Tests")
struct AudioDeviceTests {

    @Test("AudioDevice initializes with correct properties")
    func audioDeviceInitialization() {
        let device = AudioDevice(
            id: 42,
            name: "Test AirPods Pro",
            uid: "test-uid-123",
            isAirPods: true,
            isConnected: true
        )

        #expect(device.id == 42)
        #expect(device.name == "Test AirPods Pro")
        #expect(device.uid == "test-uid-123")
        #expect(device.isAirPods == true)
        #expect(device.isConnected == true)
    }

    @Test("AudioDevice conforms to Hashable")
    func audioDeviceHashable() {
        let device1 = AudioDevice(id: 1, name: "Device 1", uid: "uid-1", isAirPods: false, isConnected: true)
        let device2 = AudioDevice(id: 1, name: "Device 1", uid: "uid-1", isAirPods: false, isConnected: true)
        let device3 = AudioDevice(id: 2, name: "Device 2", uid: "uid-2", isAirPods: true, isConnected: false)

        #expect(device1 == device2)
        #expect(device1 != device3)
    }

    @Test("AudioDevice can be stored in a Set")
    func audioDeviceInSet() {
        let device1 = AudioDevice(id: 1, name: "AirPods", uid: "uid-1", isAirPods: true, isConnected: true)
        let device2 = AudioDevice(id: 2, name: "Speaker", uid: "uid-2", isAirPods: false, isConnected: true)

        var deviceSet: Set<AudioDevice> = []
        deviceSet.insert(device1)
        deviceSet.insert(device2)
        deviceSet.insert(device1) // Duplicate

        #expect(deviceSet.count == 2)
    }
}

@Suite("AggregateDevice Tests")
struct AggregateDeviceTests {

    @Test("AggregateDevice initializes correctly")
    func aggregateDeviceInit() {
        let subDevice1 = AudioDevice(id: 1, name: "AirPods 1", uid: "uid-1", isAirPods: true, isConnected: true)
        let subDevice2 = AudioDevice(id: 2, name: "AirPods 2", uid: "uid-2", isAirPods: true, isConnected: true)

        let aggregate = AggregateDevice(
            id: 100,
            name: "Pairio Shared Audio",
            subDevices: [subDevice1, subDevice2]
        )

        #expect(aggregate.id == 100)
        #expect(aggregate.name == "Pairio Shared Audio")
        #expect(aggregate.subDevices.count == 2)
    }

    @Test("AggregateDevice stores sub-devices in order")
    func aggregateDeviceOrder() {
        let subDevice1 = AudioDevice(id: 1, name: "First", uid: "uid-1", isAirPods: true, isConnected: true)
        let subDevice2 = AudioDevice(id: 2, name: "Second", uid: "uid-2", isAirPods: true, isConnected: true)

        let aggregate = AggregateDevice(
            id: 100,
            name: "Test",
            subDevices: [subDevice1, subDevice2]
        )

        #expect(aggregate.subDevices[0].name == "First")
        #expect(aggregate.subDevices[1].name == "Second")
    }
}

@Suite("DeviceUtils Tests")
struct DeviceUtilsTests {

    @Test("Detects AirPods device names")
    func detectsAirPodsNames() {
        #expect(DeviceUtils.isAirPodsDevice(name: "AirPods Pro") == true)
        #expect(DeviceUtils.isAirPodsDevice(name: "AirPods Max") == true)
        #expect(DeviceUtils.isAirPodsDevice(name: "John's AirPods") == true)
        #expect(DeviceUtils.isAirPodsDevice(name: "airpods") == true)
        #expect(DeviceUtils.isAirPodsDevice(name: "External Speaker") == false)
        #expect(DeviceUtils.isAirPodsDevice(name: "MacBook Pro Speakers") == false)
    }

    @Test("Returns correct device icons")
    func deviceIcons() {
        #expect(DeviceUtils.deviceIcon(for: "AirPods Max") == "headphones")
        #expect(DeviceUtils.deviceIcon(for: "AirPods Pro") == "airpods")
        #expect(DeviceUtils.deviceIcon(for: "External Speaker") == "hifispeaker")
        #expect(DeviceUtils.deviceIcon(for: "MacBook Pro Speakers") == "laptopcomputer")
        #expect(DeviceUtils.deviceIcon(for: "Unknown Device") == "speaker.wave.2")
    }

    @Test("Handles case insensitivity")
    func caseInsensitive() {
        #expect(DeviceUtils.isAirPodsDevice(name: "AIRPODS PRO") == true)
        #expect(DeviceUtils.isAirPodsDevice(name: "AiRpOdS") == true)
        #expect(DeviceUtils.deviceIcon(for: "MACBOOK PRO") == "laptopcomputer")
    }
}

@Suite("AudioDeviceError Tests")
struct AudioDeviceErrorTests {

    @Test("Error descriptions are human readable")
    func errorDescriptions() {
        #expect(AudioDeviceError.deviceNotFound.errorDescription == "Audio device not found")
        #expect(AudioDeviceError.aggregateCreationFailed.errorDescription == "Failed to create aggregate device")
        #expect(AudioDeviceError.invalidDevice.errorDescription == "Invalid audio device")
        #expect(AudioDeviceError.propertyQueryFailed(-50).errorDescription == "Property query failed with status: -50")
    }

    @Test("Errors are distinct")
    func errorsDistinct() {
        let error1 = AudioDeviceError.deviceNotFound
        let error2 = AudioDeviceError.aggregateCreationFailed

        // Different error types should have different descriptions
        #expect(error1.errorDescription != error2.errorDescription)
    }
}

@Suite("AudioDeviceService Tests")
@MainActor
struct AudioDeviceServiceTests {

    @Test("Service initializes with correct default state")
    func serviceInitialState() {
        let service = AudioDeviceService()

        #expect(service.isSharingActive == false)
        #expect(service.sharingInterrupted == false)
        #expect(service.statusMessage == "")
    }

    @Test("Service can query output devices without crashing")
    func queryDevices() {
        let service = AudioDeviceService()

        // This should not throw on a Mac with audio hardware
        let devices = try? service.getOutputDevices()

        // We can't assert specific devices, but it shouldn't crash
        #expect(devices != nil)
    }

    @Test("Stop sharing is safe when not sharing")
    func stopSharingWhenNotSharing() {
        let service = AudioDeviceService()

        // Should not crash or throw
        service.stopSharing()

        #expect(service.isSharingActive == false)
    }
}
