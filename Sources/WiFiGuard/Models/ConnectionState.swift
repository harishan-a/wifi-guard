import Foundation
import SwiftUI

@Observable
final class ConnectionState {
    var isConnected: Bool = false
    var ssid: String = ""
    var ipAddress: String = ""
    var gatewayIP: String = ""
    var gatewayLatencyMs: Double? = nil
    var rssi: Int = 0
    var isWiFiPoweredOn: Bool = true
    var connectedSince: Date? = nil

    var uptimeString: String {
        guard let connectedSince else { return "--" }
        let interval = Date().timeIntervalSince(connectedSince)
        return DurationFormatter.format(interval)
    }
}
