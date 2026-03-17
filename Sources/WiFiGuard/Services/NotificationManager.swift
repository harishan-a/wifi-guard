import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    /// Request notification authorization.
    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    /// Send a local notification.
    func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // deliver immediately
        )
        center.add(request)
    }

    /// Notify successful reconnection.
    func notifyReconnected(ssid: String, ip: String) {
        send(title: "Wi-Fi Reconnected", body: "Connected to \(ssid) (\(ip))")
    }

    /// Notify failed reconnection.
    func notifyReconnectFailed(attempt: Int) {
        send(title: "Wi-Fi Reconnect Failed", body: "Attempt \(attempt) failed")
    }

    /// Notify network change.
    func notifyNetworkChange(detail: String) {
        send(title: "Network Changed", body: detail)
    }
}
