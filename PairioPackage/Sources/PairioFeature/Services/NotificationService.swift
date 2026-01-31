// NotificationService.swift
// macOS system notifications for Pairio audio sharing events

import Foundation
import UserNotifications

/// Notification types that Pairio can send
public enum PairioNotificationType: String, Sendable {
    case sharingStarted = "com.loganallen.pairio.sharing.started"
    case sharingStopped = "com.loganallen.pairio.sharing.stopped"
    case deviceDisconnected = "com.loganallen.pairio.device.disconnected"
    case newDeviceConnected = "com.loganallen.pairio.device.connected"
}

/// Service for managing macOS system notifications
@Observable
@MainActor
public final class NotificationService: Sendable {

    /// Whether notification permissions have been granted
    public private(set) var isAuthorized: Bool = false

    /// Whether notifications are enabled by user preference
    public var notificationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "pairio.notifications.enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "pairio.notifications.enabled") }
    }

    public init() {
        // Set default preference to enabled on first launch
        if UserDefaults.standard.object(forKey: "pairio.notifications.enabled") == nil {
            UserDefaults.standard.set(true, forKey: "pairio.notifications.enabled")
        }
    }

    // MARK: - Permission Management

    /// Request notification permissions from the user
    public func requestPermissions() async {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            isAuthorized = granted
        } catch {
            isAuthorized = false
        }
    }

    /// Check current authorization status
    public func checkAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Notification Sending

    /// Notify that audio sharing has started
    /// - Parameter deviceCount: Number of devices sharing audio
    public func notifySharingStarted(deviceCount: Int) {
        guard shouldSendNotification() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Audio Sharing Started"
        content.body = "Now sharing audio to \(deviceCount) devices"
        content.sound = .default
        content.categoryIdentifier = PairioNotificationType.sharingStarted.rawValue

        sendNotification(identifier: PairioNotificationType.sharingStarted.rawValue, content: content)
    }

    /// Notify that audio sharing has stopped
    public func notifySharingStopped() {
        guard shouldSendNotification() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Audio Sharing Stopped"
        content.body = "Audio output restored to original device"
        content.sound = nil // Silent notification for stopping
        content.categoryIdentifier = PairioNotificationType.sharingStopped.rawValue

        sendNotification(identifier: PairioNotificationType.sharingStopped.rawValue, content: content)
    }

    /// Notify that a device was disconnected during sharing
    /// - Parameter deviceName: Name of the disconnected device
    public func notifyDeviceDisconnected(deviceName: String) {
        guard shouldSendNotification() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Device Disconnected"
        content.body = "\(deviceName) disconnected - audio restored"
        content.sound = .default
        content.categoryIdentifier = PairioNotificationType.deviceDisconnected.rawValue

        sendNotification(identifier: PairioNotificationType.deviceDisconnected.rawValue, content: content)
    }

    /// Notify that a new device (typically AirPods) has connected
    /// - Parameter deviceName: Name of the connected device
    public func notifyNewDeviceConnected(deviceName: String) {
        guard shouldSendNotification() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Device Connected"
        content.body = "\(deviceName) is now available for audio sharing"
        content.sound = nil // Silent notification for connection
        content.categoryIdentifier = PairioNotificationType.newDeviceConnected.rawValue

        sendNotification(identifier: PairioNotificationType.newDeviceConnected.rawValue, content: content)
    }

    // MARK: - Private Helpers

    private func shouldSendNotification() -> Bool {
        return isAuthorized && notificationsEnabled
    }

    private func sendNotification(identifier: String, content: UNMutableNotificationContent) {
        let request = UNNotificationRequest(
            identifier: "\(identifier).\(UUID().uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                // Log error but don't crash - notifications are non-critical
                print("Pairio: Failed to send notification: \(error.localizedDescription)")
            }
        }
    }

    /// Remove all pending notifications
    public func clearPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Remove all delivered notifications
    public func clearDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}
