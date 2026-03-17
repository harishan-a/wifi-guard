import SwiftUI

// MARK: - Menu Bar Content

/// The content displayed inside the MenuBarExtra dropdown.
/// Uses `.menu` style, so only Button, Toggle, Text, Divider, Menu, and Section are permitted.
struct MenuBarContent: View {
    let state: ConnectionState
    let disconnectLog: DisconnectLog

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        statusSection

        Divider()

        recentDisconnectsSection

        quickActionsSection

        Divider()

        Button("Settings...") {
            openWindow(id: "settings")
        }
        .keyboardShortcut(",")

        Button("Quit WiFi Guard") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

// MARK: - Status Section

extension MenuBarContent {
    @ViewBuilder
    private var statusSection: some View {
        statusHeadline

        if state.isConnected {
            connectionDetails
        }
    }

    @ViewBuilder
    private var statusHeadline: some View {
        if state.isConnected {
            Text("\u{25CF} Connected \u{2014} \(state.ssid)")
        } else if !state.isWiFiPoweredOn {
            Text("\u{2715} Wi-Fi Off")
        } else {
            Text("\u{2715} Disconnected")
        }
    }

    @ViewBuilder
    private var connectionDetails: some View {
        let quality = SignalStrength.from(rssi: state.rssi)
        Text("Signal: \(state.rssi) dBm (\(quality.label))")

        if !state.ipAddress.isEmpty {
            Text("IP: \(state.ipAddress)")
        }

        if !state.gatewayIP.isEmpty {
            gatewayText
        }

        if state.connectedSince != nil {
            Text("Uptime: \(state.uptimeString)")
        }
    }

    @ViewBuilder
    private var gatewayText: some View {
        if let latency = state.gatewayLatencyMs {
            Text("Gateway: \(state.gatewayIP) (\(String(format: "%.0f", latency))ms)")
        } else {
            Text("Gateway: \(state.gatewayIP)")
        }
    }
}

// MARK: - Recent Disconnects

extension MenuBarContent {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f
    }()

    @ViewBuilder
    private var recentDisconnectsSection: some View {
        if !disconnectLog.events.isEmpty {
            Menu("Recent Disconnects") {
                ForEach(disconnectLog.recentEvents) { event in
                    let dateStr = Self.dateFormatter.string(from: event.date)
                    let durStr = event.duration > 0
                        ? " (\(DurationFormatter.format(event.duration)))"
                        : ""
                    Text("\(dateStr) \u{2014} \(event.reason)\(durStr)")
                }
                Divider()
                Button("View Full Log...") {
                    openWindow(id: "disconnect-log")
                }
            }
            Divider()
        }
    }
}

// MARK: - Quick Actions

extension MenuBarContent {
    private static let shell = ShellExecutor()

    @ViewBuilder
    private var quickActionsSection: some View {
        Button("Restart Wi-Fi") {
            Task {
                _ = try? await Self.shell.runCommand("/usr/sbin/networksetup", "-setairportpower", "en0", "off")
                try? await Task.sleep(for: .seconds(2))
                _ = try? await Self.shell.runCommand("/usr/sbin/networksetup", "-setairportpower", "en0", "on")
            }
        }
        Button("Flush DNS") {
            Task {
                _ = try? await Self.shell.runCommand("/usr/bin/dscacheutil", "-flushcache")
                _ = try? await Self.shell.runCommand("/usr/bin/killall", "-HUP", "mDNSResponder")
            }
        }
        Button("Copy IP Address") {
            if !state.ipAddress.isEmpty {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(state.ipAddress, forType: .string)
            }
        }
        Button("Run Diagnostics...") {
            openWindow(id: "diagnostics")
        }
    }
}
