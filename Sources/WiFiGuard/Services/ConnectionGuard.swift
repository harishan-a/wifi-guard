import Foundation

@MainActor
@Observable
final class ConnectionGuard {

    // MARK: - Public state

    private(set) var consecutiveFailures: Int = 0
    private(set) var totalReconnects: Int = 0
    private(set) var successfulReconnects: Int = 0
    private(set) var lastReconnectTime: Date? = nil
    private(set) var isReconnecting: Bool = false
    private(set) var lastHealthCheck: HealthCheckResult = .healthy

    // MARK: - Callbacks

    /// Called after a successful reconnection with the restored SSID.
    var onReconnectSuccess: ((String) -> Void)?

    /// Called after a failed reconnection attempt with the current failure count.
    var onReconnectFailed: ((Int) -> Void)?

    // MARK: - Configuration (matching wifi-watchdog.sh)

    private let wifiInterface = "en0"
    private let pingTimeout: TimeInterval = 3
    private let reconnectCooldown: TimeInterval = 30
    private let maxBackoff: TimeInterval = 300
    private let powerCycleWait: TimeInterval = 3
    private let pingTargets = ["8.8.8.8", "1.1.1.1", "208.67.222.222"]

    // MARK: - Private

    private let shell = ShellExecutor()
    private weak var monitor: WiFiMonitor?
    private var lastKnownSSID: String = ""

    // MARK: - Start / Hook into WiFiMonitor

