// GlobalShortcutService.swift
// Service for managing global keyboard shortcuts

import Foundation
import AppKit
import Carbon.HIToolbox

/// Service for monitoring global keyboard shortcuts
/// Default shortcut: Command+Shift+P to toggle audio sharing
@Observable
@MainActor
public final class GlobalShortcutService {

    /// Whether the shortcut monitoring is active
    public private(set) var isMonitoring: Bool = false

    /// Callback triggered when the shortcut is pressed
    public var onShortcutTriggered: (@MainActor () -> Void)?

    /// Callback triggered when volume keys are pressed
    public var onVolumeKeyPressed: (@MainActor (VolumeKey) -> Void)?

    /// The key code for the shortcut (default: P)
    public var keyCode: UInt16 = UInt16(kVK_ANSI_P)

    /// The modifier flags for the shortcut (default: Command+Shift)
    public var modifierFlags: NSEvent.ModifierFlags = [.command, .shift]

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var volumeGlobalMonitor: Any?
    private var volumeLocalMonitor: Any?

    public init() {}

    deinit {
        // Note: stopMonitoring needs to be called explicitly before deallocation
        // since deinit cannot access MainActor-isolated state
    }

    // MARK: - Public API

    /// Start monitoring for the global shortcut
    public func startMonitoring() {
        guard !isMonitoring else { return }

        // Global monitor for when app is not focused
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handleKeyEvent(event)
            }
        }

        // Local monitor for when app is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handleKeyEvent(event)
            }
            return event
        }

        // Global monitor for media keys (volume up/down)
        volumeGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            Task { @MainActor in
                self?.handleSystemEvent(event)
            }
        }

        // Local monitor for media keys when app is focused
        volumeLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            Task { @MainActor in
                self?.handleSystemEvent(event)
            }
            return event
        }

        isMonitoring = true
    }

    /// Stop monitoring for the global shortcut
    public func stopMonitoring() {
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }

        if let volumeGlobalMonitor = volumeGlobalMonitor {
            NSEvent.removeMonitor(volumeGlobalMonitor)
            self.volumeGlobalMonitor = nil
        }

        if let volumeLocalMonitor = volumeLocalMonitor {
            NSEvent.removeMonitor(volumeLocalMonitor)
            self.volumeLocalMonitor = nil
        }

        isMonitoring = false
    }

    // MARK: - Private

    private func handleKeyEvent(_ event: NSEvent) {
        // Check if the correct key and modifiers are pressed
        guard event.keyCode == keyCode else { return }

        // Check modifiers (mask out other flags like caps lock, num lock, etc.)
        let relevantFlags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard relevantFlags == modifierFlags else { return }

        onShortcutTriggered?()
    }

    private func handleSystemEvent(_ event: NSEvent) {
        guard event.type == .systemDefined, event.subtype.rawValue == 8 else { return }

        let keyCode = (event.data1 & 0xFFFF0000) >> 16
        let keyFlags = (event.data1 & 0x0000FFFF)
        let keyState = (keyFlags & 0xFF00) >> 8
        let isKeyDown = keyState == 0xA

        guard isKeyDown else { return }

        switch Int(keyCode) {
        case VolumeKey.soundUp.keyCode:
            onVolumeKeyPressed?(.soundUp)
        case VolumeKey.soundDown.keyCode:
            onVolumeKeyPressed?(.soundDown)
        default:
            break
        }
    }
}

// MARK: - Volume Keys

public enum VolumeKey {
    case soundUp
    case soundDown

    var keyCode: Int {
        switch self {
        case .soundUp:
            return 0
        case .soundDown:
            return 1
        }
    }
}

// MARK: - Shortcut Description

extension GlobalShortcutService {

    /// Human-readable description of the current shortcut
    public var shortcutDescription: String {
        var parts: [String] = []

        if modifierFlags.contains(.command) {
            parts.append("\u{2318}") // Command symbol
        }
        if modifierFlags.contains(.shift) {
            parts.append("\u{21E7}") // Shift symbol
        }
        if modifierFlags.contains(.option) {
            parts.append("\u{2325}") // Option symbol
        }
        if modifierFlags.contains(.control) {
            parts.append("\u{2303}") // Control symbol
        }

        // Add the key character
        if let keyString = keyCodeToString(keyCode) {
            parts.append(keyString)
        }

        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String? {
        // Map common key codes to their string representation
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        default: return nil
        }
    }
}
