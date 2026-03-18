import Foundation

final class NetworkDiagnostics {

    enum Severity: String, Sendable {
        case ok = "OK"
        case warning = "WARN"
        case critical = "CRITICAL"
        case info = "INFO"
    }

    struct Finding: Identifiable, Sendable {
        let id = UUID()
        let category: String
        let severity: Severity
        let message: String
        let detail: String?
    }

    struct Report: Sendable {
        let findings: [Finding]
        let timestamp: Date
        let macOSVersion: String

        var issueCount: Int {
            findings.filter { $0.severity == .warning || $0.severity == .critical }.count
        }
    }

    private let shell = ShellExecutor()

    // MARK: - Public API

    /// Run full diagnostics and return a report.
    func runDiagnostics() async -> Report {
        var findings: [Finding] = []

        let macOS = await getMacOSVersion()

        findings += await checkNetworkExtensions()
        findings += await checkDNS()
        findings += await checkWiFiConnection()
        findings += await checkSignalStrength()
        findings += await checkVPN()
        findings += await checkConnectivity()

        return Report(findings: findings, timestamp: Date(), macOSVersion: macOS)
    }

    // MARK: - Individual Checks

    private func checkNetworkExtensions() async -> [Finding] {
        var findings: [Finding] = []
        let category = "Network Extensions"

        guard let result = try? await shell.runCommand("/usr/bin/systemextensionsctl", "list") else {
            findings.append(Finding(category: category, severity: .info, message: "Could not query system extensions", detail: nil))
            return findings
        }

        let lines = result.output.components(separatedBy: "\n")
        let netExtLines = lines.filter { $0.contains("network_extension") }
        let activeCount = netExtLines.filter { $0.contains("[activated enabled]") }.count
        let pendingUninstall = netExtLines.filter { $0.contains("[terminated waiting to uninstall") }.count

        if activeCount > 2 {
            findings.append(Finding(
                category: category, severity: .critical,
                message: "\(activeCount) active network extensions detected (recommended: 1-2 max)",
                detail: "Multiple network extensions competing for socket/DNS filtering causes cascading restarts that drop Wi-Fi connections."
            ))
        } else if activeCount > 0 {
            findings.append(Finding(category: category, severity: .ok, message: "\(activeCount) active network extension(s)", detail: nil))
        } else {
            findings.append(Finding(category: category, severity: .ok, message: "No active network extensions", detail: nil))
        }

        // Check for Cisco AnyConnect Socket Filter
        let ciscoActive = netExtLines.contains { line in
            let lower = line.lowercased()
            return (lower.contains("anyconnect") || lower.contains("cisco")) && line.contains("[activated enabled]")
        }
        if ciscoActive {
            findings.append(Finding(
                category: category, severity: .critical,
                message: "Cisco AnyConnect Socket Filter detected",
                detail: "Runs constantly even when VPN is disconnected. Known to cause Wi-Fi drops. Remove from /Applications/Cisco/ or disable the extension."
            ))
        }

        if pendingUninstall > 0 {
            findings.append(Finding(category: category, severity: .info, message: "\(pendingUninstall) extension(s) pending removal on next reboot", detail: nil))
        }

        return findings
    }

