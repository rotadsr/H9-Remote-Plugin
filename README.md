# H9 Remote
<img width="678" height="710" alt="icon_app" src="https://github.com/user-attachments/assets/df35b754-b0df-4e5b-b0e0-f70319db4419" />


A macOS/iOS remote control application and AUv3 MIDI FX plugin for the Eventide H9 guitar effects pedal. Control your H9 presets, algorithms, parameters, and settings from your computer or DAW.

## Screenshots
<img width="1066" height="908" alt="open_menu" src="https://github.com/user-attachments/assets/38d65c2d-7aa5-409d-951a-b2ec38296f5f" />


## Features

- **Standalone Application** — Control your H9 directly from macOS with a full-featured remote surface
- **AUv3 MIDI FX Plugin** — Add H9 Remote as a MIDI FX plugin in Logic Pro, MainStage, REAPER (7.55+), and other compatible hosts
- **Real-Time Parameter Control** — Adjust all 10 knobs, expression pedal, tempo, and output gain in real-time
- **Algorithm Selection** — Browse and select from all H9 algorithms organized by pedal lineage
- **Preset Management** — Save presets directly to your H9 and recall them by slot number
- **Hardware Sync** — Pull the current state from your H9 hardware or push your app settings back to the device
- **Connection Detection** — Built-in hardware detection to verify your H9 is connected and responding
- **MIDI Port Routing** — Choose which MIDI input and output ports to use for hardware communication

## Requirements

- macOS 13.0 or later
- iOS 16.0 or later (for core library)
- Eventide H9 guitar effects pedal with MIDI capability
- MIDI interface for hardware communication (physical or virtual MIDI routing)

## Installation

### From Source

1. Clone the repository
2. Open `H9Remote.xcodeproj` in Xcode
3. Select the "H9Remote" scheme
4. Build and run (⌘R)

The app will also install the AUv3 plugin extension automatically.

### Using the Plugin in a DAW

The app installs an AUv3 MIDI FX plugin titled "H9 Remote". To use it:

1. In your DAW, create a MIDI or External Instrument track
2. Add "H9 Remote" as a MIDI FX plugin in that track
3. Set up MIDI I/O routing:
   - Route your track's MIDI output to the H9's MIDI input port
   - Route the H9's MIDI output port to your track's MIDI input (for feedback)
4. Control the H9 through the plugin's UI within your DAW

**Note:** As an AUv3 App Extension, the plugin can only exchange MIDI within the host's own routing system. You must manually configure MIDI connections to your H9's physical ports. The standalone app, by contrast, talks directly to the H9.

**Compatibility:** GarageBand does not support MIDI FX plugins.

## Project Structure

```
H9Remote/                    # Standalone macOS application
├── H9RemoteApp.swift       # Main app entry point
├── ContentView.swift        # Primary UI
├── H9StandaloneViewModel.swift
├── H9MIDIConnection.swift  # MIDI port management
└── Assets/                 # App icons and assets

H9RemoteExtension/          # AUv3 MIDI FX plugin
├── H9AudioUnit.swift       # AUv3 plugin definition
├── H9AudioUnitViewController.swift
├── H9RemoteView.swift      # Plugin UI
└── H9ParameterTree.swift   # AUv3 parameter definitions

H9RemoteCore/               # Shared logic (SPM package)
├── H9SysExCodec.swift      # SysEx encoding/decoding
├── H9MIDICodec.swift       # MIDI CC handling
├── H9EngineState.swift     # State management
├── H9Checksum.swift        # SysEx checksum validation
├── H9DeviceDetection.swift # Hardware detection
├── H9ProgramDump.swift     # Preset data parsing
├── H9AlgorithmCatalog.swift # Algorithm definitions
├── H9ParameterMap.swift    # Parameter name/index mapping
├── H9ConnectionGuard.swift # Connection state management
├── H9ParameterFormat.swift # Parameter display formatting
├── UI/                     # Shared UI components
│   ├── H9KnobView.swift
│   └── H9PedalLineage+Color.swift
└── Tests/                  # Comprehensive unit tests
```

## Architecture

The project uses a layered architecture:

1. **H9RemoteCore** — Core business logic and MIDI handling shared between the app and plugin
   - SysEx/MIDI codec for H9 communication
   - Algorithm catalog and parameter definitions
   - Device detection and state management
   - Shared UI components

2. **H9Remote** — Standalone macOS application
   - Full-featured remote control interface
   - Direct MIDI port management
   - Preset save/load workflow

3. **H9RemoteExtension** — AUv3 MIDI FX plugin
   - Plugin lifecycle and parameter tree
   - Plugin UI wrapper
   - Integration with host MIDI routing

## MIDI Communication

The app communicates with the H9 using:
- **SysEx Messages** — For program dumps, parameter updates, and preset management
- **MIDI CC** — For real-time control of expression, tempo, and gain
- **Connection Verification** — Program dump requests to confirm H9 is connected

All SysEx messages include checksums for data integrity.

## Testing

The project includes comprehensive unit tests for core functionality:

```bash
xcode-build-and-test:
  - H9SysExCodec tests
  - H9MIDICodec tests
  - H9Checksum tests
  - H9DeviceDetection tests
  - H9ProgramDump tests
  - H9EngineState tests
  - H9ParameterFormat tests
  - H9AlgorithmCatalog tests
  - H9ConnectionGuard tests
```

Run tests in Xcode with ⌘U or:
```bash
xcodebuild test -scheme H9Remote
```

## Configuration

The project is configured with XcodeGen using `project.yml`:
- Bundle ID prefix: `com.h9au`
- Deployment target: macOS 13.0
- Code signing with hardened runtime enabled
- Automatic Info.plist generation

## Support

For bugs, feature requests, or questions, please open an issue on GitHub.

## License

See LICENSE file for details.

## Disclaimer

This project is an unofficial remote control application for the Eventide H9. It is not affiliated with Eventide Audio Engineering. Use at your own risk. Always test your presets before relying on them in a live performance.
