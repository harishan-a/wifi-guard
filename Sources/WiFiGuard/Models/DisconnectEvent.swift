import Foundation

struct DisconnectEvent: Codable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let reason: String     // e.g. "No gateway", "No SSID"
    let duration: TimeInterval  // how long the disconnect lasted (0 if still ongoing)
    let reconnected: Bool

    init(date: Date = Date(), reason: String, duration: TimeInterval = 0, reconnected: Bool = false) {
        self.id = UUID()
        self.date = date
        self.reason = reason
        self.duration = duration
        self.reconnected = reconnected
    }
}
