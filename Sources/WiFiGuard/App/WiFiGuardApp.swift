import SwiftUI

@main
struct WiFiGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var monitor = WiFiMonitor()
    @State private var guard_ = ConnectionGuard()
    @State private var disconnectLog = DisconnectLog()
    @State private var settings = AppSettings()
    @State private var locationManager = LocationManager()
    @State private var hotkeyManager = GlobalHotkeyManager()

    var body: some Scene {
        MenuBarExtra(
            "WiFi Guard",
            systemImage: MenuBarIcon.systemImageName(
                isConnected: monitor.state.isConnected,
                isWiFiOn: monitor.state.isWiFiPoweredOn,
                rssi: monitor.state.rssi
            )
        ) {
            MenuBarContent(state: monitor.state, disconnectLog: disconnectLog)
                .task {
                    await startServices()
                }
        }

        Window("Diagnostics", id: "diagnostics") {
            DiagnosticsView()
        }
        .defaultSize(width: 550, height: 450)

        Window("Disconnect Log", id: "disconnect-log") {
            DisconnectLogView(disconnectLog: disconnectLog)
        }
        .defaultSize(width: 700, height: 500)

        Window("Settings", id: "settings") {
            SettingsView(settings: settings)
        }
        .defaultSize(width: 400, height: 250)
    }

    @MainActor
    private func startServices() async {
        locationManager.requestAuthorization()
        await NotificationManager.shared.requestAuthorization()

        // Wire ConnectionGuard notification callbacks
        guard_.onReconnectSuccess = { ssid, failureType, recoveryMethod in
            // Always update the disconnect log, regardless of notification settings
            if !disconnectLog.events.isEmpty && !disconnectLog.events[0].reconnected {
                let duration = Date().timeIntervalSince(disconnectLog.events[0].date)
                disconnectLog.updateLast(
                    reconnected: true,
                    duration: duration,
                    reason: failureType,
                    recoveryMethod: recoveryMethod
                )
            }
            if settings.notificationsEnabled {
                let ip = monitor.state.ipAddress
                NotificationManager.shared.notifyReconnected(ssid: ssid, ip: ip)
            }
        }
        guard_.onReconnectFailed = { attempt in
            guard settings.notificationsEnabled else { return }
            NotificationManager.shared.notifyReconnectFailed(attempt: attempt)
        }

        // Start monitoring
        monitor.start()

        // Hook guard into monitor (this sets monitor.onDisconnect)
        guard_.start(monitor: monitor)

        // Wrap the guard's disconnect handler to also log events
        // and respect the autoReconnect setting.
        // Skip logging during active reconnection to avoid spurious events
        // from power cycling.
        let guardHandler = monitor.onDisconnect
        monitor.onDisconnect = {
            // Don't log spurious disconnects caused by reconnection power cycling
            guard !guard_.isReconnecting else { return }
            disconnectLog.add(DisconnectEvent(reason: "Disconnected"))
            if settings.autoReconnectEnabled {
                guardHandler?()
            }
        }

        // Wrap the reconnect handler to update the disconnect log when
        // WiFi reconnects naturally (without ConnectionGuard intervention)
        let guardReconnectHandler = monitor.onReconnect
        monitor.onReconnect = {
            // Update the most recent disconnect event if it hasn't been resolved yet
            if !disconnectLog.events.isEmpty && !disconnectLog.events[0].reconnected {
                let duration = Date().timeIntervalSince(disconnectLog.events[0].date)
                disconnectLog.updateLast(
                    reconnected: true,
                    duration: duration,
                    recoveryMethod: "Natural"
                )
            }
            guardReconnectHandler?()
        }

        // Set up global hotkey (Ctrl+Opt+Cmd+W to restart Wi-Fi)
        let shell = ShellExecutor()
        hotkeyManager.onHotkeyPressed = {
            Task {
                _ = try? await shell.runCommand("/usr/sbin/networksetup", "-setairportpower", "en0", "off")
                try? await Task.sleep(for: .seconds(2))
                _ = try? await shell.runCommand("/usr/sbin/networksetup", "-setairportpower", "en0", "on")
            }
        }
        if settings.globalHotkeyEnabled {
            hotkeyManager.start()
        }
    }
}
