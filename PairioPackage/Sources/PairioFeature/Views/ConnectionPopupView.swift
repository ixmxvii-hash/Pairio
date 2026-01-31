// ConnectionPopupView.swift
// Floating popup that appears under the notch when AirPods connect

import SwiftUI
import AppKit

/// The content view for the connection popup
struct ConnectionPopupContent: View {
    let deviceName: String
    let batteryLevel: Int?
    let isConnecting: Bool
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 16) {
            // AirPods icon with animation
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 60, height: 60)

                Image(systemName: "airpods")
                    .font(.system(size: 28))
                    .foregroundStyle(.primary)
                    .symbolEffect(.pulse, isActive: isConnecting)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(deviceName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if isConnecting {
                    Text("Connecting...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let battery = batteryLevel {
                    HStack(spacing: 4) {
                        Image(systemName: batteryIcon(for: battery))
                            .foregroundStyle(batteryColor(for: battery))
                        Text("\(battery)%")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Connected")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(width: 320)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        }
        .scaleEffect(appeared ? 1 : 0.8)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -20)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    private func batteryIcon(for level: Int) -> String {
        switch level {
        case 0..<20: return "battery.0percent"
        case 20..<50: return "battery.25percent"
        case 50..<75: return "battery.50percent"
        case 75..<100: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    private func batteryColor(for level: Int) -> Color {
        switch level {
        case 0..<20: return .red
        case 20..<50: return .orange
        default: return .green
        }
    }
}

/// Manager for showing connection popups under the notch
@MainActor
public final class ConnectionPopupManager: ObservableObject {
    public static let shared = ConnectionPopupManager()

    private var popupWindow: NSWindow?
    private var dismissTask: Task<Void, Never>?

    private init() {}

    /// Show a connection popup for a device
    public func showPopup(deviceName: String, batteryLevel: Int? = nil, isConnecting: Bool = false) {
        // Dismiss any existing popup
        dismissPopup()

        // Create the popup window
        let popup = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 100),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        popup.isOpaque = false
        popup.backgroundColor = .clear
        popup.hasShadow = false
        popup.level = .floating
        popup.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        popup.isMovableByWindowBackground = false

        let contentView = ConnectionPopupContent(
            deviceName: deviceName,
            batteryLevel: batteryLevel,
            isConnecting: isConnecting
        ) { [weak self] in
            self?.dismissPopup()
        }

        popup.contentView = NSHostingView(rootView: contentView)

        // Position under the notch (center top of main screen)
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let popupWidth: CGFloat = 320
            let popupHeight: CGFloat = 100

            // Position centered, below the menu bar/notch area
            let x = screenFrame.midX - popupWidth / 2
            let y = screenFrame.maxY - popupHeight - 50 // 50pt below top

            popup.setFrameOrigin(NSPoint(x: x, y: y))
        }

        popup.orderFrontRegardless()
        popupWindow = popup

        // Auto-dismiss after 4 seconds
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(4))
            dismissPopup()
        }
    }

    /// Dismiss the popup with animation
    public func dismissPopup() {
        dismissTask?.cancel()
        dismissTask = nil

        guard let window = popupWindow else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            window.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor [weak self] in
                window.orderOut(nil)
                self?.popupWindow = nil
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ConnectionPopupContent(
        deviceName: "Logan's AirPods Max",
        batteryLevel: 85,
        isConnecting: false,
        onDismiss: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}
