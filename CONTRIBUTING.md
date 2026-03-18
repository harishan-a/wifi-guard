# Contributing to WiFi Guard

Thank you for your interest in contributing to WiFi Guard. This document explains the process for reporting issues, requesting features, and submitting code changes.

## Reporting Bugs

If you encounter a bug, please open an issue on [GitHub Issues](https://github.com/harishan-a/wifi-guard/issues) using the **Bug Report** template. Include:

- macOS version and hardware (Apple Silicon or Intel)
- Steps to reproduce the issue
- Expected vs. actual behavior
- Relevant log output or screenshots, if applicable

## Requesting Features

Feature requests are welcome. Open an issue using the **Feature Request** template and describe:

- The problem you are trying to solve
- Your proposed solution or behavior
- Any alternatives you have considered

## Development Setup

### Prerequisites

- macOS 14 (Sonoma) or later
- Xcode 15+ or the Swift 5.9+ toolchain
- Git

### Getting started

1. Fork the repository and clone your fork:

   ```bash
   git clone https://github.com/<your-username>/wifi-guard.git
   cd wifi-guard
   ```

2. Build the project:

   ```bash
   swift build
   ```

3. Create the app bundle:

   ```bash
   ./Scripts/build.sh
   ```

4. Run the app:

   ```bash
   open .build/WiFiGuard.app
   ```

5. To build a release version:

   ```bash
   swift build -c release
   ./Scripts/build.sh
   ```

## Code Style

- Follow standard Swift conventions and the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
- Use meaningful names for types, methods, and variables.
- Keep functions focused and concise.
- Add comments for non-obvious logic, but prefer self-documenting code.
- All shell commands must use absolute paths (e.g., `/usr/sbin/networksetup`) and must not pass user input into command strings.

## Pull Request Process

1. **Fork** the repository and create a feature branch from `main`:

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Implement** your changes. Keep commits focused and write clear commit messages.

3. **Test** your changes manually:
   - Verify the app builds cleanly with `swift build`.
   - Run the app and confirm the feature works as expected.
   - Check that existing functionality is not broken.

4. **Submit** a pull request against `main`:
   - Provide a clear description of what your PR does and why.
   - Reference any related issues (e.g., "Closes #12").
   - Keep PRs focused on a single change when possible.

5. **Respond** to review feedback promptly. Maintainers may request changes before merging.

## Architecture Overview

If you are new to the codebase, here is a brief orientation:

```
Sources/WiFiGuard/
  App/                  Application lifecycle (AppDelegate, SwiftUI app entry)
  Models/               Data types -- settings, connection state, disconnect events, health results
  Services/             Core business logic:
                          WiFiMonitor       -- CoreWLAN + NWPathMonitor observation
                          ConnectionGuard   -- Auto-reconnect orchestration
                          NetworkDiagnostics -- 6-layer health check
                          ShellExecutor     -- Safe shell command execution
                          DisconnectLog     -- Persistent disconnect history
                          NotificationManager -- macOS notifications
                          GlobalHotkeyManager -- Carbon hotkey registration
                          LocationManager   -- CoreLocation authorization
  Utilities/            Helpers for formatting, menu bar icons, signal mapping
  Views/                SwiftUI views for the menu bar popover
```

The app is event-driven. `WiFiMonitor` combines three data sources:

- **NWPathMonitor** for immediate network path changes
- **CWEventDelegate** for CoreWLAN events (SSID changes, link warnings)
- **A 10-second timer** for RSSI and latency polling

When a disconnect is detected, `ConnectionGuard` drives the reconnect logic. `NetworkDiagnostics` can be invoked manually to run a 6-layer health check sequence.

## Questions?

If you have questions about contributing, feel free to open a discussion on [GitHub Issues](https://github.com/harishan-a/wifi-guard/issues).
