# Pairio - AirPods Audio Sharing for Mac

## Project Overview

Pairio is a native **macOS menu bar application** that enables AirPods audio sharing (like iPhone/Apple TV) on Mac. Users can share audio output with multiple AirPods simultaneously.

- **Platform:** macOS 26 (Tahoe) and later
- **Frameworks:** SwiftUI, CoreAudio, CoreBluetooth
- **Architecture:** Model-View (MV) pattern with workspace + SPM architecture
- **Language:** Swift 6.1+ with strict concurrency

## Project Structure

```
Pairio/
├── Config/                           # XCConfig build settings
│   ├── Debug.xcconfig               # Debug configuration
│   ├── Release.xcconfig             # Release configuration
│   ├── Shared.xcconfig              # Common settings
│   └── Pairio.entitlements          # Bluetooth + audio entitlements
├── Pairio/                          # App target (minimal wrapper)
│   ├── Assets.xcassets/
│   └── PairioApp.swift              # @main entry point with MenuBarExtra
├── PairioPackage/                   # All features and business logic
│   ├── Package.swift
│   ├── Sources/PairioFeature/
│   │   ├── PairioFeature.swift      # Public exports
│   │   ├── Views/MenuBarView.swift  # Menu bar popover UI
│   │   ├── Services/
│   │   │   ├── AudioDeviceService.swift  # CoreAudio multi-output
│   │   │   └── BluetoothService.swift    # AirPods detection
│   │   └── Models/AudioDevice.swift
│   └── Tests/PairioFeatureTests/
└── CLAUDE.md
```

## How Audio Sharing Works

macOS supports **Multi-Output Devices** via CoreAudio. Pairio:
1. Detects connected AirPods via CoreAudio device enumeration
2. Creates a virtual multi-output aggregate device combining multiple AirPods
3. Sets this aggregate device as the system output
4. Provides UI to manage which AirPods are included

## Key Technical Details

### CoreAudio Aggregate Devices
- `AudioHardwareCreateAggregateDevice` creates multi-output devices
- `AudioHardwareDestroyAggregateDevice` removes them
- Main sub-device determines clock source

### Required Entitlements
- `com.apple.security.device.bluetooth` - Bluetooth access
- `com.apple.security.device.audio-input` - Audio device access
- `com.apple.security.app-sandbox` - App sandbox

## Development Guidelines

### Architecture
- **MV Pattern:** No ViewModels - use SwiftUI's native state management
- **@Observable:** For all model classes
- **@State:** For view-local state
- **@Environment:** For shared services
- **@MainActor:** For all UI code

### Concurrency
- Swift 6 strict concurrency mode
- All types crossing concurrency boundaries must be Sendable
- Use `.task` modifier for async work tied to view lifecycle

### Code Style
- Prefer immutability (`let` over `var`)
- Small, focused functions (<50 lines)
- Early returns over nested conditionals
- Comprehensive error handling

## Building

### Package Only
```bash
cd PairioPackage
swift build
swift test
```

### Full App
Open `Pairio.xcworkspace` in Xcode or use XcodeBuildMCP tools.

## Testing
- Uses Swift Testing framework (`@Test`, `#expect`, `#require`)
- Tests in `PairioPackage/Tests/PairioFeatureTests/`
- Test models and service logic independently
