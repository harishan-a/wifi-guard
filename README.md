# WiFi Guard

**A lightweight macOS menu bar app that monitors Wi-Fi health and auto-reconnects on drops.**

[![Build](https://github.com/harishan-a/wifi-guard/actions/workflows/build.yml/badge.svg)](https://github.com/harishan-a/wifi-guard/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-brightgreen.svg)](https://www.apple.com/macos/sonoma/)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)

![WiFi Guard](assets/screenshot.png)

---

## Features

- **Real-time Wi-Fi monitoring** -- Continuously tracks connection state, signal strength, and network latency from the menu bar.
- **Auto-reconnect** -- Detects Wi-Fi drops and automatically reconnects to the last known network.
- **6-layer health check diagnostics** -- Runs a comprehensive diagnostic sequence: Wi-Fi interface, SSID association, IP assignment, gateway reachability, DNS resolution, and internet connectivity.
- **Disconnect history log** -- Records every disconnect event with timestamps, durations, and network details for later review.
- **Global hotkey** -- Press `Ctrl+Opt+Cmd+W` from anywhere to instantly restart Wi-Fi.
- **Native notifications** -- Alerts you when your connection drops or is restored.
- **Settings** -- Configure auto-reconnect behavior, polling intervals, and notification preferences.
- **Menu bar only** -- Runs entirely in the menu bar with no dock icon, staying out of your way.

## Installation

### Download

Download the latest `.app` bundle from [GitHub Releases](https://github.com/harishan-a/wifi-guard/releases).

1. Move `WiFiGuard.app` to your Applications folder.
2. Launch the app. It will appear in your menu bar.
3. Grant Location permission when prompted (required for SSID access).

### Build from source

```bash
git clone https://github.com/harishan-a/wifi-guard.git
cd wifi-guard
swift build -c release
./Scripts/build.sh
```

The built app bundle will be at `.build/WiFiGuard.app`. Move it to your Applications folder or run it directly.

## Usage

WiFi Guard lives in your menu bar. The icon reflects your current connection state:

| Icon state | Meaning |
|---|---|
| Filled Wi-Fi icon | Connected with good signal |
| Weak signal icon | Connected with poor signal |
| Disconnected icon | No Wi-Fi connection |
| Spinning indicator | Reconnecting in progress |

Click the menu bar icon to see:

- Current network name and signal strength
- Connection uptime and latency
- Quick access to diagnostics, disconnect log, and settings

## Architecture

The project is organized as a Swift Package Manager package (~1,800 lines of Swift):

```
Sources/WiFiGuard/
  App/                  Application entry point and AppDelegate
  Models/               Data types (settings, connection state, events, results)
  Services/             Core logic (monitoring, diagnostics, reconnection, shell execution)
  Utilities/            Helpers (formatting, icons, signal mapping)
  Views/                SwiftUI views (menu content, diagnostics, log, settings)
Resources/              App icon, Info.plist, entitlements
Scripts/                Build and installation scripts
```

Key services:

- **WiFiMonitor** -- Wraps CoreWLAN (`CWWiFiClient`) and `NWPathMonitor` to observe Wi-Fi state changes.
- **ConnectionGuard** -- Orchestrates auto-reconnect logic when drops are detected.
- **NetworkDiagnostics** -- Runs the 6-layer health check sequence using shell commands.
- **ShellExecutor** -- Executes system commands (`networksetup`, `ipconfig`, `ping`, `dscacheutil`) with absolute paths and no shell interpretation.
- **GlobalHotkeyManager** -- Registers the system-wide hotkey via the Carbon framework.

## How It Works

WiFi Guard uses an event-driven architecture built on three complementary mechanisms:

1. **NWPathMonitor** -- Provides immediate notification when the network path changes (connected, disconnected, interface change).
2. **CWEventDelegate** -- Receives CoreWLAN events such as SSID changes, mode changes, and link quality warnings.
3. **10-second polling timer** -- Periodically samples RSSI and measures gateway latency to detect gradual signal degradation that the event-based systems may not catch.

When a disconnect is detected, ConnectionGuard initiates a reconnect cycle: it waits briefly for the system to self-recover, then attempts to rejoin the last known SSID using `networksetup`. All shell commands use absolute paths (e.g., `/usr/sbin/networksetup`) and never pass user input into command strings, avoiding shell injection risks.

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon or Intel Mac
- Location Services permission (required by Apple for SSID access via CoreWLAN)
- Wi-Fi hardware

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on reporting bugs, requesting features, and submitting pull requests.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

- [CoreWLAN](https://developer.apple.com/documentation/corewlan) -- Apple's framework for Wi-Fi interface management.
- [Network framework](https://developer.apple.com/documentation/network) -- Provides `NWPathMonitor` for network path observation.
- [CoreLocation](https://developer.apple.com/documentation/corelocation) -- Required for SSID access authorization.
- [ServiceManagement](https://developer.apple.com/documentation/servicemanagement) -- Login item registration.
- [Carbon](https://developer.apple.com/documentation/carbon) -- Global hotkey registration via `RegisterEventHotKey`.
