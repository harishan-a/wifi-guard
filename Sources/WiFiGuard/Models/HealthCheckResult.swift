import Foundation

enum HealthCheckResult: String, Sendable {
    case healthy
    case noPower       // Wi-Fi hardware is off
    case noSSID        // Not associated with any network
    case noIP          // No IP address assigned
    case noGateway     // Can't reach gateway
    case noInternet    // Can't reach external IPs
    case noDNS         // DNS resolution failing

    var label: String {
        switch self {
        case .healthy:    return "Healthy"
        case .noPower:    return "Wi-Fi Off"
        case .noSSID:     return "Disconnected"
        case .noIP:       return "No IP Address"
        case .noGateway:  return "Gateway Unreachable"
        case .noInternet: return "No Internet"
        case .noDNS:      return "DNS Failure"
        }
    }

    var isHealthy: Bool { self == .healthy }
}
