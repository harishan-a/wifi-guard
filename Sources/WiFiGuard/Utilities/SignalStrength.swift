import Foundation

enum SignalStrength {
    case excellent
    case good
    case fair
    case poor
    case noSignal

    static func from(rssi: Int) -> SignalStrength {
        switch rssi {
        case (-50)...:     return .excellent
        case -60 ..< -50: return .good
        case -70 ..< -60: return .fair
        case -80 ..< -70: return .poor
        default:           return .noSignal
        }
    }

    var label: String {
        switch self {
        case .excellent: "Excellent"
        case .good:      "Good"
        case .fair:      "Fair"
        case .poor:      "Poor"
        case .noSignal:  "No Signal"
        }
    }

    var sfSymbol: String {
        switch self {
        case .excellent: "wifi"
        case .good:      "wifi"
        case .fair:      "wifi.exclamationmark"
        case .poor:      "wifi.exclamationmark"
        case .noSignal:  "wifi.slash"
        }
    }
}
