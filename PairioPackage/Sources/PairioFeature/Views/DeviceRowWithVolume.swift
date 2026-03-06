// DeviceRowWithVolume.swift
// Row view for displaying an audio device with volume control

import SwiftUI
import CoreAudio

struct DeviceRowWithVolume: View {
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
                                Text("- Sharing")
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
