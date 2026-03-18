import Foundation
import Network
import CoreWLAN
import CoreLocation
import SystemConfiguration

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

    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.wifiguard.pathmonitor")
    private let wifiClient = CWWiFiClient.shared()
    private let shell = ShellExecutor()

    private var refreshTimer: DispatchSourceTimer?
    private var wasConnected = false
    private var currentTimerInterval: Double = 10.0

    /// Debounce: coalesce rapid-fire CWEvent/NWPath callbacks into a single refresh.
    private var pendingRefresh: Task<Void, Never>?

    // MARK: - Lifecycle

    override init() {
        super.init()
    }

    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true

        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleRefresh()
            }
        }
        monitor.start(queue: monitorQueue)
        pathMonitor = monitor

        wifiClient.delegate = self
        try? wifiClient.startMonitoringEvent(with: .ssidDidChange)
        try? wifiClient.startMonitoringEvent(with: .linkDidChange)
        try? wifiClient.startMonitoringEvent(with: .powerDidChange)

        let timer = DispatchSource.makeTimerSource(queue: monitorQueue)
        timer.schedule(deadline: .now(), repeating: 10.0)
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                await self?.refreshState()
            }
        }
        timer.resume()
        refreshTimer = timer

        Task {
            await refreshState()
        }
    }

    func stop() {
        guard isMonitoring else { return }
        isMonitoring = false

        pathMonitor?.cancel()
        pathMonitor = nil

        wifiClient.delegate = nil
        try? wifiClient.stopMonitoringAllEvents()

        refreshTimer?.cancel()
        refreshTimer = nil

        pendingRefresh?.cancel()
        pendingRefresh = nil
    }

    // MARK: - Debounced refresh

    /// Coalesce rapid-fire events: wait 100ms, then refresh once.
    private func scheduleRefresh() {
        pendingRefresh?.cancel()
        pendingRefresh = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            await self?.refreshState()
        }
    }

    // MARK: - State refresh

    func refreshState() async {
        let iface = wifiClient.interface()

        // CoreWLAN reads are instant — no shell spawn
        let ssid = iface?.ssid() ?? ""
        let rssi = iface?.rssiValue() ?? 0
        let wifiPoweredOn = iface?.powerOn() ?? false

        // IP address via getifaddrs() — instant syscall, no shell spawn
        let ipAddress = NetworkQueries.ipAddress(for: "en0") ?? ""

        // Determine if connected
        let isConnected = wifiPoweredOn && !ssid.isEmpty && !ipAddress.isEmpty

        // Gateway via SCDynamicStore (instant) + latency via ping (only when connected).
        // When disconnected, the entire refresh is zero shell spawns.
        var gatewayIP = ""
        var latency: Double? = nil
        if isConnected {
            gatewayIP = NetworkQueries.gatewayIP() ?? ""
            if !gatewayIP.isEmpty {
                latency = await fetchGatewayLatency(gateway: gatewayIP)
            }
        }

        // Detect transitions
        if wasConnected && !isConnected {
            onDisconnect?()
            rescheduleTimer(interval: 2.0)
        } else if !wasConnected && isConnected {
            onReconnect?()
            rescheduleTimer(interval: 10.0)
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

    // MARK: - Timer management

    private func rescheduleTimer(interval: Double) {
        guard interval != currentTimerInterval else { return }
        currentTimerInterval = interval

        refreshTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: monitorQueue)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                await self?.refreshState()
            }
        }
        timer.resume()
        refreshTimer = timer
    }

    // MARK: - Shell helpers

    private func fetchGatewayLatency(gateway: String) async -> Double? {
        guard let result = try? await shell.runCommand(
            "/sbin/ping", "-c", "1", "-W", "2000", gateway,
            timeout: 5
        ), result.exitCode == 0 else {
            return nil
        }
        let output = result.output
        guard let timeRange = output.range(of: "time=") else { return nil }
        let afterTime = output[timeRange.upperBound...]
        guard let msRange = afterTime.range(of: " ms") else { return nil }
        let valueStr = afterTime[..<msRange.lowerBound]
        return Double(valueStr)
    }
}

// MARK: - CWEventDelegate

extension WiFiMonitor: CWEventDelegate {

    nonisolated func clientConnectionDidDissociate() {
        Task { @MainActor [weak self] in
            self?.scheduleRefresh()
        }
    }

    nonisolated func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        Task { @MainActor [weak self] in
            self?.scheduleRefresh()
        }
    }

    nonisolated func linkDidChangeForWiFiInterface(withName interfaceName: String) {
        Task { @MainActor [weak self] in
            self?.scheduleRefresh()
        }
    }

    nonisolated func powerStateDidChangeForWiFiInterface(withName interfaceName: String) {
        Task { @MainActor [weak self] in
            self?.scheduleRefresh()
        }
    }
}
