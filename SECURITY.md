# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in WiFi Guard, please report it through
GitHub's **private vulnerability reporting** feature:

1. Go to the [Security tab](https://github.com/harishan-a/wifi-guard/security) of this repository
2. Click **Report a vulnerability**
3. Fill in the details and submit

Please do **not** open a public issue for security vulnerabilities.

## Response Timeline

- **Acknowledgment**: Within 48 hours of report submission
- **Assessment**: Within 7 days
- **Fix or mitigation**: As soon as reasonably possible, depending on severity

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.0.x   | Yes       |

## Security Model

WiFi Guard is a macOS menu bar utility that monitors network state. Here is how it handles
potentially sensitive operations:

- **Shell commands**: The app invokes system utilities (`networksetup`, `ipconfig`, `ping`,
  `dscacheutil`, `killall`) using absolute paths (e.g., `/usr/sbin/networksetup`). Commands
  are executed via `Process` with explicit argument arrays — no shell interpretation is used.
- **No user input in commands**: All command arguments are hardcoded constants. No user-supplied
  or network-supplied data is ever interpolated into shell commands.
- **Permissions**: The app requests Location Services access solely to read the current SSID
  (an Apple requirement since macOS 12). No other sensitive permissions are requested.
- **Network access**: The app does not make any HTTP requests or connect to external servers.
  The only network operation is a local gateway ping for latency measurement.
- **Data storage**: Settings are stored via `@AppStorage` (UserDefaults). Disconnect history
  is kept in memory only and does not persist across app launches.
