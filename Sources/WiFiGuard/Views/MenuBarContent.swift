import SwiftUI

// MARK: - Menu Bar Content

/// The content displayed inside the MenuBarExtra dropdown.
/// Uses `.menu` style, so only Button, Toggle, Text, Divider, Menu, and Section are permitted.
struct MenuBarContent: View {
    let state: ConnectionState

    var body: some View {
        statusSection

        Divider()

        // Recent disconnects placeholder (Phase 3)

        // Quick actions placeholder (Phase 4)

        Divider()

        // Settings... (Phase 5)

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

    /// Top-line indicator: connected SSID, Wi-Fi off, or disconnected.
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

    /// Signal, IP, gateway, and uptime rows shown when connected.
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

    /// Gateway row with optional latency.
    @ViewBuilder
    private var gatewayText: some View {
        if let latency = state.gatewayLatencyMs {
            Text("Gateway: \(state.gatewayIP) (\(String(format: "%.0f", latency))ms)")
        } else {
            Text("Gateway: \(state.gatewayIP)")
        }
    }
}

// MARK: - Preview

#Preview {
    // Simulated connected state
    let preview: ConnectionState = {
        let s = ConnectionState()
        s.isConnected = true
        s.ssid = "HomeNetwork"
        s.rssi = -52
        s.ipAddress = "192.168.1.42"
        s.gatewayIP = "192.168.1.1"
        s.gatewayLatencyMs = 4.2
        s.connectedSince = Date().addingTimeInterval(-3725)
        s.isWiFiPoweredOn = true
        return s
    }()

    MenuBarContent(state: preview)
}
