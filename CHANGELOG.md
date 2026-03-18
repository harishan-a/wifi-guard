# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-17

### Added

- Real-time Wi-Fi monitoring via NWPathMonitor, CWEventDelegate, and periodic polling
- Live menu bar status with dynamic icon reflecting connection quality
- Signal strength display with RSSI value and quality label
- Gateway latency measurement via ping
- Connection uptime tracking
- Auto-reconnect on Wi-Fi drops with configurable retry logic
- 6-layer network diagnostics (Wi-Fi power, SSID, IP, gateway, DNS, internet)
- Disconnect history log with timestamps and durations
- Recent disconnects submenu in menu bar dropdown
- Quick actions: restart Wi-Fi, flush DNS, copy IP address
- Global hotkey (Ctrl+Opt+Cmd+W) to restart Wi-Fi from anywhere
- User notifications for reconnect success and failure
- Settings window for toggling auto-reconnect, notifications, global hotkey, and launch at login
- Cisco AnyConnect VPN detection in diagnostics
- App icon and proper .app bundle structure
- Install script for copying to ~/Applications

[1.0.0]: https://github.com/harishan-a/wifi-guard/releases/tag/v1.0.0
