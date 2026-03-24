import Foundation
import CoreWLAN

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

    /// (ssid, failureType, recoveryMethod)
    var onReconnectSuccess: ((String, String, String) -> Void)?
    var onReconnectFailed: ((Int) -> Void)?

    /// Exposed so the app can log the diagnosed failure type when creating events.
    private(set) var lastDiagnosis: String = "Disconnected"

    // MARK: - Configuration

    private let wifiInterface = "en0"
    private let pingTimeout: TimeInterval = 2
    private let pingTargets = ["8.8.8.8", "1.1.1.1", "208.67.222.222"]
    private let maxRetries = 15

    // MARK: - Flap detection

    private var recentDisconnectTimestamps: [Date] = []
    private let flapThreshold = 5
    private let flapWindowSeconds: TimeInterval = 300

    /// Whether the connection is rapidly cycling (>flapThreshold drops in flapWindowSeconds).
    var isFlapping: Bool {
        let cutoff = Date().addingTimeInterval(-flapWindowSeconds)
        return recentDisconnectTimestamps.filter { $0 >= cutoff }.count >= flapThreshold
    }

    // MARK: - Counters (for stats/observability)

    private(set) var totalPowerCycles: Int = 0
    private(set) var totalExplicitJoinSkips: Int = 0
    private(set) var totalFlapEvents: Int = 0
    private(set) var lastDisconnectRSSI: Int = 0

    // MARK: - Private

    private let shell = ShellExecutor()
    private let wifiClient = CWWiFiClient.shared()
    private weak var monitor: WiFiMonitor?
    private weak var settings: AppSettings?
    private var lastKnownSSID: String = ""
    private var retryTask: Task<Void, Never>?
    private var wasFlapping = false

    // MARK: - Start / Hook into WiFiMonitor

    func start(monitor: WiFiMonitor, settings: AppSettings? = nil) {
        self.monitor = monitor
        self.settings = settings

        let currentSSID = monitor.state.ssid
        if !currentSSID.isEmpty {
            lastKnownSSID = currentSSID
        }

        monitor.onDisconnect = { [weak self] in
            guard let self else { return }
            Task { [weak self] in
                await self?.handleDisconnect()
            }
        }

        monitor.onReconnect = { [weak self] in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let ssid = self.wifiClient.interface()?.ssid() ?? ""
                if !ssid.isEmpty {
                    self.lastKnownSSID = ssid
                }
                self.retryTask?.cancel()
                self.retryTask = nil
                self.consecutiveFailures = 0
            }
        }
    }

    // MARK: - Fast connectivity checks (no shell spawn)

    private func currentSSID() -> String {
        wifiClient.interface()?.ssid() ?? ""
    }

    private func isWiFiPoweredOn() -> Bool {
        wifiClient.interface()?.powerOn() ?? false
    }

    private func hasIP() -> Bool {
        NetworkQueries.ipAddress(for: wifiInterface) != nil
    }

    /// Instant connectivity check — zero shell spawns.
    private func isBasicConnected() -> Bool {
        !currentSSID().isEmpty && hasIP()
    }

    /// Diagnose what layer is broken — instant, no shell spawns.
    private enum DisconnectType {
        case noPower        // WiFi hardware off
        case noSSID         // Not associated to any network
        case noIP           // Associated but no IP (DHCP failure)
    }

    private func diagnose() -> DisconnectType? {
        guard isWiFiPoweredOn() else { return .noPower }
        let ssid = currentSSID()
        guard !ssid.isEmpty else { return .noSSID }
        if !ssid.isEmpty { lastKnownSSID = ssid }
        guard hasIP() else { return .noIP }
        return nil // connected
    }

    // MARK: - Health Check (6-layer, used for diagnostics/reporting)

    func checkHealth() async -> HealthCheckResult {
        guard isWiFiPoweredOn() else {
            lastHealthCheck = .noPower
            return .noPower
        }

        let ssid = currentSSID()
        guard !ssid.isEmpty else {
            lastHealthCheck = .noSSID
            return .noSSID
        }
        lastKnownSSID = ssid

        guard hasIP() else {
            lastHealthCheck = .noIP
            return .noIP
        }

        let gateway = NetworkQueries.gatewayIP() ?? ""
        if !gateway.isEmpty {
            let gatewayReachable = await pingHost(gateway)
            guard gatewayReachable else {
                lastHealthCheck = .noGateway
                return .noGateway
            }
        }

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

        let dnsOK = await checkDNS()
        guard dnsOK else {
            lastHealthCheck = .noDNS
            return .noDNS
        }

        lastHealthCheck = .healthy
        return .healthy
    }

    // MARK: - Smart Tiered Reconnection

    /// Diagnose what's wrong, then apply the right fix for each failure mode.
    /// This eliminates the 26s slow path where Tier 2 explicit rejoin wasted time
    /// on DHCP failures (SSID present but no IP).
    func reconnect(reason: String) async {
        isReconnecting = true
        totalReconnects += 1
        lastReconnectTime = Date()

        // ── Tier 1: Wait for macOS auto-recovery (up to 1.5s) ──
        // Data shows fast recoveries at ~1.5s average. Check every 200ms.
        lastDiagnosis = "Disconnected"
        for _ in 0..<8 {
            try? await Task.sleep(for: .milliseconds(200))
            if isBasicConnected() {
                await finishSuccess(via: "Auto-recovery")
                return
            }
        }

        // ── Tier 2: Diagnose and apply targeted fix ──
        // Instead of a one-size-fits-all approach, fix what's actually broken.
        let issue = diagnose()

        switch issue {
        case nil:
            await finishSuccess(via: "Auto-recovery")
            return

        case .noIP:
            lastDiagnosis = "No IP (DHCP)"
            if await recoverDHCP() { return }
            if await recoverReassociate() { return }

        case .noSSID:
            lastDiagnosis = "No SSID"
            // Explicit Join has 0% success rate on first attempt (0/84 in disconnect log
            // analysis). Skip it on first attempt unless the user has opted in via settings.
            // On retries, always try it since the AP may have recovered.
            let tryExplicitJoin = consecutiveFailures > 0 || (settings?.explicitJoinOnFirstAttempt ?? false)
            if tryExplicitJoin {
                if await recoverExplicitJoin() { return }
            } else {
                totalExplicitJoinSkips += 1
            }

        case .noPower:
            lastDiagnosis = "No Power"
            break
        }

        // ── Tier 3: Power cycle (last resort) ──
        if await recoverPowerCycle() { return }

        // All tiers failed
        consecutiveFailures += 1
        isReconnecting = false
        onReconnectFailed?(consecutiveFailures)
        scheduleRetry(reason: reason)
    }

    // MARK: - Recovery strategies

    /// Force DHCP renewal — fixes "SSID present, no IP" in ~2-3s instead of 26s.
    private func recoverDHCP() async -> Bool {
        _ = try? await shell.runCommand(
            "/usr/sbin/ipconfig", "set", wifiInterface, "DHCP"
        )
        // Poll for IP for up to 5s
        for _ in 0..<25 {
            try? await Task.sleep(for: .milliseconds(200))
            if isBasicConnected() {
                await finishSuccess(via: "DHCP Renewal")
                return true
            }
        }
        return false
    }

    /// Disassociate then reassociate — forces a fresh connection.
    private func recoverReassociate() async -> Bool {
        wifiClient.interface()?.disassociate()
        try? await Task.sleep(for: .milliseconds(500))

        if !lastKnownSSID.isEmpty {
            _ = try? await shell.runCommand(
                "/usr/sbin/networksetup",
                "-setairportnetwork", wifiInterface, lastKnownSSID
            )
        }

        for _ in 0..<25 {
            try? await Task.sleep(for: .milliseconds(200))
            if isBasicConnected() {
                await finishSuccess(via: "Reassociate")
                return true
            }
        }
        return false
    }

    /// Explicit join to last known SSID.
    private func recoverExplicitJoin() async -> Bool {
        guard !lastKnownSSID.isEmpty else { return false }

        _ = try? await shell.runCommand(
            "/usr/sbin/networksetup",
            "-setairportnetwork", wifiInterface, lastKnownSSID
        )

        for _ in 0..<25 {
            try? await Task.sleep(for: .milliseconds(200))
            if isBasicConnected() {
                await finishSuccess(via: "Explicit Join")
                return true
            }
        }

        if !currentSSID().isEmpty && !hasIP() {
            return await recoverDHCP()
        }
        return false
    }

    /// Power cycle WiFi — nuclear option.
    private func recoverPowerCycle() async -> Bool {
        totalPowerCycles += 1
        _ = try? await shell.runCommand(
            "/usr/sbin/networksetup", "-setairportpower", wifiInterface, "off"
        )
        try? await Task.sleep(for: .milliseconds(500))
        _ = try? await shell.runCommand(
            "/usr/sbin/networksetup", "-setairportpower", wifiInterface, "on"
        )
        try? await Task.sleep(for: .seconds(1))

        for _ in 0..<50 {
            try? await Task.sleep(for: .milliseconds(200))
            if isBasicConnected() {
                await finishSuccess(via: "Power Cycle")
                return true
            }
        }

        if !lastKnownSSID.isEmpty {
            _ = try? await shell.runCommand(
                "/usr/sbin/networksetup",
                "-setairportnetwork", wifiInterface, lastKnownSSID
            )
            for _ in 0..<25 {
                try? await Task.sleep(for: .milliseconds(200))
                if isBasicConnected() {
                    await finishSuccess(via: "Power Cycle + Join")
                    return true
                }
            }
        }

        if !currentSSID().isEmpty && !hasIP() {
            _ = try? await shell.runCommand(
                "/usr/sbin/ipconfig", "set", wifiInterface, "DHCP"
            )
            // Extended from 4s to 8s — log analysis showed ~41 events where DHCP
            // completed just after the original 4s window, causing misattribution.
            for _ in 0..<40 {
                try? await Task.sleep(for: .milliseconds(200))
                if isBasicConnected() {
                    await finishSuccess(via: "Power Cycle + DHCP")
                    return true
                }
            }
        }

        return false
    }

    private func finishSuccess(via method: String = "Auto-recovery") async {
        consecutiveFailures = 0
        successfulReconnects += 1
        isReconnecting = false

        retryTask?.cancel()
        retryTask = nil

        // Flush DNS after Power Cycle recoveries to prevent stale cache
        if method.hasPrefix("Power Cycle") && (settings?.flushDNSOnRecovery ?? true) {
            await flushDNSCache()
        }

        let ssid = currentSSID()
        onReconnectSuccess?(ssid, lastDiagnosis, method)
        await monitor?.refreshState()
    }

    private func flushDNSCache() async {
        _ = try? await shell.runCommand("/usr/bin/dscacheutil", "-flushcache")
        _ = try? await shell.runCommand("/usr/bin/killall", "-HUP", "mDNSResponder")
    }

    // MARK: - Retry loop

    private func scheduleRetry(reason: String) {
        guard consecutiveFailures < maxRetries else { return }
        retryTask?.cancel()

        let delay = min(3.0 * pow(2.0, Double(consecutiveFailures - 1)), 30.0)

        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            guard let self else { return }

            if self.isBasicConnected() {
                self.consecutiveFailures = 0
                await self.monitor?.refreshState()
                return
            }
            await self.reconnect(reason: reason)
        }
    }

    // MARK: - Disconnect handler

    func handleDisconnect() async {
        guard !isReconnecting else { return }

        retryTask?.cancel()
        retryTask = nil

        if isBasicConnected() { return }

        // Track flap state
        let now = Date()
        recentDisconnectTimestamps.append(now)
        let cutoff = now.addingTimeInterval(-flapWindowSeconds)
        recentDisconnectTimestamps.removeAll { $0 < cutoff }

        if isFlapping && !wasFlapping {
            totalFlapEvents += 1
            wasFlapping = true
        } else if !isFlapping {
            wasFlapping = false
        }

        // Record RSSI at time of disconnect for diagnostics
        lastDisconnectRSSI = monitor?.state.rssi ?? 0

        await reconnect(reason: "Disconnected")
    }

    // MARK: - Shell helpers (only used for pings/DNS in full health check)

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

    private func checkDNS() async -> Bool {
        guard let result = try? await shell.runCommand(
            "/usr/bin/nslookup", "apple.com",
            timeout: pingTimeout + 2
        ) else {
            return false
        }
        return result.exitCode == 0 && result.output.contains("Name:")
    }
}