    private func checkDNS() async -> [Finding] {
        var findings: [Finding] = []
        let category = "DNS"

        guard let result = try? await shell.runCommand("/usr/sbin/scutil", "--dns") else {
            findings.append(Finding(category: category, severity: .info, message: "Could not query DNS configuration", detail: nil))
            return findings
        }

        let lines = result.output.components(separatedBy: "\n")

        // Check if search domains contain IP addresses
        let searchDomainLines = lines.prefix(5).filter { $0.contains("search domain") }
        let hasIPInSearchDomains = searchDomainLines.contains { line in
            line.range(of: #"\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"#, options: .regularExpression) != nil
        }

        if hasIPInSearchDomains {
            let domains = searchDomainLines
                .compactMap { $0.components(separatedBy: ": ").last?.trimmingCharacters(in: .whitespaces) }
                .joined(separator: ", ")
            findings.append(Finding(
                category: category, severity: .critical,
                message: "IP addresses found in DNS search domains instead of DNS servers",
                detail: "Search domains: \(domains). Fix: networksetup -setdnsservers Wi-Fi 8.8.8.8 1.1.1.1 && networksetup -setsearchdomains Wi-Fi Empty"
            ))
        } else {
            findings.append(Finding(category: category, severity: .ok, message: "DNS search domains look correct", detail: nil))
        }

        // List nameservers
        let nameserverLines = lines.filter { $0.contains("nameserver") }.prefix(3)
        let servers = nameserverLines
            .compactMap { $0.components(separatedBy: ": ").last?.trimmingCharacters(in: .whitespaces) }
            .joined(separator: ", ")
        if !servers.isEmpty {
            findings.append(Finding(category: category, severity: .info, message: "DNS servers: \(servers)", detail: nil))
        }

        return findings
    }

    private func checkWiFiConnection() async -> [Finding] {
        var findings: [Finding] = []
        let category = "Wi-Fi"

        // Check Wi-Fi power
        if let powerResult = try? await shell.runCommand("/usr/sbin/networksetup", "-getairportpower", "en0") {
            if powerResult.output.contains("On") {
                findings.append(Finding(category: category, severity: .ok, message: "Wi-Fi power is on", detail: nil))
            } else {
                findings.append(Finding(category: category, severity: .critical, message: "Wi-Fi power is OFF", detail: nil))
            }
        }

        // Check IP address
        if let infoResult = try? await shell.runCommand("/usr/sbin/networksetup", "-getinfo", "Wi-Fi") {
            let lines = infoResult.output.components(separatedBy: "\n")
            if let ipLine = lines.first(where: { $0.hasPrefix("IP address:") }) {
                let ip = ipLine.components(separatedBy: ": ").last?.trimmingCharacters(in: .whitespaces) ?? ""
                if !ip.isEmpty && ip != "none" {
                    findings.append(Finding(category: category, severity: .ok, message: "Connected with IP: \(ip)", detail: nil))
                } else {
                    findings.append(Finding(category: category, severity: .warning, message: "No IP address assigned", detail: nil))
                }
            } else {
                findings.append(Finding(category: category, severity: .warning, message: "No IP address assigned", detail: nil))
            }
        }

        return findings
    }

    private func checkSignalStrength() async -> [Finding] {
        var findings: [Finding] = []
        let category = "Wi-Fi"

        guard let result = try? await shell.runCommand("/usr/sbin/system_profiler", "SPAirPortDataType", timeout: 15) else {
            return findings
        }

        let lines = result.output.components(separatedBy: "\n")

        if let signalLine = lines.first(where: { $0.contains("Signal / Noise") }) {
            // Format is typically "Signal / Noise: -58 dBm / -90 dBm"
            let value = signalLine.components(separatedBy: ": ").last?.trimmingCharacters(in: .whitespaces) ?? ""
            // Parse signal dBm (first number, e.g. "-58")
            let signalStr = value.components(separatedBy: " ").first ?? ""
            let signalVal = Int(signalStr) ?? 0

            if signalVal < -70 {
                findings.append(Finding(category: category, severity: .warning, message: "Weak signal: \(value)", detail: nil))
            } else {
                findings.append(Finding(category: category, severity: .ok, message: "Signal strength: \(value)", detail: nil))
            }
        }

        return findings
    }

    private func checkVPN() async -> [Finding] {
        var findings: [Finding] = []
        let category = "VPN"

        guard let result = try? await shell.runCommand("/usr/sbin/scutil", "--nc", "list") else {
            return findings
        }

        let lines = result.output.components(separatedBy: "\n")

        // Check for Invalid VPN configs
        let invalidLines = lines.filter { $0.contains("Invalid") }
        if !invalidLines.isEmpty {
            let detail = invalidLines.joined(separator: "\n")
            findings.append(Finding(
                category: category, severity: .warning,
                message: "Invalid VPN configuration detected (should be removed)",
                detail: detail
            ))
        }

        // Count active VPN connections
        let connectedCount = lines.filter { $0.contains("Connected") }.count
        if connectedCount > 0 {
            findings.append(Finding(category: category, severity: .info, message: "\(connectedCount) active VPN connection(s)", detail: nil))
        }

        return findings
    }

    private func checkConnectivity() async -> [Finding] {
        var findings: [Finding] = []
        let category = "Connectivity"

        // Find the gateway/router IP
        var gateway: String?
        if let infoResult = try? await shell.runCommand("/usr/sbin/networksetup", "-getinfo", "Wi-Fi") {
            let lines = infoResult.output.components(separatedBy: "\n")
            if let routerLine = lines.first(where: { $0.contains("Router") }) {
                gateway = routerLine.components(separatedBy: ": ").last?.trimmingCharacters(in: .whitespaces)
            }
        }

        // Ping gateway
        if let gw = gateway, !gw.isEmpty {
            if let result = try? await shell.runCommand("/sbin/ping", "-c", "1", "-W", "3", gw, timeout: 5) {
                if result.exitCode == 0 {
                    findings.append(Finding(category: category, severity: .ok, message: "Router is reachable", detail: nil))
                } else {
                    findings.append(Finding(category: category, severity: .warning, message: "Router is NOT reachable", detail: nil))
                }
            }
        }

        // Ping 8.8.8.8
        if let result = try? await shell.runCommand("/sbin/ping", "-c", "1", "-W", "3", "8.8.8.8", timeout: 5) {
            if result.exitCode == 0 {
                findings.append(Finding(category: category, severity: .ok, message: "Internet is reachable (8.8.8.8)", detail: nil))
            } else {
                findings.append(Finding(category: category, severity: .warning, message: "Internet is NOT reachable", detail: nil))
            }
        }

        // DNS resolution
        if let result = try? await shell.runCommand("/usr/bin/nslookup", "apple.com", timeout: 5) {
            if result.exitCode == 0 {
                findings.append(Finding(category: category, severity: .ok, message: "DNS resolution working", detail: nil))
            } else {
                findings.append(Finding(category: category, severity: .warning, message: "DNS resolution FAILED", detail: nil))
            }
        }

        return findings
    }

    private func getMacOSVersion() async -> String {
        guard let result = try? await shell.runCommand("/usr/bin/sw_vers", "-productVersion") else {
            return "Unknown"
        }
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
