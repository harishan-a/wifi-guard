import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private var center: UNUserNotificationCenter? {
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        return UNUserNotificationCenter.current()
    }

    private init() {}

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
