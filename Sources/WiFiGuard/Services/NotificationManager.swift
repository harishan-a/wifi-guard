import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private let center: UNUserNotificationCenter?

    private init() {
        // UNUserNotificationCenter.current() crashes if there is no bundle identifier,
        // so guard before accessing it.
        if Bundle.main.bundleIdentifier != nil {
            center = UNUserNotificationCenter.current()
        } else {
            center = nil
        }
    }

    func requestAuthorization() async {
        _ = try? await center?.requestAuthorization(options: [.alert, .sound])
    }

    func send(title: String, body: String) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func notifyReconnected(ssid: String, ip: String) {
        send(title: "Wi-Fi Reconnected", body: "Connected to \(ssid) (\(ip))")
    }

    func notifyReconnectFailed(attempt: Int) {
        send(title: "Wi-Fi Reconnect Failed", body: "Attempt \(attempt) failed")
    }

    func notifyNetworkChange(detail: String) {
        send(title: "Network Changed", body: detail)
    }
}
