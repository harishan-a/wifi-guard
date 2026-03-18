import Foundation
import SystemConfiguration
import Darwin

/// Zero-overhead network queries using system calls and SystemConfiguration
/// instead of spawning shell processes. These are ~1000x faster than the
/// equivalent `ipconfig` / `networksetup` commands.
enum NetworkQueries {

    /// Get the IPv4 address for a network interface using getifaddrs() syscall.
    /// Returns nil if the interface has no IPv4 address.
    /// Cost: ~0.01ms (vs ~50-100ms for `ipconfig getifaddr en0`).
    static func ipAddress(for interfaceName: String) -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(firstAddr) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let entry = cursor {
            let name = String(cString: entry.pointee.ifa_name)
            if name == interfaceName,
               let addr = entry.pointee.ifa_addr,
               addr.pointee.sa_family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let result = getnameinfo(
                    addr,
                    socklen_t(addr.pointee.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil, 0,
                    NI_NUMERICHOST
                )
                if result == 0 {
                    return String(cString: hostname)
                }
            }
            cursor = entry.pointee.ifa_next
        }
        return nil
    }

    /// Get the default gateway (router) IP from SystemConfiguration.
    /// Cost: ~0.1ms (vs ~50-100ms for `networksetup -getinfo Wi-Fi`).
    static func gatewayIP() -> String? {
        guard let store = SCDynamicStoreCreate(nil, "WiFiGuard" as CFString, nil, nil) else {
            return nil
        }
        guard let dict = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
              let router = dict["Router"] as? String else {
            return nil
        }
        return router
    }
}
