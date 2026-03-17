import Foundation
import Network
import CoreWLAN
import CoreLocation

@MainActor
@Observable
final class WiFiMonitor: NSObject {

    // MARK: - Public state

    let state = ConnectionState()
    private(set) var isMonitoring = false

    /// Called when connection drops (was connected, now disconnected).
    var onDisconnect: (() -> Void)?
    /// Called when connection is restored (was disconnected, now connected).
    var onReconnect: (() -> Void)?

    // MARK: - Private properties

    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.wifiguard.pathmonitor")
    private let wifiClient = CWWiFiClient.shared()
    private let shell = ShellExecutor()

    private var refreshTimer: DispatchSourceTimer?
    private var wasConnected = false

    // MARK: - Lifecycle

    override init() {
        super.init()
    }

    /// Begin monitoring Wi-Fi state. Sets up NWPathMonitor, CWEventDelegate,
    /// and a 10-second refresh timer for RSSI / latency polling.
    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // -- NWPathMonitor for connectivity changes --
        pathMonitor.pathUpdateHandler = { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refreshState()
            }
        }
        pathMonitor.start(queue: monitorQueue)

        // -- CWEventDelegate for SSID / link changes --
        wifiClient.delegate = self
        try? wifiClient.startMonitoringEvent(with: .ssidDidChange)
        try? wifiClient.startMonitoringEvent(with: .linkDidChange)
        try? wifiClient.startMonitoringEvent(with: .powerDidChange)

        // -- Periodic timer (10s) for RSSI + gateway latency --
        let timer = DispatchSource.makeTimerSource(queue: monitorQueue)
        timer.schedule(deadline: .now(), repeating: 10.0)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.refreshState()
            }
        }
        timer.resume()
        refreshTimer = timer

        // -- Initial read --
        Task {
            await refreshState()
        }
    }

    /// Stop all monitoring and tear down timers.
    func stop() {
        guard isMonitoring else { return }
        isMonitoring = false

        pathMonitor.cancel()

        wifiClient.delegate = nil
        try? wifiClient.stopMonitoringAllEvents()

        refreshTimer?.cancel()
        refreshTimer = nil
    }

    // MARK: - State refresh

    /// Read current Wi-Fi details and update `state`.
    func refreshState() async {
        let iface = wifiClient.interface()

        // SSID (requires location authorization on macOS 12+)
        let ssid = iface?.ssid() ?? ""

        // RSSI
        let rssi = iface?.rssiValue() ?? 0

        // Wi-Fi power
        let wifiPoweredOn = iface?.powerOn() ?? false

        // IP address via ipconfig
        let ipAddress = await fetchIPAddress()

        // Gateway IP via networksetup
        let gatewayIP = await fetchGatewayIP()

        // Gateway latency via ping (only if we have a gateway)
        var latency: Double? = nil
        if !gatewayIP.isEmpty {
            latency = await fetchGatewayLatency(gateway: gatewayIP)
        }

        // Determine if connected
        let isConnected = wifiPoweredOn && !ssid.isEmpty && !ipAddress.isEmpty

        // Detect transitions
        if wasConnected && !isConnected {
            onDisconnect?()
        } else if !wasConnected && isConnected {
            onReconnect?()
        }

        // Update connectedSince on transitions
        if isConnected && !wasConnected {
            state.connectedSince = Date()
        } else if !isConnected {
            state.connectedSince = nil
        }

        wasConnected = isConnected

        // Commit to state
        state.isConnected = isConnected
        state.ssid = ssid
        state.rssi = rssi
        state.isWiFiPoweredOn = wifiPoweredOn
        state.ipAddress = ipAddress
        state.gatewayIP = gatewayIP
        state.gatewayLatencyMs = latency
    }

    // MARK: - Shell helpers

    /// Fetch the local IP address for en0.
    private func fetchIPAddress() async -> String {
        guard let result = try? await shell.runCommand(
            "/usr/sbin/ipconfig", "getifaddr", "en0"
        ), result.exitCode == 0 else {
            return ""
        }
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parse the "Router:" line from `networksetup -getinfo Wi-Fi`.
    private func fetchGatewayIP() async -> String {
        guard let result = try? await shell.runCommand(
            "/usr/sbin/networksetup", "-getinfo", "Wi-Fi"
        ), result.exitCode == 0 else {
            return ""
        }
        for line in result.output.components(separatedBy: "\n") {
            if line.hasPrefix("Router:") {
                let ip = line
                    .replacingOccurrences(of: "Router:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                // "Router: none" when not set
                return ip == "none" ? "" : ip
            }
        }
        return ""
    }

    /// Ping the gateway once and parse `time=<ms>` from the output.
    private func fetchGatewayLatency(gateway: String) async -> Double? {
        guard let result = try? await shell.runCommand(
            "/sbin/ping", "-c", "1", "-W", "2", gateway,
            timeout: 5
        ), result.exitCode == 0 else {
            return nil
        }
        // Look for "time=12.345 ms" in the output
        let output = result.output
        guard let timeRange = output.range(of: "time=") else { return nil }
        let afterTime = output[timeRange.upperBound...]
        guard let msRange = afterTime.range(of: " ms") else { return nil }
        let valueStr = afterTime[..<msRange.lowerBound]
        return Double(valueStr)
    }
}

// MARK: - CWEventDelegate

/// CWEventDelegate callbacks are invoked on arbitrary threads, so this
/// conformance is non-isolated. Each callback bounces to @MainActor
/// to trigger a state refresh.
extension WiFiMonitor: CWEventDelegate {

    nonisolated func clientConnectionDidDissociate() {
        Task { @MainActor in
            await self.refreshState()
        }
    }

    nonisolated func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        Task { @MainActor in
            await self.refreshState()
        }
    }

    nonisolated func linkDidChangeForWiFiInterface(withName interfaceName: String) {
        Task { @MainActor in
            await self.refreshState()
        }
    }

    nonisolated func powerStateDidChangeForWiFiInterface(withName interfaceName: String) {
        Task { @MainActor in
            await self.refreshState()
        }
    }
}
