import Foundation

struct DisconnectEvent: Codable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let reason: String              // Diagnosed failure: "No IP", "No SSID", "No Power", "Disconnected"
    let duration: TimeInterval      // How long the disconnect lasted (0 if still ongoing)
    let reconnected: Bool
    let recoveryMethod: String?     // What fixed it: "Auto-recovery", "DHCP Renewal", "Reassociate", etc.

    init(
        date: Date = Date(),
        reason: String,
        duration: TimeInterval = 0,
        reconnected: Bool = false,
        recoveryMethod: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.reason = reason
        self.duration = duration
        self.reconnected = reconnected
        self.recoveryMethod = recoveryMethod
    }
}
