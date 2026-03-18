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

```mermaid
graph TD
    A["NWPathMonitor<br><i>path changes</i>"] --> D
    B["CWEventDelegate<br><i>SSID / link / power events</i>"] --> D
    C["10s Polling Timer<br><i>RSSI + latency sampling</i>"] --> D

    D["WiFiMonitor<br>merges all signals → ConnectionState"]

    D -- "disconnect detected" --> E["ConnectionGuard<br><i>auto-reconnect</i>"]
    D -- "disconnect detected" --> F["DisconnectLog<br><i>event history</i>"]
    D -- "state updated" --> G["MenuBarContent<br><i>live UI</i>"]

    style A fill:#1a3a5c,stroke:#4a9eff,color:#fff
    style B fill:#1a3a5c,stroke:#4a9eff,color:#fff
    style C fill:#1a3a5c,stroke:#4a9eff,color:#fff
    style D fill:#0d2137,stroke:#4a9eff,color:#fff,stroke-width:2px
    style E fill:#1a3a5c,stroke:#2ecc71,color:#fff
    style F fill:#1a3a5c,stroke:#2ecc71,color:#fff
    style G fill:#1a3a5c,stroke:#2ecc71,color:#fff
```

All shell commands use absolute paths (e.g., `/usr/sbin/networksetup`) with explicit argument arrays — no shell interpretation, no user input in commands.

## Architecture

```mermaid
graph LR
    subgraph Sources/WiFiGuard
        A["App<br><i>entry point, AppDelegate</i>"]
        M["Models<br><i>settings, state, events</i>"]
        S["Services<br><i>monitoring, diagnostics,<br>reconnection, shell</i>"]
        U["Utilities<br><i>formatting, icons, signal</i>"]
        V["Views<br><i>menu, diagnostics,<br>disconnect log, settings</i>"]
    end

    R["Resources<br><i>app icon, Info.plist,<br>entitlements</i>"]
    SC["Scripts<br><i>build, install,<br>icon generation</i>"]

    A --> S
    V --> M
    V --> S
    S --> U

    style A fill:#1a3a5c,stroke:#4a9eff,color:#fff
    style M fill:#1a3a5c,stroke:#4a9eff,color:#fff
    style S fill:#0d2137,stroke:#4a9eff,color:#fff,stroke-width:2px
    style U fill:#1a3a5c,stroke:#4a9eff,color:#fff
    style V fill:#1a3a5c,stroke:#4a9eff,color:#fff
    style R fill:#2d2d3d,stroke:#888,color:#ccc
    style SC fill:#2d2d3d,stroke:#888,color:#ccc
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
