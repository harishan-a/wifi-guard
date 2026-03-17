import Foundation

enum MenuBarIcon {
    static func systemImageName(isConnected: Bool, isWiFiOn: Bool, rssi: Int) -> String {
        guard isWiFiOn else {
            return "wifi.slash"
        }
        guard isConnected else {
            return "wifi.slash"
        }
        if rssi >= -70 {
            return "wifi"
        } else {
            return "wifi.exclamationmark"
        }
    }
}
