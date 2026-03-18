<div align="center">

<img src="assets/app-icon.png" width="128" height="128" alt="WiFi Guard icon">

# WiFi Guard

**A lightweight macOS menu bar app that monitors Wi-Fi health and auto-reconnects on drops.**

[![Build](https://github.com/harishan-a/wifi-guard/actions/workflows/build.yml/badge.svg)](https://github.com/harishan-a/wifi-guard/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/sonoma/)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](https://swift.org)

<br>

<img src="assets/hero-banner.png" width="720" alt="WiFi Guard menu bar preview">

</div>

<br>

## Features

<table>
<tr>
<td width="50%">

#### Real-time Monitoring
Continuously tracks connection state, signal strength (RSSI), gateway latency, and uptime — all visible from the menu bar.

#### Auto-reconnect
Detects Wi-Fi drops and automatically reconnects to the last known network with configurable retry logic.

#### 6-layer Diagnostics
Comprehensive health check: Wi-Fi power, SSID, IP assignment, gateway reachability, DNS resolution, and internet connectivity.

</td>
<td width="50%">

#### Disconnect History
Logs every disconnect event with timestamps, durations, and reconnection status. Export to CSV for analysis.

#### Global Hotkey
Press <kbd>Ctrl</kbd> + <kbd>Opt</kbd> + <kbd>Cmd</kbd> + <kbd>W</kbd> from anywhere to instantly restart Wi-Fi.

#### Menu Bar Native
Runs entirely in the menu bar with no dock icon. Quick actions for restarting Wi-Fi, flushing DNS, and copying your IP address.

</td>
</tr>
</table>

## Installation

### Download

Download the latest `WiFiGuard.app.zip` from [**GitHub Releases**](https://github.com/harishan-a/wifi-guard/releases).

1. Unzip and move `WiFiGuard.app` to your Applications folder
2. Launch the app — it will appear in your menu bar
3. Grant Location permission when prompted (required for SSID access)

### Build from Source

```bash
git clone https://github.com/harishan-a/wifi-guard.git
cd wifi-guard
./Scripts/build.sh
open .build/WiFiGuard.app
```

## Usage

WiFi Guard lives in your menu bar. The icon reflects your current connection state:

| State | Icon | Description |
|:------|:-----|:------------|
| **Connected** | Filled Wi-Fi bars | Strong signal, everything healthy |
| **Weak signal** | Partial Wi-Fi bars | Connected but signal is degraded |
| **Disconnected** | Wi-Fi with slash | No connection — auto-reconnect kicks in |
| **Wi-Fi off** | No icon | Wi-Fi hardware is powered off |

Click the menu bar icon for live stats, quick actions, and access to diagnostics, disconnect log, and settings.

## How It Works

WiFi Guard uses an event-driven architecture built on three complementary mechanisms:

```
NWPathMonitor          CWEventDelegate          10s Polling Timer
     |                       |                        |
     |   path changed        |   SSID/link/power      |   RSSI + latency
     |                       |   events                |   sampling
     v                       v                        v
  +----------------------------------------------------------+
  |                    WiFiMonitor                            |
  |          merges all signals into ConnectionState          |
  +----------------------------------------------------------+
                             |
              disconnect detected?
                             |
                  +----------+----------+
                  |                     |
                  v                     v
          ConnectionGuard        DisconnectLog
          (auto-reconnect)       (event history)
```

All shell commands use absolute paths (e.g., `/usr/sbin/networksetup`) with explicit argument arrays — no shell interpretation, no user input in commands.

## Architecture

```
Sources/WiFiGuard/
  App/           Application entry point and AppDelegate
  Models/        Data types — settings, connection state, events, health results
  Services/      Core logic — monitoring, diagnostics, reconnection, shell execution
  Utilities/     Helpers — formatting, icon mapping, signal strength
  Views/         SwiftUI views — menu content, diagnostics, disconnect log, settings
Resources/       App icon, Info.plist, entitlements
Scripts/         Build, install, and icon generation scripts
```

## Requirements

| Requirement | Details |
|:------------|:--------|
| **macOS** | 14 (Sonoma) or later |
| **Hardware** | Apple Silicon or Intel with Wi-Fi |
| **Permissions** | Location Services (required by Apple for SSID access via CoreWLAN) |

## Contributing

Contributions are welcome! Please read [**CONTRIBUTING.md**](CONTRIBUTING.md) for guidelines on reporting bugs, requesting features, and submitting pull requests.

## License

This project is licensed under the MIT License. See [**LICENSE**](LICENSE) for details.

## Acknowledgments

Built with Apple's native frameworks:

[CoreWLAN](https://developer.apple.com/documentation/corewlan) ·
[Network](https://developer.apple.com/documentation/network) ·
[CoreLocation](https://developer.apple.com/documentation/corelocation) ·
[ServiceManagement](https://developer.apple.com/documentation/servicemanagement) ·
[Carbon](https://developer.apple.com/documentation/carbon)