    /// Hook into the monitor's disconnect callback to trigger reconnection.
    func start(monitor: WiFiMonitor) {
        self.monitor = monitor

        // Capture the current SSID as the last known network
        let currentSSID = monitor.state.ssid
        if !currentSSID.isEmpty {
            lastKnownSSID = currentSSID
        }

        monitor.onDisconnect = { [weak self] in
            guard let self else { return }
            // Detach from MainActor so reconnect work doesn't block the UI
            Task.detached { [weak self] in
                await self?.handleDisconnect()
            }
        }

        // Also track SSID changes so we always know the last good network
        monitor.onReconnect = { [weak self] in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let ssid = self.monitor?.state.ssid ?? ""
                if !ssid.isEmpty {
                    self.lastKnownSSID = ssid
                }
            }
        }
    }

    // MARK: - Health Check (6-layer, same order as bash script)

    func checkHealth() async -> HealthCheckResult {
        // Layer 1: Is Wi-Fi power on?
        let powerOn = await checkWiFiPower()
        guard powerOn else {
            lastHealthCheck = .noPower
            return .noPower
        }

        // Layer 2: Is there an SSID?
        let ssid = await fetchSSID()
        guard !ssid.isEmpty else {
            lastHealthCheck = .noSSID
            return .noSSID
        }

        // Remember this SSID for reconnection attempts
        lastKnownSSID = ssid

        // Layer 3: Is there an IP address?
        let ip = await fetchIPAddress()
        guard !ip.isEmpty else {
            lastHealthCheck = .noIP
            return .noIP
        }

        // Layer 4: Can we reach the gateway?
        let gateway = await fetchGatewayIP()
        if !gateway.isEmpty {
            let gatewayReachable = await pingHost(gateway)
            guard gatewayReachable else {
                lastHealthCheck = .noGateway
                return .noGateway
            }
        }

        // Layer 5: Can we reach the internet? (try each ping target)
        var internetReachable = false
        for target in pingTargets {
            if await pingHost(target) {
                internetReachable = true
                break
            }
        }
        guard internetReachable else {
            lastHealthCheck = .noInternet
            return .noInternet
        }

        // Layer 6: DNS resolution
        let dnsOK = await checkDNS()
        guard dnsOK else {
            lastHealthCheck = .noDNS
            return .noDNS
        }

        lastHealthCheck = .healthy
        return .healthy
    }

    // MARK: - Reconnection

    func reconnect(reason: String) async {
        // Calculate backoff: cooldown * 2^failures, capped at maxBackoff
        let backoff = min(
            reconnectCooldown * pow(2.0, Double(consecutiveFailures)),
            maxBackoff
        )

        // If too soon since last attempt, skip
        if let lastTime = lastReconnectTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < backoff {
                return
            }
        }

        isReconnecting = true
        totalReconnects += 1
        lastReconnectTime = Date()

        // Step 1: Power cycle Wi-Fi off
        _ = try? await shell.runCommand(
            "/usr/sbin/networksetup", "-setairportpower", wifiInterface, "off"
        )
        try? await Task.sleep(for: .seconds(powerCycleWait))

        // Step 2: Power cycle Wi-Fi on
        _ = try? await shell.runCommand(
            "/usr/sbin/networksetup", "-setairportpower", wifiInterface, "on"
        )
        try? await Task.sleep(for: .seconds(powerCycleWait))

        // Step 3: Wait up to 15s for auto-join (check SSID + IP every second)
        var autoJoined = false
        for _ in 0..<15 {
            let ssid = await fetchSSID()
            let ip = await fetchIPAddress()
            if !ssid.isEmpty && !ip.isEmpty {
                autoJoined = true
                break
            }
            try? await Task.sleep(for: .seconds(1))
        }

        // Step 4: If auto-join failed, try explicit join to last known SSID
        if !autoJoined && !lastKnownSSID.isEmpty {
            _ = try? await shell.runCommand(
                "/usr/sbin/networksetup",
                "-setairportnetwork", wifiInterface, lastKnownSSID
            )
            // Wait up to 10s for the explicit join to complete
            for _ in 0..<10 {
                let ssid = await fetchSSID()
                let ip = await fetchIPAddress()
                if !ssid.isEmpty && !ip.isEmpty {
                    autoJoined = true
                    break
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }

        // Evaluate result
        let health = await checkHealth()

        if health.isHealthy {
            consecutiveFailures = 0
            successfulReconnects += 1
            isReconnecting = false

            let restoredSSID = await fetchSSID()
            onReconnectSuccess?(restoredSSID)

            // Refresh the monitor's state so the UI updates
            await monitor?.refreshState()
        } else {
            consecutiveFailures += 1
            isReconnecting = false

            onReconnectFailed?(consecutiveFailures)
        }
    }

    // MARK: - Disconnect handler

    func handleDisconnect() async {
        let health = await checkHealth()

        switch health {
        case .healthy:
            // False alarm; nothing to do
            return

        case .noPower:
            // Wi-Fi hardware is off; user likely turned it off intentionally.
            // Still attempt once in case it was a glitch.
            await reconnect(reason: health.label)

        case .noSSID:
            // Not associated; try reconnect immediately
            await reconnect(reason: health.label)

        case .noIP:
            // Sometimes DHCP is just slow. Wait 5s and recheck.
            try? await Task.sleep(for: .seconds(5))
            let recheck = await checkHealth()
            guard !recheck.isHealthy else { return }
            await reconnect(reason: recheck.label)

        case .noGateway:
            // Gateway unreachable; short wait then reconnect
            try? await Task.sleep(for: .seconds(3))
            let recheck = await checkHealth()
            guard !recheck.isHealthy else { return }
            await reconnect(reason: recheck.label)

        case .noInternet:
            // Can reach gateway but not internet; might be transient
            try? await Task.sleep(for: .seconds(3))
            let recheck = await checkHealth()
            guard !recheck.isHealthy else { return }
            await reconnect(reason: recheck.label)

        case .noDNS:
            // DNS failure; flush the cache first, then recheck
            _ = try? await shell.runCommand(
                "/usr/bin/dscacheutil", "-flushcache"
            )
            _ = try? await shell.runCommand(
                "/usr/bin/sudo", "killall", "-HUP", "mDNSResponder"
            )
            try? await Task.sleep(for: .seconds(2))
            let recheck = await checkHealth()
            guard !recheck.isHealthy else { return }
            await reconnect(reason: recheck.label)
        }
    }

    // MARK: - Shell helpers

    /// Check if Wi-Fi power is on via networksetup.
    private func checkWiFiPower() async -> Bool {
        guard let result = try? await shell.runCommand(
            "/usr/sbin/networksetup", "-getairportpower", wifiInterface
        ), result.exitCode == 0 else {
            return false
        }
        // Output: "Wi-Fi Power (en0): On" or "Wi-Fi Power (en0): Off"
        return result.output.lowercased().contains(": on")
    }

    /// Fetch the current SSID from networksetup.
    private func fetchSSID() async -> String {
        guard let result = try? await shell.runCommand(
            "/usr/sbin/networksetup", "-getairportnetwork", wifiInterface
        ), result.exitCode == 0 else {
            return ""
        }
        // Output: "Current Wi-Fi Network: MyNetwork" or
        //         "You are not associated with an AirPort network."
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if output.contains("not associated") {
            return ""
        }
        // Parse "Current Wi-Fi Network: <SSID>"
        if let colonRange = output.range(of: ": ") {
            return String(output[colonRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    /// Fetch the IP address for the Wi-Fi interface.
    private func fetchIPAddress() async -> String {
        guard let result = try? await shell.runCommand(
            "/usr/sbin/ipconfig", "getifaddr", wifiInterface
        ), result.exitCode == 0 else {
            return ""
        }
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Fetch the gateway IP from networksetup.
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
                return ip == "none" ? "" : ip
            }
        }
        return ""
    }

    /// Ping a host once with the configured timeout.
    private func pingHost(_ host: String) async -> Bool {
        let timeoutStr = String(Int(pingTimeout * 1000))
        guard let result = try? await shell.runCommand(
            "/sbin/ping", "-c", "1", "-W", timeoutStr, host,
            timeout: pingTimeout + 2
        ) else {
            return false
        }
        return result.exitCode == 0
    }

    /// Check DNS resolution via nslookup.
    private func checkDNS() async -> Bool {
        guard let result = try? await shell.runCommand(
            "/usr/bin/nslookup", "apple.com",
            timeout: pingTimeout + 2
        ) else {
            return false
        }
        // nslookup returns 0 on success and the output contains "Address:"
        // lines for the resolved IPs (beyond the server's own address)
        return result.exitCode == 0 && result.output.contains("Name:")
    }
}
